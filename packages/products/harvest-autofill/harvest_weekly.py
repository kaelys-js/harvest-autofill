#!/usr/bin/env python3
"""Weekly Harvest auto-fill — config-driven, timeline-based allocation. Pure stdlib.

Reads a calendar (Apps Script) + your GitHub PR commits + Azure DevOps commits/pushes,
allocates the daily target across Harvest projects by a TIMELINE of when you worked on
what during work hours, writes in timestamp mode, verifies, prints a summary + JSON.

All identity/project/rule settings live in config.json (see CONFIG_PATH). Secrets come
from the environment only.

Env required: HARVEST_ACCOUNT_ID HARVEST_ACCESS_TOKEN APPS_SCRIPT_URL APPS_SCRIPT_SECRET GITHUB_TOKEN
Env optional:  DRY_RUN=1 (default; no writes)  WEEK_START=YYYY-MM-DD  SKIP_DEDUP=1  CONFIG_PATH=...
Azure DevOps (optional): ADO_PAT ADO_ORG ADO_PROJECT ADO_REPOS ADO_AUTHOR

Structure: the pure decision logic (day selection, calendar classification, timeline
attribution, allocation, summary) lives in module-level functions that take everything
they need as arguments — importing this module runs nothing and touches no network, so
the logic is unit-testable. main() does the config/env/HTTP orchestration.

API hosts are overridable via env (GH_API_BASE / HARVEST_API_BASE / ADO_API_BASE) so an
end-to-end test can point the real script at a local mock server.
"""

import base64
import datetime
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor

GH_API_BASE = os.environ.get("GH_API_BASE", "https://api.github.com")
HARVEST_API_BASE = os.environ.get("HARVEST_API_BASE", "https://api.harvestapp.com")
ADO_API_BASE = os.environ.get("ADO_API_BASE", "https://dev.azure.com")


def parse_iso(s):
    return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))


def tovan(dtutc, tz):
    return dtutc.astimezone(tz)


def vday(s, tz):
    return tovan(parse_iso(s), tz).date()


def vdt(s, tz):
    return tovan(parse_iso(s), tz)


def q(x):
    return round(x * 4) / 4


def parse_ampm(s):
    m = re.match(r"(\d+):(\d+)\s*(am|pm)", s.strip().lower())
    h = int(m.group(1)) % 12
    return (h + (12 if m.group(3) == "pm" else 0)) * 60 + int(m.group(2))


def fmt(mins):
    h, m = divmod(int(round(mins)), 60)
    ap = "am" if h < 12 else "pm"
    return f"{h % 12 or 12}:{m:02d}{ap}"


def span(a, b):
    def nice(m):
        return fmt(m).replace("am", " AM").replace("pm", " PM")

    return f"{nice(a)}–{nice(b)}"


def plain_task(p, kind):
    return "Development" if kind != "meeting" else ("Internal meetings" if p == "Internal" else "Client Meetings")


def select_days(mon, today):
    """The five weekdays of the target week, capped at `today`.

    Only fill days that have actually happened. Mid-week (and any manual run before the
    Friday job) must not fabricate a full day for days still in the future — that showed a
    45h week on a Monday and, worse, would write unworked time to Harvest on "Log week".
    The Friday 18:00 run has today == Fri, so all five days are included; a WEEK_START in a
    past week likewise includes all five (every day <= today)."""
    return [d for d in (mon + datetime.timedelta(i) for i in range(5)) if d <= today]


def meeting_project(title, meeting_rules, default):
    t = title.lower()
    for rule in meeting_rules:
        if any(k.lower() in t for k in rule["keywords"]):
            return rule["project"]
    return default


def scope_of(msg, br, scope_rules, default):
    m = re.match(r"^[a-z]+\(([^)]+)\)!?:", msg)
    s = m.group(1).lower() if m else ""
    blob = s + " " + br.lower() + " " + msg.lower()
    for rule in scope_rules:
        if s.startswith(rule["keywords"][0]) or any(k.lower() in blob for k in rule["keywords"]):
            return rule["project"]
    return default


