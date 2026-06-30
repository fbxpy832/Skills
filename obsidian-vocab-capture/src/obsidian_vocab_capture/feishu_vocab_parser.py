"""Feishu bot message parser for English word extraction.

Parses messages from Feishu Hermes Bot and determines:
1. Whether the message is a valid English word request
2. Extracts and normalizes the word
"""

import logging
import re
from typing import Optional

logger = logging.getLogger("obsidian_vocab_capture.feishu_vocab_parser")

# Prefixes that indicate a word lookup request
PREFIX_PATTERNS = [
    r"^word\s+(.+)$",
    r"^单词\s+(.+)$",
    r"^add\s+word\s+(.+)$",
    r"^添加单词\s+(.+)$",
]

# Valid word pattern: only letters, hyphens, apostrophes; must contain at least one letter
WORD_PATTERN = re.compile(r"^(?:[a-zA-Z]+(?:[-'][a-zA-Z]+)*|[a-zA-Z]+)$")


def parse_word_message(text: str) -> tuple[bool, Optional[str], Optional[str]]:
    """Parse a Feishu message to determine if it's a valid English word request.

    Supports formats:
        obligation
        word Liability
        单词 incentive
        add word infrastructure

    Args:
        text: The raw message text from Feishu.

    Returns:
        Tuple of (is_valid, word, error):
        - is_valid: True if a valid English word was extracted.
        - word: The normalized lowercase word if valid, None otherwise.
        - error: Error message if invalid, None otherwise.
    """
    if not text:
        return False, None, "消息为空"

    text = text.strip()
    if not text:
        return False, None, "消息为空"

    # Check if message starts with one of the prefixes
    word = None
    for pattern in PREFIX_PATTERNS:
        m = re.match(pattern, text, re.IGNORECASE)
        if m:
            word = m.group(1).strip()
            break

    # If no prefix matched, treat the entire text as the word candidate
    if word is None:
        word = text

    # Validate: must not contain spaces (single word only)
    if " " in word:
        return False, None, "当前只支持单个英文单词，不支持短语。例如：obligation"

    # Validate: must match word pattern
    if not WORD_PATTERN.match(word):
        return False, None, "当前只支持发送一个英文单词，例如：obligation"

    # Normalize to lowercase
    normalized = word.lower()

    return True, normalized, None
