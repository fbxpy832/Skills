# obsidian-vocab-capture

English vocabulary capture tool - select a word in any macOS app, press a shortcut, and it's AI-explained and saved to your Obsidian vault.

## Overview

- Select an English word or phrase anywhere in macOS
- Press a shortcut (via PopClip, Raycast, Automator, or Shortcuts)
- AI looks it up and generates a structured explanation
- Automatically appended to your Obsidian `Vocabulary.md`

## Installation

```bash
# Clone or navigate to the project
cd obsidian-vocab-capture

# Install with pip
pip install -e .

# Or with dev dependencies for testing
pip install -e ".[dev]"
```

## Quick Start

### 1. Configure AI Provider

```bash
# Using environment variables (recommended)
export VOCAB_AI_BASE_URL="https://api.openai.com/v1"
export VOCAB_AI_API_KEY="sk-your-key-here"
export VOCAB_AI_MODEL="gpt-4.1-mini"

# Or using config file
obsidian-vocab-capture config init \
  --api-key sk-your-key \
  --model gpt-4.1-mini \
  --base-url https://api.openai.com/v1
```

Verify configuration:

```bash
obsidian-vocab-capture config show
```

### 2. Add Your First Word

```bash
obsidian-vocab-capture add "abandon"
```

This will:
1. Call the AI to look up "abandon"
2. Generate a structured Markdown entry
3. Append it to `~/Documents/RichardHub/English/Vocabulary.md`

### 3. Set Up Quick Capture

See [macOS Quick Actions Guide](docs/macos-quick-actions.md) for setting up PopClip, Raycast, Automator, or Shortcuts.

## Command Reference

### `add` - Add a word or phrase
```bash
obsidian-vocab-capture add "resilient"
obsidian-vocab-capture add "take for granted" --context "He took his health for granted."
```

### `clip` - Add from clipboard
```bash
# Copy a word, then run:
obsidian-vocab-capture clip
```

### `lookup` - Look up without saving
```bash
obsidian-vocab-capture lookup "ubiquitous"
obsidian-vocab-capture lookup "break the ice" --context "During the meeting, he broke the ice."
```

### `batch` - Add multiple words from a file
```bash
# words.txt contains one word per line:
# abandon
# resilient
# persistent

obsidian-vocab-capture batch words.txt
```

### `export-anki` - Export to Anki CSV
```bash
obsidian-vocab-capture export-anki
# Output: ~/Documents/RichardHub/English/vocabulary_anki.csv
```

### `config` - Manage configuration
```bash
obsidian-vocab-capture config show
obsidian-vocab-capture config init --api-key sk-xxx --model gpt-4.1-mini
```

## Markdown Entry Format

Each word creates a structured entry in Vocabulary.md:

```markdown
## abandon

- 音标：/əˈbændən/
- 词性：verb
- 中文释义：放弃；抛弃
- 英文解释：to leave behind or give up completely
- 常见搭配：
  - abandon hope
  - abandon ship
  - abandon oneself to
- 例句：
  - He abandoned the project after months of hard work.
  - The crew had to abandon the sinking ship.
- 词根/记忆：from Old French abandoner "to surrender"
- 使用场景：formal and informal; can describe physical or emotional relinquishment
- 易混词：
  - abundant (充足的)
  - abdomen (腹部)
- 添加时间：2026-05-07
- 来源：manual-capture
```

## Duplicate Handling

When you try to add a word that already exists:

| Policy | Behavior |
|--------|----------|
| `skip` | Do nothing |
| `append_encounter` | Add "再次遇到" record under existing entry |
| `overwrite` | Replace existing entry with new AI results |

Set via config or environment:

```bash
export VOCAB_DUPLICATE_POLICY=append_encounter
```

## Supported AI Providers

Compatible with any OpenAI-compatible API:

- **OpenAI**: `gpt-4.1-mini`, `gpt-4o`, etc.
- **DeepSeek**: `deepseek-chat`
- **GLM/Zhipu**: `glm-4-flash`
- **Ollama** (local): `http://localhost:11434/v1` with any model

## Configuration

| Env Variable | Config Key | Description |
|---|---|---|
| `VOCAB_AI_BASE_URL` | `ai.base_url` | API endpoint |
| `VOCAB_AI_API_KEY` | `ai.api_key` | API key (never logged) |
| `VOCAB_AI_MODEL` | `ai.model` | Model name |
| `VOCAB_VAULT_PATH` | `vault_path` | Obsidian vault path |
| `VOCAB_VOCAB_FILE` | `vocab_file` | Vocabulary file path |
| `VOCAB_LANGUAGE` | `language` | Response language (zh-CN, en, etc.) |
| `VOCAB_DUPLICATE_POLICY` | `duplicate_policy` | skip / append_encounter / overwrite |
| `VOCAB_DATE_FORMAT` | `date_format` | Date format |

Config file location: `~/.config/obsidian-vocab-capture/config.json`

## Safety

- **NEVER** exposes API keys in logs or errors (always masked: `sk-a***xYz`)
- **ALWAYS** creates timestamped backups before modifying files (`.bak-YYYYMMDD-HHMMSS`)
- **NEVER** deletes or overwrites vocabulary files without backup
- **NEVER** writes incomplete entries (AI failure = no write)
- **ONLY** modifies the configured vocabulary file (not other vault files)

## Logs

Log file: `~/.local/state/obsidian-vocab-capture/logs/app.log`

Enable verbose logging with `-v` flag on any command.

## Development

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest tests/ -v

# Run specific test
pytest tests/test_parser.py -v
```

## TODO / Future Features

- [ ] Auto-tagging by category (#英语/科技, #英语/金融, etc.)
- [ ] Daily review file generation with spaced repetition
- [ ] Obsidian wikilink support (`[[Vocabulary#word]]`)
- [ ] Split entries into individual word files
- [ ] Review scheduler based on forgetting curve (Day 1, 3, 7, 15, 30)
- [ ] Rich terminal UI with progress bars for batch operations
