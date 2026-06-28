# obsidian-article-extractor 优化方案

> 基于 git 仓库 v2.0 版本（`extract-article.js` 473 行）分析。当前版本已具备基础提取能力，但在解析稳健性、内容完整性、可维护性、工程化方面存在明确改进空间。本方案按优先级分级，每项含「问题—影响—方案—工作量」。

## 现状概览

- 技术栈：Node.js + turndown + turndown-plugin-gfm + domino（间接依赖）
- 流程：fetch HTML → 正则提取正文/元数据 → 清洗 → 图片占位符下载 → turndown 转 Markdown → 写入 Vault
- 配置缓存：`~/.config/obsidian-article-extractor/{vault-path,inbox-folder}`
- 安装副本：`~/.codex/skills/`、`~/.agents/skills/` 均为 v1.8 旧版，落后于 git v2.0

---

## P0 — 影响正确性，建议优先修复

### 1. `rich_media_content` fallback 正则截断正文

- **问题**：`extractContent` 的 fallback 用 `class="rich_media_content"[^>]*>([\s\S]*?)<\/div>`，非贪婪 `[\s\S]*?` 会匹配到最近的 `</div>`，而微信正文内部大量嵌套 div，导致内容在第一个内层 div 闭合处被截断。
- **影响**：当 `js_content` 主正则失效（页面结构变化或 `js_pc_qr_code` 标记缺失）时，文章被切到第一段为止，静默丢内容。
- **方案**：用 domino（已在依赖树中）做 DOM 解析，`document.getElementById('js_content')` 或 `querySelector('.rich_media_content')` 取 `innerHTML`，彻底替代正文正则。通用网页 fallback 同样用 `document.querySelector('article, main, body')`。
- **工作量**：0.5 天。需重构 `extractContent`，引入 domino 解析入口。

### 2. 广告过滤误删连续图集正文

- **问题**：`AD_SECTION_PATTERNS` 最后一条 `/(?:<img[^>]+>\s*){3,}/gi` 匹配「连续 3 张及以上图片」整段删除。教程、摄影、测评类文章常含连续配图，会被整段清空。
- **影响**：图集型正文大面积丢图，且无告警，用户难以察觉。
- **方案**：删除该条规则。如需识别广告合辑，改为结合上下文判定：仅当连续图片所在 section 同时命中「广告/推广/赞助」关键词，或该图片组位于文章末尾且无正文文字伴随时才删除。
- **工作量**：0.5 天（含回归样本验证）。

### 3. 注释与代码不符（缓存路径误导）

- **问题**：`extract-article.js` 第 7 行注释写「缓存到 `~/.agents/skills/.vault-path` 和 `.inbox-folder`」，实际代码（第 23 行）用 `~/.config/obsidian-article-extractor/`。注释是历史遗留，未随重构更新。
- **影响**：排查缓存问题时被误导，怀疑 SKILL.md 与实现不一致。
- **方案**：更新注释为 `~/.config/obsidian-article-extractor/{vault-path,inbox-folder}`。
- **工作量**：5 分钟。

### 4. SKILL.md 引用不存在的参考文档

- **问题**：SKILL.md「实现亮点」第 7 条引用 `references/utf8-chunk-boundary-fix.md`，该文件不存在，`references/` 下只有 `extract-article.md`。
- **影响**：Agent 按指令加载参考文件会失败，触发 fallback，浪费一轮交互。
- **方案**：补写 `references/utf8-chunk-boundary-fix.md`（记录 chunk 边界乱码问题与 `setEncoding('utf-8')` 修复），或删除该引用。
- **工作量**：补文档 0.5 小时；删引用 1 分钟。建议补文档，保留经验沉淀。

### 5. 安装副本落后于 git（多副本不同步）

- **问题**：`~/.codex/skills/obsidian-article-extractor/` 和 `~/.agents/skills/` 仍是 v1.8，缺少 UTF-8 流式解码、data-src 优先、超大图片跳过、实体解码顺序修复。git 已是 v2.0。
- **影响**：实际运行的是旧版，v2.0 的修复未生效；中文跨包乱码、图片懒加载失败等问题仍会复现。references 文档还残留 `Git/Skills/` 旧路径一处。
- **方案**：写一个 `sync.sh`，从 git 目录 rsync 到两个安装目录（排除 `.git`、`node_modules`，安装目录单独 `npm ci`）。或反向：让 SKILL.md 的 `AGENT_SKILL_DIR` 直接指向 git 目录，不再维护副本。推荐后者，单一来源。
- **工作量**：1 小时（脚本 + 验证）。

---

