"""Forward-adjusted price calculation using Tushare adj_factor.

前复权价格 = close × adj_factor / 最新 adj_factor
"""

import pandas as pd


def forward_adjust(stock_df, adj_factor_df):
    """Calculate forward-adjusted close prices.

    Args:
        stock_df: DataFrame with columns [trade_date, close, ...], sorted by trade_date.
        adj_factor_df: DataFrame with columns [trade_date, adj_factor, ...],
                       sorted by trade_date.

    Returns:
        DataFrame with additional 'adj_close' column.
    """
    df = stock_df.copy()
    df = df.sort_values("trade_date")

    # Merge adj_factor
    adj = adj_factor_df[["trade_date", "adj_factor"]].copy()
    adj["trade_date"] = adj["trade_date"].astype(str)
    df["trade_date"] = df["trade_date"].astype(str)

    df = df.merge(adj, on="trade_date", how="left")

    # Forward-fill any missing adj_factor (rare but safe)
    df["adj_factor"] = df["adj_factor"].ffill().bfill()

    if df["adj_factor"].isna().any():
        # No adj_factor available; use raw close
        df["adj_close"] = df["close"].astype(float)
        df["adj_note"] = "未复权"
        return df

    latest_adj = df["adj_factor"].iloc[-1]
    df["adj_close"] = df["close"].astype(float) * df["adj_factor"] / latest_adj
    df["adj_note"] = "前复权"

    return df


def get_latest_adj_price(stock_df, adj_factor_df):
    """Get the latest forward-adjusted close price."""
    adj_df = forward_adjust(stock_df, adj_factor_df)
    return float(adj_df["adj_close"].iloc[-1])