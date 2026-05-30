# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: A-Stock Trigger (a-stock-trigger)

A股异动触发价格计算工具。计算 3日/10日/30日异动偏离值，反推触发价。

**Location**: `/Users/xpy/Documents/RichardHub/Git/a-stock-trigger/`
**Python**: 3.9+ (system `/usr/bin/python3`)

## Available Commands

Run all commands from the project directory (`cd /Users/xpy/Documents/RichardHub/Git/a-stock-trigger`).

### Check a stock's abnormal deviation
```
python3 main.py check <ts_code>
python3 main.py check <ts_code> --json
python3 main.py check <ts_code> --reset-from YYYYMMDD
```
Outputs 3d, 10d, 30d deviation values + risk level for each.

### Back-calculate trigger price
```
python3 main.py trigger <ts_code> --window 30
python3 main.py trigger <ts_code> --window 30 --threshold 200 --json
```
Shows trigger prices under 5 index scenarios (-2%, -1%, 0%, +1%, +2%).

### Simulate
```
python3 main.py simulate <ts_code> --stock-change 7 --index-change 1 --window 30
```
No API token needed. Pure calculation.

### Watchlist management
```
python3 main.py config add <ts_code>
python3 main.py config remove <ts_code>
python3 main.py config list
python3 main.py watchlist
```

### Tests
```
python3 -m pytest tests/ -v
```

## When the user asks about stocks in Feishu

When the user sends a message via Feishu bridge asking about a stock:
1. cd to the project directory
2. Run the appropriate command
3. Return the formatted results

Natural language examples → commands:
- "查一下 603629.SH 的异动情况" → `python3 main.py check 603629.SH`
- "查 300750.SZ 的 30 天偏离值" → `python3 main.py check 300750.SZ --json`
- "603629 的触发价是多少" → `python3 main.py trigger 603629.SH --window 30`
- "检查我的自选股" → `python3 main.py watchlist`
- "模拟一下 603629 涨7% 指数涨1% 走30天" → `python3 main.py simulate 603629.SH --stock-change 7 --index-change 1 --window 30`