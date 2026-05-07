"""Tests for Markdown store module."""

import tempfile
from pathlib import Path

from obsidian_vocab_capture.markdown_store import MarkdownStore


class TestMarkdownStore:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.vocab_path = Path(self.tmpdir) / "Vocabulary.md"

    def test_creates_file_and_dir_if_missing(self):
        store = MarkdownStore(self.vocab_path)
        assert self.vocab_path.exists()
        content = store.read_file()
        assert "# English Vocabulary" in content

    def test_append_entry(self):
        store = MarkdownStore(self.vocab_path)
        entry = "## test\n\n- 音标：xxx\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n"
        store.append_entry(entry)
        content = store.read_file()
        assert "## test" in content
        assert "音标：xxx" in content

    def test_word_exists(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## abandon\n\n- 音标：xxx\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n")
        assert store.word_exists("abandon")
        assert not store.word_exists("unknown")

    def test_append_encounter(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## abandon\n\n- 音标：xxx\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n")

        encounter = "### 再次遇到\n\n- 2026-05-08：再次遇到该词。\n\n"
        store.append_encounter("abandon", encounter)

        content = store.read_file()
        assert "### 再次遇到" in content
        assert "2026-05-08：再次遇到该词。" in content

    def test_append_encounter_nonexistent_word(self):
        store = MarkdownStore(self.vocab_path)
        import pytest
        with pytest.raises(ValueError, match="not found"):
            store.append_encounter("unknown", "### 再次遇到\n\n")

    def test_overwrite_entry(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## abandon\n\n- 音标：old\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n")

        new_entry = "## abandon\n\n- 音标：new\n- 添加时间：2026-05-08\n- 来源：manual-capture\n\n"
        store.overwrite_entry("abandon", new_entry)

        content = store.read_file()
        assert "音标：new" in content
        assert "音标：old" not in content

    def test_multiple_entries(self):
        store = MarkdownStore(self.vocab_path)
        store.append_entry("## abandon\n\n- 音标：a\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n")
        store.append_entry("## hello\n\n- 音标：h\n- 添加时间：2026-05-07\n- 来源：manual-capture\n\n")

        assert store.word_exists("abandon")
        assert store.word_exists("hello")

        # Add encounter to first word
        store.append_encounter("abandon", "### 再次遇到\n\n- 2026-05-08：再次遇到该词。\n\n")
        content = store.read_file()

        # Verify encounter is under abandon, not hello
        abandon_idx = content.find("## abandon")
        hello_idx = content.find("## hello")
        encounter_idx = content.find("### 再次遇到")
        assert abandon_idx < encounter_idx < hello_idx
