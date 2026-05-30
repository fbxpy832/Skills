你现在作为 OMA coder agent 执行任务。
Codex 是总控和最终 reviewer，你不是最终验收者。

你必须：

1. 阅读任务文件；
2. 阅读 planner 输出；
3. 阅读项目结构；
4. 最小化修改；
5. 实现用户需求；
6. 不做无关重构；
7. 不修改密钥、环境变量、部署配置；
8. 如果需要新增依赖，必须说明原因；
9. 尽量运行相关测试；
10. 输出修改文件清单；
11. 输出变更摘要；
12. 输出风险；
13. 如果遇到权限、模型、网络、工具调用失败，立即停止并报告。

不要伪造测试结果。
不要声称完成没有验证的事情。
# Skill Hub Development Task

Build a directly runnable desktop app named Skill Hub under `/Users/xpy/Documents/RichardHub/Git/skill-hub`.

Requirements:
- Use Electron for a macOS desktop app that can run with `npm start`.
- Use `/Users/xpy/Documents/RichardHub/Git` as the default Git skills source.
- Detect local skills as directories containing `SKILL.md`.
- Manage and distribute skills to Codex, Claude Code, OpenCode, and Hermes Agent local skill directories.
- Show each skill's status per target: synced, missing, outdated, or conflict.
- Sync selected skills to selected target tools.
- Back up existing target skill folders before replacement.
- Exclude sensitive or irrelevant files such as `.git`, `.env`, cookies, keys, `node_modules`, `.codex-opencode`, and `.superpowers`.
- Provide a compact cc-switch-like UI centered on Git skills first and target tools second.
- Include a Skill Hub icon based on a central node distributing to four tool nodes.
- Include tests for the core skill scanning and sync logic.

Current work:
- A design spec and implementation plan exist under `docs/superpowers/`.
- The first version of `skill-hub/src/lib/skillManager.js`, `skill-hub/package.json`, and `skill-hub/test/skillManager.test.js` has been started.

Please continue implementation without editing secrets or unrelated files. Keep changes scoped to `skill-hub/` and the existing docs unless a test requires a small fix.
# Plan Round 1

Task:
# Skill Hub Development Task

Build a directly runnable desktop app named Skill Hub under `/Users/xpy/Documents/RichardHub/Git/skill-hub`.

Requirements:
- Use Electron for a macOS desktop app that can run with `npm start`.
- Use `/Users/xpy/Documents/RichardHub/Git` as the default Git skills source.
- Detect local skills as directories containing `SKILL.md`.
- Manage and distribute skills to Codex, Claude Code, OpenCode, and Hermes Agent local skill directories.
- Show each skill's status per target: synced, missing, outdated, or conflict.
- Sync selected skills to selected target tools.
- Back up existing target skill folders before replacement.
- Exclude sensitive or irrelevant files such as `.git`, `.env`, cookies, keys, `node_modules`, `.codex-opencode`, and `.superpowers`.
- Provide a compact cc-switch-like UI centered on Git skills first and target tools second.
- Include a Skill Hub icon based on a central node distributing to four tool nodes.
- Include tests for the core skill scanning and sync logic.

Current work:
- A design spec and implementation plan exist under `docs/superpowers/`.
- The first version of `skill-hub/src/lib/skillManager.js`, `skill-hub/package.json`, and `skill-hub/test/skillManager.test.js` has been started.

Please continue implementation without editing secrets or unrelated files. Keep changes scoped to `skill-hub/` and the existing docs unless a test requires a small fix.

Mode:
auto

Guidance:
- Keep changes minimal and inside project scope.
- Do not modify secrets, tokens, cookies, .env files, SSH keys, certificates, or system configuration.
- Do not install dependencies unless explicitly allowed by .codex-opencode/config.json.
- Do not claim tests passed unless they actually ran.

## Runtime Instructions
OMA mode: auto
If CLI agent selection is not supported, role selection is prompt-based, not CLI-enforced.
Write a concise summary, changed files, tests run, and risks.
