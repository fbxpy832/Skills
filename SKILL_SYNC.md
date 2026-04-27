# Skill Sync Layout

This repository is the source of truth for user-managed skills across Claude, Codex, and ccswitch.

## Source Folders

- `.agents/skills/`: cross-terminal skills. Put skills here when they can work in Claude, Codex, and other agent terminals.
- `.claude/skills/`: Claude-only skills. Put skills here when they depend on Claude-specific tools, environment variables, plugins, or wording.
- `.codex/skills/`: Codex-only skills. Put skills here when they depend on Codex-specific tools or desktop/runtime behavior.
- `scripts/sync-skills.sh`: deploy the source folders into local runtime folders on each Mac.

## Current Classification

Common skills:

- `auto-calendar-tasks`
- `find-skills`
- `lark-*`
- `obsidian-article-extractor`

Claude-only skills:

- `frontend-design`: currently sourced from a Claude plugin and references Claude behavior.
- `web-access`: depends on Claude-style browser/CDP workflow and `CLAUDE_SKILL_DIR`.

Codex-only skills:

- None currently. Do not sync Codex built-ins such as `.system` or `codex-primary-runtime`.

## Install On A Mac

From this repository:

```bash
scripts/sync-skills.sh --dry-run
scripts/sync-skills.sh
```

The script copies common skills into `~/.agents/skills` as real directories because Hermes Agent does not recognize symlinked skills there. It creates symlinks for Claude, Codex, and ccswitch runtime folders so those terminals can still point directly at this repository.
