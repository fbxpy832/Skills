#!/usr/bin/env python3
"""
A-Stock Trigger — A股异动触发价格计算工具

Calculate A-share abnormal movement (异动) deviation values and trigger prices.
Supports 3-day, 10-day, and 30-day windows per exchange regulations.

Usage:
    python main.py init --token <token>
    python main.py check <ts_code>
    python main.py trigger <ts_code> --window 30 --threshold 200
    python main.py simulate <ts_code> --stock-change 7 --index-change 1 --window 30
    python main.py watchlist
    python main.py config add|remove|list <ts_code>
"""

import sys
import argparse
import warnings

# Suppress urllib3 OpenSSL warning on macOS
warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL")

from config import ConfigManager
from data import TushareProData
from calculator import DeviationCalculator
from simulator import simulate, calculate_trigger_prices, estimate_base_price
from resolver import resolve_board, get_index_info
from formatter import Formatter
from exceptions import AStockTriggerError


def get_data_api(cfg):
    """Initialize TushareProData from config manager."""
    token = cfg.get_tushare_token()
    if not token:
        raise AStockTriggerError(
            "Tushare token not configured. "
            "Use `init --token <token>` or set TUSHARE_TOKEN env var."
        )
    return TushareProData(token)


def cmd_init(args):
    """Initialize config with Tushare token."""
    cfg = ConfigManager()
    cfg.set_tushare_token(args.token)
    print(f"Token saved to config.json")


def cmd_config(args, cfg):
    """Manage watchlist."""
    if args.action == "list":
        watchlist = cfg.get_watchlist()
        if not watchlist:
            print("Watchlist is empty.")
        else:
            print("Watchlist:")
            for i, code in enumerate(watchlist, 1):
                print(f"  {i}. {code}")
    elif args.action == "add":
        if not args.ts_code:
            print("Error: Specify stock code to add.")
            return
        if cfg.add_to_watchlist(args.ts_code):
            print(f"Added {args.ts_code} to watchlist.")
        else:
            print(f"{args.ts_code} is already in watchlist.")
    elif args.action == "remove":
        if not args.ts_code:
            print("Error: Specify stock code to remove.")
            return
        if cfg.remove_from_watchlist(args.ts_code):
            print(f"Removed {args.ts_code} from watchlist.")
        else:
            print(f"{args.ts_code} not found in watchlist.")


def cmd_check(args):
    """Check deviation for a single stock."""
    cfg = ConfigManager()
    data = get_data_api(cfg)
    calculator = DeviationCalculator(data)
    formatter = Formatter()

    result = calculator.check_stock(
        args.ts_code,
        windows=[3, 10, 30],
        reset_from=args.reset_from,
    )
    print(formatter.format_check(result, json_output=args.json))


def cmd_trigger(args):
    """Back-calculate trigger prices."""
    cfg = ConfigManager()
    data = get_data_api(cfg)
    formatter = Formatter()

    # Fetch stock data to determine base price
    calculator = DeviationCalculator(data)
    windows = [args.window]
    start_date, end_date = calculator._data_date_range(args.ts_code, args.window, args.reset_from)

    stock_df = data.daily_adj(args.ts_code, start_date, end_date)
    stock_df = stock_df.sort_values("trade_date").reset_index(drop=True)

    base_info = estimate_base_price(stock_df, args.window, args.reset_from)

    # Determine threshold
    board = resolve_board(args.ts_code)
    is_st = False  # We don't have name here, but it's OK for trigger
    from rules import get_threshold
    t = get_threshold(board, is_st, args.window)
    threshold_val = args.threshold if args.threshold is not None else t["positive"]

    result = calculate_trigger_prices(
        args.ts_code,
        base_price=base_info["base_price"],
        window=args.window,
        threshold_val=threshold_val,
    )
    # Add context from base_info
    result["base_date"] = base_info["base_date"]
    result["latest_price"] = base_info["latest_price"]
    result["latest_date"] = base_info["latest_date"]
    result["current_return"] = base_info["stock_return_since_base"]

    print(formatter.format_trigger(result, json_output=args.json))


