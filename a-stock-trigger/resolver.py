"""Stock code resolution: board detection, index mapping, ST detection."""

from exceptions import StockCodeInvalidError


# Map: board → (index_code, index_name)
BOARD_INDEX_MAP = {
    "主板_SH": ("000001.SH", "上证指数"),
    "主板_SZ": ("399107.SZ", "深证A指"),
    "创业板": ("399102.SZ", "创业板综指"),
    "科创板": ("000688.SH", "科创50"),
    "北交所": ("899050.BJ", "北证50"),
}


def _code_prefix(code_str):
    """Extract the meaningful prefix group from a stock code.

    Returns integer for comparison, e.g. 603629 → 603, 000001 → 0 or 000 → 0.
    """
    # First 3 digits define the group
    prefix = code_str[:3]
    return int(prefix)


def resolve_board(ts_code):
    """Detect board from stock code like 603629.SH.

    Returns:
        board (str): e.g. "主板_SH", "创业板", "科创板", "北交所"
    """
    if "." not in ts_code:
        raise StockCodeInvalidError(
            f"Invalid stock code format: '{ts_code}'. Use format like 603629.SH"
        )

    code_part, exchange = ts_code.rsplit(".", 1)
    exchange = exchange.upper()

    if not code_part.isdigit():
        raise StockCodeInvalidError(
            f"Invalid stock code: '{ts_code}'. Code must be numeric."
        )

    prefix = _code_prefix(code_part)

    if exchange == "SH":
        # SH main board: 600-605, 605 (600xxx-605xxx)
        if 600 <= prefix <= 605:
            return "主板_SH"
        # SH科创板
        elif 688 <= prefix <= 689:
            return "科创板"
        else:
            raise StockCodeInvalidError(
                f"Unknown SH board for code: {ts_code} "
                f"(prefix {prefix}xx)"
            )
    elif exchange == "SZ":
        # SZ main board: 000-001, 002-004 (002 = 中小板, included in 深证A指)
        if prefix <= 4:
            return "主板_SZ"
        # SZ创业板: 300-301
        elif 300 <= prefix <= 301:
            return "创业板"
        elif 200 <= prefix <= 204:
            raise StockCodeInvalidError(f"B-shares not supported: {ts_code}")
        else:
            raise StockCodeInvalidError(
                f"Unknown SZ board for code: {ts_code} "
                f"(prefix {prefix}xx)"
            )
    elif exchange == "BJ":
        # 北交所: 4xx, 8xx codes on BJ exchange
        return "北交所"
    else:
        raise StockCodeInvalidError(
            f"Unknown exchange: '{exchange}' in {ts_code}. "
            "Use .SH, .SZ, or .BJ suffix."
        )


def get_index_info(board):
    """Get (index_code, index_name) for a board."""
    if board in BOARD_INDEX_MAP:
        return BOARD_INDEX_MAP[board]
    raise StockCodeInvalidError(f"No index mapping for board: {board}")


def detect_is_st(name):
    """Detect if stock is ST/*ST from its name."""
    if not name:
        return False
    name_upper = name.upper()
    return name_upper.startswith("ST") or name_upper.startswith("*ST")


def classify_st_status(name):
    """Return ST classification: 'ST', 'STAR_ST', or None."""
    if not name:
        return None
    name_upper = name.upper()
    if name_upper.startswith("*ST"):
        return "STAR_ST"
    if name_upper.startswith("ST"):
        return "ST"
    return None