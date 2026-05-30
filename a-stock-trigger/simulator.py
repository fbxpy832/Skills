"""Simulation and trigger price back-calculation logic.

- simulate: Given assumed stock/index changes, check if triggered
- trigger: Back-calculate trigger prices under different index scenarios
"""

from resolver import resolve_board, get_index_info, detect_is_st
from rules import get_threshold, get_risk_level


def simulate(ts_code, stock_change, index_change, window, is_st=False):
    """Simulate whether a stock would trigger under assumed changes.

    Args:
        ts_code: Stock code for board detection.
        stock_change: Assumed stock price change in %.
        index_change: Assumed index change in %.
        window: Window days (3, 10, 30).
        is_st: Whether stock is ST/*ST.

    Returns:
        dict with simulation result.
    """
    board = resolve_board(ts_code)
    index_code, index_name = get_index_info(board)

    deviation = stock_change - index_change
    threshold = get_threshold(board, is_st, window)

    pos = threshold["positive"]
    neg = threshold["negative"]

    triggered = False
    if pos is not None and deviation >= pos:
        triggered = True
    if neg is not None and deviation <= neg:
        triggered = True

    risk_label, remaining = get_risk_level(deviation, threshold, triggered)

    return {
        "ts_code": ts_code,
        "board": board,
        "index_code": index_code,
        "index_name": index_name,
        "window_days": window,
        "stock_change": stock_change,
        "index_change": index_change,
        "deviation": round(deviation, 2),
        "threshold_positive": pos,
        "threshold_negative": neg,
        "remaining": round(remaining, 2),
        "triggered": triggered,
        "risk_level": risk_label,
    }


def calculate_trigger_prices(
    ts_code, base_price, window, threshold_val=None, is_st=False
):
    """Back-calculate trigger prices under different index scenarios.

    Args:
        ts_code: Stock code for board detection.
        base_price: Base price (close before window start).
        window: Window days (3, 10, 30).
        threshold_val: Override threshold. If None, use default for board+window.
        is_st: Whether stock is ST/*ST.

    Returns:
        dict with trigger price scenarios.
    """
    board = resolve_board(ts_code)
    index_code, index_name = get_index_info(board)

    t = get_threshold(board, is_st, window)
    effective_threshold = threshold_val if threshold_val is not None else t["positive"]

    # Index scenarios to show
    index_scenarios = [-2.0, -1.0, 0.0, 1.0, 2.0]

    scenarios = []
    for idx_chg in index_scenarios:
        needed_stock_return = effective_threshold + idx_chg
        trigger_price = base_price * (1 + needed_stock_return / 100.0)
        scenarios.append({
            "index_change": idx_chg,
            "needed_stock_return": round(needed_stock_return, 2),
            "trigger_price": round(trigger_price, 3),
        })

    return {
        "ts_code": ts_code,
        "board": board,
        "index_code": index_code,
        "index_name": index_name,
        "window_days": window,
        "threshold": t["positive"],
        "threshold_negative": t["negative"],
        "is_st": is_st,
        "base_price": base_price,
        "scenarios": scenarios,
        "generated_at": __import__("datetime").date.today().strftime("%Y-%m-%d"),
    }


def estimate_base_price(stock_df, window, reset_from=None):
    """Estimate base price from stock data for trigger command.

    Uses the close on the day before the window start.

    Args:
        stock_df: DataFrame with adj_close column, sorted by trade_date ascending.
        window: Window days.
        reset_from: Optional reset date string YYYYMMDD.

    Returns:
        (base_price, base_date, latest_price, latest_date, stock_return)
    """
    total = len(stock_df)
    end_idx = total - 1
    window_start_idx = end_idx - window

    if reset_from:
        reset_pos = stock_df[stock_df["trade_date"] >= reset_from].index
        if len(reset_pos) > 0:
            window_start_idx = max(window_start_idx, reset_pos[0])

    base_idx = window_start_idx - 1
    if base_idx < 0:
        raise ValueError("Insufficient data for base price calculation")

    base_price = float(stock_df.iloc[base_idx]["adj_close"])
    base_date = str(stock_df.iloc[base_idx]["trade_date"])
    latest_price = float(stock_df.iloc[end_idx]["adj_close"])
    latest_date = str(stock_df.iloc[end_idx]["trade_date"])
    stock_return = (latest_price / base_price - 1) * 100.0

    return {
        "base_price": round(base_price, 3),
        "base_date": base_date,
        "latest_price": round(latest_price, 3),
        "latest_date": latest_date,
        "stock_return_since_base": round(stock_return, 2),
    }