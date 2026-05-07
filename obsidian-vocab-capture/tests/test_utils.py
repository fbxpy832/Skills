"""Tests for utils module."""

from obsidian_vocab_capture.utils import clean_input, is_likely_english, norm_word


class TestCleanInput:
    def test_trim_whitespace(self):
        assert clean_input("  hello  ") == "hello"

    def test_collapse_spaces(self):
        assert clean_input("take   for   granted") == "take for granted"

    def test_strip_punctuation(self):
        assert clean_input("hello.") == "hello"
        assert clean_input("(hello)") == "hello"

    def test_phrase_preserved(self):
        assert clean_input("take for granted") == "take for granted"


class TestIsLikelyEnglish:
    def test_english(self):
        assert is_likely_english("hello world")

    def test_chinese(self):
        assert not is_likely_english("你好世界")

    def test_mixed_mostly_english(self):
        assert is_likely_english("CPU is running")

    def test_empty(self):
        assert not is_likely_english("")


class TestNormWord:
    def test_lowercase(self):
        assert norm_word("Hello") == "hello"

    def test_trim(self):
        assert norm_word("  hello  ") == "hello"

    def test_phrase(self):
        assert norm_word("Take For Granted") == "take for granted"
