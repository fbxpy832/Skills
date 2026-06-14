# hermes-dev-skill/scripts/lib/review_parser.py
"""Parse Codex review output and decide pass/fail.

A review is considered a PASS iff:
  - The review contains a line `VERDICT: APPROVED`
  - The review contains no P0 or P1 markers

P0/P1/P2 markers are matched as bracketed issue tags `[P0]`, `[P1]`, `[P2]`.
This is the format Codex uses for actual issue list items (e.g.
`- [P0] src/auth.py:12 — auth check is missing`). Section headers like
`### P0 — must fix` do NOT count, so an "approved with no P0 issues"
review that still has the P0 section header is correctly counted as 0.
"""
from __future__ import annotations

import re
from pathlib import Path


VERDICT_RE = re.compile(r"^VERDICT:\s*(APPROVED|REJECTED)\s*$", re.MULTILINE)
P0_RE = re.compile(r"\[P0\]")
P1_RE = re.compile(r"\[P1\]")
P2_RE = re.compile(r"\[P2\]")
ISSUES_SECTION_RE = re.compile(
    r"##\s*Issues found\s*\n(.*?)(?=\n##|\Z)", re.DOTALL
)


def parse(review_md: str) -> dict:
    """Return {verdict, p0, p1, p2, summary}."""
    verdict_m = VERDICT_RE.search(review_md)
    verdict = verdict_m.group(1) if verdict_m else "REJECTED"
    return {
        "verdict": verdict,
        "p0": len(P0_RE.findall(review_md)),
        "p1": len(P1_RE.findall(review_md)),
        "p2": len(P2_RE.findall(review_md)),
        "summary": _extract_summary(review_md),
    }


def is_pass(parsed: dict) -> bool:
    return (
        parsed["verdict"] == "APPROVED"
        and parsed["p0"] == 0
        and parsed["p1"] == 0
    )


def _extract_summary(review_md: str) -> str:
    m = ISSUES_SECTION_RE.search(review_md)
    if not m:
        return review_md[:200].strip()
    return m.group(1).strip()[:300]


def parse_file(path: Path) -> dict:
    return parse(Path(path).read_text(encoding="utf-8"))
