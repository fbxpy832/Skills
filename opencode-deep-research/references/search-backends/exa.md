# Exa Search API — Scheme F

## 概述

Exa 是基于嵌入向量（embeddings）的语义搜索引擎，专为 AI 应用设计。与传统关键词搜索不同，Exa 通过语义理解返回最相关的结果，特别适合学术研究、技术查询和深度信息发现。

- 官网：[exa.ai](https://exa.ai)
- API 端点：`POST https://api.exa.ai/search`
- 认证：`x-api-key` header
- 免费额度：1,000 次/月（含 contents）
- 定价：$7/千次（含前10条结果的 text+highlights），按量计费

## API Key 获取

1. 访问 [dashboard.exa.ai/api-keys](https://dashboard.exa.ai/api-keys) 注册
2. 创建 API Key
3. 新用户有 1,000 次/月的免费额度

```bash
export EXA_API_KEY="your-exa-api-key"
```

## 搜索类型

| type | 延迟 | 特点 | 适用场景 |
|------|:---:|------|---------|
| `auto` | ~1s | 智能组合 neural + keyword | **默认推荐** |
| `neural` | ~1s | 纯嵌入向量语义搜索 | 概念性/模糊查询 |
| `fast` | <500ms | 精简模型，低延迟 | 实时应用 |
| `instant` | <180ms | 最低延迟 | 事实性简单查询 |
| `deep` | ~5s | 深度多步搜索+综合输出 | 复杂研究问题 |
| `deep-reasoning` | ~10s | 最强深度推理 | 需要推理的综合问题 |

## 分类过滤（category）

| category | 说明 |
|----------|------|
| `research paper` | 学术论文 |
| `company` | 公司信息/LinkedIn |
| `news` | 新闻 |
| `financial report` | 财报 |
| `personal site` | 个人网站 |
| `people` | 人物/LinkedIn 档案 |

## 内容提取（contents）

```json
{
  "contents": {
    "text": true,              // 返回完整页面文本
    "highlights": true,        // 返回LLM提取的关键高亮
    "summary": {               // LLM生成摘要
      "query": "自定义摘要引导"
    }
  }
}
```

## API 调用

### 基础搜索

```bash
curl -s --connect-timeout 15 \
  -H "x-api-key: $EXA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"latest LLM research 2025","numResults":10,"type":"auto","contents":{"highlights":true}}' \
  "https://api.exa.ai/search"
```

### 学术论文搜索

```bash
curl -s --connect-timeout 15 \
  -H "x-api-key: $EXA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"transformer architecture efficiency","numResults":10,"type":"auto","category":"research paper","startPublishedDate":"2025-01-01","contents":{"highlights":true}}' \
  "https://api.exa.ai/search"
```

### 通过 search.sh 调用

```bash
# 英文自动路由（有 Key 时优先 Exa）
scripts/search.sh "latest LLM research" --lang en

# 强制 Exa
scripts/search.sh "transformer optimization" --backend exa --lang en

# 并发 Exa + Brave
scripts/search.sh "AI safety research" --parallel --lang en
```

## 返回结构

```json
{
  "requestId": "abc123...",
  "results": [
    {
      "title": "论文/页面标题",
      "url": "https://example.com",
      "publishedDate": "2025-06-01",
      "author": "作者信息",
      "score": 0.285,
      "highlights": ["高亮文本1", "高亮文本2"],
      "text": "完整页面文本（如请求）"
    }
  ],
  "costDollars": {
    "total": 0.007
  }
}
```

## 在 Deep Research 中的角色

Exa 被设定为 **Scheme F — 英文语义搜索引擎**：

```
搜索路由（已更新）：
├── 中文查询 → 博查（主力）+ Brave（并发备用）
├── 英文查询 → Exa（语义主力）+ Brave（并发备用）
├── 学术查询 → Exa（category: research paper）
├── 公司/人物 → Exa（category: company/people）
└── 深度研究 → Exa（type: deep）
```

## 与 Brave 的互补

| 维度 | Exa | Brave |
|------|-----|:---:|
| **搜索方式** | 语义向量 | 关键词 |
| **学术搜索** | ★★★★★ | ★★★★☆ |
| **新闻搜索** | ★★★★☆ | ★★★★★ |
| **长尾查询** | ★★★★★ 概念匹配 | ★★★☆☆ |
| **事实查询** | ★★★☆☆ | ★★★★★ |
| **延迟** | ~1s (auto) | <500ms |
| **中文质量** | ★★☆☆☆ | ★★★☆☆ |
| **价格** | $7/千次 | $5/千次 |

## 注意事项

1. **Exa 强于概念搜索**：查询 "improving transformer efficiency" 优于 "transformer speed paper 2025"
2. **中文内容有限**：Exa 索引以英文为主，中文查询建议走博查
3. **category 限制**：使用 company/people 分类时，部分 filter 参数不可用
4. **按量计费**：注意控制 deep/deep-reasoning 类型的使用频率
