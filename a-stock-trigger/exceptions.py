"""Custom exceptions for a-stock-trigger."""


class AStockTriggerError(Exception):
    """Base exception for a-stock-trigger."""
    pass


class TushareTokenNotConfiguredError(AStockTriggerError):
    """Raised when Tushare token is not configured."""
    def __init__(self, message=None):
        super().__init__(
            message or "Tushare token not configured. "
            "Use `init --token <token>` or set TUSHARE_TOKEN env var."
        )


class TushareAPIError(AStockTriggerError):
    """Raised when Tushare API call fails."""
    pass


class TushareRateLimitError(TushareAPIError):
    """Raised when Tushare API rate limit is hit."""
    pass


class StockCodeInvalidError(AStockTriggerError):
    """Raised when stock code format is invalid."""
    pass


class DataNotEnoughError(AStockTriggerError):
    """Raised when not enough trading data for calculation."""
    pass


class DataEmptyError(AStockTriggerError):
    """Raised when Tushare returns empty data."""
    pass


class IndexDataMissingError(AStockTriggerError):
    """Raised when index data is missing for required dates."""
    pass


class TradingDayNotExistsError(AStockTriggerError):
    """Raised when given date is not a trading day."""
    pass


class StockSuspendedError(AStockTriggerError):
    """Raised when stock is suspended (no trading data in period)."""
    pass