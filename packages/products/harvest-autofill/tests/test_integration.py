"""Integration tests: the real main() run in-process against mocked urllib. These exercise
config load, calendar + GitHub fetch, allocation, dedup, dry-run, and the write+verify
branch end to end (and count toward coverage)."""

import mockapi


def test_dry_run_reports_the_week_without_writing(run_main):
    out, summary, rc = run_main()
    assert rc == 0
    assert summary["state"] == "dryrun"
    assert summary["daysWorked"] == 2  # Mon + Tue; Wed holiday, Thu off, Fri social
    assert summary["total"] == 18.0
    assert len(summary["days"]) == 5
    assert "DRY-RUN — no writes performed." in out


def test_dry_run_marks_the_non_work_days(run_main):
    _, summary, _ = run_main()
    notes = {d["name"]: d["note"] for d in summary["days"] if d["note"]}
    assert any("holiday" in n for n in notes.values())
    assert any("time off" in n for n in notes.values())
    assert any("social" in n for n in notes.values())


def test_dedup_aborts_when_the_window_already_has_entries(run_main):
    out, summary, rc = run_main(resp_overrides={"/v2/time_entries": (200, {"total_entries": 3})})
    assert summary["state"] == "dedup"
    assert "ABORT" in out


def test_future_week_does_nothing(run_main):
    out, summary, rc = run_main(env_overrides={"WEEK_START": "2026-09-07"})
    assert rc == 0
    assert summary is None
    assert "hasn't started yet" in out


def test_write_path_writes_then_verifies(run_main):
    stateful = mockapi.StatefulMock()
    out, summary, rc = run_main(env_overrides={"DRY_RUN": "0"}, urlopen=stateful.urlopen)
    assert rc == 0
    assert summary["state"] == "written"
    assert "VERIFY: PASS" in out
    # two work days at the 9h target = 18h across the entries actually posted
    assert round(sum(e["hours"] for e in stateful.entries), 2) == 18.0
