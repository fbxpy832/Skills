"""AI client for querying vocabulary explanations.

Supports OpenAI-compatible, DeepSeek, GLM/Zhipu, and Ollama APIs.
"""

import json
import re
import logging
from typing import Any, Dict, List, Optional

import httpx

from .config import Config, mask_key

logger = logging.getLogger("obsidian_vocab_capture.ai_client")

# Prompt template for vocabulary explanation
VOCAB_PROMPT_TEMPLATE = """你是一个面向中文母语用户的英语词汇学习助手。请解释用户输入的英文单词或短语。要求准确、简洁、适合记录到 Obsidian 词库。请输出严格 JSON，不要输出 Markdown，不要输出额外解释。

输入：{word}
{context_block}

输出字段：
{{
  "word": "",
  "phonetic": "",
  "part_of_speech": "",
  "core_meaning": "",
  "chinese_meaning": "",
  "memory_hook": "",
  "usage_frequency": "",
  "simple_explanation": "",
  "example_sentences": [{"en": "", "zh": ""}],
  "similar_words": [{"word": "", "difference": ""}],
  "collocations": [],
  "usage_notes": "",
  "my_context": ""
}}

要求：
- 中文释义要准确，不要过度展开；
- Core Meaning 用英文简洁核心定义，适合中高级英语学习者；
- Simple Explanation 用更简单的英文解释；
- 例句要自然、实用；
- example_sentences 每条包含 en(英文) 和 zh(中文)；
- similar_words 每条包含 word(易混词) 和 difference(区别说明)；
- 只返回 JSON。"""

CONTEXT_BLOCK = """
上下文：{context}
请结合上下文说明该词在此语境中的具体含义。"""


class AIClient:
    """Generic AI client supporting multiple providers."""

    def __init__(self, config: Config):
        self.config = config.ai
        self._client = httpx.Client(
            base_url=self.config.base_url,
            timeout=60.0,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.config.api_key}",
            },
        )

    def close(self):
        self._client.close()

    def lookup(self, word: str, context: Optional[str] = None) -> Dict[str, Any]:
        """Look up a word/phrase and return structured JSON."""
        masked = mask_key(self.config.api_key)
        logger.info(f"Looking up '{word}' using model {self.config.model} (key: {masked})")

        context_block = ""
        if context:
            context_block = CONTEXT_BLOCK.format(context=context)

        prompt = VOCAB_PROMPT_TEMPLATE.format(word=word, context_block=context_block)

        try:
            response = self._client.post(
                "/chat/completions",
                json={
                    "model": self.config.model,
                    "messages": [
                        {"role": "system", "content": "You are a helpful English vocabulary assistant. Output only valid JSON."},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.3,
                    "max_tokens": 2000,
                },
            )

            # Handle non-200 responses
            if response.status_code != 200:
                error_body = response.text[:500]
                logger.error(f"AI API error ({response.status_code}): {error_body}")
                raise RuntimeError(
                    f"AI API returned {response.status_code}: {error_body}"
                )

            data = response.json()
            content = data["choices"][0]["message"]["content"]
            logger.debug(f"AI raw response ({len(content)} chars)")

            return self._parse_response(content, word)

        except httpx.RequestError as e:
            logger.error(f"AI request failed: {e}")
            raise RuntimeError(f"Failed to connect to AI API: {e}") from e

    def _parse_response(self, content: str, word: str) -> Dict[str, Any]:
        """Parse AI response, extracting JSON from potentially messy output."""
        # Try direct JSON parse first
        try:
            result = json.loads(content)
            result.setdefault("word", word)
            return self._validate_result(result)
        except json.JSONDecodeError:
            pass

        # Try to extract JSON from markdown code blocks
        json_match = re.search(r'```(?:json)?\s*([\s\S]*?)```', content)
        if json_match:
            try:
                result = json.loads(json_match.group(1))
                result.setdefault("word", word)
                return self._validate_result(result)
            except json.JSONDecodeError:
                pass

        # Try to find JSON object with regex
        json_match = re.search(r'\{[\s\S]*\}', content)
        if json_match:
            try:
                result = json.loads(json_match.group(0))
                result.setdefault("word", word)
                return self._validate_result(result)
            except json.JSONDecodeError:
                pass

        # Failed to parse - log raw response and raise
        logger.error(f"Failed to parse AI response as JSON. Raw: {content[:1000]}")
        raise RuntimeError(
            f"AI did not return valid JSON. "
            f"Raw response (first 500 chars): {content[:500]}"
        )

    def _validate_result(self, result: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and normalize the result structure."""
        required_keys = [
            "word", "phonetic", "part_of_speech", "core_meaning",
            "chinese_meaning", "memory_hook", "usage_frequency",
            "simple_explanation", "example_sentences",
            "similar_words", "collocations", "usage_notes", "my_context",
        ]
        for key in required_keys:
            is_list = key in ("collocations", "example_sentences", "similar_words")
            if key not in result:
                result[key] = [] if is_list else ""

        # Ensure lists are lists
        for list_key in ("collocations", "example_sentences", "similar_words"):
            if not isinstance(result.get(list_key), list):
                result[list_key] = [result[list_key]] if result[list_key] else []

        return result
