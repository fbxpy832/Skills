"""Render AI response JSON into Obsidian-compatible Markdown.

Unified format compatible with SKILL.md agent output.
"""

from datetime import datetime
from typing import Any, Dict, List, Optional


def render_vocab_entry(data: Dict[str, Any], date_str: Optional[str] = None,
                       context: Optional[str] = None,
                       date_format: str = "%Y-%m-%d") -> str:
    """Render a vocabulary entry as Markdown in unified SKILL.md-compatible format.

    Args:
        data: The AI response JSON.
        date_str: Date string. Defaults to today formatted with date_format.
        context: Optional context sentence.
        date_format: strftime format string for date rendering.

    Returns:
        Markdown string for the vocabulary entry.
    """
    if date_str is None:
        date_str = datetime.now().strftime(date_format)

    word = data.get("word", "")
    phonetic = data.get("phonetic", "")
    pos = data.get("part_of_speech", "")
    core = data.get("core_meaning", "")
    chinese = data.get("chinese_meaning", "")
    memory = data.get("memory_hook", "")
    freq = data.get("usage_frequency", "")
    simple = data.get("simple_explanation", "")
    examples = data.get("example_sentences", [])
    similar = data.get("similar_words", [])
    collocations = data.get("collocations", [])
    usage_notes = data.get("usage_notes", "")
    my_context = data.get("my_context", "")

    lines = [f"## {word}", ""]

    # Metadata fields
    lines.append(f"- Date: {date_str}")
    if pos:
        lines.append(f"- Part of Speech: {pos}")
    if core:
        lines.append(f"- Core Meaning: {core}")
    if chinese:
        lines.append(f"- Chinese Meaning: {chinese}")
    if phonetic:
        lines.append(f"- Phonetic: {phonetic}")
    if memory:
        lines.append(f"- Memory Hook: {memory}")
    if freq:
        lines.append(f"- Usage Frequency: {freq}")

    # Context (from CLI --context param)
    if context:
        lines.append(f"- Context: {context}")

    lines.append("")

    # Simple Explanation
    if simple:
        lines.append("### Simple Explanation")
        lines.append(simple)
        lines.append("")

    # Example Sentences
    if examples:
        lines.append("### Example Sentences")
        for i, ex in enumerate(examples, 1):
            en = ex.get("en", "") if isinstance(ex, dict) else str(ex)
            zh = ex.get("zh", "") if isinstance(ex, dict) else ""
            if en and zh:
                lines.append(f"{i}. {en}")
                lines.append(f"   {zh}")
            elif en:
                lines.append(f"{i}. {en}")
        lines.append("")

    # Common Collocations
    if collocations:
        lines.append("### Common Collocations")
        for c in collocations:
            lines.append(f"- {c}")
        lines.append("")

    # Similar Words
    if similar:
        lines.append("### Similar Words")
        for sw in similar:
            sw_word = sw.get("word", "") if isinstance(sw, dict) else str(sw)
            sw_diff = sw.get("difference", "") if isinstance(sw, dict) else ""
            if sw_word and sw_diff:
                lines.append(f"- {sw_word}: {sw_diff}")
            elif sw_word:
                lines.append(f"- {sw_word}")
        lines.append("")

    # Usage Notes
    if usage_notes:
        lines.append("### Usage Notes")
        lines.append(usage_notes)
        lines.append("")

    # My Context
    if my_context:
        lines.append("### My Context")
        lines.append(my_context)
        lines.append("")

    # Separator
    lines.append("---")
    lines.append("")

    return "\n".join(lines)


def render_encounter_entry(date_str: Optional[str] = None,
                           context: Optional[str] = None,
                           date_format: str = "%Y-%m-%d") -> str:
    """Render an encounter record for an existing word entry."""
    if date_str is None:
        date_str = datetime.now().strftime(date_format)

    lines = ["### Encounter", ""]
    if context:
        lines.append(f"- {date_str}: Encountered again. Context: {context}")
    else:
        lines.append(f"- {date_str}: Encountered again.")
    lines.append("")
    return "\n".join(lines)
