"""Render AI response JSON into Obsidian-compatible Markdown."""

from datetime import datetime
from typing import Any, Dict, Optional


def render_vocab_entry(data: Dict[str, Any], date_str: Optional[str] = None,
                       context: Optional[str] = None) -> str:
    """Render a vocabulary entry as Markdown.

    Args:
        data: The AI response JSON.
        date_str: Date string (YYYY-MM-DD). Defaults to today.
        context: Optional context sentence.

    Returns:
        Markdown string for the vocabulary entry.
    """
    if date_str is None:
        date_str = datetime.now().strftime("%Y-%m-%d")

    word = data.get("word", "")
    phonetic = data.get("phonetic", "")
    pos = data.get("part_of_speech", "")
    chinese = data.get("chinese_meaning", "")
    english = data.get("english_explanation", "")
    collocations = data.get("collocations", [])
    examples = data.get("example_sentences", [])
    etymology = data.get("etymology_or_memory_tip", "")
    usage = data.get("usage_note", "")
    confusable = data.get("confusable_words", [])

    lines = [f"## {word}", ""]

    if phonetic:
        lines.append(f"- 音标：{phonetic}")
    if pos:
        lines.append(f"- 词性：{pos}")
    if chinese:
        lines.append(f"- 中文释义：{chinese}")
    if english:
        lines.append(f"- 英文解释：{english}")

    # Context
    if context:
        lines.append(f"- 语境：{context}")

    # Collocations
    if collocations:
        lines.append("- 常见搭配：")
        for c in collocations:
            lines.append(f"  - {c}")

    # Example sentences
    if examples:
        lines.append("- 例句：")
        for ex in examples:
            lines.append(f"  - {ex}")

    # Etymology / memory tip
    if etymology:
        lines.append(f"- 词根/记忆：{etymology}")

    # Usage note
    if usage:
        lines.append(f"- 使用场景：{usage}")

    # Confusable words
    if confusable:
        lines.append("- 易混词：")
        for cw in confusable:
            lines.append(f"  - {cw}")

    lines.append(f"- 添加时间：{date_str}")
    lines.append("- 来源：manual-capture")
    lines.append("")

    return "\n".join(lines)


def render_encounter_entry(date_str: Optional[str] = None,
                           context: Optional[str] = None) -> str:
    """Render an encounter record for an existing word.

    Args:
        date_str: Date string.
        context: Optional context where word was encountered.

    Returns:
        Markdown string for the encounter entry.
    """
    if date_str is None:
        date_str = datetime.now().strftime("%Y-%m-%d")

    lines = ["### 再次遇到", ""]
    if context:
        lines.append(f"- {date_str}：再次遇到该词。上下文：{context}")
    else:
        lines.append(f"- {date_str}：再次遇到该词。")
    lines.append("")
    return "\n".join(lines)
