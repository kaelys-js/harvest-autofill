"""Shared pytest fixtures for the engine tests.

- `cfg` gives the derived-config dict the pure functions consume.
- `run_main` runs the real `main()` in-process with mocked urllib (counts toward coverage).
- `mock_server` starts a stateful HTTP stub of the calendar / GitHub / Harvest APIs on a
  random port for the subprocess end-to-end test (real sockets, real script)."""

import contextlib
import io
import json
import os
import socket
import sys
import threading
import urllib.request
from contextlib import redirect_stdout
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, SRC)

import mockapi  # noqa: E402

CONFIG = os.path.join(HERE, "fixtures", "config.json")


@pytest.fixture
def tz():
    from zoneinfo import ZoneInfo

    return ZoneInfo("America/Vancouver")


@pytest.fixture
def hw():
    import harvest_weekly

    return harvest_weekly


@pytest.fixture
def cfg(hw, tz):
    """derive()'d config from the fixture, with holidays folded in."""
    conf = json.load(open(CONFIG))
    holidays = set(conf["holidays"]["dates"])
    return hw.derive(conf, tz, holidays)


def _base_env():
    return {
        "CONFIG_PATH": CONFIG,
        "HARVEST_ACCOUNT_ID": "acc",
        "HARVEST_ACCESS_TOKEN": "tok",
        "APPS_SCRIPT_URL": "http://mock/cal",
        "APPS_SCRIPT_SECRET": "sec",
        "GITHUB_TOKEN": "ght",
        "WEEK_START": mockapi.WEEK_START,
        "DRY_RUN": "1",
    }


@pytest.fixture
def run_main(tmp_path):
    """Run the real main() in-process with mocked urllib; returns (stdout, summary.json)."""

    def _run(env_overrides=None, resp_overrides=None, urlopen=None):
        env = _base_env()
        env.update(env_overrides or {})
        resp = mockapi.responses()
        resp.update(resp_overrides or {})
        saved_env, saved_urlopen = dict(os.environ), urllib.request.urlopen
        os.environ.pop("ADO_PAT", None)
        os.environ.update(env)
        os.environ["HARVEST_DATA_DIR"] = str(tmp_path)
        urllib.request.urlopen = urlopen or mockapi.make_urlopen(resp)
        out = io.StringIO()
        try:
            for m in [m for m in list(sys.modules) if m == "harvest_weekly"]:
                del sys.modules[m]
            import harvest_weekly

            with redirect_stdout(out):
                rc = harvest_weekly.main()
        finally:
            urllib.request.urlopen = saved_urlopen
            os.environ.clear()
            os.environ.update(saved_env)
        sp = tmp_path / "logs" / "summary.json"
        summary = json.load(open(sp)) if sp.exists() else None
        return out.getvalue(), summary, rc

    return _run


class _StatefulHandler(BaseHTTPRequestHandler):
    entries = []
    _next_id = [1]

    def log_message(self, *a):
        pass

    def _send(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())

    def do_GET(self):
        if "action=events" in self.path:
            return self._send(200, {"events": mockapi.CAL_EVENTS})
        if "/v2/time_entries" in self.path:
            return self._send(200, {"total_entries": len(self.entries), "time_entries": self.entries})
        self._send(404, {"error": self.path})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        if "/graphql" in self.path:
            return self._send(200, {"data": {"search": {"nodes": mockapi.GH_NODES}}})
        if "/v2/time_entries" in self.path:
            import datetime

            p = json.loads(raw)
            hours = (
                datetime.datetime.strptime(p["ended_time"], "%I:%M%p")
                - datetime.datetime.strptime(p["started_time"], "%I:%M%p")
            ).seconds / 3600
            eid = self._next_id[0]
            self._next_id[0] += 1
            entry = {"id": eid, "hours": hours, "is_running": False, "spent_date": p["spent_date"]}
            self.entries.append(entry)
            return self._send(201, entry)
        self._send(404, {"error": self.path})


@contextlib.contextmanager
def _server():
    _StatefulHandler.entries = []
    _StatefulHandler._next_id = [1]
    port = _free_port()
    srv = HTTPServer(("127.0.0.1", port), _StatefulHandler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    try:
        yield f"http://127.0.0.1:{port}"
    finally:
        srv.shutdown()


def _free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


@pytest.fixture
def mock_server():
    return _server
