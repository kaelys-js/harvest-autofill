"""Shared canned API responses + a urllib.urlopen replacement for the engine tests.

The fixture covers a full week (Mon 2026-08-24 … Fri 2026-08-28, all in the past relative
to any realistic test date, so select_days includes all five): ITC + Wheaton commit
timelines, an ITC standup, a vacation day, a Wednesday holiday (config), and a Friday
offsite that trips the social-day rule."""

import json

WEEK_START = "2026-08-24"

# Vancouver is UTC-7 in August; commit authoredDate is UTC, so Van 10:00 == 17:00Z.
GH_NODES = [
    {
        "headRefName": "feature/itc-thing",
        "commits": {
            "nodes": [
                {
                    "commit": {
                        "oid": "a1",
                        "authoredDate": "2026-08-24T17:00:00Z",
                        "messageHeadline": "itc: build the thing",
                        "author": {"email": "testuser@example.com", "user": {"login": "testuser"}},
                    }
                },
                {
                    "commit": {
                        "oid": "a2",
                        "authoredDate": "2026-08-24T21:00:00Z",
                        "messageHeadline": "itc: more work",
                        "author": {"email": "testuser@example.com", "user": {"login": "testuser"}},
                    }
                },
            ]
        },
    },
    {
        "headRefName": "feature/oms-thing",
        "commits": {
            "nodes": [
                {
                    "commit": {
                        "oid": "b1",
                        "authoredDate": "2026-08-25T18:00:00Z",
                        "messageHeadline": "oms: fix the bug",
                        "author": {"email": "testuser@example.com", "user": {"login": "testuser"}},
                    }
                }
            ]
        },
    },
]

CAL_EVENTS = [
    {
        "title": "ITC standup",
        "start": "2026-08-24T09:00:00-07:00",
        "end": "2026-08-24T09:30:00-07:00",
        "allDay": False,
        "status": "accepted",
    },
    {
        "title": "Vacation day",
        "start": "2026-08-27T00:00:00-07:00",
        "end": "2026-08-28T00:00:00-07:00",
        "allDay": True,
        "status": "accepted",
    },
    {
        "title": "Team offsite",
        "start": "2026-08-28T09:00:00-07:00",
        "end": "2026-08-28T18:00:00-07:00",
        "allDay": False,
        "status": "accepted",
    },
]


def responses(*, dedup_total=0, time_entries=None):
    """Map a URL substring -> (status, json-serialisable body)."""
    return {
        "action=events": (200, {"events": CAL_EVENTS}),
        "/graphql": (200, {"data": {"search": {"nodes": GH_NODES}}}),
        # GET dedup + verify hit the same path; the body carries both shapes.
        "/v2/time_entries": (200, {"total_entries": dedup_total, "time_entries": time_entries or []}),
    }


class _Resp:
    def __init__(self, status, body):
        self.status = status
        self._body = body.encode() if isinstance(body, str) else json.dumps(body).encode()

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def make_urlopen(resp_map):
    """A urllib.request.urlopen replacement matching req.full_url against resp_map keys."""

    def _urlopen(req, timeout=None):
        url = req.full_url if hasattr(req, "full_url") else str(req)
        for needle, (status, body) in resp_map.items():
            if needle in url:
                return _Resp(status, body)
        return _Resp(404, {"error": f"no mock for {url}"})

    return _urlopen


class StatefulMock:
    """A urlopen that records Harvest POSTs and replays them on GET — so an in-process run
    with DRY_RUN=0 exercises the real write+verify branch (and passes verification)."""

    def __init__(self):
        self.entries = []
        self._id = 0

    def urlopen(self, req, timeout=None):
        import datetime

        url = req.full_url
        if "action=events" in url:
            return _Resp(200, {"events": CAL_EVENTS})
        if "/graphql" in url:
            return _Resp(200, {"data": {"search": {"nodes": GH_NODES}}})
        if "/v2/time_entries" in url:
            if req.get_method() == "POST":
                p = json.loads(req.data)
                hours = (
                    datetime.datetime.strptime(p["ended_time"], "%I:%M%p")
                    - datetime.datetime.strptime(p["started_time"], "%I:%M%p")
                ).seconds / 3600
                self._id += 1
                e = {"id": self._id, "hours": hours, "is_running": False, "spent_date": p["spent_date"]}
                self.entries.append(e)
                return _Resp(201, e)
            return _Resp(200, {"total_entries": len(self.entries), "time_entries": self.entries})
        return _Resp(404, {"error": url})