def is_social(e, dur, social_kw, long_event_h):
    t = e["title"].lower()
    if any(k in t for k in social_kw):
        return True
    if (not e["allDay"]) and dur > long_event_h:
        return True  # long block/offsite — catches unnamed company events
    return False


def counts(e, dur, social_kw, long_event_h):
    if e["allDay"] or e["status"] == "NO":
        return False
    if "optional" in e["title"].lower():
        return False
    if is_social(e, dur, social_kw, long_event_h):
        return False
    return True


def gh_mine(cm, gh_login, email_hints):
    u = (cm.get("author") or {}).get("user") or {}
    if u.get("login") == gh_login:
        return True
    em = ((cm.get("author") or {}).get("email") or "").lower()
    return any(k in em for k in email_hints)


def classify_calendar(events, days, *, tz, social_kw, long_event_h, ooo_kw, meeting_rules, meeting_default):
    """Split calendar events into per-day meeting hours, OOO days, and social hours."""
    meet = {d: {} for d in days}
    off = set()
    social_h = {d: 0.0 for d in days}
    for e in events:
        d = vday(e["start"], tz)
        if d not in meet:
            continue
        dur = (parse_iso(e["end"]) - parse_iso(e["start"])).total_seconds() / 3600
        if e["allDay"] and any(k in e["title"].lower() for k in ooo_kw):
            off.add(d)
        if e["status"] != "NO" and not e["allDay"] and is_social(e, dur, social_kw, long_event_h):
            social_h[d] += dur
        if counts(e, dur, social_kw, long_event_h):
            p = meeting_project(e["title"], meeting_rules, meeting_default)
            meet[d][p] = meet[d].get(p, 0.0) + dur
    return meet, off, social_h


def attribute(events, day, *, work_start, work_end, tz, lead_in, gap_cap):
    """Minutes of work per project on `day`, from commit timestamps inside work hours,
    crediting each capped inter-commit gap (+ a lead-in) to that commit's project."""

    # work_start/work_end are hours at half-hour resolution (e.g. 9.0, 17.5). The window runs from
    # the start time to the end time inclusive (the :59 seconds keeps a commit on the end minute in).
    def at(x, sec):
        h = int(x)
        m = int(round((x - h) * 60))
        return datetime.datetime.combine(day, datetime.time(h, m, sec), tz)

    w0 = at(work_start, 0)
    w1 = at(work_end, 59)
    evs = sorted([(dt, p) for dt, p in events if w0 <= dt <= w1])
    t = defaultdict(float)
    prev = None
    for dt, p in evs:
        t[p] += lead_in if prev is None else min((dt - prev).total_seconds() / 60, gap_cap)
        prev = dt
    return t


def split_props(budget, props):
    if budget <= 0 or not props:
        return {}
    tot = sum(props.values())
    if tot <= 0:
        return {"Work": budget}
    raw = {p: budget * props[p] / tot for p in props if props[p] > 0}
    r = {p: q(v) for p, v in raw.items()}
    drift = round(budget - sum(r.values()), 2)
    if r:
        k = max(r, key=lambda p: raw[p])
        r[k] = round(r[k] + drift, 2)
    return {p: v for p, v in r.items() if v > 0}


