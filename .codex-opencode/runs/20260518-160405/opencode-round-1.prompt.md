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
Create a new skill named deep-research-skill based on the existing opencode-deep-research skill in this repository.

Important coordination rules:
- You are OpenCode CLI handling the development task under codex-opencode-autoloop.
- Treat current working tree changes as user/Codex existing work. Do not revert unrelated changes.
- Review the existing deep-research-skill directory if present and continue from it rather than starting over.
- Keep the original opencode-deep-research core research workflow materially unchanged.

Required outcome:
- deep-research-skill/SKILL.md must use name: deep-research-skill and describe a company-rollout-ready deep research workflow.
- Add first-use setup like hermes setup: users can choose model sources, configure endpoints/base URLs, enter API key or token plan key, and assign models per research agent.
- Support multiple model sources such as OpenCode token plan, DeepSeek, Moonshot/Kimi, OpenAI, OpenRouter, SiliconFlow, and a custom OpenAI-compatible endpoint.
- Model routing must prefer local user configuration when present and fall back to built-in defaults when not configured.
- Search tools must require users to configure their own API keys. Remove any hardcoded personal Brave/Bocha/Exa API keys from the new skill.
- Prompt users to configure BRAVE_API_KEY, BOCHA_API_KEY, and EXA_API_KEY during setup.
- Ensure scripts are executable and do not write secrets into the repository.
- Update references that still mention old hardcoded keys or opencode-deep-research paths where they would confuse users of deep-research-skill.

Verification:
- Run shell syntax checks for deep-research-skill/scripts/*.sh.
- Run the model router with and without a temporary config override to prove local per-agent model selection works.
- Run search.sh --dry-run in a way that does not require network.
- Report changed files, validation results, and any remaining limitations.
# Plan Round 1

Task:
Create a new skill named deep-research-skill based on the existing opencode-deep-research skill in this repository.

Important coordination rules:
- You are OpenCode CLI handling the development task under codex-opencode-autoloop.
- Treat current working tree changes as user/Codex existing work. Do not revert unrelated changes.
- Review the existing deep-research-skill directory if present and continue from it rather than starting over.
- Keep the original opencode-deep-research core research workflow materially unchanged.

Required outcome:
- deep-research-skill/SKILL.md must use name: deep-research-skill and describe a company-rollout-ready deep research workflow.
- Add first-use setup like hermes setup: users can choose model sources, configure endpoints/base URLs, enter API key or token plan key, and assign models per research agent.
- Support multiple model sources such as OpenCode token plan, DeepSeek, Moonshot/Kimi, OpenAI, OpenRouter, SiliconFlow, and a custom OpenAI-compatible endpoint.
- Model routing must prefer local user configuration when present and fall back to built-in defaults when not configured.
- Search tools must require users to configure their own API keys. Remove any hardcoded personal Brave/Bocha/Exa API keys from the new skill.
- Prompt users to configure BRAVE_API_KEY, BOCHA_API_KEY, and EXA_API_KEY during setup.
- Ensure scripts are executable and do not write secrets into the repository.
- Update references that still mention old hardcoded keys or opencode-deep-research paths where they would confuse users of deep-research-skill.

Verification:
- Run shell syntax checks for deep-research-skill/scripts/*.sh.
- Run the model router with and without a temporary config override to prove local per-agent model selection works.
- Run search.sh --dry-run in a way that does not require network.
- Report changed files, validation results, and any remaining limitations.

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
