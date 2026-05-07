"""Export vocabulary entries to Anki-compatible CSV format."""

import csv
import logging
import re
from pathlib import Path
from typing import List, Dict, Any

logger = logging.getLogger("obsidian_vocab_capture.anki_export")


def export_to_csv(vocab_path: Path, output_path: Path) -> int:
    """Parse Vocabulary.md and export entries to Anki CSV.

    CSV fields:
        word, phonetic, chinese_meaning, english_explanation,
        example_sentence, collocations, memory_tip

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
            "word", "phonetic", "chinese_meaning", "english_explanation",
            "example_sentence", "collocations", "memory_tip"
        ])

        for entry in entries:
            writer.writerow([
                entry.get("word", ""),
                entry.get("phonetic", ""),
                entry.get("chinese_meaning", ""),
                entry.get("english_explanation", ""),
                _join_list(entry.get("example_sentences", [])),
                _join_list(entry.get("collocations", [])),
                entry.get("etymology", ""),
            ])

    logger.info(f"Exported {len(entries)} entries to {output_path}")
    return len(entries)


def _parse_vocab_file(vocab_path: Path) -> List[Dict[str, Any]]:
    """Parse the entire vocabulary file into structured entries."""
    with open(vocab_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Split by ## headings (word entries)
    entries = []
    # Pattern: ## word followed by content until next ## or EOF
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
    """Parse a single vocabulary section."""
    lines = section.split('\n')
    entry: Dict[str, Any] = {}

    # First line should be heading
    if lines:
        heading_match = re.match(r'^##\s+(.+)', lines[0])
        if heading_match:
            entry["word"] = heading_match.group(1).strip()

    text = '\n'.join(lines)

    # Simple field extraction
    field_map = {
        "phonetic": r'- 音标：(.+)',
        "chinese_meaning": r'- 中文释义：(.+)',
        "english_explanation": r'- 英文解释：(.+)',
        "etymology": r'- 词根/记忆：(.+)',
    }

    for key, pattern in field_map.items():
        m = re.search(pattern, text)
        if m:
            entry[key] = m.group(1).strip()

    # Extract lists
    entry["collocations"] = _extract_indented_list(text, r'- 常见搭配：')
    entry["example_sentences"] = _extract_indented_list(text, r'- 例句：')
    entry["confusable_words"] = _extract_indented_list(text, r'- 易混词：')

    return entry


def _extract_indented_list(text: str, section_header: str) -> List[str]:
    """Extract indented list items following a section header."""
    # Find the section
    idx = text.find(section_header)
    if idx < 0:
        return []

    # Get text after the header
    remaining = text[idx + len(section_header):]
    items = []
    for line in remaining.split('\n'):
        # Only accept indented list items (two spaces + dash)
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
