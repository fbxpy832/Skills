# hermes-dev-skill/tests/test_feishu.py
import json
import os
import subprocess
from pathlib import Path
import pytest

from scripts.lib.feishu import send_text, send_card, FeishuError


@pytest.fixture
def fake_hermes(tmp_path, monkeypatch):
    """Install a fake hermes binary on PATH and capture its invocations."""
    fixture = Path(__file__).parent / "fixtures" / "fake_hermes.sh"
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (bin_dir / "hermes").write_text(fixture.read_text())
    (bin_dir / "hermes").chmod(0o755)
    log = tmp_path / "hermes.log"
    monkeypatch.setenv("PATH", f"{bin_dir}:{os.environ['PATH']}")
    monkeypatch.setenv("HERMES_TEST_LOG", str(log))
    monkeypatch.delenv("HERMES_TEST_FAIL", raising=False)
    return log


def test_send_text_invokes_hermes(fake_hermes):
    msg_id = send_text("hello world")
    assert msg_id.startswith("om_test_")
    invocation = fake_hermes.read_text()
    assert "hermes send --text hello world" in invocation


def test_send_text_raises_on_hermes_failure(fake_hermes, monkeypatch):
    monkeypatch.setenv("HERMES_TEST_FAIL", "fail")
    with pytest.raises(FeishuError):
        send_text("hi")


def test_send_text_returns_empty_when_no_message_id(tmp_path, monkeypatch):
    """If hermes send doesn't print 'message_id: ...', we return '' without raising."""
    no_id = tmp_path / "bin" / "hermes"
    no_id.parent.mkdir()
    no_id.write_text("#!/bin/bash\necho 'sent ok'\nexit 0\n")
    no_id.chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path / 'bin'}:{os.environ['PATH']}")
    assert send_text("hi") == ""


def test_send_card_renders_title_fields_buttons(fake_hermes):
    msg_id = send_card(
        title="Job #abc — Phase 4/5",
        fields=[{"key": "Status", "value": "REJECTED"}],
        buttons=[{"text": "View", "url": "file:///x.md", "type": "primary"}],
    )
    assert msg_id.startswith("om_test_")
    invocation = fake_hermes.read_text()
    # Find the --card-json argument value
    assert "hermes send --card-json" in invocation
    # Extract JSON
    idx = invocation.find("--card-json ") + len("--card-json ")
    end = invocation.find("\n", idx)
    payload = json.loads(invocation[idx:end])
    assert payload["header"]["title"]["content"] == "Job #abc — Phase 4/5"
    assert payload["elements"][0]["text"]["content"] == "**Status**: REJECTED"
    assert payload["elements"][1]["actions"][0]["text"]["content"] == "View"


def test_send_card_with_no_buttons(fake_hermes):
    msg_id = send_card("Hi", [{"key": "K", "value": "V"}])
    assert msg_id.startswith("om_test_")
    invocation = fake_hermes.read_text()
    idx = invocation.find("--card-json ") + len("--card-json ")
    payload = json.loads(invocation[idx:invocation.find("\n", idx)])
    assert "actions" not in str(payload["elements"])
