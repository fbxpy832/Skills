# Feishu message format reference

All Feishu traffic from this skill goes through `hermes send`, which
takes `--text` or `--card-json`. The Python wrapper `lib/feishu.py`
provides `send_text()` and `send_card()`.

## Plain text (`send_text`)

```python
send_text("Job #abc 已启动，需求澄清中")
```

Becomes:

```bash
hermes send --text "Job #abc 已启动，需求澄清中"
```

## Card (`send_card`)

```python
send_card(
    title="Job #abc — Phase 4/5",
    fields=[
        {"key": "Status", "value": "REJECTED"},
        {"key": "Round",  "value": "2 of 5"},
    ],
    buttons=[
        {"text": "View Review", "url": "file:///x.md", "type": "primary"},
        {"text": "Continue",    "value": {"action": "continue"}},
    ],
)
```

Becomes:

```bash
hermes send --card-json '{
  "header": {"title": {"tag": "plain_text", "content": "Job #abc — Phase 4/5"}},
  "elements": [
    {"tag": "div", "text": {"tag": "lark_md", "content": "**Status**: REJECTED"}},
    {"tag": "div", "text": {"tag": "lark_md", "content": "**Round**: 2 of 5"}},
    {"tag": "action", "actions": [
      {"tag": "button", "text": {"tag": "plain_text", "content": "View Review"},
       "type": "primary", "url": "file:///x.md"},
      {"tag": "button", "text": {"tag": "plain_text", "content": "Continue"},
       "value": {"action": "continue"}}
    ]}
  ]
}'
```

## Card button actions

A card button can have either:
- `url`: opens a URL when clicked (used for `file://` links to spec/plan)
- `value`: sends a card callback to the bot with the given JSON

The skill uses `value` only for `{"action": "continue"}`, which the
message handler in SKILL.md maps to `on_continue.sh <job_id>`.
