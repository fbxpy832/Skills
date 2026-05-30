"""Tests for rules module - threshold definitions and risk level classification."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from rules import get_threshold, get_risk_level, BOARD_THRESHOLDS


def test_get_threshold_main_board_3day():
    t = get_threshold("主板_SH", is_st=False, window_days=3)
    assert t["positive"] == 20.0
    assert t["negative"] == -20.0
    assert t["window_days"] == 3


def test_get_threshold_main_board_10day():
    t = get_threshold("主板_SH", is_st=False, window_days=10)
    assert t["positive"] == 100.0
    assert t["negative"] == -50.0


def test_get_threshold_main_board_30day():
    t = get_threshold("主板_SH", is_st=False, window_days=30)
    assert t["positive"] == 200.0
    assert t["negative"] == -70.0


def test_get_threshold_st_3day():
    t = get_threshold("主板_SH", is_st=True, window_days=3)
    assert t["positive"] == 12.0
    assert t["negative"] == -12.0


def test_get_threshold_gem_3day():
    t = get_threshold("创业板", is_st=False, window_days=3)
    assert t["positive"] == 30.0
    assert t["negative"] == -30.0


def test_get_threshold_star_3day():
    t = get_threshold("科创板", is_st=False, window_days=3)
    assert t["positive"] == 30.0
    assert t["negative"] == -30.0


def test_get_threshold_bj_3day():
    t = get_threshold("北交所", is_st=False, window_days=3)
    assert t["positive"] == 40.0
    assert t["negative"] == -40.0


def test_all_boards_defined():
    """All boards must have thresholds for 3, 10, 30 day windows."""
    for board, windows in BOARD_THRESHOLDS.items():
        for w in [3, 10, 30]:
            assert w in windows, f"{board} missing {w}-day threshold"


def test_risk_normal():
    # deviation=5, pos=20 → remaining=15 → 接近 (<=15%)
    risk, rem = get_risk_level(5.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "接近"
    assert rem == 15.0


def test_risk_close():
    # deviation=12, pos=20 → remaining=8 → 高风险 (<=8%)
    risk, rem = get_risk_level(12.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "高风险"
    assert abs(rem - 8.0) < 0.01


def test_risk_high():
    # deviation=14, pos=20 → remaining=6 → 高风险 (<=8%)
    risk, rem = get_risk_level(14.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "高风险"
    assert abs(rem - 6.0) < 0.01


def test_risk_extreme():
    # deviation=18, pos=20 → remaining=2 → 极高风险 (<=3%)
    risk, rem = get_risk_level(18.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "极高风险"
    assert abs(rem - 2.0) < 0.01


def test_risk_triggered_positive():
    risk, rem = get_risk_level(20.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "已触发"
    assert rem == 0.0


def test_risk_triggered_negative():
    risk, rem = get_risk_level(-25.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "已触发"
    assert rem == 0.0


def test_risk_negative_deviation():
    """Negative deviation -10: remaining = |-10 - (-20)| = 10 → 接近 (<=15%)."""
    risk, rem = get_risk_level(-10.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "接近"
    assert abs(rem - 10.0) < 0.01


def test_risk_explicit_triggered_flag():
    risk, rem = get_risk_level(15.0, {"positive": 20.0, "negative": -20.0}, triggered=True)
    assert risk == "已触发"
    assert rem == 0.0


def test_risk_st_30day():
    """ST stock with 30-day threshold: negative = -70%."""
    risk, rem = get_risk_level(-60.0, {"positive": 200.0, "negative": -70.0, "window_days": 30})
    assert risk == "接近"  # remaining = |-60 - (-70)| = 10
    assert abs(rem - 10.0) < 0.01


def test_get_threshold_invalid_board():
    try:
        get_threshold("非主板", is_st=False, window_days=3)
        assert False, "Should have raised ValueError"
    except ValueError:
        pass


def test_get_threshold_invalid_window():
    try:
        get_threshold("主板_SH", is_st=False, window_days=50)
        assert False, "Should have raised ValueError"
    except ValueError:
        pass


if __name__ == "__main__":
    for name, fn in sorted({k: v for k, v in globals().items() if k.startswith("test_")}.items()):
        try:
            fn()
            print(f"  PASS: {name}")
        except Exception as e:
            print(f"  FAIL: {name} - {e}")