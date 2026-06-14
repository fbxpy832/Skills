# hermes-dev-skill/tests/test_review_parser.py
from pathlib import Path
import pytest

from scripts.lib.review_parser import parse, is_pass


FIX = Path(__file__).parent / "fixtures"


def test_parse_approved():
    parsed = parse((FIX / "sample-review-approved.md").read_text())
    assert parsed["verdict"] == "APPROVED"
    assert parsed["p0"] == 0
    assert parsed["p1"] == 0
    assert parsed["p2"] == 1


def test_parse_rejected_p0():
    parsed = parse((FIX / "sample-review-rejected-p0.md").read_text())
    assert parsed["verdict"] == "REJECTED"
    assert parsed["p0"] == 2
    assert parsed["p1"] == 0


def test_parse_rejected_p1():
    parsed = parse((FIX / "sample-review-rejected-p1.md").read_text())
    assert parsed["verdict"] == "REJECTED"
    assert parsed["p0"] == 0
    assert parsed["p1"] == 3


def test_parse_malformed_defaults_to_rejected():
    parsed = parse((FIX / "sample-review-malformed.md").read_text())
    assert parsed["verdict"] == "REJECTED"


def test_is_pass_only_when_approved_and_no_p0_p1():
    assert is_pass({"verdict": "APPROVED", "p0": 0, "p1": 0}) is True
    assert is_pass({"verdict": "APPROVED", "p0": 1, "p1": 0}) is False
    assert is_pass({"verdict": "REJECTED", "p0": 0, "p1": 0}) is False
