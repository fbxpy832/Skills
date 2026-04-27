---
name: auto-calendar-tasks
description: Create calendar events and todo/reminder tasks with sensible reminder defaults. Use when the user asks to add, schedule, create, or record an event, meeting, appointment, reminder, todo, task, deadline, follow-up, or alert. Default to Apple Calendar and Apple Reminders on macOS with a 15-minute-before reminder unless the user specifies another reminder. If the user explicitly asks for Lark/Feishu/飞书 calendar events, meetings, online meetings, or tasks, route through lark-cli and the relevant lark-* skills; when a Lark event includes a meeting, ask whether to create a Lark online meeting link.
---

# Auto Calendar Tasks

## Core Workflow

1. Classify the request as a calendar event or a todo/reminder.
2. Classify the target system:
   - Use Apple Calendar / Apple Reminders by default.
   - Use Lark/Feishu only when the user explicitly says Lark, Feishu, 飞书, Lark calendar, 飞书日程, 飞书待办, Lark task, or asks for a Lark online meeting link.
3. Resolve missing details before creating live records:
   - Calendar events need title, start date/time, and either end date/time or duration.
   - Todos need title. If the user asks for a timed reminder, resolve due date/time.
   - Use the user's locale/timezone context unless they specify another timezone.
   - Apply a reminder 15 minutes before by default. Respect explicit reminders such as "提前 1 小时", "no reminder", or "tomorrow at 9".
4. Check dependencies before creation. Use `scripts/check_dependencies.sh apple` for Apple targets and `scripts/check_dependencies.sh lark` for Lark targets.
5. Create the record and report the concrete result: title, date/time, target calendar/list/task source, reminder timing, and meeting link when applicable.

## Apple Calendar And Reminders

Use `scripts/apple_add.py` for Apple targets. It wraps macOS `osascript` and handles date construction, default reminders, calendar/list selection, notes, location, and URLs.

Examples:

```bash
python3 /Users/xpy/.codex/skills/auto-calendar-tasks/scripts/apple_add.py event \
  --title "Project sync" \
  --start "2026-04-24 15:00" \
  --duration-minutes 30 \
  --calendar "Calendar" \
  --alarm-minutes 15
```

```bash
python3 /Users/xpy/.codex/skills/auto-calendar-tasks/scripts/apple_add.py task \
  --title "Submit expenses" \
  --due "2026-04-25 18:00" \
  --list "Reminders" \
  --alarm-minutes 15
```

Notes:

- Add `--dry-run` while validating parsed dates and options; remove it before creating the live Apple record.
- If Calendar or Reminders automation permission prompts appear, tell the user macOS needs permission for the terminal/Codex app to control those apps, then retry after permission is granted.
- If the user gives a date without a time for a todo, either create a due-date-only reminder when that matches the request, or ask for a time if they specifically asked for an alert.
- Use the default Apple calendar/list when the user does not specify one.

## Lark / Feishu Routing

Before doing any Lark operation:

1. Run `scripts/check_dependencies.sh lark`.
2. If a needed Lark skill is missing, use `skill-installer` or the available local skill source to install it before proceeding.
3. If `lark-cli` is missing or auth is not configured, use `lark-shared` guidance first.

Then use the most specific Lark skill:

- For 飞书日程 / Lark calendar events or meeting scheduling, read and follow `lark-calendar`.
- For 飞书待办 / Lark tasks, read and follow `lark-task`.
- For auth, identity, permissions, or missing scopes, read and follow `lark-shared`.

When creating a Lark calendar event that includes a meeting:

- Treat words like meeting, call, sync, standup, review, 面试, 会议, 沟通, 评审, 同步 as meeting indicators.
- Ask the user whether to create a Lark online meeting link unless they already explicitly requested or rejected one.
- If they say yes, create the event with the Lark online meeting option through the `lark-calendar` workflow so the generated link is attached to the event.

## Dependency Policy

Run the dependency check before live changes, not after:

```bash
/Users/xpy/.codex/skills/auto-calendar-tasks/scripts/check_dependencies.sh apple
/Users/xpy/.codex/skills/auto-calendar-tasks/scripts/check_dependencies.sh lark
```

If a dependency is missing, fix it before creating the event/task when possible. Do not silently fall back from an explicitly requested Lark record to Apple, or from Apple to Lark.

## Confirmation Rules

Create directly when the user provided enough information and the target is unambiguous.

Ask a concise question when any required field is missing, when a Lark meeting needs an online meeting decision, or when an automation permission/auth step requires user action.

Never invent attendees, meeting rooms, calendars, or Lark identities. If the user names attendees or rooms, verify through the relevant Lark workflow before creating the record.