def cmd_simulate(args):
    """Simulate deviation with assumed changes."""
    cfg = ConfigManager()
    formatter = Formatter()

    # Try to get stock name for better output
    stock_name = args.ts_code
    try:
        data = get_data_api(cfg)
        try:
            info_df = data.stock_info(args.ts_code)
            if "name" in info_df.columns and not info_df.empty:
                stock_name = str(info_df.iloc[0]["name"])
        except Exception:
            pass
    except Exception:
        pass

    board = resolve_board(args.ts_code)
    is_st = False  # simplified; no API call needed

    result = simulate(
        args.ts_code,
        args.stock_change,
        args.index_change,
        args.window,
        is_st=is_st,
    )
    result["stock_name"] = stock_name
    print(formatter.format_simulate(result, json_output=args.json))


def cmd_watchlist(args):
    """Check all stocks in watchlist."""
    cfg = ConfigManager()
    data = get_data_api(cfg)
    calculator = DeviationCalculator(data)
    formatter = Formatter()

    watchlist = cfg.get_watchlist()
    if not watchlist:
        print("Watchlist is empty. Use `config add <ts_code>` to add stocks.")
        return

    results = []
    for ts_code in watchlist:
        try:
            result = calculator.check_stock(ts_code)
            results.append(result)
        except AStockTriggerError as e:
            results.append({
                "ts_code": ts_code,
                "error": str(e),
            })
        except Exception as e:
            results.append({
                "ts_code": ts_code,
                "error": str(e),
            })

    print(formatter.format_watchlist(results, json_output=args.json))


def main():
    parser = argparse.ArgumentParser(
        description="A-Stock Trigger - A股异动触发价格计算工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py init --token your_tushare_token
  python main.py check 603629.SH
  python main.py check 603629.SH --reset-from 20260401 --json
  python main.py trigger 603629.SH --window 30 --threshold 200
  python main.py simulate 603629.SH --stock-change 7 --index-change 1 --window 30
  python main.py watchlist
  python main.py config add 603629.SH
        """,
    )
    subparsers = parser.add_subparsers(dest="command")

    # init
    p_init = subparsers.add_parser("init", help="Initialize Tushare token")
    p_init.add_argument("--token", required=True, help="Tushare Pro API token")

    # config
    p_config = subparsers.add_parser("config", help="Manage watchlist")
    p_config.add_argument("action", choices=["add", "remove", "list"])
    p_config.add_argument("ts_code", nargs="?", help="Stock code (for add/remove)")

    # check
    p_check = subparsers.add_parser("check", help="Check abnormal deviation for a stock")
    p_check.add_argument("ts_code", help="Stock code, e.g. 603629.SH")
    p_check.add_argument("--reset-from", help="Reset calculation start date (YYYYMMDD)")
    p_check.add_argument("--json", action="store_true", help="Output as JSON")

    # trigger
    p_trigger = subparsers.add_parser("trigger", help="Back-calculate trigger prices")
    p_trigger.add_argument("ts_code", help="Stock code")
    p_trigger.add_argument("--window", type=int, default=30, choices=[3, 10, 30],
                           help="Window in trading days (default: 30)")
    p_trigger.add_argument("--threshold", type=float, help="Threshold override (default: board default)")
    p_trigger.add_argument("--reset-from", help="Reset date (YYYYMMDD)")
    p_trigger.add_argument("--json", action="store_true", help="Output as JSON")

    # simulate
    p_sim = subparsers.add_parser("simulate", help="Simulate deviation with assumed changes")
    p_sim.add_argument("ts_code", help="Stock code")
    p_sim.add_argument("--stock-change", type=float, required=True,
                       help="Assumed stock price change in %")
    p_sim.add_argument("--index-change", type=float, required=True,
                       help="Assumed index change in %")
    p_sim.add_argument("--window", type=int, default=30, choices=[3, 10, 30],
                       help="Window in trading days (default: 30)")
    p_sim.add_argument("--json", action="store_true", help="Output as JSON")

    # watchlist
    p_wl = subparsers.add_parser("watchlist", help="Check all watchlist stocks")
    p_wl.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    try:
        cfg = ConfigManager()

        if args.command == "init":
            cmd_init(args)
        elif args.command == "config":
            cmd_config(args, cfg)
        elif args.command == "check":
            cmd_check(args)
        elif args.command == "trigger":
            cmd_trigger(args)
        elif args.command == "simulate":
            cmd_simulate(args)
        elif args.command == "watchlist":
            cmd_watchlist(args)
    except AStockTriggerError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()