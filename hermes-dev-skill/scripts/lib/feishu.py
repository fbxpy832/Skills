# hermes-dev-skill/scripts/lib/feishu.py
"""Thin wrapper around `hermes send` for Feishu.

Contract: `hermes send` is expected to print a line of the form
`message_id: om_xxx` to stdout on success. If it does not, the wrapper
returns "" (best-effort) and does not raise. If `hermes send` exits
non-zero, raises FeishuError.
"""
from __future__ import annotations

import json
import shlex
import subprocess
from typing import Any


class FeishuError(Exception):
    """hermes send failed (non-zero exit)."""


def _run(args: list[str]) -> str:
    """Run `hermes send <args>` and return the message_id from stdout.

    If the output does not contain a parseable `message_id: ...` line,
    returns "". Non-zero exit raises FeishuError.
    """
    result = subprocess.run(
        ["hermes", "send", *args],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise FeishuError(
            f"hermes send failed (exit {result.returncode}): "
            f"stderr={result.stderr.strip()!r}"
        )
    for line in result.stdout.splitlines():
        if line.startswith("message_id:"):
            return line.split(":", 1)[1].strip()
    return ""


def send_text(text: str) -> str:
    """Send a plain-text message via hermes send. Returns the message_id or ''."""
    return _run(["--text", text])


def send_card(title: str, fields: list[dict[str, str]],
              buttons: list[dict[str, Any]] | None = None) -> str:
    """Send a Feishu interactive card.

    `fields` is a list of {"key": ..., "value": ...} dicts shown as
    key:value rows. `buttons` (optional) is a list of button specs
    with keys: text, type (default|primary|danger), value, url.
    """
    elements: list[dict] = []
    for f in fields:
        elements.append({
            "tag": "div",
            "text": {
                "tag": "lark_md",
                "content": f"**{f['key']}**: {f['value']}",
            },
        })
    if buttons:
        elements.append({"tag": "action", "actions": [
            {
                "tag": "button",
                "text": {"tag": "plain_text", "content": b["text"]},
                "type": b.get("type", "default"),
                **({"url": b["url"]} if "url" in b else {}),
                **({"value": b["value"]} if "value" in b else {}),
            }
            for b in buttons
        ]})
    card = {
        "header": {"title": {"tag": "plain_text", "content": title}},
        "elements": elements,
    }
    return _run(["--card-json", json.dumps(card, ensure_ascii=False)])