def build_plan(days, meet, off, social_h, day_events, week_mins, *, cfg):
    """Turn the classified calendar + commit timeline into (plan, posts, issues).

    `cfg` is the derived-config dict produced by derive(). Pure: no I/O, no globals."""
    target = cfg["target"]
    order = cfg["order"]
    anchor = cfg["anchor"]
    posts, plan, issues = [], [], []
    for d in days:
        key = d.isoformat()
        if key in cfg["holidays"]:
            plan.append((d, "holiday", None))
            continue
        if d in off:
            plan.append((d, "off", None))
            continue
        if social_h[d] >= cfg["social_day_h"]:
            plan.append((d, "social", None))
            continue
        mt = {p: q(h) for p, h in meet[d].items() if q(h) > 0}
        mh = round(sum(mt.values()), 2)
        if mh > target:
            issues.append(
                f"{d.strftime('%a %b %-d')}: {mh}h of meetings exceed the {target:g}h day — recorded nothing, add manually if real"
            )
            plan.append((d, "overbooked", None))
            continue
        worked = bool(mt) or cfg["gh_n"] > 0 or cfg["ado_n"] > 0
        if not worked:
            plan.append((d, "skip", None))
            continue
        dev_budget = round(target - mh, 2)
        mins = attribute(
            day_events.get(d, []),
            d,
            work_start=cfg["work_start"],
            work_end=cfg["work_end"],
            tz=cfg["tz"],
            lead_in=cfg["lead_in"],
            gap_cap=cfg["gap_cap"],
        )
        props = mins if mins else week_mins  # fallback to the week's mix, then residual
        dev = split_props(dev_budget, props)
        cur = anchor
        entries = []
        for p in order:
            if mt.get(p, 0) > 0:
                dur = mt[p] * 60
                entries.append((p, cfg["mtask"][p], "meeting", mt[p], cur, cur + dur))
                cur += dur
        for p in order:
            if dev.get(p, 0) > 0:
                dur = dev[p] * 60
                entries.append((p, cfg["dtask"][p], "dev", dev[p], cur, cur + dur))
                cur += dur
        for p, task, kind, h, a, b in entries:
            posts.append(
                {
                    "user_id": cfg["user"],
                    "project_id": cfg["proj"][p],
                    "task_id": task,
                    "spent_date": key,
                    "started_time": fmt(a),
                    "ended_time": fmt(b),
                    "notes": (
                        cfg["ado_note"]
                        if p == cfg["ado_bucket"]
                        else ("Client/Internal meetings (calendar)" if kind == "meeting" else "Development")
                    ),
                }
            )
        plan.append((d, "work", entries))
    return plan, posts, issues


def week_label(mon, fri):
    if mon == fri:
        return mon.strftime("%b %-d")
    # Same month: "Aug 31–4". Crossing a month: name both ends so "Aug 31 – Sep 1" keeps the month.
    if mon.month == fri.month:
        return f"{mon.strftime('%b')} {mon.day}–{fri.day}"
    return f"{mon.strftime('%b %-d')} – {fri.strftime('%b %-d')}"


def summary_json(plan, mon, fri, flags, issues, state, message="", today=None):
    """The summary.json payload the native app reads. Pure.

    `today` flags the current day as projected in the live (dry-run) view: its hours are the
    full daily target laid out across the workday, not what's happened up to now. Only set in
    the dry-run summary — a finalized (written/dedup/fail) week is not a projection."""
    ph = defaultdict(float)
    for _d, _k, _e in plan:
        if _k == "work":
            for _p, _t, _kn, _h, _a, _b in _e:
                ph[_p] += _h
    worked = [d for d, k, e in plan if k == "work"]
    days_json = []
    for d, kind, entries in plan:
        dn = d.strftime("%a %b %-d")
        if kind != "work":
            note = {
                "holiday": "holiday · skipped",
                "off": "time off · skipped",
                "skip": "no activity · skipped",
                "social": "company / social event · skipped",
                "overbooked": "meetings exceed target · needs review",
            }.get(kind, kind)
            days_json.append({"name": dn, "total": None, "note": note, "entries": []})
        else:
            days_json.append(
                {
                    "name": dn,
                    "total": round(sum(e[3] for e in entries), 2),
                    "note": None,
                    "projected": today is not None and d == today,
                    "entries": [
                        {
                            "span": span(a, b),
                            "project": p,
                            "task": plain_task(p, knd),
                            "hours": h,
                        }
                        for p, task, knd, h, a, b in entries
                    ],
                }
            )
    return {
        "state": state,
        "week": week_label(mon, fri),
        "total": round(sum(ph.values()), 2),
        "daysWorked": len(worked),
        "days": days_json,
        "flags": flags,
        "issues": issues,
        "message": message,
    }


