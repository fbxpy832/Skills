"""Tests for feishu_vocab_parser.py"""

from obsidian_vocab_capture.feishu_vocab_parser import parse_word_message


class TestParseWordMessage:
    """Test word extraction from Feishu messages."""

    # ── Plain word ────────────────────────────────────────────────

    def test_plain_lowercase_word(self):
        is_valid, word, error = parse_word_message("obligation")
        assert is_valid is True
        assert word == "obligation"
        assert error is None

    def test_plain_capitalized_word(self):
        is_valid, word, error = parse_word_message("Obligation")
        assert is_valid is True
        assert word == "obligation"
        assert error is None

    def test_plain_uppercase_word(self):
        is_valid, word, error = parse_word_message("OBLIGATION")
        assert is_valid is True
        assert word == "obligation"
        assert error is None

    # ── Prefix formats ────────────────────────────────────────────

    def test_prefix_word_lowercase(self):
        is_valid, word, error = parse_word_message("word Liability")
        assert is_valid is True
        assert word == "liability"
        assert error is None

    def test_prefix_chinese_word(self):
        is_valid, word, error = parse_word_message("单词 incentive")
        assert is_valid is True
        assert word == "incentive"
        assert error is None

    def test_prefix_add_word(self):
        is_valid, word, error = parse_word_message("add word infrastructure")
        assert is_valid is True
        assert word == "infrastructure"
        assert error is None

    def test_prefix_add_chinese(self):
        is_valid, word, error = parse_word_message("添加单词 obligation")
        assert is_valid is True
        assert word == "obligation"
        assert error is None

    # ── Words with special characters ─────────────────────────────

    def test_word_with_hyphen(self):
        is_valid, word, error = parse_word_message("well-being")
        assert is_valid is True
        assert word == "well-being"
        assert error is None

    def test_word_with_apostrophe(self):
        is_valid, word, error = parse_word_message("don't")
        assert is_valid is True
        assert word == "don't"
        assert error is None

    # ── Invalid inputs ────────────────────────────────────────────

    def test_two_words(self):
        is_valid, word, error = parse_word_message("hello world")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_numbers(self):
        is_valid, word, error = parse_word_message("12345")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_mixed_letters_and_numbers(self):
        is_valid, word, error = parse_word_message("hello123")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_chinese_only(self):
        is_valid, word, error = parse_word_message("中文")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_empty_string(self):
        is_valid, word, error = parse_word_message("")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_whitespace_only(self):
        is_valid, word, error = parse_word_message("   ")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_none_input(self):
        is_valid, word, error = parse_word_message(None)
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_hyphen_only(self):
        is_valid, word, error = parse_word_message("-")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_apostrophe_only(self):
        is_valid, word, error = parse_word_message("'")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_multiple_hyphens_only(self):
        is_valid, word, error = parse_word_message("--")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_hyphen_and_apostrophe_only(self):
        is_valid, word, error = parse_word_message("'-")
        assert is_valid is False
        assert word is None
        assert error is not None

    # ── Edge cases ────────────────────────────────────────────────

    def test_prefix_with_extra_spaces(self):
        is_valid, word, error = parse_word_message("  word   liability  ")
        assert is_valid is True
        assert word == "liability"
        assert error is None

    def test_word_with_trailing_punctuation(self):
        """Punctuation is not allowed by the word pattern."""
        is_valid, word, error = parse_word_message("hello!")
        assert is_valid is False
        assert word is None
        assert error is not None

    def test_case_preservation_after_normalization(self):
        is_valid, word, error = parse_word_message("word LIABILITY")
        assert is_valid is True
        assert word == "liability"
        assert error is None
