"""Tests for Anki export module."""

import csv
import tempfile
from pathlib import Path

from obsidian_vocab_capture.anki_export import export_to_csv


class TestAnkiExport:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.vocab_path = Path(self.tmpdir) / "Vocabulary.md"
        self.output_path = Path(self.tmpdir) / "output.csv"

    def _write_vocab(self, content):
        self.vocab_path.write_text(content, encoding="utf-8")

    def test_basic_export(self):
        content = """
## abandon

- Date: 2026-05-07
- Part of Speech: verb
- Core Meaning: to give up completely
- Chinese Meaning: 放弃
- Phonetic: /əˈbændən/
- Memory Hook: from French

### Example Sentences
1. He abandoned the project.

### Common Collocations
- abandon hope

### Similar Words
- abundant: 充足的，完全不同

## hello

- Date: 2026-05-07
- Part of Speech: interjection
- Core Meaning: a greeting
- Chinese Meaning: 你好
- Phonetic: /həˈloʊ/
"""
        self._write_vocab(content)

        count = export_to_csv(self.vocab_path, self.output_path)
        assert count == 2

        with open(self.output_path, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        assert len(rows) == 2
        assert rows[0]["word"] == "abandon"
        assert rows[0]["phonetic"] == "/əˈbændən/"
        assert rows[0]["chinese_meaning"] == "放弃"
        assert rows[0]["core_meaning"] == "to give up completely"
        assert "He abandoned the project." in rows[0]["example_sentence"]
        assert "abandon hope" in rows[0]["collocations"]
        assert rows[0]["memory_hook"] == "from French"

        assert rows[1]["word"] == "hello"

    def test_empty_vocab(self):
        self._write_vocab("# English Vocabulary\n\n")
        count = export_to_csv(self.vocab_path, self.output_path)
        assert count == 0

    def test_file_not_found(self):
        import pytest
        with pytest.raises(FileNotFoundError):
            export_to_csv(Path("/nonexistent.md"), self.output_path)

    def test_single_entry(self):
        content = """## test

- Date: 2026-05-07
- Part of Speech: noun
- Core Meaning: an examination
- Chinese Meaning: 测试
- Phonetic: /tɛst/

### Example Sentences
1. This is a test.
2. Another test example.

### Common Collocations
- test case
- test drive
- test run
"""
        self._write_vocab(content)

        count = export_to_csv(self.vocab_path, self.output_path)
        assert count == 1

        with open(self.output_path, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        assert rows[0]["word"] == "test"
        assert "This is a test." in rows[0]["example_sentence"]
        assert "test case" in rows[0]["collocations"]

    def test_missing_fields(self):
        content = """## minimal

- Date: 2026-05-07
- Chinese Meaning: 最小的
"""
        self._write_vocab(content)

        count = export_to_csv(self.vocab_path, self.output_path)
        assert count == 1

        with open(self.output_path, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        assert rows[0]["word"] == "minimal"
        assert rows[0]["chinese_meaning"] == "最小的"
        assert rows[0]["phonetic"] == ""
        assert rows[0]["core_meaning"] == ""
