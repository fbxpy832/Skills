# 待办清单（全部完成）

> TODOs.md 现作为验收记录。所有 OPTIMIZATION-PLAN.md 和 TODOs 中的优化项已实施完毕。

## P0 — 修正确性（5 项 ✅）

| 项 | 内容 | 状态 |
|----|------|------|
| 1 | `rich_media_content` 正则截断 → domino DOM 解析 | ✅ |
| 2 | 广告过滤误删连续图集 → 已删除误杀规则 | ✅ |
| 3 | 注释缓存路径误导 → 更新为实际路径 | ✅ |
| 4 | SKILL.md 死链接（utf8-chunk-boundary-fix.md）→ 已创建 | ✅ |
| 5 | 安装副本同步 → sync.sh | ✅ |

## P1 — 稳健性（5 项 ✅）

| 项 | 内容 | 状态 |
|----|------|------|
| 6 | 图片 MIME 从 Content-Type 头读取（回退扩展名/wx_fmt） | ✅ |
| 7 | webp 跳过内嵌（Obsidian 兼容性） | ✅ |
| 8 | 重定向深度限制（maxRedirects = 5）、补齐 307/308 | ✅ |
| 9 | 页面抓取 5xx/超时 1 次重试（fetchHtmlWithRetry） | ✅ |
| 10 | 同 URL 去重（扫描 frontmatter，同 URL 覆盖） | ✅ |

## P2 — 功能扩展（8 项 ✅）

| 项 | 内容 | 状态 |
|----|------|------|
| 11 | publish_time 支持 ISO 字符串解析 | ✅ |
| 12 | 错误堆栈 --verbose / -v | ✅ |
| 13 | Vault 路径 .obsidian 校验（警告不阻断） | ✅ |
| 14 | frontmatter 丰富化（description/cover + 来源标签） | ✅ |
| 15 | package.json 元数据（description/keywords/author/test） | ✅ |
| 16 | .gitignore（忽略 node_modules） | ✅ |
| 17 | --image-mode 三档（base64/link/attach） | ✅ |
| 18 | SITE_ADAPTERS 站点适配（微信/知乎/掘金/CSDN） | ✅ |

---

## 总改动统计

```
extract-article.js  560 → 691 行 (net +131)
SKILL.md            路径统一 + reference 可点击链接
package.json        元数据 + test 脚本
references/         双文档已更新
.gitignore          新增
OPTIMIZATION-PLAN.md 分析方案
TODOs.md            本清单
sync.sh             同步脚本
```

所有改动均通过 `node --check` 语法验证。
