"""Core deviation calculation logic for A-share abnormal movement monitoring.

偏离值 = 个股区间涨跌幅 - 对应指数区间涨跌幅
个股区间涨跌幅 = 区间期末收盘价 / 区间期初前收盘价 - 1
指数区间涨跌幅 = 指数期末点位 / 指数期初前收盘点位 - 1
"""

from datetime import date, datetime, timedelta

from exceptions import (
    DataNotEnoughError,
    IndexDataMissingError,
)
from resolver import resolve_board, get_index_info, detect_is_st
from rules import get_threshold, get_risk_level


class DeviationCalculator:
    """Calculator for A-share abnormal movement deviation values."""

    def __init__(self, data_api):
        self.data = data_api

    def check_stock(self, ts_code, windows=None, reset_from=None):
        """Check all deviation windows for a single stock.

        Args:
            ts_code: e.g. '603629.SH'.
            windows: List of window days, e.g. [3, 10, 30].
            reset_from: Optional reset date string YYYYMMDD.

        Returns:
            dict with stock info and per-window results.
        """
        if windows is None:
            windows = [3, 10, 30]

        max_window = max(windows)
        start_date, end_date = self._data_date_range(ts_code, max_window, reset_from)

        # Fetch stock data with forward-adjusted prices (single API call)
        stock_df = self.data.daily_adj(ts_code, start_date, end_date)
        stock_df = stock_df.sort_values("trade_date").reset_index(drop=True)

        if stock_df.empty:
            raise DataNotEnoughError(f"No trading data for {ts_code} in range")

        # Check suspension: if latest date is stale, warn but continue
        latest_date = stock_df["trade_date"].iloc[-1]
        today_str = date.today().strftime("%Y%m%d")
        days_since = (datetime.strptime(today_str, "%Y%m%d") - datetime.strptime(latest_date, "%Y%m%d")).days
        suspended = days_since > 10

        # Get stock info
        stock_name = self._get_stock_name(ts_code)
        board = resolve_board(ts_code)
        is_st = detect_is_st(stock_name)
        index_code, index_name = get_index_info(board)

        # Fetch index data
        try:
            index_df = self.data.index_daily(index_code, start_date, end_date)
            index_df = index_df.sort_values("trade_date").reset_index(drop=True)
        except Exception as e:
            raise IndexDataMissingError(
                f"Cannot fetch index data for {index_code} ({index_name}): {e}"
            )

        # Calculate for each window
        windows_results = {}
        for w in windows:
            try:
                result = self._calc_window(
                    stock_df, index_df, w, board, is_st, reset_from
                )
                windows_results[str(w)] = result
            except DataNotEnoughError as e:
                windows_results[str(w)] = {
                    "window_days": w,
                    "error": str(e),
                    "stock_return": None,
                    "index_return": None,
                    "deviation": None,
                    "threshold_positive": None,
                    "threshold_negative": None,
                    "remaining": None,
                    "triggered": None,
                    "risk_level": "数据不足",
                }

        return {
            "stock": {
                "code": ts_code,
                "name": stock_name,
                "board": board,
                "index_code": index_code,
                "index_name": index_name,
                "is_st": is_st,
                "suspended": suspended,
            },
            "query_date": today_str,
            "data_date": latest_date,
            "price_adjusted": True,
            "windows": windows_results,
        }

    def _get_stock_name(self, ts_code):
        """Get stock name from Tushare."""
        try:
            info_df = self.data.stock_info(ts_code)
            if "name" in info_df.columns and not info_df.empty:
                return str(info_df.iloc[0]["name"])
        except Exception:
            pass
        return ts_code

    def _data_date_range(self, ts_code, max_window, reset_from=None):
        """Determine date range for data fetching."""
        today = date.today()
        # Roughly 2.2x calendar days for trading days, plus extra
        cal_days = int(max_window * 2.2) + 15
        start = (today - timedelta(days=cal_days)).strftime("%Y%m%d")
        end = today.strftime("%Y%m%d")

        if reset_from:
            reset_dt = datetime.strptime(reset_from, "%Y%m%d").date()
            if reset_dt < datetime.strptime(start, "%Y%m%d").date():
                # Need to start from reset date
                start = (reset_dt - timedelta(days=10)).strftime("%Y%m%d")

        return start, end

    def _calc_window(self, stock_df, index_df, window_days, board, is_st, reset_from):
        """Calculate deviation for a single window."""
        total_rows = len(stock_df)

        # Latest data point
        end_idx = total_rows - 1
        window_start_idx = end_idx - window_days

        if reset_from:
            # Find the position of reset_from in the data
            reset_positions = stock_df[stock_df["trade_date"] >= reset_from].index
            if len(reset_positions) > 0:
                reset_idx = reset_positions[0]
                # Effective window start is max(natural_start, reset)
                window_start_idx = max(window_start_idx, reset_idx)

        if window_start_idx < 0:
            raise DataNotEnoughError(
                f"Insufficient data for {window_days}-day window "
                f"(need {window_days + 1} trading days, got {total_rows})"
            )

        base_idx = window_start_idx - 1
        if base_idx < 0:
            raise DataNotEnoughError(
                f"Insufficient data for {window_days}-day window base price"
            )

        # Get prices and dates
        row_base = stock_df.iloc[base_idx]
        row_start = stock_df.iloc[window_start_idx]
        row_end = stock_df.iloc[end_idx]

        base_price = float(row_base["adj_close"])
        end_price = float(row_end["adj_close"])
        base_date = str(row_base["trade_date"])
        window_start_date = str(row_start["trade_date"])
        end_date = str(row_end["trade_date"])

        # Index data matching
        idx_base_row = index_df[index_df["trade_date"] == base_date]
        idx_end_row = index_df[index_df["trade_date"] == end_date]

        if idx_base_row.empty:
            # Try to find the nearest index data before base_date
            idx_available = index_df[index_df["trade_date"] <= base_date]
            if not idx_available.empty:
                idx_base_row = idx_available.tail(1)
            else:
                raise IndexDataMissingError(
                    f"Index data missing for base date {base_date}"
                )

        if idx_end_row.empty:
            idx_available = index_df[index_df["trade_date"] <= end_date]
            if not idx_available.empty:
                idx_end_row = idx_available.tail(1)
            else:
                raise IndexDataMissingError(
                    f"Index data missing for end date {end_date}"
                )

        index_base_close = float(idx_base_row.iloc[0]["close"])
        index_end_close = float(idx_end_row.iloc[0]["close"])

        # Calculate returns
        stock_return = (end_price / base_price - 1) * 100.0
        index_return = (index_end_close / index_base_close - 1) * 100.0
        deviation = stock_return - index_return

        # Get threshold
        threshold = get_threshold(board, is_st, window_days)

        # Determine triggered and risk level
        pos = threshold["positive"]
        neg = threshold["negative"]
        triggered = False
        if pos is not None and deviation >= pos:
            triggered = True
        if neg is not None and deviation <= neg:
            triggered = True

        risk_label, remaining = get_risk_level(deviation, threshold, triggered)

        return {
            "window_days": window_days,
            "stock_return": round(stock_return, 2),
            "index_return": round(index_return, 2),
            "deviation": round(deviation, 2),
            "threshold_positive": pos,
            "threshold_negative": neg,
            "remaining": round(remaining, 2),
            "triggered": triggered,
            "risk_level": risk_label,
            "base_date": base_date,
            "window_start_date": window_start_date,
            "end_date": end_date,
            "base_price": round(base_price, 3),
            "end_price": round(end_price, 3),
            "actual_trading_days": end_idx - window_start_idx + 1,
        }