"""Unit tests for discover.py's statutory-holiday generator (pure, no network)."""

import datetime as dt

import pytest

import discover


def test_easter_2026_and_2027():
    assert discover._easter(2026) == dt.date(2026, 4, 5)
    assert discover._easter(2027) == dt.date(2027, 3, 28)


def test_nth_weekday():
    # 3rd Monday of February 2026 = Family Day, Feb 16.
    assert discover._nth_wd(2026, 2, 0, 3) == dt.date(2026, 2, 16)
    # 1st Monday of September 2026 = Labour Day, Sep 7.
    assert discover._nth_wd(2026, 9, 0, 1) == dt.date(2026, 9, 7)


def test_last_weekday():
    # Last Monday of May 2026 = US Memorial Day, May 25.
    assert discover._last_wd(2026, 5, 0) == dt.date(2026, 5, 25)


def test_mon_before():
    # Monday on/before May 25 2026 = Victoria Day, May 18.
    assert discover._mon_before(2026, 5, 25) == dt.date(2026, 5, 18)


def test_ca_bc_2026_matches_the_shipped_dates():
    got = set(discover.gen_holidays("CA-BC", {2026}))
    expected = {
        "2026-01-01",  # New Year
        "2026-02-16",  # Family Day
        "2026-04-03",  # Good Friday
        "2026-05-18",  # Victoria Day
        "2026-07-01",  # Canada Day
        "2026-08-03",  # BC Day
        "2026-09-07",  # Labour Day
        "2026-09-30",  # Truth & Reconciliation
        "2026-10-12",  # Thanksgiving
        "2026-11-11",  # Remembrance Day
        "2026-12-25",  # Christmas
    }
    assert got == expected


@pytest.mark.parametrize("region", discover.SUPPORTED_REGIONS)
def test_every_region_returns_new_year_and_christmas(region):
    got = set(discover.gen_holidays(region, {2026}))
    assert "2026-01-01" in got
    assert "2026-12-25" in got
    assert got, "region produced no holidays"


def test_us_federal_has_juneteenth_and_independence_day():
    got = set(discover.gen_holidays("US-Federal", {2026}))
    assert "2026-06-19" in got
    assert "2026-07-04" in got


def test_multiple_years_are_unioned_and_sorted():
    got = discover.gen_holidays("CA-BC", {2026, 2027})
    assert got == sorted(got)
    assert any(d.startswith("2026") for d in got)
    assert any(d.startswith("2027") for d in got)
