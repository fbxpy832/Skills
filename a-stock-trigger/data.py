"""Tushare Pro data access layer with retry, rate limiting, and caching."""

import os
import time
import pickle
import hashlib
import tushare as ts
import pandas as pd
from datetime import date, timedelta
from pathlib import Path

from exceptions import (
    TushareTokenNotConfiguredError,
    TushareAPIError,
    TushareRateLimitError,
    DataEmptyError,
)

CACHE_DIR = Path(__file__).parent / ".cache"
CACHE_TTL_HOURS = 4  # Cache API responses for 4 hours


class TushareProData:
    """Wrapper around Tushare Pro API with caching and retry.

    Free tier rate limits (approximate):
      - Most endpoints: ~1 call/second
      - Some endpoints (adj_factor, index_daily): 1 call/minute
    We use file-based caching + pacing to stay within limits.
    """

    def __init__(self, token):
        if not token:
            raise TushareTokenNotConfiguredError()
        self.pro = ts.pro_api(token)
        self._mem_cache = {}
        self._last_call_time = 0.0
        self._min_interval = 1.2
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def _pace(self):
        """Ensure minimum interval between API calls."""
        now = time.time()
        elapsed = now - self._last_call_time
        if elapsed < self._min_interval:
            time.sleep(self._min_interval - elapsed)
        self._last_call_time = time.time()

    def _cache_key(self, prefix, **kwargs):
        items = sorted(kwargs.items())
        key_str = f"{prefix}:" + ":".join(f"{k}={v}" for k, v in items)
        return key_str

    def _mem_get(self, key):
        return self._mem_cache.get(key)

    def _mem_set(self, key, df):
        self._mem_cache[key] = df.copy()

    def _disk_get(self, key):
        """Load from file cache if fresh."""
        cache_file = CACHE_DIR / hashlib.md5(key.encode()).hexdigest()
        if not cache_file.exists():
            return None
        try:
            mtime = os.path.getmtime(cache_file)
            age_hours = (time.time() - mtime) / 3600
            if age_hours > CACHE_TTL_HOURS:
                cache_file.unlink(missing_ok=True)
                return None
            with open(cache_file, "rb") as f:
                return pickle.load(f)
        except Exception:
            return None

    def _disk_set(self, key, df):
        """Save to file cache."""
        try:
            cache_file = CACHE_DIR / hashlib.md5(key.encode()).hexdigest()
            with open(cache_file, "wb") as f:
                pickle.dump(df, f)
        except Exception:
            pass  # Non-critical; skip disk cache on error

    def _get_cached(self, key):
        """Try memory cache, then disk cache."""
        df = self._mem_get(key)
        if df is not None:
            return df
        df = self._disk_get(key)
        if df is not None:
            self._mem_set(key, df)
            return df
        return None

    def _set_cached(self, key, df):
        self._mem_set(key, df)
        self._disk_set(key, df)

    def _call_with_retry(self, api_func, description="", max_retries=3):
        """Call a Tushare API function with pacing, retry on rate limit / transient errors."""
        for attempt in range(max_retries):
            self._pace()
            try:
                result = api_func()
                if result is None:
                    raise DataEmptyError(f"No data returned: {description}")
                return result
            except DataEmptyError:
                raise
            except Exception as e:
                err_str = str(e).lower()
                if "rate" in err_str or "次数" in err_str or "频次" in err_str:
                    # Free tier: many endpoints have 1/min limit
                    # Wait 65s on retry to let the window reset
                    if attempt < max_retries - 1:
                        wait_time = 65.0
                        time.sleep(wait_time)
                        continue
                    raise TushareRateLimitError(
                        f"API rate limit exceeded ({description}). "
                        "Tushare free tier may limit to 1 call/min per endpoint. "
                        "Use `sleep 65 && python3 main.py check ...` between runs, "
                        "or upgrade Tushare Pro for higher limits. "
                        f"Details: {e}"
                    ) from e
                if "过载" in err_str or "timeout" in err_str or "无权限" in err_str:
                    if attempt < max_retries - 1:
                        time.sleep(1.0 * (attempt + 1))
                        continue
                    raise TushareAPIError(
                        f"API call failed ({description}): {e}"
                    ) from e
                raise TushareAPIError(
                    f"API call failed ({description}): {e}"
                ) from e
        raise TushareAPIError(f"API call failed after {max_retries} retries: {description}")

    def daily(self, ts_code, start_date, end_date):
        """Get daily k-line data for a stock."""
        ck = self._cache_key("daily", ts_code=ts_code, start=start_date, end=end_date)
        cached = self._get_cached(ck)
        if cached is not None:
            return cached

        def _fetch():
            return self.pro.daily(
                ts_code=ts_code, start_date=start_date, end_date=end_date
            )

        df = self._call_with_retry(_fetch, f"daily {ts_code} {start_date}-{end_date}")
        if df.empty:
            raise DataEmptyError(
                f"No daily data for {ts_code} from {start_date} to {end_date}"
            )
        df["trade_date"] = df["trade_date"].astype(str)
        self._set_cached(ck, df)
        return df

    def daily_adj(self, ts_code, start_date, end_date):
        """Get forward-adjusted daily data (one API call, no separate adj_factor needed)."""
        ck = self._cache_key("daily_adj", ts_code=ts_code, start=start_date, end=end_date)
        cached = self._get_cached(ck)
        if cached is not None:
            return cached

        def _fetch():
            return self.pro.daily(
                ts_code=ts_code, start_date=start_date, end_date=end_date, adj="qfq"
            )

        df = self._call_with_retry(
            _fetch, f"daily_adj {ts_code} {start_date}-{end_date}"
        )
        if df.empty:
            raise DataEmptyError(
                f"No daily data for {ts_code} from {start_date} to {end_date}"
            )
        df["trade_date"] = df["trade_date"].astype(str)
        df["adj_close"] = df["close"].astype(float)
        self._set_cached(ck, df)
        return df

    def index_daily(self, ts_code, start_date, end_date):
        """Get index daily data.

        Uses Tushare index_daily (with caching), falls back to AKShare
        when Tushare free tier rate limit is exceeded.
        """
        ck = self._cache_key("index_daily", ts_code=ts_code, start=start_date, end=end_date)
        cached = self._get_cached(ck)
        if cached is not None:
            return cached

        # Primary: Try Tushare index_daily
        try:
            def _fetch():
                return self.pro.index_daily(
                    ts_code=ts_code, start_date=start_date, end_date=end_date
                )

            df = self._call_with_retry(
                _fetch, f"index_daily {ts_code} {start_date}-{end_date}"
            )
        except TushareRateLimitError:
            # Fallback: AKShare (no rate limits for individual users)
            try:
                df = self._index_daily_akshare(ts_code, start_date, end_date)
            except Exception as ake:
                raise DataEmptyError(
                    f"Index data unavailable for {ts_code} "
                    f"(Tushare rate-limited and AKShare fallback failed: {ake})"
                )

        if df.empty:
            raise DataEmptyError(
                f"No index data for {ts_code} from {start_date} to {end_date}"
            )
        df["trade_date"] = df["trade_date"].astype(str)
        self._set_cached(ck, df)
        return df

    def _index_daily_akshare(self, ts_code, start_date, end_date):
        """Fetch index daily data via AKShare as free-tier fallback."""
        import akshare as ak

        # Map Tushare index codes to AKShare symbols
        AK_CODE_MAP = {
            "000001.SH": "sh000001",
            "399107.SZ": "sz399107",
            "399102.SZ": "sz399102",
            "000688.SH": "sh000688",
            "899050.BJ": "bj899050",
        }

        aksymbol = AK_CODE_MAP.get(ts_code)
        if not aksymbol:
            raise ValueError(f"No AKShare mapping for {ts_code}")

        df = ak.stock_zh_index_daily(symbol=aksymbol)
        if df.empty:
            raise DataEmptyError(f"AKShare returned no data for {ts_code}")

        # Rename columns to match Tushare format
        df = df.rename(columns={
            "date": "trade_date",
            "open": "open",
            "high": "high",
            "low": "low",
            "close": "close",
            "volume": "vol",
        })
        df["trade_date"] = pd.to_datetime(df["trade_date"]).dt.strftime("%Y%m%d")

        # Filter by date range
        df = df[(df["trade_date"] >= start_date) & (df["trade_date"] <= end_date)]
        df = df.sort_values("trade_date").reset_index(drop=True)

        return df

    def adj_factor(self, ts_code, start_date, end_date):
        """Get adjustment factors for a stock."""
        ck = self._cache_key(
            "adj_factor", ts_code=ts_code, start=start_date, end=end_date
        )
        cached = self._get_cached(ck)
        if cached is not None:
            return cached

        def _fetch():
            return self.pro.adj_factor(
                ts_code=ts_code, start_date=start_date, end_date=end_date
            )

        try:
            df = self._call_with_retry(
                _fetch, f"adj_factor {ts_code} {start_date}-{end_date}"
            )
            if df.empty:
                # Return empty DataFrame with expected columns instead of raising
                return pd.DataFrame(columns=["trade_date", "adj_factor"])
            df["trade_date"] = df["trade_date"].astype(str)
            self._set_cached(ck, df)
            return df
        except DataEmptyError:
            return pd.DataFrame(columns=["trade_date", "adj_factor"])

    def stock_info(self, ts_code):
        """Get stock basic info (name, listing date, etc.)."""
        ck = self._cache_key("stock_info", ts_code=ts_code)
        cached = self._get_cached(ck)
        if cached is not None:
            return cached

        def _fetch():
            return self.pro.stock_basic(ts_code=ts_code)

        try:
            df = self._call_with_retry(_fetch, f"stock_basic {ts_code}")
            if df.empty:
                # Try alternate endpoint
                def _fetch_alt():
                    return self.pro.daily_basic(ts_code=ts_code, start_date="20200101")

                df_alt = self._call_with_retry(
                    _fetch_alt, f"daily_basic {ts_code}"
                )
                if df_alt.empty:
                    raise DataEmptyError(f"No stock info found for {ts_code}")
                self._cache[ck] = df_alt.copy()
                return df_alt
            self._set_cached(ck, df)
            return df
        except DataEmptyError:
            raise DataEmptyError(f"No stock info found for {ts_code}")

    def trade_cal(self, start_date, end_date):
        """Get trading calendar."""
        ck = self._cache_key("trade_cal", start=start_date, end=end_date)
        cached = self._get_cached(ck)
        if cached is not None:
            return cached

        def _fetch():
            return self.pro.trade_cal(
                start_date=start_date, end_date=end_date
            )

        df = self._call_with_retry(
            _fetch, f"trade_cal {start_date}-{end_date}"
        )
        df["cal_date"] = df["cal_date"].astype(str)
        self._set_cached(ck, df)
        return df

    def is_trading_day(self, date_str):
        """Check if a date is a trading day."""
        df = self.trade_cal(date_str, date_str)
        if df.empty:
            return False
        return bool(df.iloc[0]["is_open"])

    def latest_trading_day(self):
        """Get the latest trading day as string YYYYMMDD."""
        today_str = date.today().strftime("%Y%m%d")
        # Look back up to 10 days
        for offset in range(10):
            d = (date.today() - timedelta(days=offset)).strftime("%Y%m%d")
            if self.is_trading_day(d):
                return d
        return today_str