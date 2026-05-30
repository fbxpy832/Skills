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
