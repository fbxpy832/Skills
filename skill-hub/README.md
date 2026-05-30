# Skill Hub

Desktop manager for distributing local agent skills from a Git skills root to Codex, Claude Code, OpenCode, and Hermes Agent.

## Run

```bash
npm install
npm start
```

If Electron downloads slowly or times out on the current network, use:

```bash
ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/" npm install
npm start
```

## Defaults

- Source skills root: `/Users/xpy/Documents/RichardHub/Git`
- Codex target: `~/.codex/skills`
- Claude Code target: `~/.claude/skills`
- OpenCode target: `~/.config/opencode/skills`
- Hermes Agent target: `~/.hermes/skills`

Skill Hub treats any source child directory containing `SKILL.md` as a skill.

## Safety

Existing target skill folders are backed up into `.skill-hub-backups` before replacement. The sync logic excludes `.git`, `.env`, cookies, secret-like files, key/certificate extensions, dependency folders, `.codex-opencode`, and `.superpowers`.

Use `Force` only when you want to replace a target folder that exists but does not look like a normal skill folder.

`Delete Selected` removes selected skills only from selected target directories. It does not delete the source skill folders under the Git skills root, and it skips target folders that do not contain `SKILL.md`.