def http(url, headers=None, data=None, method=None):
    h = headers or {}
    body = None
    if data is not None:
        body = json.dumps(data).encode()
        h.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(
        url,
        data=body,
        headers=h,
        method=method or ("POST" if data is not None else "GET"),
    )
    attempts = 1 if data is not None else 5  # NEVER retry writes (a lost response could double-post)
    # Writes keep a generous timeout (a slow-but-successful POST must not be cut off — we never
    # retry them). Reads get a tighter 15s so a single hung endpoint can't stall a background
    # refresh for minutes and block the next one (refreshes are single-flight).
    timeout = 45 if data is not None else 15
    for i in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.status, json.loads(r.read() or "null")
        except urllib.error.HTTPError as e:
            return e.code, (e.read().decode()[:400])
        except urllib.error.URLError:
            if i == attempts - 1:
                raise
            time.sleep(2 * (i + 1))


def load_config(path):
    try:
        return json.load(open(path))
    except Exception as e:
        sys.exit(f"cannot read config {path}: {e}")


def derive(cfg, tz, holidays, gh_n=0, ado_n=0):
    """Fold config.json into the flat dict build_plan / summary expect."""
    proj = {k: v["project_id"] for k, v in cfg["projects"].items()}
    # The Azure DevOps commits/pushes all bucket into one project (configurable); its note,
    # if any, is stamped on those entries. Both are config-driven so no project name is baked in.
    ado_bucket = cfg.get("azure_devops", {}).get("project_bucket", "Work")
    return {
        "target": float(cfg.get("daily_target_hours", 9.0)),
        "work_start": float(cfg.get("work_hours", {}).get("start", 9)),
        "work_end": float(cfg.get("work_hours", {}).get("end", 17)),
        "gap_cap": float(cfg.get("timeline", {}).get("gap_cap_min", 90)),
        "lead_in": float(cfg.get("timeline", {}).get("lead_in_min", 45)),
        "anchor": parse_ampm(cfg.get("anchor_start", "9:00am")),
        "tz": tz,
        "proj": proj,
        "mtask": {k: v["meeting_task"] for k, v in cfg["projects"].items()},
        "dtask": {k: v["dev_task"] for k, v in cfg["projects"].items()},
        "ado_bucket": ado_bucket,
        "ado_note": cfg["projects"].get(ado_bucket, {}).get("note", ""),
        "user": cfg["harvest"]["user_id"],
        "order": cfg.get("dev_order", list(proj.keys())),
        "social_kw": tuple(k.lower() for k in cfg.get("social_keywords", [])),
        "ooo_kw": tuple(
            k.lower() for k in cfg.get("ooo_keywords", ["ooo", "vacation", "pto", "out of office", "day off"])
        ),
        "long_event_h": float(cfg.get("long_event_hours", 5.0)),
        "social_day_h": float(cfg.get("social_day_hours", 4.5)),
        "meeting_rules": cfg.get("meeting_rules", []),
        "meeting_default": cfg.get("meeting_default_project", "Internal"),
        "scope_rules": cfg["github"].get("scope_rules", []),
        "scope_default": cfg["github"].get("scope_default", "Internal"),
        "holidays": holidays,
        "gh_n": gh_n,
        "ado_n": ado_n,
    }


def write_summary(obj):
    try:
        pth = os.path.join(
            os.environ.get("HARVEST_DATA_DIR", os.path.dirname(os.path.abspath(__file__))),
            "logs",
            "summary.json",
        )
        os.makedirs(os.path.dirname(pth), exist_ok=True)
        open(pth, "w").write(json.dumps(obj, indent=2))
    except Exception:
        pass


