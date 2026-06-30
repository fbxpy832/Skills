"""Tests for renderer module (unified SKILL.md format)."""

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
            "core_meaning": "to leave behind or give up completely",
            "chinese_meaning": "放弃",
            "memory_hook": "a-ban-don → 我得放弃这个计划了",
            "usage_frequency": "high",
            "simple_explanation": "When you abandon something, you leave it and never come back.",
            "example_sentences": [
                {"en": "He abandoned the project.", "zh": "他放弃了这个项目。"},
                {"en": "They abandoned their plans.", "zh": "他们放弃了计划。"}
            ],
            "similar_words": [
                {"word": "abundant", "difference": "意思完全不同，是“丰富的”"},
            ],
            "collocations": ["abandon hope", "abandon ship"],
            "usage_notes": "formal and informal contexts",
            "my_context": "Used in project management when a feature is dropped.",
        }

        result = render_vocab_entry(data, date_str="2026-05-07")

        # Heading
        assert "## abandon" in result

        # Metadata fields
        assert "- Date: 2026-05-07" in result
        assert "- Part of Speech: verb" in result
        assert "- Core Meaning: to leave behind" in result
        assert "- Chinese Meaning: 放弃" in result
        assert "- Phonetic: /ə" in result
        assert "- Memory Hook: a-ban-don" in result
        assert "- Usage Frequency: high" in result

        # Simple Explanation section
        assert "### Simple Explanation" in result
        assert "When you abandon something" in result

        # Example Sentences section
        assert "### Example Sentences" in result
        assert "1. He abandoned the project." in result
        assert "   他放弃了这个项目。" in result

        # Common Collocations section
        assert "### Common Collocations" in result
        assert "- abandon hope" in result

        # Similar Words section
        assert "### Similar Words" in result
        assert "- abundant:" in result

        # Usage Notes
        assert "### Usage Notes" in result
        assert "formal and informal" in result

        # My Context
        assert "### My Context" in result
        assert "project management" in result

        # Separator
        assert "---" in result

        # No old field names
        assert "音标：" not in result  # 音标

    def test_entry_with_context(self):
        data = {
            "word": "resilient",
            "phonetic": "",
            "part_of_speech": "adj",
            "core_meaning": "able to recover quickly",
            "chinese_meaning": "有韧性的",
            "memory_hook": "",
            "usage_frequency": "",
            "simple_explanation": "",
            "example_sentences": [],
            "similar_words": [],
            "collocations": [],
            "usage_notes": "",
            "my_context": "",
        }
        result = render_vocab_entry(data, date_str="2026-05-07",
                                     context="We need a resilient system.")
        # Context field should appear
        assert "- Context: We need a resilient system." in result
        # Empty fields should not appear
        assert "- Memory Hook:" not in result
        assert "- Usage Frequency:" not in result

    def test_entry_empty_fields(self):
        data = {
            "word": "test",
            "phonetic": "",
            "part_of_speech": "",
            "core_meaning": "",
            "chinese_meaning": "测试",
            "memory_hook": "",
            "usage_frequency": "",
            "simple_explanation": "",
            "example_sentences": [],
            "similar_words": [],
            "collocations": [],
            "usage_notes": "",
            "my_context": "",
        }
        result = render_vocab_entry(data, date_str="2026-05-07")
        assert "## test" in result
        assert "- Chinese Meaning: 测试" in result
        assert "- Phonetic:" not in result  # empty field should not appear
        assert "- Part of Speech:" not in result

    def test_example_sentences_flat_strings(self):
        """Handle legacy example_sentences as list of strings."""
        data = {
            "word": "test",
            "phonetic": "",
            "part_of_speech": "",
            "core_meaning": "",
            "chinese_meaning": "",
            "memory_hook": "",
            "usage_frequency": "",
            "simple_explanation": "",
            "example_sentences": ["flat example"],
            "similar_words": [],
            "collocations": [],
            "usage_notes": "",
            "my_context": "",
        }
        result = render_vocab_entry(data, date_str="2026-05-07")
        assert "### Example Sentences" in result
        assert "1. flat example" in result


class TestRenderEncounterEntry:
    def test_basic_encounter(self):
        result = render_encounter_entry(date_str="2026-05-07")
        assert "### Encounter" in result
        assert "2026-05-07: Encountered again." in result

    def test_encounter_with_context(self):
        result = render_encounter_entry(date_str="2026-05-07",
                                         context="I saw this in a meeting.")
        assert "Context: I saw this in a meeting." in result
