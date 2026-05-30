# A-Stock Trigger — A股异动触发价格计算工具

计算 A 股 3 日 / 10 日 / 30 日异动偏离值，反推触发异动所需价格，支持实时数据源（Tushare Pro）。

## 快速开始

### 安装

```bash
pip install -r requirements.txt
```

### 配置 Token

```bash
# 方式 1: init 命令
python main.py init --token your_tushare_token_here

# 方式 2: 环境变量
export TUSHARE_TOKEN=your_tushare_token_here

# 方式 3: 编辑 config.py 中的 DEFAULT_TUSHARE_TOKEN
```

Token 读取优先级：`环境变量 TUSHARE_TOKEN` > `config.json` > `config.py DEFAULT_TUSHARE_TOKEN`

## 命令说明

### `check` — 检查异动偏离值

计算单只股票 3 日 / 10 日 / 30 日偏离值，输出风险等级。

```bash
python main.py check 603629.SH
python main.py check 300750.SZ --json
python main.py check 000001.SZ --reset-from 20260401
```

### `trigger` — 反推触发价

计算在不同指数情景（±2%、±1%、0%）下的个股异动触发价。

```bash
python main.py trigger 603629.SH --window 30 --threshold 200
python main.py trigger 300750.SZ --window 3
```

### `simulate` — 模拟异动

输入假设的个股涨幅和指数涨幅，判断是否触发异动（无需 Token）。

```bash
python main.py simulate 603629.SH --stock-change 7 --index-change 1 --window 30
python main.py simulate 300750.SZ --stock-change 28 --index-change -2 --window 3
```

### `watchlist` — 批量检查自选股

```bash
python main.py config add 603629.SH
python main.py config add 300750.SZ
python main.py watchlist
```

### `config` — 管理自选股

```bash
python main.py config list
python main.py config add 603629.SH
python main.py config remove 603629.SH
```

## 支持规则

| 板块 | 3 日 | 10 日 | 30 日 |
|------|------|-------|-------|
| 沪深主板 | ±20% (ST: ±12%) | +100% / -50% | +200% / -70% |
| 创业板 | ±30% | +100% / -50% | +200% / -70% |
| 科创板 | ±30% | +100% / -50% | +200% / -70% |
| 北交所 | ±40% | +100% / -50% | +200% / -70% |

风险等级：已触发 / 极高风险(≤3%) / 高风险(≤8%) / 接近(≤15%) / 正常(>15%)

## 飞书桥接调用

已有 claude-to-im 飞书桥接运行中，在飞书中对 Claude 说：

- "查一下 603629.SH 的异动情况"
- "检查我的自选股"
- "查 300750.SZ 的 30 天偏离值"

## 计算口径

偏离值 = 个股区间涨跌幅 - 对应指数区间涨跌幅
- 个股涨跌幅 = 区间期末收盘价 / 区间期初前收盘价 - 1
- 指数涨跌幅 = 指数期末点位 / 指数期初前收盘点位 - 1
- 价格使用前复权价格估算（adj_factor 法）

## 项目结构

```
a-stock-trigger/
├── main.py              # CLI 入口
├── config.py            # 配置管理
├── data.py              # Tushare Pro 数据层
├── calculator.py        # 偏离值计算
├── simulator.py         # 模拟和推演
├── rules.py             # 阈值定义和风险分级
├── resolver.py          # 板块和指数解析
├── adjust.py            # 前复权价格计算
├── formatter.py         # 输出格式化
├── exceptions.py        # 异常定义
├── config.json          # 运行时配置
├── requirements.txt
└── tests/
```

## 后续需人工核验

- **指数映射**: 深市中小板（002xxx）目前使用深证A指，如需精确匹配可改用中小板指(399005.SZ)
- **ST 检测**: 基于当前名称判断，历史 ST 状态需自行确认
- **前复权价格**: 复权因子在分红送转后可能变化，长期窗口需关注
- **实时行情**: V1 仅做盘后日线级别检查，不包含盘中实时推送