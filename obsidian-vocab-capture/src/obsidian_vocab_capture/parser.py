"""Parser for Vocabulary.md to detect duplicates and extract entries.

Supports both the unified SKILL.md-compatible format and legacy Chinese-field format.
"""

import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .utils import norm_word

# Pattern to match ## word heading
HEADING_PATTERN = re.compile(r"^##\s+(.+)$", re.MULTILINE)


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
        m = HEADING_PATTERN.match(line.rstrip("\n"))
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
            m = HEADING_PATTERN.match(line.rstrip("\n"))
            if m:
                words.append(m.group(1).strip())
    return words


def parse_vocab_entry(lines: List[str], start: int, end: int) -> Dict[str, Any]:
    """Parse a single vocabulary entry from lines.

    Supports both unified SKILL.md format and legacy Chinese-field format.
    Tries unified format first, falls back to legacy.

    Args:
        lines: All lines of the vocabulary file.
        start: Start line index (heading).
        end: End line index (inclusive).

    Returns:
        Dictionary with parsed fields.
    """
    entry_lines = lines[start:end + 1]
    entry_text = "".join(entry_lines)

    result: Dict[str, Any] = {}

    # Extract heading
    heading_match = HEADING_PATTERN.match(entry_lines[0].rstrip("\n"))
    if heading_match:
        result["word"] = heading_match.group(1).strip()

    # Try unified format first (English bullet fields)
    if _is_unified_format(entry_text):
        result.update(_parse_unified_entry(entry_text))
    else:
        # Fall back to legacy Chinese-field format
        result.update(_parse_legacy_entry(entry_text))

    return result


def _is_unified_format(text: str) -> bool:
    """Detect if the entry uses unified SKILL.md format."""
    return bool(re.search(r"- (Part of Speech|Core Meaning|Chinese Meaning|Memory Hook):", text))


def _parse_unified_entry(text: str) -> Dict[str, Any]:
    """Parse an entry in unified SKILL.md format."""
    result: Dict[str, Any] = {}

    # Bullet field patterns
    field_patterns = {
        "date": r"- Date:\s*(.+)",
        "phonetic": r"- Phonetic:\s*(.+)",
        "part_of_speech": r"- Part of Speech:\s*(.+)",
        "core_meaning": r"- Core Meaning:\s*(.+)",
        "chinese_meaning": r"- Chinese Meaning:\s*(.+)",
        "memory_hook": r"- Memory Hook:\s*(.+)",
        "usage_frequency": r"- Usage Frequency:\s*(.+)",
        "context": r"- Context:\s*(.+)",
    }
    for key, pattern in field_patterns.items():
        m = re.search(pattern, text)
        if m:
            result[key] = m.group(1).strip()

    # Section-based content
    simple_section = _extract_section(text, "Simple Explanation")
    if simple_section is not None:
        result["simple_explanation"] = simple_section.strip()

    # Example Sentences
    examples_text = _extract_section(text, "Example Sentences")
    if examples_text is not None:
        examples = []
        for line in examples_text.strip().split("\n"):
            line = line.strip()
            m = re.match(r"^\d+\.\s+(.+)", line)
            if m:
                examples.append({"en": m.group(1).strip(), "zh": ""})
        result["example_sentences"] = examples

    # Common Collocations
    coll_text = _extract_section(text, "Common Collocations")
    if coll_text is not None:
        collocations = []
        for line in coll_text.strip().split("\n"):
            line = line.strip()
            m = re.match(r"^-\s+(.+)", line)
            if m:
                collocations.append(m.group(1).strip())
        result["collocations"] = collocations

    # Similar Words
    sim_text = _extract_section(text, "Similar Words")
    if sim_text is not None:
        similar = []
        for line in sim_text.strip().split("\n"):
            line = line.strip()
            m = re.match(r"^-\s+(.+):\s*(.*)", line)
            if m:
                similar.append({
                    "word": m.group(1).strip(),
                    "difference": m.group(2).strip(),
                })
        result["similar_words"] = similar

    # Usage Notes
    usage_section = _extract_section(text, "Usage Notes")
    if usage_section is not None:
        result["usage_notes"] = usage_section.strip()

    # My Context
    myctx_section = _extract_section(text, "My Context")
    if myctx_section is not None:
        result["my_context"] = myctx_section.strip()

    # Encounter records
    enc_text = _extract_section(text, "Encounter")
    if enc_text is not None:
        encounters = []
        for line in enc_text.strip().split("\n"):
            line = line.strip()
            m = re.match(r"^-\s+(.+):\s*(.*)", line)
            if m:
                encounters.append({
                    "date": m.group(1).strip(),
                    "context": m.group(2).strip(),
                })
        result["encounters"] = encounters

    return result


def _parse_legacy_entry(text: str) -> Dict[str, Any]:
    """Parse an entry in legacy Chinese-field format."""
    result: Dict[str, str] = {}

    # Extract fields using Chinese bullet patterns
    field_patterns = {
        "phonetic": r"- \u97f3\u6807\uff1a(.+)",
        "part_of_speech": r"- \u8bcd\u6027\uff1a(.+)",
        "chinese_meaning": r"- \u4e2d\u6587\u91ca\u4e49\uff1a(.+)",
        "english_explanation": r"- \u82f1\u6587\u89e3\u91ca\uff1a(.+)",
        "etymology": r"- \u8bcd\u6839/\u8bb0\u5fc6\uff1a(.+)",
        "usage_note": r"- \u4f7f\u7528\u573a\u666f\uff1a(.+)",
        "date": r"- \u6dfb\u52a0\u65f6\u95f4\uff1a(.+)",
        "source": r"- \u6765\u6e90\uff1a(.+)",
        "context": r"- \u8bed\u5883\uff1a(.+)",
    }

    for key, pattern in field_patterns.items():
        m = re.search(pattern, text)
        if m:
            result[key] = m.group(1).strip()

    # Extract lists (collocations, examples, confusable words)
    result["collocations"] = _extract_list(text, r"- \u5e38\u89c1\u642d\u914d\uff1a")
    result["example_sentences"] = _extract_list(text, r"- \u4f8b\u53e5\uff1a")
    result["confusable_words"] = _extract_list(text, r"- \u6613\u6df7\u8bcd\uff1a")

    return result


def _extract_section(text: str, heading: str) -> Optional[str]:
    """Extract content under an ### heading.

    Returns the text between the heading and the next ### or end of entry.
    """
    esc_heading = re.escape(heading)
    pattern = r"###\s+" + esc_heading + r"\s*\n(.*?)(?=\n###|\n---|\Z)"
    m = re.search(pattern, text, re.DOTALL)
    if m:
        return m.group(1).strip()
    return None


def _extract_list(text: str, section_header: str) -> List[str]:
    """Extract indented list items following a section header (legacy format)."""
    idx = text.find(section_header)
    if idx < 0:
        return []
    remaining = text[idx + len(section_header):]
    items = []
    for line in remaining.split("\n"):
        if line.startswith("  - "):
            items.append(line[4:].strip())
        elif line.strip() and not line.startswith("  - "):
            break
    return items
