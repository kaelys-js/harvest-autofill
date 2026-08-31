"""End-to-end: the real harvest_weekly.py, run as a subprocess over real sockets against a
stateful HTTP stub of the three APIs. Nothing about the engine is mocked in-process — this
exercises the actual script, urllib, argument handling, and summary.json write."""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)


def _run(base_url, tmp_path, dry="1"):
    env = {
        **os.environ,
        "CONFIG_PATH": os.path.join(HERE, "fixtures", "config.json"),
        "HARVEST_ACCOUNT_ID": "acc",
        "HARVEST_ACCESS_TOKEN": "tok",
        "APPS_SCRIPT_URL": base_url,
        "APPS_SCRIPT_SECRET": "sec",
        "GITHUB_TOKEN": "ght",
        "GH_API_BASE": base_url,
        "HARVEST_API_BASE": base_url,
        "WEEK_START": "2026-08-24",
        "DRY_RUN": dry,
        "HARVEST_DATA_DIR": str(tmp_path),
    }
    env.pop("ADO_PAT", None)
    r = subprocess.run(
        [sys.executable, os.path.join(SRC, "harvest_weekly.py")],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    sp = tmp_path / "logs" / "summary.json"
    summary = json.load(open(sp)) if sp.exists() else None
    return r, summary


def test_e2e_dry_run(mock_server, tmp_path):
    with mock_server() as url:
        r, summary = _run(url, tmp_path, "1")
    assert r.returncode == 0, r.stderr
    assert summary["state"] == "dryrun"
    assert summary["total"] == 18.0
    assert summary["daysWorked"] == 2


def test_e2e_full_write_then_verify(mock_server, tmp_path):
    with mock_server() as url:
        r, summary = _run(url, tmp_path, "0")
    assert r.returncode == 0, r.stderr
    assert summary["state"] == "written"
    assert "VERIFY: PASS" in r.stdout
