"""Unit tests for the engine's pure functions. Each asserts a specific intent, not just
that the call returns something."""

import datetime as dt

import pytest


# ---------- time / format helpers ----------
@pytest.mark.parametrize(
    "s,expected",
    [("9:00am", 540), ("5:00pm", 1020), ("12:00pm", 720), ("12:30am", 30), ("1:15pm", 795)],
)
def test_parse_ampm(hw, s, expected):
    assert hw.parse_ampm(s) == expected


@pytest.mark.parametrize("x,expected", [(1.1, 1.0), (1.13, 1.25), (0.6, 0.5), (0.0, 0.0), (2.0, 2.0)])
def test_q_rounds_to_quarter_hours(hw, x, expected):
    assert hw.q(x) == expected


@pytest.mark.parametrize(
    "mins,expected", [(540, "9:00am"), (1020, "5:00pm"), (720, "12:00pm"), (30, "12:30am"), (0, "12:00am")]
)
def test_fmt(hw, mins, expected):
    assert hw.fmt(mins) == expected


def test_span_reads_as_am_pm_range(hw):
    assert hw.span(540, 570) == "9:00 AM–9:30 AM"


@pytest.mark.parametrize(
    "project,kind,expected",
    [
        ("ITC", "dev", "Development"),
        ("Internal", "meeting", "Internal meetings"),
        ("ITC", "meeting", "Client Meetings"),
    ],
)
def test_plain_task(hw, project, kind, expected):
    assert hw.plain_task(project, kind) == expected


# ---------- select_days: the "no future days" rule (the 45h fix) ----------
def test_select_days_monday_only_fills_monday(hw):
    mon = dt.date(2026, 8, 31)  # a Monday
    assert hw.select_days(mon, today=mon) == [mon]


def test_select_days_midweek_stops_at_today(hw):
    mon = dt.date(2026, 8, 31)
    assert hw.select_days(mon, today=dt.date(2026, 9, 2)) == [
        dt.date(2026, 8, 31),
        dt.date(2026, 9, 1),
        dt.date(2026, 9, 2),
    ]


def test_select_days_friday_fills_all_five(hw):
    mon = dt.date(2026, 8, 31)
    assert len(hw.select_days(mon, today=dt.date(2026, 9, 4))) == 5


def test_select_days_past_week_fills_all_five(hw):
    mon = dt.date(2026, 8, 24)
    assert len(hw.select_days(mon, today=dt.date(2026, 8, 31))) == 5


def test_select_days_future_week_is_empty(hw):
    mon = dt.date(2026, 9, 7)
    assert hw.select_days(mon, today=dt.date(2026, 8, 31)) == []


# ---------- split_props ----------
def test_split_props_is_proportional(hw):
    assert hw.split_props(8, {"ITC": 60, "Wheaton": 20}) == {"ITC": 6.0, "Wheaton": 2.0}


def test_split_props_absorbs_rounding_drift_into_largest(hw):
    out = hw.split_props(9, {"ITC": 100, "Internal": 100, "Wheaton": 100})
    assert round(sum(out.values()), 2) == 9.0  # exact budget despite quarter-hour rounding


def test_split_props_zero_budget_is_empty(hw):
    assert hw.split_props(0, {"ITC": 60}) == {}


def test_split_props_all_zero_props_falls_back_to_wheaton(hw):
    assert hw.split_props(8, {"ITC": 0}) == {"Wheaton": 8}


# ---------- classification ----------
@pytest.mark.parametrize(
    "title,expected",
    [("ITC standup", "ITC"), ("OMS sync", "Wheaton"), ("Providence chat", "Providence"), ("Random", "Internal")],
)
def test_meeting_project(hw, cfg, title, expected):
    assert hw.meeting_project(title, cfg["meeting_rules"], cfg["meeting_default"]) == expected


@pytest.mark.parametrize(
    "msg,br,expected",
    [("itc: build", "", "ITC"), ("oms: fix", "feature/oms", "Wheaton"), ("chore: bump", "main", "Internal")],
)
def test_scope_of(hw, cfg, msg, br, expected):
    assert hw.scope_of(msg, br, cfg["scope_rules"], cfg["scope_default"]) == expected


def test_is_social_by_keyword_and_by_length(hw):
    assert hw.is_social({"title": "Team offsite", "allDay": False}, 2, ("offsite",), 5) is True
    assert hw.is_social({"title": "Long block", "allDay": False}, 6, ("offsite",), 5) is True
    assert hw.is_social({"title": "Standup", "allDay": False}, 0.5, ("offsite",), 5) is False


def test_counts_excludes_allday_declined_optional_and_social(hw):
    social, longh = ("offsite",), 5
    assert hw.counts({"title": "Standup", "allDay": False, "status": "accepted"}, 0.5, social, longh) is True
    assert hw.counts({"title": "Standup", "allDay": True, "status": "accepted"}, 0.5, social, longh) is False
    assert hw.counts({"title": "Standup", "allDay": False, "status": "NO"}, 0.5, social, longh) is False
    assert hw.counts({"title": "Optional sync", "allDay": False, "status": "accepted"}, 0.5, social, longh) is False
    assert hw.counts({"title": "Team offsite", "allDay": False, "status": "accepted"}, 2, social, longh) is False


def test_gh_mine_by_login_or_email_hint(hw):
    assert hw.gh_mine({"author": {"user": {"login": "testuser"}}}, "testuser", ["hint"]) is True
    assert hw.gh_mine({"author": {"email": "x-testuser@y"}}, "other", ["testuser"]) is True
    assert hw.gh_mine({"author": {"user": {"login": "other"}, "email": "a@b"}}, "testuser", ["hint"]) is False


# ---------- timeline attribution ----------
def test_attribute_credits_lead_in_plus_capped_gap(hw, tz):
    events = [
        (dt.datetime(2026, 8, 24, 10, 0, tzinfo=tz), "ITC"),
        (dt.datetime(2026, 8, 24, 14, 0, tzinfo=tz), "ITC"),  # 4h gap, capped at 90
    ]
    out = hw.attribute(events, dt.date(2026, 8, 24), work_start=9, work_end=17, tz=tz, lead_in=45, gap_cap=90)
    assert out == {"ITC": 45 + 90}


def test_attribute_ignores_commits_outside_work_hours(hw, tz):
    events = [(dt.datetime(2026, 8, 24, 3, 0, tzinfo=tz), "ITC")]  # 3am, before work
    out = hw.attribute(events, dt.date(2026, 8, 24), work_start=9, work_end=17, tz=tz, lead_in=45, gap_cap=90)
    assert dict(out) == {}


# ---------- calendar classification against the fixture ----------
def test_classify_calendar_splits_meetings_ooo_and_social(hw, cfg, tz):
    import mockapi

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
    assert meet[dt.date(2026, 8, 24)] == {"ITC": 0.5}  # ITC standup, 30 min
    assert off == {dt.date(2026, 8, 27)}  # vacation day
    assert social_h[dt.date(2026, 8, 28)] == 9.0  # 9h offsite


# ---------- misc ----------
def test_week_label(hw):
    assert hw.week_label(dt.date(2026, 8, 24), dt.date(2026, 8, 24)) == "Aug 24"
    assert hw.week_label(dt.date(2026, 8, 24), dt.date(2026, 8, 28)) == "Aug 24–28"


def test_derive_maps_config(hw, cfg):
    assert cfg["target"] == 9.0
    assert cfg["proj"]["ITC"] == 100
    assert cfg["order"] == ["ITC", "Providence", "Internal", "Wheaton"]
    assert "2026-08-26" in cfg["holidays"]
