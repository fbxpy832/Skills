"""Tests for simulator module - simulation and trigger price calculation."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from simulator import simulate, calculate_trigger_prices, estimate_base_price
from rules import get_threshold


def test_simulate_normal():
    result = simulate("603629.SH", stock_change=7.0, index_change=1.0, window=30)
    assert result["board"] == "主板_SH"
    assert result["deviation"] == 6.0
    assert result["risk_level"] == "正常"
    assert not result["triggered"]


def test_simulate_triggered():
    result = simulate("603629.SH", stock_change=210.0, index_change=5.0, window=30)
    assert result["deviation"] == 205.0
    assert result["triggered"] is True
    assert result["risk_level"] == "已触发"


def test_simulate_negative_triggered():
    result = simulate("603629.SH", stock_change=-80.0, index_change=-5.0, window=30)
    deviation = -80.0 - (-5.0)
    assert result["deviation"] == deviation
    assert result["triggered"] is True


def test_simulate_gem():
    """GEM (创业板) has 30% threshold for 3-day."""
    result = simulate("300750.SZ", stock_change=28.0, index_change=1.0, window=3)
    assert result["board"] == "创业板"
    assert result["deviation"] == 27.0
    assert result["threshold_positive"] == 30.0
    assert result["risk_level"] == "极高风险"
    assert not result["triggered"]


def test_simulate_star():
    result = simulate("688001.SH", stock_change=15.0, index_change=1.0, window=10)
    assert result["board"] == "科创板"
    assert result["threshold_positive"] == 100.0


def test_simulate_bj():
    result = simulate("830001.BJ", stock_change=35.0, index_change=1.0, window=3)
    assert result["board"] == "北交所"
    assert result["threshold_positive"] == 40.0
    # deviation=34, remaining=6 → 高风险
    assert result["risk_level"] == "高风险"


def test_trigger_prices():
    result = calculate_trigger_prices("603629.SH", base_price=10.0, window=30)
    assert len(result["scenarios"]) == 5
    # With index change 0%, need stock return = threshold = 200%
    assert result["scenarios"][2]["trigger_price"] == 30.0  # base=10 * (1+200/100)
    assert result["scenarios"][2]["needed_stock_return"] == 200.0


def test_trigger_prices_custom_threshold():
    result = calculate_trigger_prices("603629.SH", base_price=10.0, window=3, threshold_val=20.0)
    assert result["threshold"] == 20.0
    # Index 0%, need 20% return → price=12
    assert result["scenarios"][2]["trigger_price"] == 12.0


def test_trigger_prices_negative_index():
    result = calculate_trigger_prices("603629.SH", base_price=10.0, window=30, threshold_val=200.0)
    # Index -2%: need 200 + (-2) = 198% return → price=29.8
    assert result["scenarios"][0]["index_change"] == -2.0
    assert abs(result["scenarios"][0]["needed_stock_return"] - 198.0) < 0.01
    assert abs(result["scenarios"][0]["trigger_price"] - 29.8) < 0.01


def test_estimate_base_price_invalid():
    """estimate_base_price with insufficient data should raise."""
    import pandas as pd
    df = pd.DataFrame({
        "trade_date": ["20260101", "20260102"],
        "adj_close": [10.0, 11.0],
    })
    try:
        estimate_base_price(df, window=30)
        assert False, "Should have raised ValueError"
    except ValueError:
        pass


def test_estimate_base_price_valid():
    import pandas as pd
    df = pd.DataFrame({
        "trade_date": [f"202601{str(i).zfill(2)}" for i in range(5, 40)],
        "adj_close": [10.0 + i * 0.5 for i in range(35)],
    })
    result = estimate_base_price(df, window=30)
    assert result["base_price"] > 0
    assert result["base_date"] is not None
    assert result["latest_date"] is not None
    assert result["stock_return_since_base"] is not None


if __name__ == "__main__":
    for name, fn in sorted({k: v for k, v in globals().items() if k.startswith("test_")}.items()):
        try:
            fn()
            print(f"  PASS: {name}")
        except Exception as e:
            print(f"  FAIL: {name} - {e}")