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

- 音标：/əˈbændən/
- 中文释义：放弃
- 英文解释：to give up completely
- 例句：
  - He abandoned the project.
- 常见搭配：
  - abandon hope
- 词根/记忆：from French
- 添加时间：2026-05-07
- 来源：manual-capture

## hello

- 音标：/həˈloʊ/
- 中文释义：你好
- 英文解释：a greeting
- 添加时间：2026-05-07
- 来源：manual-capture
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
        assert rows[0]["english_explanation"] == "to give up completely"
        assert "He abandoned the project." in rows[0]["example_sentence"]
        assert "abandon hope" in rows[0]["collocations"]
        assert rows[0]["memory_tip"] == "from French"

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

- 音标：/tɛst/
- 中文释义：测试
- 英文解释：an examination
- 例句：
  - This is a test.
  - Another test example.
- 常见搭配：
  - test case
  - test drive
  - test run
- 添加时间：2026-05-07
- 来源：manual-capture
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

- 中文释义：最小的
- 添加时间：2026-05-07
- 来源：manual-capture
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
        assert rows[0]["english_explanation"] == ""
