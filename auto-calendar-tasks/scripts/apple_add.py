#!/usr/bin/env python3
"""Create Apple Calendar events or Apple Reminders tasks via osascript."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys


MONTHS = "January February March April May June July August September October November December".split()


def parse_datetime(value: str) -> tuple[dt.datetime, bool]:
    """Return (datetime, is_date_only)."""
    value = value.strip()
    formats = [
        ("%Y-%m-%d %H:%M:%S", False),
        ("%Y-%m-%d %H:%M", False),
        ("%Y/%m/%d %H:%M:%S", False),
        ("%Y/%m/%d %H:%M", False),
        ("%Y-%m-%d", True),
        ("%Y/%m/%d", True),
    ]
    for fmt, is_date_only in formats:
        try:
            parsed = dt.datetime.strptime(value, fmt)
            return parsed, is_date_only
        except ValueError:
            pass
    try:
        return dt.datetime.fromisoformat(value), False
    except ValueError as exc:
        raise SystemExit(f"Could not parse datetime: {value!r}") from exc


def date_args(value: dt.datetime) -> list[str]:
    if value.tzinfo is not None:
        value = value.astimezone()
    return [
        str(value.year),
        str(value.month),
        str(value.day),
        str(value.hour),
        str(value.minute),
        str(value.second),
    ]


def run_osascript(script: str, args: list[str]) -> str:
    proc = subprocess.run(
        ["osascript", "-", *args],
        input=script,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or f"osascript failed with code {proc.returncode}")
    return proc.stdout.strip()


def make_applescript_date_function() -> str:
    month_items = ", ".join(MONTHS)
    return f"""
on makeDate(y, m, d, h, minValue, s)
  set theDate to current date
  -- Set day to 1 first to avoid overflow bug when current day > target month length
  -- e.g. Mar 31 → set month to Feb overflows to Mar 3 if day is still 31
  set day of theDate to 1
  set month of theDate to item (m as integer) of {{{month_items}}}
  set year of theDate to y as integer
  set day of theDate to d as integer
  set time of theDate to ((h as integer) * hours + (minValue as integer) * minutes + (s as integer))
  return theDate
end makeDate
"""


def create_event(args: argparse.Namespace) -> None:
    start, start_is_date = parse_datetime(args.start)
    if args.end:
        end, _ = parse_datetime(args.end)
    else:
        end = start + dt.timedelta(minutes=args.duration_minutes)

    # Date-only -> all-day event: midnight to next midnight, no alarm
    if start_is_date:
        start = start.replace(hour=0, minute=0, second=0, microsecond=0)
        if not args.end:
            end = start + dt.timedelta(days=1)

    if end <= start:
        raise SystemExit("Event end must be after start.")

    if args.dry_run:
        print(json.dumps({"dry_run": True, "type": "event", "title": args.title, "start": start.isoformat(), "end": end.isoformat(), "calendar": args.calendar, "location": args.location, "notes": args.notes, "url": args.url, "alarm_minutes": args.alarm_minutes if args.alarm_minutes > 0 else None}, ensure_ascii=False))
        return

    script = (
        make_applescript_date_function()
        + """
on run argv
  set eventTitle to item 1 of argv
  set calName to item 2 of argv
  set eventLocation to item 3 of argv
  set eventNotes to item 4 of argv
  set eventUrl to item 5 of argv
  set alarmMinutes to item 6 of argv as integer
  set startDate to makeDate(item 7 of argv, item 8 of argv, item 9 of argv, item 10 of argv, item 11 of argv, item 12 of argv)
  set endDate to makeDate(item 13 of argv, item 14 of argv, item 15 of argv, item 16 of argv, item 17 of argv, item 18 of argv)
  tell application "Calendar"
    if calName is "" then
      set targetCalendar to first calendar
    else
      set targetCalendar to calendar calName
    end if
    set newEvent to make new event at end of events of targetCalendar with properties {summary:eventTitle, start date:startDate, end date:endDate}
    if eventLocation is not "" then set location of newEvent to eventLocation
    if eventNotes is not "" then set description of newEvent to eventNotes
    if eventUrl is not "" then set url of newEvent to eventUrl
    if alarmMinutes is greater than 0 then
      make new display alarm at end of display alarms of newEvent with properties {trigger interval:(0 - alarmMinutes)}
    end if
    return uid of newEvent
  end tell
