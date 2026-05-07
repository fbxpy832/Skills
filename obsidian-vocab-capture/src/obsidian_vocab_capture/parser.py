"""Parser for Vocabulary.md to detect duplicates and extract entries."""

import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .utils import norm_word

# Pattern to match ## word heading
HEADING_PATTERN = re.compile(r'^##\s+(.+)$', re.MULTILINE)


def find_word_position(vocab_path: Path, word: str) -> Optional[Tuple[int, int]]:
    """Find the position of a word entry in the vocabulary file.

    Returns (start_line, end_line) if found, None otherwise.
    Both are 0-indexed line numbers.
    Start line is the heading line. End line is the line BEFORE the next heading
    (or EOF if last entry).

    Args:
        vocab_path: Path to Vocabulary.md.
        word: The normalized word to look for.

    Returns:
        Tuple of (start_line, end_line) or None.
    """
    if not vocab_path.exists():
        return None

    normalized = norm_word(word)
    with open(vocab_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    headings = []  # [(line_index, heading_text)]
    for i, line in enumerate(lines):
        m = HEADING_PATTERN.match(line.rstrip('\n'))
        if m:
            headings.append((i, m.group(1).strip()))

    for idx, (start, heading) in enumerate(headings):
        if norm_word(heading) == normalized:
            # Found the word - determine end
            if idx + 1 < len(headings):
                end = headings[idx + 1][0] - 1  # line before next heading
            else:
                end = len(lines) - 1
            return (start, end)

    return None


def word_exists(vocab_path: Path, word: str) -> bool:
    """Check if a word already exists in the vocabulary file."""
    return find_word_position(vocab_path, word) is not None


def extract_all_words(vocab_path: Path) -> List[str]:
    """Extract all word headings from the vocabulary file."""
    if not vocab_path.exists():
        return []

    words = []
    with open(vocab_path, "r", encoding="utf-8") as f:
        for line in f:
            m = HEADING_PATTERN.match(line.rstrip('\n'))
            if m:
                words.append(m.group(1).strip())
    return words


def parse_vocab_entry(lines: List[str], start: int, end: int) -> Dict[str, str]:
    """Parse a single vocabulary entry from lines.

    Args:
        lines: All lines of the vocabulary file.
        start: Start line index (heading).
        end: End line index (inclusive).

    Returns:
        Dictionary with parsed fields.
    """
    entry_lines = lines[start:end + 1]
    entry_text = "".join(entry_lines)

    result: Dict[str, str] = {}

    # Extract heading
    heading_match = HEADING_PATTERN.match(entry_lines[0].rstrip('\n'))
    if heading_match:
        result["word"] = heading_match.group(1).strip()

    # Extract fields using bullet patterns
    field_patterns = {
        "phonetic": r'- 音标：(.+)',
        "part_of_speech": r'- 词性：(.+)',
        "chinese_meaning": r'- 中文释义：(.+)',
        "english_explanation": r'- 英文解释：(.+)',
        "etymology": r'- 词根/记忆：(.+)',
        "usage_note": r'- 使用场景：(.+)',
        "date": r'- 添加时间：(.+)',
        "source": r'- 来源：(.+)',
        "context": r'- 语境：(.+)',
    }

    for key, pattern in field_patterns.items():
        match = re.search(pattern, entry_text)
        if match:
            result[key] = match.group(1).strip()

    # Extract lists (collocations, examples, confusable words)
    result["collocations"] = _extract_list(entry_text, r'- 常见搭配：\n((?:\s{2}- .+\n?)*)')
    result["example_sentences"] = _extract_list(entry_text, r'- 例句：\n((?:\s{2}- .+\n?)*)')
    result["confusable_words"] = _extract_list(entry_text, r'- 易混词：\n((?:\s{2}- .+\n?)*)')

    return result


def _extract_list(text: str, pattern: str) -> List[str]:
    """Extract indented list items from markdown."""
    match = re.search(pattern, text)
    if not match:
        return []
    items = []
    for line in match.group(1).strip().split('\n'):
        item = line.strip().lstrip('-').strip()
        if item:
            items.append(item)
    return items
