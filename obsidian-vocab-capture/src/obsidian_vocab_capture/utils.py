"""Utility functions for obsidian-vocab-capture."""

import logging
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from .config import ensure_log_dir, get_log_path


def setup_logging(verbose: bool = False) -> None:
    """Set up logging to file and optionally to stderr."""
    log_dir = ensure_log_dir()
    log_file = get_log_path()

    logger = logging.getLogger("obsidian_vocab_capture")
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)

    # File handler (always)
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    ))
    logger.addHandler(fh)

    # Console handler (verbose only)
    if verbose:
        ch = logging.StreamHandler(sys.stderr)
        ch.setLevel(logging.DEBUG)
        ch.setFormatter(logging.Formatter(
            "[%(levelname)s] %(message)s"
        ))
        logger.addHandler(ch)


def get_logger() -> logging.Logger:
    return logging.getLogger("obsidian_vocab_capture")


def backup_file(file_path: Path) -> Optional[Path]:
    """Create a timestamped backup of a file.

    Returns the backup path, or None if the file doesn't exist.
    """
    if not file_path.exists():
        return None

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = file_path.parent / f"{file_path.name}.bak-{timestamp}"
    shutil.copy2(file_path, backup_path)
    get_logger().info(f"Backed up {file_path} -> {backup_path}")
    return backup_path


def get_clipboard_content() -> str:
    """Get the current macOS clipboard content."""
    try:
        result = subprocess.run(
            ["pbpaste"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            raise RuntimeError(f"pbpaste failed: {result.stderr.strip()}")
        return result.stdout.strip()
    except FileNotFoundError:
        raise RuntimeError(
            "pbpaste not found. This tool requires macOS."
        ) from None
    except subprocess.TimeoutExpired:
        raise RuntimeError("Clipboard read timed out.") from None


def clean_input(text: str) -> str:
    """Clean input text: trim, collapse whitespace, remove leading/trailing punctuation."""
    import re
    text = text.strip()
    text = re.sub(r'\s+', ' ', text)
    # Remove leading/trailing punctuation except those that might be part of the word
    text = text.strip('.,;:!?\'"()[]{}<>»«›‹/\\|@#$%^&*+=~`')
    return text.strip()


def is_likely_english(text: str) -> bool:
    """Check if text is likely English (word or phrase)."""
    import re
    if not text:
        return False
    # Must contain at least some ASCII letters
    if not re.search(r'[a-zA-Z]', text):
        return False
    # Should be primarily ASCII
    ascii_chars = sum(1 for c in text if ord(c) < 128)
    total_chars = len(text)
    if total_chars == 0:
        return False
    ratio = ascii_chars / total_chars
    return ratio > 0.7


def norm_word(word: str) -> str:
    """Normalize a word for comparison."""
    import re
    word = word.lower().strip()
    word = re.sub(r'\s+', ' ', word)
    word = word.strip('.,;:!?\'"()[]{}<>')
    return word.strip()
