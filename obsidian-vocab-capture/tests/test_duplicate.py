"""Tests for duplicate detection."""

import tempfile
from pathlib import Path

from obsidian_vocab_capture.markdown_store import MarkdownStore
from obsidian_vocab_capture.utils import clean_input, is_likely_english, norm_word


class TestCleanInput:
    def test_basic_trim(self):
        assert clean_input("  hello  ") == "hello"

    def test_newlines(self):
        assert clean_input("hello\nworld") == "hello world"

    def test_punctuation(self):
        assert clean_input("hello.") == "hello"
        assert clean_input("'hello'") == "hello"

    def test_multiple_spaces(self):
        assert clean_input("take   for   granted") == "take for granted"

    def test_phrase(self):
        assert clean_input("take for granted") == "take for granted"

    def test_empty(self):
        assert clean_input("   ") == ""
        assert clean_input("") == ""


class TestIsLikelyEnglish:
    def test_english_word(self):
        assert is_likely_english("hello")

    def test_english_phrase(self):
        assert is_likely_english("take for granted")

    def test_chinese(self):
        assert not is_likely_english("你好世界")

    def test_mixed(self):
        # Mostly English
        assert is_likely_english("CPU is running")
        # Mostly Chinese
        assert not is_likely_english("CPU 正在运行状态监控")

    def test_empty(self):
        assert not is_likely_english("")
        assert not is_likely_english("   ")


class TestDuplicatePrevention:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.vocab_path = Path(self.tmpdir) / "Vocabulary.md"

    def test_duplicate_detection_case_insensitive(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## abandon\n\n- 中文释义：放弃\n\n")
        assert store.word_exists("abandon")
        assert store.word_exists("Abandon")
        assert store.word_exists("ABANDON")

    def test_duplicate_detection_with_punctuation(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## hello\n\n- 中文释义：你好\n\n")
        assert store.word_exists("hello.")
        assert store.word_exists("hello!")

    def test_no_duplicate_heading_created(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## abandon\n\n- 中文释义：放弃\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n")

        # Simulate adding encounter twice
        encounter = "### 再次遇到\n\n- 2026-05-08：再次遇到该词。\n\n"
        store.append_encounter("abandon", encounter)
        store.append_encounter("abandon", encounter)

        content = store.read_file()
        # Count headings
        heading_count = content.count("## abandon")
        assert heading_count == 1
