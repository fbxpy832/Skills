---
name: obsidian-article-extractor
description: "从微信公众号或其他网页提取文章，转换为 Markdown 保存至 Obsidian Vault。图片 base64 内嵌，无需额外文件夹。Vault 路径和收件箱文件夹名分别缓存，首次调用后自动记忆。"
metadata:
  requires:
    bins: [node]
    node_modules: [turndown, turndown-plugin-gfm]
  pitfalls:
    - "缓存必须放在用户本机目录，例如 ~/.config/obsidian-article-extractor；不要写进 skill 源码目录，否则多台 Mac 同步时会互相污染"
    - "node_modules 必须放在 extract-article.js 同级目录，否则 require('turndown') 失败"
    - "Turndown 不支持 async rule！图片嵌入必须用占位符策略：先把所有 img src 替换为 __IMG_PLACEHOLDER_N__，下载 base64 完成后批量替换"
    - "微信公众号的 <title> 是 JS 渲染前为空，必须优先读 og:title 或 activity-name"
    - "中文 URL 在 Turndown 里会被编码成 &lt;...&gt;，占位符策略绕过此问题"
    - "微信图片需带 Referer: https://mp.weixin.qq.com/ 否则 403"
---

# Obsidian 文章提取器

从微信公众号或其他网页提取文章内容，保存为 Markdown 文件到 Obsidian Vault 收件箱文件夹。

## 基本用法

```bash
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js <url> [vaultPath] [inboxFolder]
```

| 参数 | 说明 |
|------|------|
| `url` | 文章链接（必填） |
| `vaultPath` | Obsidian Vault 路径（首次必填，之后省略） |
| `inboxFolder` | 目标文件夹（首次必填，之后省略） |

## 使用步骤

**第一次使用** — 需传入 vault 路径和收件箱文件夹（提取后自动记忆）：
```bash
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js \
  "https://mp.weixin.qq.com/s/xxxxx" \
  "/Users/你的/Vault/路径" \
  "收件箱"
```

**之后使用** — 直接传 URL，其他参数自动复用：
```bash
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js "https://mp.weixin.qq.com/s/xxxxx"
```

## 常见问题

- **忘记 vault 路径**：删掉 `~/.config/obsidian-article-extractor/vault-path`，下次调用时重新传入
- **收件箱名称不对**：删掉 `~/.config/obsidian-article-extractor/inbox-folder`，重新传入
- **微信公众号失败**：部分付费/登录内容无法提取，换用镜像站（sohu.com / 53ai.com / finance.sina.com.cn）
- **图片下载失败**：保留原始 URL，不影响正文内容

## 实现亮点

1. **Turndown + GFM** — 专业 HTML→Markdown 转换，代码块/表格/GFM 支持
2. **图片 base64 内嵌** — 图片直接转为 `data:image/jpeg;base64,...` 存入 Markdown，单文件即可迁移
3. **微信公众号优化** — 识别 `js_content` 区域，提取作者/发布日期
4. **标题 fallback** — HTML 标题为空时从 markdown 正文 H1 反向补全
5. **双参数缓存** — Vault 路径和收件箱文件夹名分别缓存，互不干扰
6. **HTML 实体解码** — `&#39;` → `'`、`&amp;` → `&` 等

## 输出格式

成功时返回：
```json
{
  "success": true,
  "filePath": "/path/to/Vault/收件箱/2026-04-21T10-00-00_文章标题.md",
  "title": "文章标题",
  "author": "作者名",
  "publishedDate": "2026-04-21",
  "isWxArticle": true,
  "imagesEmbedded": 6
}
```

失败时返回：
```json
{
  "success": false,
  "error": "错误描述"
}
```
