# Source Failure Log

当 web 搜索、资料抓取、API 调用、文件读取或来源验证失败时，必须记录 `source_failure_log`。

## Trigger Conditions

任一情况触发：

- web 搜索失败。
- 外部检索不可用。
- API 超时或返回错误。
- 资料抓取失败。
- 公开来源不足。
- 关键来源只有 C/D 级。
- 关键数据没有发布时间、统计口径或获取时间。

## Required Fields

```yaml
source_failure_log:
  - failure_time:
    failed_stage:
    failure_type: web_search_failed / fetch_failed / api_timeout / source_insufficient / source_quality_low / timestamp_missing
    affected_scope:
    fallback_handling:
    required_manual_sources:
    suggested_databases_or_keywords:
```

## High Quality Downgrade

`high_quality` 模式下，如果外部搜索、抓取或来源核验失败：

- 不得标记为最终高质量报告。
- 文件名必须加 `-离线初稿` 或 `-待联网核验版`。
- 报告开头必须标注“本报告为离线初稿/待联网核验版”。
- 交付摘要必须写明搜索状态为 `failed` 或 `partial_success`。
- 审计等级最高为 `CONDITIONAL_PASS`。

## Technical Route Source Requirements

技术路线研究类任务必须强制启用 source_agent。即使搜索失败，source_agent 也必须输出：

- 来源缺口清单。
- 建议补充检索的数据库。
- 建议补充检索的关键词。
- 当前结论哪些部分不能作为最终技术路线决策依据。

技术路线高质量报告优先核验：

- IEEE Xplore。
- arXiv。
- ACM Digital Library。
- ISSCC。
- IEDM。
- Hot Chips。
- 相关公司官网。
- 专利数据库。
- 头部半导体公司白皮书或技术博客。
- 招投标、产业政策、投融资公开信息。

## Offline Draft Labels

如果报告为离线初稿，文件名必须自动加后缀：

- `-离线初稿`
- 或 `-待联网核验版`