## P1 — 影响体验与稳健性

### 6. 图片 MIME 靠 URL 扩展名推断，微信 CDN 常无扩展名

- **问题**：`doDownloadImage` 用 `path.extname(new URL(imgUrl).pathname)` 推断 mime。微信图片 URL 形如 `mmbiz_png/.../640?wx_fmt=png` 或无扩展名 cgi，推断常落空默认 `image/jpeg`，导致 webp/png 被标成 jpeg。
- **影响**：base64 前缀 mime 错误，Obsidian 部分版本不渲染或显示破损图标。
- **方案**：优先读响应头 `Content-Type`，回退到 URL 扩展名，再回退 `application/octet-stream` 时跳过内嵌保留 URL。同时支持 `wx_fmt` 查询参数推断。
- **工作量**：0.5 天。

### 7. webp base64 在 Obsidian 兼容性差

- **问题**：webp 图片 base64 内嵌，Obsidian 桌面端早期版本、移动端对 `data:image/webp` 渲染支持不稳。
- **影响**：图片不显示，但无报错。
- **方案**：可选策略——(a) webp 保留原 URL 不内嵌；(b) 用 `sharp` 转 png 再内嵌（增加原生依赖，与「单文件无依赖」理念冲突）。推荐 (a)，作为配置项 `--no-webp-embed`。
- **工作量**：0.5 天。

### 8. `fetchHtml` 重定向无深度限制

- **问题**：`fetchHtml` 递归跟随重定向无上限，异常站点可能形成重定向环。
- **影响**：极端情况下递归爆栈或超时后行为混乱。
- **方案**：加 `maxRedirects = 5` 参数，超过抛错。同时图片下载 `doDownloadImage` 只处理 301/302，补齐 307/308 与 `fetchHtml` 一致。
- **工作量**：1 小时。

### 9. 页面抓取无重试，微信偶发 502 直接失败

- **问题**：`fetchHtml` 失败立即 reject，仅图片有重试。微信 CDN 偶发 502/503。
- **影响**：偶发失败需用户手动重跑。
- **方案**：对 5xx 和超时做 1 次重试（间隔 1s），4xx 不重试。
- **工作量**：1 小时。

### 10. frontmatter 与文档示例不一致（缺 `source` 字段）

- **问题**：`references/extract-article.md`「生成的文件格式」示例含 `source: https://...`，实际代码只写 `url`，无 `source`。
- **影响**：文档与实现不符，依赖 `source` 字段的下游插件/查询失效。
- **方案**：要么代码补 `source`（与 `url` 重复，建议删除文档示例里的 `source`），要么统一为 `url`。建议删文档冗余字段。
- **工作量**：10 分钟。

### 11. 同 URL 重复提取生成多份文件，无去重

- **问题**：每次提取都用时间戳前缀生成新文件，同一文章提取 N 次产生 N 个文件。
- **影响**：收件箱堆积重复笔记。
- **方案**：写入前扫描 inbox，若存在 frontmatter `url` 相同的文件，默认覆盖（或加 `--skip-duplicate` 跳过、`--force` 强制新建）。默认行为建议「同 URL 覆盖，不同 URL 新建」。
- **工作量**：0.5 天。

### 12. `publish_time` ISO 字符串解析失败

- **问题**：`extractWxMeta` 对 `"publish_time":"..."` 匹配后直接 `parseInt(ts)`，若值为 ISO 字符串（`2026-04-21T...`）得到 NaN，`new Date(NaN).toISOString()` 抛错被外层 catch 吞掉，日期为 null。
- **影响**：日期元数据静默丢失。
- **方案**：判断 `ts` 是否全数字，否则用 `new Date(ts)` 直接解析；解析失败置 null 不抛。
- **工作量**：30 分钟。

---

## P2 — 工程化与可维护性

### 13. `node_modules` 提交进 git（1042 个文件被跟踪）

- **问题**：`git ls-files node_modules` 显示 1042 个文件入库，仓库膨胀，跨平台可选依赖可能因平台二进制不一致出问题。
- **影响**：clone 慢、同步污染、违背 git 最佳实践。
- **方案**：加 `.gitignore` 忽略 `node_modules/`，`git rm -r --cached node_modules`，README/SKILL.md 注明首次需 `npm ci`。SKILL.md `requires.node_modules` 字段已声明，Agent 安装流程应负责装依赖。
- **工作量**：30 分钟。

### 14. 零测试覆盖

