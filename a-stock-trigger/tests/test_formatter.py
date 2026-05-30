"""Tests for formatter module - output formatting."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from formatter import Formatter


def test_format_error():
    f = Formatter()
    result = f.format_error(ValueError("test error"))
    assert "test error" in result


def test_format_check_normal():
    f = Formatter()
    result = f.format_check({
        "stock": {
            "code": "603629.SH",
            "name": "TestStock",
            "board": "主板_SH",
            "index_code": "000001.SH",
            "index_name": "上证指数",
            "is_st": False,
            "suspended": False,
        },
        "query_date": "2026-05-26",
        "data_date": "2026-05-25",
        "price_adjusted": True,
        "windows": {
            "3": {
                "window_days": 3,
                "stock_return": 1.23,
                "index_return": 0.45,
                "deviation": 0.78,
                "threshold_positive": 20.0,
                "threshold_negative": -20.0,
                "remaining": 19.22,
                "triggered": False,
                "risk_level": "正常",
                "base_date": "20260520",
                "end_date": "20260525",
                "base_price": 10.0,
                "end_price": 10.5,
                "actual_trading_days": 3,
            },
            "10": {
                "window_days": 10,
                "stock_return": 5.0,
                "index_return": 1.0,
                "deviation": 4.0,
                "threshold_positive": 100.0,
                "threshold_negative": -50.0,
                "remaining": 96.0,
                "triggered": False,
                "risk_level": "正常",
                "base_date": "20260510",
                "end_date": "20260525",
                "base_price": 10.0,
                "end_price": 10.5,
                "actual_trading_days": 10,
            },
        },
    })
    # Should contain key information
    assert "603629.SH" in result
    assert "TestStock" in result
    assert "正常" in result
    assert "上证指数" in result


def test_format_check_triggered():
    f = Formatter()
    result = f.format_check({
        "stock": {
            "code": "300750.SZ",
            "name": "TriggerStock",
            "board": "创业板",
            "index_code": "399102.SZ",
            "index_name": "创业板综指",
            "is_st": False,
            "suspended": False,
        },
        "query_date": "2026-05-26",
        "data_date": "2026-05-25",
        "price_adjusted": True,
        "windows": {
            "3": {
                "window_days": 3,
                "stock_return": 32.0,
                "index_return": 1.0,
                "deviation": 31.0,
                "threshold_positive": 30.0,
                "threshold_negative": -30.0,
                "remaining": 0.0,
                "triggered": True,
                "risk_level": "已触发",
                "base_date": "20260520",
                "end_date": "20260525",
                "base_price": 10.0,
                "end_price": 13.2,
                "actual_trading_days": 3,
            },
        },
    })
    assert "已触发" in result
    assert "TRIGGERED" in result


def test_format_check_json():
    f = Formatter()
    data = {
        "stock": {"code": "603629.SH", "name": "T", "board": "主板_SH",
                   "index_code": "000001.SH", "index_name": "上证指数",
                   "is_st": False, "suspended": False},
        "query_date": "2026-05-26",
        "data_date": "2026-05-25",
        "price_adjusted": True,
        "windows": {},
    }
    result = f.format_check(data, json_output=True)
    assert '"603629.SH"' in result
    import json
    parsed = json.loads(result)
    assert parsed["stock"]["code"] == "603629.SH"


def test_format_trigger():
    f = Formatter()
    result = f.format_trigger({
        "ts_code": "603629.SH",
        "board": "主板_SH",
        "index_code": "000001.SH",
        "index_name": "上证指数",
        "window_days": 30,
        "threshold": 200.0,
        "threshold_negative": -70.0,
        "is_st": False,
        "base_price": 10.0,
        "scenarios": [
            {"index_change": -2.0, "needed_stock_return": 198.0, "trigger_price": 29.8},
            {"index_change": 0.0, "needed_stock_return": 200.0, "trigger_price": 30.0},
        ],
        "generated_at": "2026-05-26",
    })
    assert "30.000" in result or "30.0" in result
    assert "200.00%" in result or "200%" in result or "198" in result


def test_format_trigger_json():
    f = Formatter()
    result = f.format_trigger({"ts_code": "603629.SH"}, json_output=True)
    import json
    parsed = json.loads(result)
    assert parsed["ts_code"] == "603629.SH"


def test_format_simulate():
    f = Formatter()
    result = f.format_simulate({
        "ts_code": "603629.SH",
        "board": "主板_SH",
        "index_code": "000001.SH",
        "index_name": "上证指数",
        "window_days": 30,
        "stock_change": 7.0,
        "index_change": 1.0,
        "deviation": 6.0,
        "threshold_positive": 200.0,
        "threshold_negative": -70.0,
        "remaining": 194.0,
        "triggered": False,
        "risk_level": "正常",
    })
    assert "603629.SH" in result
    assert "+6.00%" in result


def test_format_simulate_json():
    f = Formatter()
    result = f.format_simulate({
        "ts_code": "603629.SH",
        "deviation": 6.0,
    }, json_output=True)
    import json
    parsed = json.loads(result)
    assert parsed["deviation"] == 6.0


def test_format_watchlist():
    f = Formatter()
    result = f.format_watchlist([
        {
            "stock": {"code": "603629.SH", "name": "S1", "board": "主板_SH"},
            "windows": {
                "3": {"risk_level": "正常", "deviation": 1.0, "error": None},
                "10": {"risk_level": "接近", "deviation": 12.0, "error": None},
                "30": {"risk_level": "正常", "deviation": 50.0, "error": None},
            },
        },
        {
            "stock": {"code": "300750.SZ", "name": "S2", "board": "创业板"},
            "windows": {
                "3": {"risk_level": "已触发", "deviation": 31.0, "error": None},
            },
        },
        {
            "ts_code": "000001.SZ",
            "error": "API failed",
        },
    ])
    assert "603629.SH" in result
    assert "300750.SZ" in result
    assert "已触发" in result
    assert "API failed" in result or "ERROR" in result


def test_format_watchlist_json():
    f = Formatter()
    result = f.format_watchlist([{"ts_code": "603629.SH"}], json_output=True)
    import json
    parsed = json.loads(result)
    assert parsed[0]["ts_code"] == "603629.SH"


if __name__ == "__main__":
    for name, fn in sorted({k: v for k, v in globals().items() if k.startswith("test_")}.items()):
        try:
            fn()
            print(f"  PASS: {name}")
        except Exception as e:
            print(f"  FAIL: {name} - {e}")