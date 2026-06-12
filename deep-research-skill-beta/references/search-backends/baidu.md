# 百度智能云搜索服务 (Baidu Intelligent Cloud Search)

## 概述

百度智能云搜索服务（Baidu Search Service）是百度提供的企业级网页搜索 API，通过 OAuth2 认证、RESTful 接口返回结构化搜索结果。非常适合中文搜索场景。

- 控制台：[console.bce.baidu.com](https://console.bce.baidu.com/)
- Token 端点：`POST https://aip.baidubce.com/oauth/2.0/token`
- API 端点：`POST https://aip.baidubce.com/rpc/2.0/solution/v1/websearch/search`
- 认证方式：OAuth2 client_credentials（API Key + Secret Key）
- 网络：国内直连，无需代理
- 免费额度：每月一定量免费调用（具体以百度智能云控制台为准）

## API Key 获取

1. 访问 [console.bce.baidu.com](https://console.bce.baidu.com/) 注册百度智能云账号
2. 在控制台搜索「搜索服务」或找到「人工智能 > 搜索服务」
3. 创建应用，获取 **API Key** 和 **Secret Key**
4. 将密钥配置到环境变量：

```bash
# 必需：API Key 和 Secret Key 必须同时设置
export BAIDU_API_KEY="your-api-key"
export BAIDU_SECRET_KEY="your-secret-key"
```

## 搜索 API

### 请求格式

```bash
# 1. 获取 Access Token
curl -s "https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=API_KEY&client_secret=SECRET_KEY" -d ''

# 2. 搜索
curl -s "https://aip.baidubce.com/rpc/2.0/solution/v1/websearch/search?access_token=TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"搜索关键词","num":8}'
```

### 请求参数

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| query | string | 是 | 搜索关键词 |
| num | int | 否 | 返回结果数（默认 10） |

### 响应格式

```json
{
  "log_id": 1234567890,
  "result": {
    "items": [
      {
        "title": "结果标题",
        "url": "https://example.com/page",
        "desc": "摘要描述..."
      }
    ]
  }
}
```

### Token 管理

search.sh 自动管理 Access Token：
- 首次搜索时通过 API Key + Secret Key 获取 Token
- Token 缓存到 `~/.cache/deep-research-skill/baidu_token.json`
- 默认有效期 30 天，脚本在过期前 5 分钟自动刷新
- 缓存文件权限为 `chmod 600`

## 搜索路由

在 `deep-research-skill-beta` 中，百度智能云搜索的优先级：

- **中文搜索**：百度 → 博查 → Brave → Exa
- **英文搜索**：不变（Exa → Brave → Bocha）
- **并发模式**（中文）：百度(primary) + 博查(secondary)

## 与其它后端对比

| 维度 | 百度智能云搜索 | 博查 | Brave |
|------|---------------|------|-------|
| 中文质量 | ✅ 最高 | ✅ 高 | ✅ 好 |
| 英文质量 | ⚪ 有限 | ⚠️ 可用 | ✅ 好 |
| 认证方式 | OAuth2 (Key+Secret) | Bearer Token | Header Token |
| 网络要求 | 国内直连 | 国内直连 | 需代理 |
| 成本 | 有免费额度 | 有免费额度 | 有限免费 |
| 是否需要代理 | 否 | 否 | 是 |
