"""Tests for parser module."""

import tempfile
from pathlib import Path

from obsidian_vocab_capture.parser import (
    find_word_position,
    word_exists,
    extract_all_words,
    norm_word,
)


class TestNormWord:
    def test_lowercase(self):
        assert norm_word("Hello") == "hello"

    def test_trim(self):
        assert norm_word("  hello  ") == "hello"

    def test_punctuation(self):
        assert norm_word("hello.") == "hello"
        assert norm_word("'hello'") == "hello"
        assert norm_word("(hello)") == "hello"

    def test_phrase(self):
        assert norm_word("take for granted") == "take for granted"

    def test_collapse_spaces(self):
        assert norm_word("take   for   granted") == "take for granted"


class TestWordExists:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.vocab_path = Path(self.tmpdir) / "test.md"

    def _write(self, content):
        self.vocab_path.write_text(content, encoding="utf-8")

    def test_word_found(self):
        self._write("## abandon\n\n- 音标：xxx\n\n## hello\n\n- 音标：yyy\n")
        assert word_exists(self.vocab_path, "abandon")
        assert word_exists(self.vocab_path, "hello")
        assert word_exists(self.vocab_path, "Abandon")
        assert word_exists(self.vocab_path, "  HELLO  ")

    def test_word_not_found(self):
        self._write("## abandon\n\n- 音标：xxx\n")
        assert not word_exists(self.vocab_path, "unknown")
        assert not word_exists(self.vocab_path, "aban")

    def test_empty_file(self):
        self._write("# English Vocabulary\n\n")
        assert not word_exists(self.vocab_path, "anything")

    def test_file_not_exists(self):
        path = Path(self.tmpdir) / "nonexistent.md"
        assert not word_exists(path, "anything")


class TestExtractAllWords:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.vocab_path = Path(self.tmpdir) / "test.md"

    def test_extract_words(self):
        self.vocab_path.write_text(
            "## abandon\n\n- 音标：xxx\n\n## hello world\n\n- 音标：yyy\n\n## resilient\n",
            encoding="utf-8",
        )
        words = extract_all_words(self.vocab_path)
        assert words == ["abandon", "hello world", "resilient"]

    def test_empty_file(self):
        self.vocab_path.write_text("", encoding="utf-8")
        assert extract_all_words(self.vocab_path) == []


class TestFindWordPosition:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.vocab_path = Path(self.tmpdir) / "test.md"

    def test_first_entry(self):
        self.vocab_path.write_text(
            "## abandon\nline1\nline2\n\n## hello\nline3\n",
            encoding="utf-8",
        )
        pos = find_word_position(self.vocab_path, "abandon")
        assert pos is not None
        start, end = pos
        assert start == 0
        assert end == 3

    def test_second_entry(self):
        self.vocab_path.write_text(
            "## abandon\nline1\n\n## hello\nline3\nline4\n\n## test\nline5\n",
            encoding="utf-8",
        )
        pos = find_word_position(self.vocab_path, "hello")
        assert pos is not None
        start, end = pos
        assert start == 3
        assert end == 6

    def test_last_entry(self):
        self.vocab_path.write_text(
            "## abandon\nline1\n\n## test\nline5\nline6\n",
            encoding="utf-8",
        )
        pos = find_word_position(self.vocab_path, "test")
        assert pos is not None
        start, end = pos
        assert start == 3
