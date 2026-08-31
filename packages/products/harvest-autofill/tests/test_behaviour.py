"""Behaviour tests for build_plan — each encodes a rule the business cares about, phrased
given/when/then, so it fails if that rule changes (not just if the code moves)."""

import datetime as dt

import mockapi
import pytest


@pytest.fixture
def week(hw, cfg, tz):
    """The fixture week classified into build_plan's inputs."""
    days = [dt.date(2026, 8, 24) + dt.timedelta(i) for i in range(5)]
    meet, off, social_h = hw.classify_calendar(
        mockapi.CAL_EVENTS,
        days,
        tz=tz,
        social_kw=cfg["social_kw"],
        long_event_h=cfg["long_event_h"],
        ooo_kw=cfg["ooo_kw"],
        meeting_rules=cfg["meeting_rules"],
        meeting_default=cfg["meeting_default"],
    )
    day_events = {
        dt.date(2026, 8, 24): [
            (dt.datetime(2026, 8, 24, 10, 0, tzinfo=tz), "ITC"),
            (dt.datetime(2026, 8, 24, 14, 0, tzinfo=tz), "ITC"),
        ],
        dt.date(2026, 8, 25): [(dt.datetime(2026, 8, 25, 11, 0, tzinfo=tz), "Wheaton")],
    }
    from collections import defaultdict

    week_mins = defaultdict(float)
    for d in days:
        for p, m in hw.attribute(
            day_events.get(d, []), d, work_start=9, work_end=17, tz=tz, lead_in=45, gap_cap=90
        ).items():
            week_mins[p] += m
    return days, meet, off, social_h, day_events, week_mins


def _kinds(plan):
    return {d: kind for d, kind, _ in plan}


def test_worked_day_splits_target_between_meeting_and_dev(hw, cfg, week):
    days, meet, off, social_h, day_events, week_mins = week
    c = {**cfg, "gh_n": 3, "ado_n": 0}
    plan, posts, issues = hw.build_plan(days, meet, off, social_h, day_events, week_mins, cfg=c)
    mon = next(entries for d, kind, entries in plan if d == dt.date(2026, 8, 24) and kind == "work")
    # ITC meeting 0.5h then ITC dev fills the rest of the 9h day.
    assert [(p, kind, h) for p, _, kind, h, _, _ in mon] == [("ITC", "meeting", 0.5), ("ITC", "dev", 8.5)]
    assert sum(h for *_, h, _, _ in mon) == 9.0


def test_holiday_off_and_social_days_record_nothing(hw, cfg, week):
    days, meet, off, social_h, day_events, week_mins = week
    c = {**cfg, "gh_n": 3, "ado_n": 0}
    plan, posts, issues = hw.build_plan(days, meet, off, social_h, day_events, week_mins, cfg=c)
    kinds = _kinds(plan)
    assert kinds[dt.date(2026, 8, 26)] == "holiday"  # in config holidays
    assert kinds[dt.date(2026, 8, 27)] == "off"  # all-day vacation
    assert kinds[dt.date(2026, 8, 28)] == "social"  # 9h offsite
    # none of those three produced Harvest posts
    assert not any(p["spent_date"] in ("2026-08-26", "2026-08-27", "2026-08-28") for p in posts)


def test_quiet_day_is_skipped_when_no_meetings_and_no_commits(hw, cfg, tz):
    days = [dt.date(2026, 8, 24)]
    c = {**cfg, "gh_n": 0, "ado_n": 0}
    plan, posts, issues = hw.build_plan(days, {days[0]: {}}, set(), {days[0]: 0.0}, {}, {}, cfg=c)
    assert _kinds(plan)[days[0]] == "skip"
    assert posts == []


def test_meetings_over_target_are_flagged_overbooked_and_write_nothing(hw, cfg):
    d = dt.date(2026, 8, 24)
    c = {**cfg, "gh_n": 1, "ado_n": 0}
    plan, posts, issues = hw.build_plan([d], {d: {"ITC": 10.0}}, set(), {d: 0.0}, {}, {}, cfg=c)
    assert _kinds(plan)[d] == "overbooked"
    assert posts == []
    assert any("exceed" in msg for msg in issues)


def test_every_post_carries_the_right_ids(hw, cfg, week):
    days, meet, off, social_h, day_events, week_mins = week
    c = {**cfg, "gh_n": 3, "ado_n": 0}
    _, posts, _ = hw.build_plan(days, meet, off, social_h, day_events, week_mins, cfg=c)
    assert posts, "expected some entries"
    for p in posts:
        assert p["user_id"] == 999
        assert p["project_id"] in (100, 200, 300, 400)
        assert p["started_time"] and p["ended_time"] and p["spent_date"]
