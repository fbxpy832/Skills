# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Available Projects

### a-stock-trigger — A股异动触发价格计算工具

**Location**: `/Users/xpy/Documents/RichardHub/Git/a-stock-trigger/`

Tool for calculating A-share abnormal movement deviation values (3d/10d/30d windows) and back-calculating trigger prices. Uses Tushare Pro + AKShare data sources.

**Run from project dir**:
```bash
cd /Users/xpy/Documents/RichardHub/Git/a-stock-trigger
python3 main.py check 603629.SH
python3 main.py trigger 603629.SH --window 30
python3 main.py simulate 603629.SH --stock-change 7 --index-change 1 --window 30
python3 main.py watchlist
python3 main.py config add 603629.SH
```

**When the user asks about stocks via Feishu**: cd to the project directory and run the appropriate command. See `a-stock-trigger/CLAUDE.md` for full details.