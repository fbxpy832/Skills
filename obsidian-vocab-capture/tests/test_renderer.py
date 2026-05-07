"""Tests for renderer module."""

from obsidian_vocab_capture.renderer import (
    render_vocab_entry,
    render_encounter_entry,
)


class TestRenderVocabEntry:
    def test_basic_entry(self):
        data = {
            "word": "abandon",
            "phonetic": "/əˈbændən/",
            "part_of_speech": "verb",
            "chinese_meaning": "放弃",
            "english_explanation": "to leave behind or give up completely",
            "collocations": ["abandon hope", "abandon ship"],
            "example_sentences": ["He abandoned the project.", "They abandoned their plans."],
            "etymology_or_memory_tip": "from Old French abandoner",
            "usage_note": "formal and informal contexts",
            "confusable_words": ["abundant", "abdomen"],
        }

        result = render_vocab_entry(data, date_str="2026-05-07")

        assert "## abandon" in result
        assert "音标：/əˈbændən/" in result
        assert "词性：verb" in result
        assert "中文释义：放弃" in result
        assert "英文解释：to leave behind" in result
        assert "常见搭配：" in result
        assert "  - abandon hope" in result
        assert "  - abandon ship" in result
        assert "例句：" in result
        assert "  - He abandoned the project." in result
        assert "词根/记忆：from Old French abandoner" in result
        assert "使用场景：formal and informal contexts" in result
        assert "易混词：" in result
        assert "  - abundant" in result
        assert "添加时间：2026-05-07" in result
        assert "来源：manual-capture" in result

    def test_entry_with_context(self):
        data = {
            "word": "resilient",
            "phonetic": "",
            "part_of_speech": "adj",
            "chinese_meaning": "有韧性的",
            "english_explanation": "able to recover quickly",
            "collocations": [],
            "example_sentences": [],
            "etymology_or_memory_tip": "",
            "usage_note": "",
            "confusable_words": [],
        }
        result = render_vocab_entry(data, date_str="2026-05-07",
                                     context="We need a resilient system.")
        assert "语境：We need a resilient system." in result

    def test_entry_empty_fields(self):
        data = {
            "word": "test",
            "phonetic": "",
            "part_of_speech": "",
            "chinese_meaning": "测试",
            "english_explanation": "",
            "collocations": [],
            "example_sentences": [],
            "etymology_or_memory_tip": "",
            "usage_note": "",
            "confusable_words": [],
        }
        result = render_vocab_entry(data, date_str="2026-05-07")
        assert "## test" in result
        assert "中文释义：测试" in result
        assert "音标：" not in result  # empty field should not appear
        assert "词性：" not in result


class TestRenderEncounterEntry:
    def test_basic_encounter(self):
        result = render_encounter_entry(date_str="2026-05-07")
        assert "### 再次遇到" in result
        assert "2026-05-07：再次遇到该词。" in result

    def test_encounter_with_context(self):
        result = render_encounter_entry(date_str="2026-05-07",
                                         context="I saw this in a meeting.")
        assert "上下文：I saw this in a meeting." in result
