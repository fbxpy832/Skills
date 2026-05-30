"""Threshold definitions and risk level classification for A-share abnormal movement monitoring.

Risk levels (by remaining distance before triggering):
  已触发    — threshold reached or exceeded
  极高风险  — remaining <= 3%
  高风险    — remaining <= 8%
  接近      — remaining <= 15%
  正常      — remaining > 15%
"""

# Default thresholds per board and window
# Format: (positive_threshold, negative_threshold)
# positive_threshold: e.g. 20 means +20%
# negative_threshold: e.g. -20 means -20%, None means no negative threshold
BOARD_THRESHOLDS = {
    "主板_SH": {
        3:  (20.0, -20.0),
        10: (100.0, -50.0),
        30: (200.0, -70.0),
    },
    "主板_SZ": {
        3:  (20.0, -20.0),
        10: (100.0, -50.0),
        30: (200.0, -70.0),
    },
    "创业板": {
        3:  (30.0, -30.0),
        10: (100.0, -50.0),
        30: (200.0, -70.0),
    },
    "科创板": {
        3:  (30.0, -30.0),
        10: (100.0, -50.0),
        30: (200.0, -70.0),
    },
    "北交所": {
        3:  (40.0, -40.0),
        10: (100.0, -50.0),
        30: (200.0, -70.0),
    },
}

# ST/*ST stock thresholds (override for 3-day)
ST_3DAY_POSITIVE = 12.0
ST_3DAY_NEGATIVE = -12.0


def get_threshold(board, is_st, window_days):
    """Get threshold for a board/st/window combination.

    Args:
        board: Board name string.
        is_st: True if stock is ST/*ST.
        window_days: 3, 10, or 30.

    Returns:
        dict with keys: window_days, positive, negative
    """
    board_key = board
    if board_key not in BOARD_THRESHOLDS:
        raise ValueError(f"Unknown board: {board}")

    thresholds = BOARD_THRESHOLDS[board_key]
    if window_days not in thresholds:
        raise ValueError(f"Unsupported window: {window_days} days")

    pos, neg = thresholds[window_days]

    # ST/*ST overrides for 3-day window
    if is_st and window_days == 3:
        pos = ST_3DAY_POSITIVE
        neg = ST_3DAY_NEGATIVE

    return {
        "window_days": window_days,
        "positive": pos,
        "negative": neg,
    }


def get_risk_level(deviation, threshold, triggered=False):
    """Determine risk level based on deviation vs threshold.

    Args:
        deviation: Calculated deviation value (percentage).
        threshold: Dict from get_threshold().
        triggered: Whether already triggered.

    Returns:
        (risk_level_string, remaining_distance)
    """
    pos = threshold["positive"]
    neg = threshold["negative"]

    if triggered or (pos is not None and deviation >= pos) or (neg is not None and deviation <= neg):
        return "已触发", 0.0

    # Remaining distance in the direction of the deviation
    if deviation >= 0:
        remaining = (pos - deviation) if pos is not None else float("inf")
    else:
        remaining = (deviation - neg) if neg is not None else float("inf")

    remaining = max(remaining, 0.0)

    if remaining <= 3.0:
        return "极高风险", remaining
    elif remaining <= 8.0:
        return "高风险", remaining
    elif remaining <= 15.0:
        return "接近", remaining
    else:
        return "正常", remaining