end run
"""
    )
    output = run_osascript(
        script,
        [
            args.title,
            args.calendar or "",
            args.location or "",
            args.notes or "",
            args.url or "",
            str(args.alarm_minutes if args.alarm_minutes > 0 else -1),
            *date_args(start),
            *date_args(end),
        ],
    )
    print(json.dumps({"type": "event", "uid": output, "title": args.title, "start": start.isoformat(), "end": end.isoformat(), "alarm_minutes": args.alarm_minutes if args.alarm_minutes > 0 else None}, ensure_ascii=False))


def create_task(args: argparse.Namespace) -> None:
    due = None
    due_is_date = False
    if args.due:
        due, due_is_date = parse_datetime(args.due)
        if due_is_date:
            due = due.replace(hour=23, minute=59, second=0, microsecond=0)
    alarm = (due - dt.timedelta(minutes=args.alarm_minutes)) if due and args.alarm_minutes > 0 else None
    due_parts = date_args(due) if due else ["", "", "", "", "", ""]
    alarm_parts = date_args(alarm) if alarm else ["", "", "", "", "", ""]

    if args.dry_run:
        print(json.dumps({"dry_run": True, "type": "task", "title": args.title, "due": due.isoformat() if due else None, "list": args.list, "notes": args.notes, "alarm_minutes": args.alarm_minutes if alarm else None}, ensure_ascii=False))
        return

    script = (
        make_applescript_date_function()
        + """
on run argv
  set taskTitle to item 1 of argv
  set listName to item 2 of argv
  set taskNotes to item 3 of argv
  set hasDueDate to item 4 of argv
  set hasAlarm to item 5 of argv
  tell application "Reminders"
    if listName is "" then
      set targetList to default list
    else
      set targetList to list listName
    end if
    set newReminder to make new reminder at end of reminders of targetList with properties {name:taskTitle}
    if taskNotes is not "" then set body of newReminder to taskNotes
    if hasDueDate is "1" then
      set dueDateValue to makeDate(item 6 of argv, item 7 of argv, item 8 of argv, item 9 of argv, item 10 of argv, item 11 of argv)
      set due date of newReminder to dueDateValue
    end if
    if hasAlarm is "1" then
      set alarmDateValue to makeDate(item 12 of argv, item 13 of argv, item 14 of argv, item 15 of argv, item 16 of argv, item 17 of argv)
      make new display alarm at end of alarms of newReminder with properties {trigger date:alarmDateValue}
    end if
    return id of newReminder
  end tell
end run
"""
    )
    output = run_osascript(
        script,
        [
            args.title,
            args.list or "",
            args.notes or "",
            "1" if due else "0",
            "1" if alarm else "0",
            *due_parts,
            *alarm_parts,
        ],
    )
    print(json.dumps({"type": "task", "id": output, "title": args.title, "due": due.isoformat() if due else None, "alarm_minutes": args.alarm_minutes if alarm else None}, ensure_ascii=False))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    event = subparsers.add_parser("event", help="Create an Apple Calendar event")
    event.add_argument("--title", required=True)
    event.add_argument("--start", required=True, help="YYYY-MM-DD HH:MM or ISO datetime")
    end_group = event.add_mutually_exclusive_group()
    end_group.add_argument("--end", help="YYYY-MM-DD HH:MM or ISO datetime")
    end_group.add_argument("--duration-minutes", type=int, default=60)
    event.add_argument("--calendar")
    event.add_argument("--location")
    event.add_argument("--notes")
    event.add_argument("--url")
    event.add_argument("--alarm-minutes", type=int, default=15, help="Use 0 or -1 for no alarm")
    event.add_argument("--dry-run", action="store_true", help="Print the planned event without creating it")
    event.set_defaults(func=create_event)

    task = subparsers.add_parser("task", help="Create an Apple Reminders task")
    task.add_argument("--title", required=True)
    task.add_argument("--due", help="YYYY-MM-DD HH:MM or ISO datetime")
    task.add_argument("--list")
    task.add_argument("--notes")
    task.add_argument("--alarm-minutes", type=int, default=15, help="Use 0 or -1 for no alarm")
    task.add_argument("--dry-run", action="store_true", help="Print the planned task without creating it")
    task.set_defaults(func=create_task)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
