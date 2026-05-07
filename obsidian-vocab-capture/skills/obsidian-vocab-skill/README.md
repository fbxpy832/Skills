# obsidian-vocab-skill

An OpenCode Skill for English vocabulary management with Obsidian.

## Installation

1. Ensure the `obsidian-vocab-capture` CLI tool is installed:
   ```bash
   cd obsidian-vocab-capture
   pip install -e .
   ```

2. Register this skill with OpenCode.

3. Configure your AI provider:
   ```bash
   obsidian-vocab-capture config init --api-key YOUR_KEY --model gpt-4.1-mini
   ```

## Usage Examples

### Quick Word Capture
```
User: I just saw "ubiquitous" in an article. Add it to my vocab.
Assistant: *Uses obsidian-vocab-capture add "ubiquitous"*
```

### Batch Import
```
User: Here's a list of words I need to learn: abandon, resilient, persistent, ubiquity
Assistant: *Creates words.txt and runs obsidian-vocab-capture batch words.txt*
```

### Generate Anki Flashcards
```
User: Export all my vocabulary to Anki.
Assistant: *Runs obsidian-vocab-capture export-anki*
```

### Check for Duplicates
```
User: Check if I already have "resilient" in my vocabulary.
Assistant: *Reads Vocabulary.md and checks for `## resilient` heading*
```

## Scripts

See `scripts/` directory for helper scripts:
- `organize_tags.py` - Tag vocabulary entries by category
- `generate_review.py` - Generate daily review files
- `check_duplicates.py` - Scan for duplicate entries
