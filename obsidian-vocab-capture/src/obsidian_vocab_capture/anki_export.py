"""Export vocabulary entries to Anki-compatible CSV format.

Supports both unified SKILL.md format and legacy Chinese-field format.
"""

import csv
import logging
import re
from pathlib import Path
from typing import Any, Dict, List

logger = logging.getLogger("obsidian_vocab_capture.anki_export")


def export_to_csv(vocab_path: Path, output_path: Path) -> int:
    """Parse Vocabulary.md and export entries to Anki CSV.

    CSV fields:
        word, phonetic, chinese_meaning, core_meaning,
        example_sentence, collocations, memory_hook

    Args:
        vocab_path: Path to Vocabulary.md.
        output_path: Path to write the CSV file.

    Returns:
        Number of entries exported.
    """
    if not vocab_path.exists():
        raise FileNotFoundError(f"Vocabulary file not found: {vocab_path}")

    entries = _parse_vocab_file(vocab_path)
    logger.info(f"Parsed {len(entries)} entries from {vocab_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow([
            "word", "phonetic", "chinese_meaning", "core_meaning",
            "example_sentence", "collocations", "memory_hook"
        ])

        for entry in entries:
            writer.writerow([
                entry.get("word", ""),
                entry.get("phonetic", ""),
                entry.get("chinese_meaning", ""),
                entry.get("core_meaning", "") or entry.get("english_explanation", ""),
                _join_list(entry.get("example_sentences", [])),
                _join_list(entry.get("collocations", [])),
                entry.get("memory_hook", "") or entry.get("etymology", ""),
            ])

    logger.info(f"Exported {len(entries)} entries to {output_path}")
    return len(entries)


def _parse_vocab_file(vocab_path: Path) -> List[Dict[str, Any]]:
    """Parse the entire vocabulary file into structured entries."""
    with open(vocab_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Split by ## headings (word entries)
    entries = []
    sections = re.split(r'\n(?=##\s+)', content)

    for section in sections:
        section = section.strip()
        if not section:
            continue

        entry = _parse_section(section)
        if entry and entry.get("word"):
            entries.append(entry)

    return entries


def _parse_section(section: str) -> Dict[str, Any]:
    """Parse a single vocabulary section.

    Supports both unified SKILL.md format and legacy Chinese-field format.
    """
    lines = section.split('\n')
    entry: Dict[str, Any] = {}

    # First line should be heading
    if lines:
        heading_match = re.match(r'^##\s+(.+)', lines[0])
        if heading_match:
            entry["word"] = heading_match.group(1).strip()

    text = '\n'.join(lines)

    # Detect format
    is_unified = bool(re.search(r'- (Part of Speech|Core Meaning|Chinese Meaning):', text))

    if is_unified:
        entry.update(_parse_unified(text))
    else:
        entry.update(_parse_legacy(text))

    return entry


def _parse_unified(text: str) -> Dict[str, Any]:
    """Parse unified SKILL.md format section."""
    entry: Dict[str, Any] = {}

    # Bullet fields
    field_map = {
        "phonetic": r'- Phonetic:\s*(.+)',
        "chinese_meaning": r'- Chinese Meaning:\s*(.+)',
        "core_meaning": r'- Core Meaning:\s*(.+)',
        "memory_hook": r'- Memory Hook:\s*(.+)',
    }
    for key, pattern in field_map.items():
        m = re.search(pattern, text)
        if m:
            entry[key] = m.group(1).strip()

    # Example Sentences section
    ex_text = _extract_section(text, "Example Sentences")
    if ex_text:
        examples = []
        for line in ex_text.strip().split('\n'):
            line = line.strip()
            m2 = re.match(r'^\d+\.\s+(.+)', line)
            if m2:
                examples.append(m2.group(1).strip())
        entry["example_sentences"] = examples

    # Common Collocations section
    col_text = _extract_section(text, "Common Collocations")
    if col_text:
        collocations = []
        for line in col_text.strip().split('\n'):
            line = line.strip()
            m2 = re.match(r'^-\s+(.+)', line)
            if m2:
                collocations.append(m2.group(1).strip())
        entry["collocations"] = collocations

    return entry


def _parse_legacy(text: str) -> Dict[str, Any]:
    """Parse legacy Chinese-field format section."""
    entry: Dict[str, Any] = {}

    field_map = {
        "phonetic": r'- \u97f3\u6807\uff1a(.+)',
        "chinese_meaning": r'- \u4e2d\u6587\u91ca\u4e49\uff1a(.+)',
        "english_explanation": r'- \u82f1\u6587\u89e3\u91ca\uff1a(.+)',
        "etymology": r'- \u8bcd\u6839/\u8bb0\u5fc6\uff1a(.+)',
    }
    for key, pattern in field_map.items():
        m = re.search(pattern, text)
        if m:
            entry[key] = m.group(1).strip()

    entry["collocations"] = _extract_indented_list(text, r'- \u5e38\u89c1\u642d\u914d\uff1a')
    entry["example_sentences"] = _extract_indented_list(text, r'- \u4f8b\u53e5\uff1a')

    return entry


def _extract_section(text: str, heading: str) -> str:
    """Extract content under an ### heading."""
    esc_heading = re.escape(heading)
    pattern = r"###\s+" + esc_heading + r"\s*\n(.*?)(?=\n###|\n---|\Z)"
    m = re.search(pattern, text, re.DOTALL)
    return m.group(1).strip() if m else ""


def _extract_indented_list(text: str, section_header: str) -> List[str]:
    """Extract indented list items following a section header."""
    idx = text.find(section_header)
    if idx < 0:
        return []

    remaining = text[idx + len(section_header):]
    items = []
    for line in remaining.split('\n'):
        if line.startswith('  - '):
            items.append(line[4:].strip())
        elif line.strip() and not line.startswith('  - '):
            break
    return items


def _join_list(items: List[str], sep: str = "; ") -> str:
    """Join list items with separator."""
    if not items:
        return ""
    return sep.join(items)