- **问题**：`package.json` test 脚本是占位 `echo "Error: no test specified"`，无任何单测/集成测。正则解析逻辑脆弱，每次改正文提取或广告过滤都靠肉眼。
- **影响**：回归风险高，P0 第 1、2 项 bug 修复后无法验证不复发。
- **方案**：引入 `node:test`（Node 内置，零依赖）。建立 `test/fixtures/` 存放脱敏的微信/通用网页 HTML 样本，针对 `extractContent`、`extractWxMeta`、`removeAdContent`、`embedImages`（mock 下载）、`safeFilename`、`decodeHtmlEntities` 写单测。目标覆盖核心解析路径。
- **工作量**：1.5 天。

### 15. 错误输出丢失堆栈

- **问题**：`main().catch` 只打印 `err.message`，正则/DOM 解析错误时定位困难。
- **影响**：线上问题难复现排查。
- **方案**：加 `--verbose` 标志，开启时输出 `err.stack`；默认仍只输出 message 保持 JSON 输出干净。
- **工作量**：30 分钟。

### 16. frontmatter 信息单薄，未提取 og:description / og:image

- **问题**：仅提取 title/author/date，未取 og:description（摘要）、og:image（封面）。tags 固定 article/inbox，无来源分类。
- **影响**：笔记元数据不够丰富，Obsidian Dataview 查询、封面预览缺失。
- **方案**：补 `description`、`cover` 字段；`tags` 按域名自动追加来源标签（`wx`/`zhihu`/`blog`），保留 article/inbox。
- **工作量**：0.5 天。

### 17. Vault 路径未校验是否为真实 Obsidian Vault

- **问题**：`vaultPath` 只检查存在，未校验 `.obsidian` 目录，可能误写到任意文件夹。
- **影响**：配错路径时笔记写进非 Vault 目录，Obsidian 看不到。
- **方案**：警告级（不阻断）——无 `.obsidian` 时 stderr 提示「该路径未检测到 Obsidian 配置，确认是否正确」，仍继续写入。
- **工作量**：20 分钟。

### 18. 大文件性能与体积

- **问题**：base64 内嵌使单 md 文件可达 10MB+，Obsidian 打开卡顿；多次全量 `replace` 在大 HTML 上 CPU 开销高。
- **影响**：图文密集长文体验差。
- **方案**：提供 `--image-mode=link|base64|attach` 三档。`link` 仅保留 URL（最快最小），`base64` 当前行为，`attach` 存到 Vault `attachments/` 子目录用 `![](attachments/xxx.png)` 引用（需建子目录，回到「多文件」但体积可控）。默认保持 base64 兼容现有体验。
- **工作量**：1 天。

### 19. 站点适配有限

- **问题**：仅微信专项优化，知乎/掘金/CSDN/简书等通用网页走 `<article>/<main>/<body>` fallback，正文选择器命中率和噪音过滤效果参差。
- **影响**：非微信站点正文常含侧栏、评论、推荐区。
- **方案**：引入轻量「站点适配表」`siteAdapters`，按域名注册正文选择器与清洗规则，微信作为首个适配项。通用 fallback 保留。
- **工作量**：1 天（含 2-3 个主流站点适配）。

### 20. package.json 元数据缺失

- **问题**：`description` 为空，`author`/`license`/`keywords` 未填，`test` 脚本占位。
- **影响**：不规范，影响可发布性。
- **方案**：补 description、license（ISC 已声明，确认即可）、keywords、test 脚本指向 `node --test`。
- **工作量**：10 分钟。

---

## 实施建议

**第一批（1-2 天，修正确性）**：项 1、2、3、4、5、10、12 — 修复正文截断、图集误删、注释/文档一致性、安装副本同步、日期解析。这一批直接提升「提取结果是否完整正确」。

**第二批（2-3 天，稳健性）**：项 6、7、8、9、11、15、17 — 图片 mime、webp、重定向、重试、去重、堆栈、vault 校验。

**第三批（2-3 天，工程化）**：项 13、14、16、18、19、20 — gitignore、测试、元数据、图片模式、站点适配、package 元数据。

建议每批完成后跑一次真实微信文章端到端提取，对照「提取后验证」脚本检查 U+FFFD 计数与正文完整性，再进入下一批。

## 验收标准

- P0 全部修复，端到端提取 3 篇真实微信文章（含图集、含嵌套 div、含懒加载图）正文与图片完整，无截断、无图集误删。
- `~/.codex/skills` 与 `~/.agents/skills` 副本与 git 版本一致（v2.0+）。
- 核心解析函数有单测覆盖，`npm test` 通过。
- node_modules 移出 git 跟踪，clone 后 `npm ci` 可正常运行。
- SKILL.md 所有 references 引用真实存在，注释与代码一致。