def emit(state, title, subtitle, message):
    print(f"SUMMARY\t{state}\t{title}\t{subtitle}\t{message}")


def main():
    cfg_path = os.environ.get("CONFIG_PATH") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
    CFG = load_config(cfg_path)

    def env(k):
        v = os.environ.get(k)
        if not v:
            sys.exit(f"missing env {k}")
        return v

    HACC = env("HARVEST_ACCOUNT_ID")
    HTOK = env("HARVEST_ACCESS_TOKEN")
    ASURL = env("APPS_SCRIPT_URL")
    ASSEC = env("APPS_SCRIPT_SECRET")
    GHTOK = env("GITHUB_TOKEN")
    DRY = os.environ.get("DRY_RUN", "1") != "0"

    try:
        from zoneinfo import ZoneInfo

        VAN = ZoneInfo(CFG.get("timezone", "America/Vancouver"))
    except Exception:
        VAN = datetime.timezone(datetime.timedelta(hours=-7))

    today = tovan(datetime.datetime.now(datetime.timezone.utc), VAN).date()
    if os.environ.get("WEEK_START"):
        mon = datetime.date.fromisoformat(os.environ["WEEK_START"])
    else:
        mon = today - datetime.timedelta(days=today.weekday())
    days = select_days(mon, today)
    if not days:
        print(f"Target week ({mon}) hasn't started yet — nothing to fill.")
        return 0
    fri = days[-1]
    NAMES = {d: d.strftime("%a %Y-%m-%d") for d in days}

    _holreg = CFG.get("holidays", {}).get("region", "")
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from discover import gen_holidays as _genhol

        _hol = set(_genhol(_holreg, {mon.year, fri.year}))
    except Exception:
        _hol = set()
    HOLIDAYS = set(CFG.get("holidays", {}).get("dates") or []) | _hol

    flags = []
    cfg = derive(CFG, VAN, HOLIDAYS)
    USER = cfg["user"]
    HHEAD = {
        "Authorization": f"Bearer {HTOK}",
        "Harvest-Account-Id": HACC,
        "User-Agent": CFG["harvest"].get("user_agent", "harvest-fill"),
    }

    cu = (
        ASURL
        + "?"
        + urllib.parse.urlencode(
            {
                "secret": ASSEC,
                "action": "events",
                "start": mon.isoformat(),
                "end": (fri + datetime.timedelta(1)).isoformat(),
            }
        )
    )
    st, cal = http(cu)
    if st != 200 or not isinstance(cal, dict):
        sys.exit(f"calendar fetch failed: {st} {cal}")
    meet, off, social_h = classify_calendar(
        cal["events"],
        days,
        tz=VAN,
        social_kw=cfg["social_kw"],
        long_event_h=cfg["long_event_h"],
        ooo_kw=cfg["ooo_kw"],
        meeting_rules=cfg["meeting_rules"],
        meeting_default=cfg["meeting_default"],
    )

    day_events = defaultdict(list)
    GH_LOGIN = CFG["github"]["login"]
    GH_ORGS = CFG["github"].get("orgs", [])
    EMAIL_HINTS = [h.lower() for h in CFG["github"].get("author_email_hints", [])]

    def gh_graphql(query, vars):
        _st, r = http(
            f"{GH_API_BASE}/graphql",
            {"Authorization": f"bearer {GHTOK}", "User-Agent": "harvest-fill"},
            {"query": query, "variables": vars},
        )
        return r

    gh_n = 0
    for org in GH_ORGS:
        r = gh_graphql(
            """query($q:String!){search(query:$q,type:ISSUE,first:100){nodes{... on PullRequest{
      headRefName commits(last:100){nodes{commit{oid authoredDate messageHeadline author{email user{login}}}}}}}}}""",
            {"q": f"org:{org} author:{GH_LOGIN} type:pr updated:>={(mon - datetime.timedelta(4)).isoformat()}"},
        )
        seen = {}
        for nd in r.get("data", {}).get("search", {}).get("nodes") or []:
            if not nd:
                continue
            br = nd.get("headRefName") or ""
            for c in nd["commits"]["nodes"]:
                cm = c["commit"]
                if gh_mine(cm, GH_LOGIN, EMAIL_HINTS):
                    seen[cm["oid"]] = (br, cm["messageHeadline"], cm["authoredDate"])
        for oid, (br, msg, date) in seen.items():
            dd = vday(date, VAN)
            if mon <= dd <= fri:
                day_events[dd].append((vdt(date, VAN), scope_of(msg, br, cfg["scope_rules"], cfg["scope_default"])))
                gh_n += 1

    ado = CFG.get("azure_devops", {})
    pat = os.environ.get("ADO_PAT")
    if ado.get("enabled", True) and pat:
        org = ado.get("org")
        proj = ado.get("project")
        author = ado.get("author")
        repos = ado.get("repos", [])
        bucket = ado.get("project_bucket", "Work")
        if org and proj and author and repos:
            hdr = {
                "Authorization": "Basic " + base64.b64encode((":" + pat).encode()).decode(),
                "User-Agent": "harvest-fill",
            }
            base = f"{ADO_API_BASE}/{org}/{proj}/_apis/git/repositories"
            seen_ids = set()

            def add(dt_iso, cid):
                if not dt_iso or (cid and cid in seen_ids):
                    return
                if cid:
                    seen_ids.add(cid)
                dd = vday(dt_iso, VAN)
                if mon <= dd <= fri:
                    day_events[dd].append((vdt(dt_iso, VAN), bucket))

            frm, to = mon.isoformat(), (fri + datetime.timedelta(1)).isoformat()

            # Each of these does one HTTP call and returns raw (date, commitId) tuples (or, for
            # the push list, the pushes to expand). They touch no shared state, so they're safe
            # to run concurrently; add() — which dedups and buckets by day — is applied serially
            # afterwards. This replaces a fully sequential per-repo, per-push walk (up to ~80
            # push-detail round-trips per repo) that dominated the engine's wall-time.
            def fetch_commits(repo):
                try:
                    st, r = http(
                        f"{base}/{repo}/commits?searchCriteria.author={urllib.parse.quote(author)}"
                        f"&searchCriteria.fromDate={frm}&searchCriteria.toDate={to}&api-version=7.1",
                        hdr,
                    )
                    if st == 200 and isinstance(r, dict):
                        return [((c.get("author") or {}).get("date"), c.get("commitId")) for c in r.get("value", [])]
                except Exception:
                    pass
                return []

            def fetch_push_ids(repo):
                try:
                    st, r = http(
                        f"{base}/{repo}/pushes?searchCriteria.fromDate={frm}"
                        f"&searchCriteria.toDate={to}&$top=200&api-version=7.1",
                        hdr,
                    )
                    pushes = r.get("value", []) if (st == 200 and isinstance(r, dict)) else []
                    mine = [
                        p for p in pushes if (p.get("pushedBy") or {}).get("uniqueName", "").lower() == author.lower()
                    ][:80]
                    return [(repo, p["pushId"]) for p in mine]
                except Exception:
                    return []

            def fetch_push_detail(repo_push):
                repo, push_id = repo_push
                try:
                    st, pr = http(f"{base}/{repo}/pushes/{push_id}?api-version=7.1", hdr)
                    if st == 200 and isinstance(pr, dict):
                        return [((c.get("author") or {}).get("date"), c.get("commitId")) for c in pr.get("commits", [])]
                except Exception:
                    pass
                return []

            tuples = []
            with ThreadPoolExecutor(max_workers=8) as ex:
                commit_futs = [ex.submit(fetch_commits, repo) for repo in repos]
                pushid_futs = [ex.submit(fetch_push_ids, repo) for repo in repos]
                for f in commit_futs:
                    tuples.extend(f.result())
                push_ids = []
                for f in pushid_futs:
                    push_ids.extend(f.result())
                for f in [ex.submit(fetch_push_detail, rp) for rp in push_ids]:
                    tuples.extend(f.result())
            for dt_iso, cid in tuples:
                add(dt_iso, cid)

    ado_n = sum(1 for d in day_events for (dt, p) in day_events[d] if p == ado.get("project_bucket", "Work"))
    flags.append(
        f"per-day timeline split — GitHub {gh_n} commits, Azure DevOps {ado_n} commits/pushes "
        f"(work-hours {fmt(int(round(cfg['work_start'] * 60)))}–{fmt(int(round(cfg['work_end'] * 60)))})"
    )
    cfg["gh_n"] = gh_n
    cfg["ado_n"] = ado_n

    week_mins = defaultdict(float)
    for d in days:
        for p, m in attribute(
            day_events.get(d, []),
            d,
            work_start=cfg["work_start"],
            work_end=cfg["work_end"],
            tz=VAN,
            lead_in=cfg["lead_in"],
            gap_cap=cfg["gap_cap"],
        ).items():
            week_mins[p] += m

    plan, posts, issues = build_plan(days, meet, off, social_h, day_events, week_mins, cfg=cfg)

    print(
        f"\n{'=' * 70}\nHarvest weekly fill — {mon} … {fri}  ({CFG.get('timezone')})  {'[DRY-RUN]' if DRY else '[WRITE]'}"
    )
    for d, kind, entries in plan:
        if kind != "work":
            print(f"  {NAMES[d]}: {kind.upper()} — no entries")
            continue
        tot = sum(e[3] for e in entries)
        print(f"  {NAMES[d]}: {tot:.2f}h — " + ", ".join(f"{p} {kind2} {h}" for p, _, kind2, h, _, _ in entries))
    print(f"total entries: {len(posts)}")
    if flags:
        print("FLAGS:\n  " + "\n  ".join(flags))

    _wl = week_label(mon, fri)
    _worked = [d for d, k, e in plan if k == "work"]
    _blanks = [(d, k) for d, k, e in plan if k != "work"]
    _ph = defaultdict(float)
    for _d, _k, _e in plan:
        if _k == "work":
            for _p, _t, _kn, _h, _a, _b in _e:
                _ph[_p] += _h
    _totalh = round(sum(_ph.values()), 2)
    _brk = " · ".join(f"{p} {round(h, 1)}h" for p, h in sorted(_ph.items(), key=lambda x: -x[1])) or "—"
    _nm = {"holiday": "holiday", "off": "OOO", "skip": "quiet", "social": "event", "overbooked": "overbooked"}
    _bl = (" · " + ", ".join(f"{d.strftime('%a')} {_nm.get(k, k)}" for d, k in _blanks)) if _blanks else ""

    print("DETAIL_BEGIN")
    print(f"{_wl} · {_totalh}h across {len(_worked)} day{'s' if len(_worked) != 1 else ''}")
    for d, kind, entries in plan:
        dn = d.strftime("%a %b %-d")
        if kind != "work":
            lab = {
                "holiday": "holiday",
                "off": "time off",
                "skip": "no activity",
                "social": "company / social event",
                "overbooked": "meetings exceed target — needs review",
            }.get(kind, kind)
            print(f"\n{dn}   —  {lab}, skipped")
            continue
        tot = sum(e[3] for e in entries)
        print(f"\n{dn}   ({tot:.2f}h)")
        for p, task, knd, h, a, b in entries:
            print(
                f"   {fmt(a)}–{fmt(b)}   ·   {p} {'Development' if knd == 'dev' else ('Internal meetings' if p == 'Internal' else 'Client Meetings')}   ·   {h}h"
            )
    print("DETAIL_END")

    st, ex = http(f"{HARVEST_API_BASE}/v2/time_entries?user_id={USER}&from={mon}&to={fri}", HHEAD)
    n_ex = ex.get("total_entries") if isinstance(ex, dict) else "?"
    print(f"\ndedup pre-flight: {n_ex} existing entries in window")
    if n_ex not in (0, None) and os.environ.get("SKIP_DEDUP") != "1":
        emit(
            "dedup",
            "Harvest · Already filled",
            f"{_wl} left untouched",
            f"{n_ex} entries already there — nothing written",
        )
        write_summary(
            summary_json(plan, mon, fri, flags, issues, "dedup", f"{n_ex} entries already there — nothing written")
        )
        print("ABORT: entries already exist for this window — not double-booking.")
        return 0
    if os.environ.get("SKIP_DEDUP") == "1":
        print("SKIP_DEDUP=1 — dedup override (use only when you've verified the window is empty)")

    if DRY:
        emit("dryrun", "Harvest · Dry run", f"{_wl} · would log {_totalh}h", _brk + _bl)
        write_summary(summary_json(plan, mon, fri, flags, issues, "dryrun", today=today))
        print("\nDRY-RUN — no writes performed.")
        return 0

    created = []
    for p in posts:
        st, r = http(f"{HARVEST_API_BASE}/v2/time_entries", HHEAD, p)
        if (
            st not in (200, 201)
            or r.get("is_running")
            or abs(
                r.get("hours", 0)
                - (
                    (
                        datetime.datetime.strptime(p["ended_time"], "%I:%M%p")
                        - datetime.datetime.strptime(p["started_time"], "%I:%M%p")
                    ).seconds
                    / 3600
                )
            )
            > 0.01
        ):
            emit(
                "fail",
                "Harvest · Run failed",
                "couldn't write the week",
                f"stopped on {p['spent_date']} — see latest.log",
            )
            write_summary(summary_json(plan, mon, fri, flags, issues, "fail", "stopped mid-write — see latest.log"))
            print(f"WRITE FAIL on {p['spent_date']} {p['started_time']}-{p['ended_time']}: {st} {r}")
            print("Stopping. Created so far:", created)
            return 1
        created.append(r["id"])
    print(f"\nwrote {len(created)} entries: {created}")
    st, ver = http(f"{HARVEST_API_BASE}/v2/time_entries?user_id={USER}&from={mon}&to={fri}", HHEAD)
    byday = {}
    ok = True
    for te in ver.get("time_entries", []):
        if te.get("is_running"):
            ok = False
            print("VERIFY FAIL: running timer", te["id"])
        byday[te["spent_date"]] = byday.get(te["spent_date"], 0) + te["hours"]
    for d, kind, entries in plan:
        dn = d.strftime("%a %b %-d")
        if kind == "work":
            s = round(byday.get(d.isoformat(), 0), 2)
            if abs(s - cfg["target"]) > 0.01:
                ok = False
                issues.append(f"{dn}: recorded {s}h but expected {cfg['target']:g}h")
                print(f"VERIFY FAIL: {d} sums to {s}h, expected {cfg['target']:g}")
        else:
            if byday.get(d.isoformat()):
                ok = False
                issues.append(f"{dn}: should be blank ({kind}) but has entries")
                print(f"VERIFY FAIL: {d} is {kind} but has entries")
    print("VERIFY:", "PASS ✅" if ok else "FAIL ❌")
    if ok:
        sub = f"{_wl} · {len(_worked)} days · {_totalh}h" + (f" · {len(issues)} to review" if issues else "")
        emit("written", "Harvest · Week logged", sub, _brk + _bl)
        write_summary(summary_json(plan, mon, fri, flags, issues, "written"))
    else:
        emit("fail", "Harvest · Needs a look", "written but verification failed", "; ".join(issues) or "see latest.log")
        write_summary(summary_json(plan, mon, fri, flags, issues, "fail", "; ".join(issues) or "see latest.log"))
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
