# 文章提取器使用指南

## 功能说明

从微信公众号或其他网页提取文章内容，转换为带 frontmatter 的 Markdown 文件，保存至 Obsidian Vault 的收件箱文件夹。

## 前置配置

### 1. 配置 Obsidian Vault 路径

首次使用时传入 Obsidian Vault 路径，脚本会缓存到当前 Mac 的 `~/.config/obsidian-article-extractor/vault-path`：

```bash
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js \
  "https://example.com/article" \
  "/path/to/your/Obsidian/Vault"
```

**如何找到 Obsidian Vault 路径**：
- 在 Obsidian 中打开任意笔记
- 右键点击标签页标题 → 查看"文件位置"
- 复制文件夹路径

### 2. 测试配置

```bash
# 验证 Vault 路径缓存
cat ~/.config/obsidian-article-extractor/vault-path

# 查看 Vault 中的收件箱文件夹（如果不存在会自动创建）
ls ~/Obsidian/Vault/收件箱 2>/dev/null || echo "收件箱文件夹不存在，会自动创建"
```

## 使用方式

### 方式一：命令行直接使用

```bash
# 基本用法（使用当前 Mac 缓存的 Vault 路径）
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js <url>

# 示例：提取微信公众号文章
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js \
  "https://mp.weixin.qq.com/s/xxxxx"

# 示例：提取普通网页（指定 Vault 路径）
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js \
  "https://example.com/article" \
  "/Users/xxx/Obsidian/Vault"

# 示例：使用自定义收件箱文件夹
node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js \
  "https://mp.weixin.qq.com/s/xxxxx" \
  "/Users/xxx/Obsidian/Vault" \
  "微信文章"
```

### 方式二：Hermes Agent 调用

当用户说"帮我提取这篇文章"或"保存到 Obsidian"时：

1. 确认 URL
2. 调用 extract-article.js（脚本会自动读取配置）

```bash
ARTICLE_URL="用户提供的URL"

node ${AGENT_SKILL_DIR:-$HOME/Documents/RichardHub/Git/Skills/obsidian-article-extractor}/extract-article.js "$ARTICLE_URL"
```

## 输出示例

### 成功输出

```json
{
  "success": true,
  "filePath": "/Users/xxx/Obsidian/Vault/收件箱/2026-04-21T10-30-00_如何学习编程.md",
  "title": "如何学习编程",
  "author": "张三",
  "publishedDate": "2026-04-20"
}
```

### 失败输出

```json
{
  "success": false,
  "error": "HTTP 404 Not Found"
}
```

## 生成的文件格式

```markdown
---
title: "文章标题"
url: "https://..."
author: 作者名
date: 2026-04-21
source: https://...
tags:
  - article
  - inbox
---

# 文章标题

> **作者**: 作者名
> **来源**: [原文链接](https://...)
> **发布日期**: 2026-04-21

---

文章正文内容...

## 二级标题

段落内容...

- 列表项1
- 列表项2
```

## 注意事项

1. **微信公众号限制**
   - 部分公众号文章需要登录才能访问
   - 部分付费文章无法提取
   - 图片可能无法直接显示

2. **文件名生成规则**
   - 时间戳前缀确保文件不重名：`2026-04-21T10-30-00_`
   - 标题中非法字符自动替换：`<>:"/\|?*` → `_`
   - 标题截断至 100 字符

3. **收件箱文件夹**
   - 默认使用 `收件箱` 文件夹
   - 如果不存在会自动创建
   - 可以在第三个参数指定其他文件夹名称

4. **编码**
   - 所有文件使用 UTF-8 编码
   - 适合中文内容保存

5. **依赖**
   - 需要 Node.js 运行环境（v14+）
