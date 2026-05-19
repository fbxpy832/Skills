# Security Policy

## Credential Storage

- 所有 API key 和 token 只保存在本机私有配置文件：
  ```
  ~/.config/deep-research-skill/config.env
  ```
- 该文件权限必须为 `0600`（仅 owner 可读写）
- **严禁**将 `config.env` 提交到 git 或分享给他人
- 可通过 `DEEP_RESEARCH_CONFIG_ENV` 指向自定义配置文件路径

## Logging

- Runner 日志和 dry-run 输出不得写入 API key 或 token
- 搜索缓存（`/tmp/opencode-brave-cache.json`）不得保存含敏感信息的 query
- 如需清理搜索缓存：`rm -f /tmp/opencode-brave-cache.json`

## Events

- `events.ndjson` 中的 `message` 和 `error` 字段不得包含 API key 或完整 token
- 写事件前，`write_event()` 函数已做 JSON escaping，不直接拼接敏感字符串

## Files excluded from git

`.gitignore` 已排除：
```
config.env
.env
*.key
outputs/
runs/
```

## Reporting

发现安全问题请通过内部渠道报告，不要提交公开 issue。
