# obsidian-vocab-skill

An OpenCode Skill for maintaining your English vocabulary Obsidian vault.

## When to Trigger

Use this skill when the user asks to:
- Add English words or phrases to their Obsidian vocabulary
- Look up English word meanings quickly
- Maintain or organize their English vocabulary file
- Generate review plans or export to Anki
- Check for duplicate entries
- Tag and categorize vocabulary entries
- Batch process vocabulary

## Input Forms

- **Word/phrase**: Direct text, clipboard content, or selection
- **Context**: Optional sentence showing where the word was encountered
- **Batch**: Text file with one word per line

## Output Forms

- **Obsidian Markdown**: Structured vocabulary entries in `Vocabulary.md`
- **Terminal display**: Word lookups without writing to file
- **Anki CSV**: Export for flashcard import

## Vocabulary File Path

Default: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub/阅读学习/Vocabulary.md`

The path can be changed via:
- Environment variable: `VOCAB_VOCAB_FILE`
- Config file: `~/.config/obsidian-vocab-capture/config.json`

## Operations

### Add a word
```
obsidian-vocab-capture add "word" [--context "sentence"]
```

### Add from clipboard
```
obsidian-vocab-capture clip
```

### Quick lookup (no write)
```
obsidian-vocab-capture lookup "word"
```

### Batch add
```
obsidian-vocab-capture batch words.txt
```

### Export for Anki
```
obsidian-vocab-capture export-anki
```

### Manage config
```
obsidian-vocab-capture config show
obsidian-vocab-capture config init --api-key sk-xxx --model gpt-4.1-mini
```

## Safety Boundaries

- **NEVER delete** the vocabulary file
- **NEVER modify** other Obsidian files
- **NEVER change** system environment variables
- **NEVER hardcode** API keys in any file
- **NEVER log** API keys (always mask: `sk-a***b1c2`)
- **ALWAYS backup** the vocabulary file before any modification (`.bak-YYYYMMDD-HHMMSS`)
- **ALWAYS validate** AI response JSON before writing
- **ALWAYS prompt user** before batch operations if >10 words
- **ALWAYS check for duplicates** before adding new entries

## Duplicate Handling

The tool supports three policies (configurable via `duplicate_policy`):
- `skip`: Don't add the word again
- `append_encounter`: Add an encounter record under the existing entry
- `overwrite`: Replace the existing entry with new AI results

Default: `append_encounter`

## Tags and Categories

Optional features to support:
- `#英语/高频` - High-frequency words
- `#英语/科技` - Tech vocabulary
- `#英语/金融` - Finance vocabulary
- `#英语/管理` - Management vocabulary
- `#英语/短语` - Phrases and idioms
- `#英语/学术` - Academic vocabulary

## Spaced Repetition Support

Supports generating review plans based on forgetting curve:
- Day 1, Day 3, Day 7, Day 15, Day 30

Review files go to: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub/阅读学习/Review/YYYY-MM-DD.md`

## Obsidian Integration

- Entries use `## heading` format compatible with Obsidian outline
- Supports `[[Wikilinks]]` with Obsidian's internal linking
- Daily review files can link back to `[[Vocabulary#word]]`

## Configuration

The skill uses `obsidian-vocab-capture` CLI tool. Before first use:
1. Run `pip install -e .` from the project root
2. Configure AI provider: `obsidian-vocab-capture config init --api-key YOUR_KEY`
3. Verify: `obsidian-vocab-capture config show`
