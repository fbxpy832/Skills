"""Tests for calculator module - deviation calculation logic."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from calculator import DeviationCalculator
from rules import get_threshold, get_risk_level


def test_rules_get_threshold():
    t = get_threshold("主板_SH", False, 3)
    assert t["positive"] == 20.0


def test_get_risk_level_triggered():
    risk, rem = get_risk_level(22.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "已触发"
    assert rem == 0.0


def test_get_risk_level_not_triggered():
    risk, rem = get_risk_level(15.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "高风险"
    assert abs(rem - 5.0) < 0.01


def test_get_risk_level_negative():
    risk, rem = get_risk_level(-15.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "高风险"
    assert abs(rem - 5.0) < 0.01


def test_get_risk_level_edge_trigger_positive():
    risk, rem = get_risk_level(20.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "已触发"


def test_get_risk_level_edge_trigger_negative():
    risk, rem = get_risk_level(-20.0, {"positive": 20.0, "negative": -20.0, "window_days": 3})
    assert risk == "已触发"


if __name__ == "__main__":
    for name, fn in sorted({k: v for k, v in globals().items() if k.startswith("test_")}.items()):
        try:
            fn()
            print(f"  PASS: {name}")
        except Exception as e:
            print(f"  FAIL: {name} - {e}")