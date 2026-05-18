# 博查 AI Search API — Scheme E

## 概述

博查（Bocha）是国内首个 AI 原生的搜索引擎 API，专为 AI Agent 设计。API 返回长摘要（非传统 50 字 snippet），支持流式输出，是国内中文搜索质量最高的 API 之一。

- 官网：[open.bochaai.com](https://open.bochaai.com/)
- API 端点：`POST https://api.bochaai.com/v1/web-search`
- 数据来源：~100 亿网页 + 头条/抖音/微博/高德/腾讯文库等生态数据
- 服务规模：40K+ 企业用户，10 万+ AI 应用，3000 万+ 日调用量
- 网络：100% 国内服务，无需代理，数据不出境

## API Key 获取

1. 访问 [open.bochaai.com](https://open.bochaai.com/) 注册账号
2. 在控制台（Dashboard）创建 API Key
3. **重要**：新注册账户需先激活免费套餐或购买额度。若无额度，API 返回 `403: You do not have enough money or package quota`
4. 进入 [控制台/价格页面](https://open.bochaai.com/dashboard) 查看并激活可用套餐
5. 将 Key 设置为环境变量或保存到配置文件：

```bash
# 方式1：环境变量
export BOCHA_API_KEY="sk-xxxxxxxxxxxxxxxx"

# 方式2：配置文件（自动加载，推荐）
echo 'BOCHA_API_KEY=sk-xxxxxxxxxxxxxxxx' > ~/.bocha-config
chmod 600 ~/.bocha-config
# search.sh 会自动从 ~/.bocha-config 加载 Key
```

## API 端点

### Web Search API（文本搜索）

```bash
POST https://api.bochaai.com/v1/web-search
Authorization: Bearer $BOCHA_API_KEY
Content-Type: application/json

{
  "query": "搜索关键词",
  "count": 10,          # 返回结果数（1-50）
  "freshness": "noLimit" # noLimit | oneDay | oneWeek | oneMonth | oneYear
}
```

### AI Search API（多模态搜索 + AI 答案）

```bash
POST https://api.bochaai.com/v1/ai-search
Authorization: Bearer $BOCHA_API_KEY
Content-Type: application/json

{
  "query": "搜索关键词",
  "count": 10,
  "answer": true,       # 是否生成 AI 答案
  "stream": false       # 是否流式返回
}
```

### Agent Search API（专用领域搜索，带深度答案）

```bash
POST https://api.bochaai.com/v1/agent-search
Authorization: Bearer $BOCHA_API_KEY
Content-Type: application/json

{
  "query": "搜索关键词",
  "count": 10,
  "stream": false
}
```

## 返回结构（Web Search API）

```json
{
  "code": 200,
  "data": {
    "total": 12345,
    "webPages": {
        "webSearchUrl": "https://bochaai.com/search?q=...",
        "totalEstimatedMatches": 10000000,
        "value": [
      {
        "id": "result-1",
        "title": "结果标题",
        "url": "https://example.com/article",
        "displayUrl": "example.com/article",
        "snippet": "简短摘要",
        "summary": "长摘要 — AI 优化的内容提取，包含关键事实和数据",
        "siteName": "来源站点",
        "siteIcon": "https://...",
        "dateLastCrawled": "2026-05-09T10:00:00Z",
        "language": "zh"
      }
    ],
    "suggestion": [
      {
        "query": "相关搜索建议1",
        "displayText": "相关搜索建议1"
      }
    ]
  }
}
```

### 关键字段说明

| 字段 | 说明 | 用途 |
|------|------|------|
| `webPages.value[].summary` | AI 优化的长摘要 | **核心价值字段** — 可直接提取数据，无需抓取页面 |
| `webPages.value[].snippet` | 传统短摘要 | 快速浏览 |
| `webPages.value[].dateLastCrawled` | 最后抓取日期 | 时效性判断 |
| `webPages.value[].siteName` | 来源站点名 | 来源初步分级 |
| `webPages.totalEstimatedMatches` | 总结果数 | 搜索覆盖度评估 |
| `data.suggestion[]` | 相关搜索建议 | 补充搜索方向 |

## 与 Brave Search API 的对比

| 维度 | 博查 | Brave Search |
|------|------|:---:|
| **中文搜索质量** | ★★★★★ 业界最佳 | ★★★☆☆ 索引有限 |
| **英文搜索质量** | ★★★☆☆ 可用 | ★★★★☆ 好 |
| **网络需求** | 直连（国内服务） | 需代理 |
| **返回摘要长度** | 长摘要（500+ 字符） | extra_snippets（150-200 字符） |
| **AI 优化** | ✅ AI Search/Agent Search 端点 | ⚠️ LLM Context API（新） |
| **国内合规** | ✅ 完全合规 | ❌ 需自行审查 |
| **免费额度** | 个人/小团队免费 | 2000次/月 |
| **并发支持** | ✅ | ✅ |
| **政策/法规搜索** | ★★★★★ 中文长尾政策搜索好 | ★★★☆☆ |
| **行业报告搜索** | ★★★★☆ 中文行业报告好 | ★★★☆☆ |
| **学术论文搜索** | ★★★☆☆ | ★★★☆☆ |

## 在 Deep Research 中的角色

博查被设定为 **Scheme E — 中文主力搜索引擎**，优先级高于 Brave：

```
搜索路由逻辑：
├── 中文查询 → 博查（主力）+ SearXNG（备用）
├── 英文查询 → Brave（主力）+ Exa（语义）/ Serper（低价备用）
├── 学术查询 → Exa（语义）+ Brave
└── 政策/法规 → 博查 + gov.cn 直连
```

## 使用模板

### 单次搜索

```bash
curl -s --connect-timeout 15 \
  -H "Authorization: Bearer $BOCHA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"智慧停车 城市治理 政策 2025","count":10,"freshness":"noLimit"}' \
  "https://api.bochaai.com/v1/web-search" | \
  python3 -c "
import json,sys
data = json.load(sys.stdin)
for p in data.get('data',{}).get('pages',[]):
    print(f'[{p.get(\"language\",\"?\")}] {p.get(\"title\",\"\")}')
    print(f'  {p.get(\"url\",\"\")}')
    print(f'  summary: {p.get(\"summary\",\"\")[:200]}')
    print()
"
```

### 带时效性过滤

```bash
# 最近一周
curl ... -d '{"query":"...","count":10,"freshness":"oneWeek"}' ...

# 最近一个月
curl ... -d '{"query":"...","count":10,"freshness":"oneMonth"}' ...
```

## 频率限制

- 免费用户：通常 100-500 次/天
- 具体限额以注册时控制台显示为准
- 超限返回 429 错误，建议加入重试逻辑（指数退避）

## 注意事项

1. **API Key 安全**：不要将 Key 硬编码在脚本中，使用环境变量
2. **国内合规**：博查已过滤敏感内容，搜索结果符合国内安全规范
3. **数据时效**：关注 `dateLastCrawled` 字段判断内容新鲜度
4. **与 Brave 互补**：博查强于中文长尾政策/行业搜索，Brave 强于英文和技术搜索
