# Execution Consistency

最终报告不得把“模型路由建议”写成“真实已使用模型”，除非有可检测执行记录支持。

## Model Status Terms

- `真实切换`：runner 或 OpenCode 命令明确以 `--model <model_id>` 调用，并在运行日志中记录该 model_id。
- `指令级建议`：Skill 或配置建议某 agent 使用某模型，但当前会话无法验证真实执行模型。
- `无法验证`：没有 runner 日志、OpenCode 状态、命令输出或其他可审计记录。

## Mandatory Rule

最终交付摘要中的模型使用说明必须基于真实可检测上下文：

- 有 `run-summary.md` 和 `logs/*.log`：可写“请求模型/命令模型为 ...”，但仍需区分“请求模型”和“OpenCode UI 实际显示模型”。
- 有 OpenCode 状态栏或命令输出显示实际模型：可写“检测到实际模型为 ...”。
- 无法检测真实模型：必须写“模型使用未能自动验证”，不得宣称“已使用 DeepSeek V4 Pro/Kimi 2.6/Flash”。

如果 OpenCode Skill 当前无法真正切换模型，模型路由机制必须标记为“指令级路由建议”。

## Consistency Checklist

最终交付前检查：

- 声明的运行模式是否与实际任务一致。
- 声明的模型是否能被验证。
- OpenCode UI/状态栏模型是否与报告声明一致。
- 启用的 Subagent 是否与任务类型匹配。
- 技术路线任务是否启用 source_agent。
- 搜索状态是否成功。
- 来源失败是否进入 `source_failure_log`。
- 质量审计是否考虑搜索失败和模型不一致。

## Reporting Fields

```yaml
real_model_detection_status: verified / partially_verified / not_verified
model_route_execution_status: real_switch / instruction_level_recommendation / unable_to_verify
declared_model:
detected_model:
model_mismatch: yes / no / unknown
search_status: success / partial_success / failed
audit_grade: PASS / CONDITIONAL_PASS / FAIL
report_usability: 正式版 / 内部初稿 / 离线初稿 / 仅供参考
required_source_verification:
```

## Mismatch Handling

如果实际模型与声明模型不一致：

- high_quality 不得 PASS。
- 如果内容结构完整且来源可后续核验，最多 `CONDITIONAL_PASS`。
- 必须在报告开头和交付摘要写明模型不一致。
- 不得写“已使用 Pro 级审计模型”。

如果模型使用无法验证：

- high_quality 不得 PASS。
- 报告可用性最多为“内部初稿”或“离线初稿”。
- 必须写“模型使用未能自动验证，结论需人工复核。”
