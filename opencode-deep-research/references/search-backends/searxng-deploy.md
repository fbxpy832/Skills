# SearXNG 自建部署指南 — Scheme G

## 概述

SearXNG 是免费、开源的元搜索引擎，可聚合 70+ 搜索引擎的结果。自建实例可实现零 API 成本的无限搜索，特别适合中国大陆环境（支持百度、必应中文、搜狗微信等）。

- 官网：[docs.searxng.org](https://docs.searxng.org)
- GitHub：[searxng/searxng](https://github.com/searxng/searxng)
- 许可：AGPL-3.0
- 成本：仅 VPS 费用（$5-10/月）

## 快速部署（Docker，推荐）

### 1. 准备 VPS

在中国大陆部署建议使用阿里云/腾讯云轻量服务器（2核2G，约 ¥30-50/月）。

### 2. 创建配置

```bash
mkdir -p ~/searxng && cd ~/searxng

# 创建 settings.yml
cat > settings.yml <<'EOF'
use_default_settings: true

search:
  safe_search: 0
  autocomplete: ""
  default_lang: ""
  formats:
    - html
    - json

server:
  secret_key: "CHANGE_ME_TO_RANDOM_STRING"
  bind_address: "0.0.0.0"
  limiter: false
  image_proxy: true

ui:
  static_use_hash: true

redis:
  url: redis://redis:6379/0

engines:
  # 中文搜索引擎
  - name: baidu
    engine: baidu
    shortcut: bd

  - name: bing
    engine: bing
    shortcut: bi

  - name: bing news
    engine: bing_news
    shortcut: bin

  - name: sogou
    engine: sogou
    shortcut: sg

  # 微信搜一搜（需 cookies）
  # - name: sogou wechat
  #   engine: sogou_wechat
  #   shortcut: wx

  # 英文搜索引擎
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg

  - name: brave
    engine: brave
    shortcut: br

  - name: google
    engine: google
    shortcut: go

  - name: wikipedia
    engine: wikipedia
    shortcut: wp

  - name: arxiv
    engine: arxiv
    shortcut: ar

  - name: github
    engine: github
    shortcut: gh
EOF
```

### 3. 启动

```bash
# docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  redis:
    image: redis:alpine
    restart: always

  searxng:
    image: searxng/searxng:latest
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - ./settings.yml:/etc/searxng/settings.yml:ro
    environment:
      - SEARXNG_BASE_URL=http://YOUR_SERVER_IP:8080
    depends_on:
      - redis
EOF

docker-compose up -d
```

### 4. 验证

```bash
# JSON API 搜索测试
curl "http://localhost:8080/search?q=智慧停车&format=json" | python3 -m json.tool | head -20
```

## API 使用

SearXNG 原生支持 JSON 输出，可直接作为搜索后端：

```bash
# 基础搜索
curl "http://YOUR_SERVER:8080/search?q=智慧停车+城市治理&format=json&categories=general"

# 限定搜索引擎
curl "http://YOUR_SERVER:8080/search?q=AI+research&format=json&engines=arxiv,google"

# 新闻搜索
curl "http://YOUR_SERVER:8080/search?q=胖东来+郑州&format=json&categories=news"
```

## 在 Deep Research 中集成

建议作为 **Scheme G — 自建元搜索** 备用通道：

```bash
# 通过 search.sh 调用（未来支持）
scripts/search.sh "查询" --backend searxng --lang zh

# 或在 Phase 2 搜索执行时手动调用
export SEARXNG_URL="http://your-server:8080"
curl -s "$SEARXNG_URL/search?q=QUERY&format=json" | \
  python3 -c "
import json,sys,urllib.parse
data = json.load(sys.stdin)
for r in data.get('results',[])[:10]:
    print(f'[{r.get(\"engine\",\"?\")}] {r.get(\"title\",\"\")}')
    print(f'  {r.get(\"url\",\"\")}')
    print(f'  {r.get(\"content\",\"\")[:150]}')
    print()
"
```

## 优势与限制

| 优势 | 限制 |
|------|------|
| 零 API 成本 | 需要 VPS 运维 |
| 70+ 引擎聚合 | 百度/Google 可能触发反爬 |
| 支持百度/必应中文/搜狗微信 | 部分引擎需 cookies（微信搜一搜） |
| JSON API 原生支持 | 延迟高于专用 API（需聚合多引擎） |
| 隐私保护（不追踪） | 搜索结果无 AI 优化（传统 snippet） |
| 可自定义引擎权重 | 单实例稳定性依赖 VPS |

## 进阶配置

### 微信搜一搜（需 cookies）

```yaml
- name: sogou wechat
  engine: sogou_wechat
  shortcut: wx
  cookies:
    SUID: "your-sogou-cookie"
    ABTEST: "..."
```

获取方式：浏览器登录搜狗微信搜索 → F12 → Application → Cookies → 复制 SUID 等值。

### 提升百度稳定性

百度对服务器 IP 有反爬限制。建议：
1. 使用中国大陆 VPS（阿里云/腾讯云）
2. 降低百度搜索频率（`limiter: true`）
3. 如触发验证码，在 settings.yml 中暂时禁用百度引擎
