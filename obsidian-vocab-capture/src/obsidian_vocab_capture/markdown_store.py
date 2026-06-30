"""Markdown store for reading and writing vocabulary entries to Obsidian.

Handles:
- Appending new entries
- Checking for duplicates
- Appending encounter records
- Automatic backups
"""

import logging
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

from .parser import find_word_position
from .utils import backup_file

logger = logging.getLogger("obsidian_vocab_capture.markdown_store")


class MarkdownStore:
    """Manages the vocabulary Markdown file in the Obsidian vault."""

    def __init__(self, vocab_path: Path):
        self.vocab_path = vocab_path
        self._ensure_file()

    def _ensure_file(self) -> None:
        """Ensure the vocabulary file and its directory exist."""
        self.vocab_path.parent.mkdir(parents=True, exist_ok=True)
        if not self.vocab_path.exists():
            self.vocab_path.write_text(
                "# English Vocabulary\n\n",
                encoding="utf-8"
            )
            logger.info(f"Created vocabulary file: {self.vocab_path}")

    MAX_BACKUPS = 5

    def backup(self) -> Optional[Path]:
        """Create a backup of the vocabulary file and prune old ones."""
        result = backup_file(self.vocab_path)
        self._prune_backups()
        return result

    def _prune_backups(self) -> None:
        """Remove excess backup files, keeping only the most recent MAX_BACKUPS."""
        pattern = self.vocab_path.name + ".bak-*"
        backups = sorted(self.vocab_path.parent.glob(pattern))
        while len(backups) > self.MAX_BACKUPS:
            oldest = backups.pop(0)
            oldest.unlink()
            logger.info(f"Pruned old backup: {oldest}")

    def read_file(self) -> str:
        """Read the entire vocabulary file."""
        return self.vocab_path.read_text(encoding="utf-8")

    def write_file(self, content: str) -> None:
        """Write content to the vocabulary file with backup."""
        self.backup()
        self.vocab_path.write_text(content, encoding="utf-8")
        logger.info(f"Wrote vocabulary file: {self.vocab_path}")

    def append_entry(self, markdown: str) -> None:
        """Append a new vocabulary entry to the end of the file."""
        self.backup()
        content = self.read_file()
        if not content.endswith('\n'):
            content += '\n'
        content += markdown
        self.vocab_path.write_text(content, encoding="utf-8")
        logger.info(f"Appended new entry to {self.vocab_path}")

    def find_entry(self, word: str) -> Optional[Tuple[int, int]]:
        """Find a word entry position in the file.

        Returns (start_line, end_line) or None.
        """
        return find_word_position(self.vocab_path, word)

    def word_exists(self, word: str) -> bool:
        """Check if a word exists in the vocabulary file."""
        return self.find_entry(word) is not None

    def append_encounter(self, word: str, encounter_md: str) -> None:
        """Append an encounter record to an existing word entry.

        Raises ValueError if the word is not found.
        """
        pos = self.find_entry(word)
        if pos is None:
            raise ValueError(f"Word '{word}' not found in vocabulary file")

        start, end = pos
        self.backup()

        with open(self.vocab_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Append encounter after the end of the current entry,
        # before the next heading
        insert_pos = end + 1
        encounter_lines = encounter_md.splitlines(keepends=True)
        for i, line in enumerate(encounter_lines):
            lines.insert(insert_pos + i, line)
            if i == len(encounter_lines) - 1 and not line.endswith('\n'):
                lines[insert_pos + i] += '\n'

        self.vocab_path.write_text("".join(lines), encoding="utf-8")
        logger.info(f"Appended encounter record for '{word}'")

    def overwrite_entry(self, word: str, new_markdown: str) -> None:
        """Overwrite an existing word entry with new content."""
        pos = self.find_entry(word)
        if pos is None:
            raise ValueError(f"Word '{word}' not found in vocabulary file")

        start, end = pos
        self.backup()

        with open(self.vocab_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Replace lines from start to end (inclusive)
        new_lines = new_markdown.splitlines(keepends=True)
        # Ensure trailing newline
        if new_lines and not new_lines[-1].endswith('\n'):
            new_lines[-1] += '\n'

        lines[start:end + 1] = new_lines
        self.vocab_path.write_text("".join(lines), encoding="utf-8")
        logger.info(f"Overwrote entry for '{word}'")
