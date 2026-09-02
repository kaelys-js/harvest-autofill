#!/usr/bin/env python3
"""Discovery helper — auto-populate config from a user's own Harvest + GitHub accounts.
Preferences calls this on first run so a new user doesn't hand-enter IDs. Pure stdlib.
Reads HARVEST_ACCOUNT_ID / HARVEST_ACCESS_TOKEN / GITHUB_TOKEN from the environment.
Prints a JSON blob: {harvest:{user_id,user_agent}, harvest_projects:{name:{...}}, github:{login}}.
"""

import datetime
import json
import os
import urllib.request


# stdlib statutory-holiday generator (no external deps)
def _easter(y):
    a = y % 19
    b = y // 100
    c = y % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7  # noqa: E741 — canonical computus variable name
    m = (a + 11 * h + 22 * l) // 451
    mo = (h + l - 7 * m + 114) // 31
    da = ((h + l - 7 * m + 114) % 31) + 1
    return datetime.date(y, mo, da)


def _nth_wd(y, mo, wd, n):
    d = datetime.date(y, mo, 1)
    return d + datetime.timedelta(((wd - d.weekday()) % 7) + 7 * (n - 1))


def _mon_before(y, mo, day):
    d = datetime.date(y, mo, day - 1)
    return d - datetime.timedelta(d.weekday() % 7)


def _last_wd(y, mo, wd):
    import calendar

    d = datetime.date(y, mo, calendar.monthrange(y, mo)[1])
    return d - datetime.timedelta((d.weekday() - wd) % 7)


SUPPORTED_REGIONS = ["CA-BC", "CA-ON", "CA-AB", "CA-QC", "US-Federal"]


def gen_holidays(region, years):
    """Statutory holidays for a supported region across `years`."""
    r = region.upper()
    out = set()
    for y in sorted(set(years)):
        ny = f"{y}-01-01"
        canada = f"{y}-07-01"
        xmas = f"{y}-12-25"
        rem = f"{y}-11-11"
        gf = (_easter(y) - datetime.timedelta(2)).isoformat()
        family = _nth_wd(y, 2, 0, 3).isoformat()
        victoria = _mon_before(y, 5, 25).isoformat()
        labour = _nth_wd(y, 9, 0, 1).isoformat()
        thanks_ca = _nth_wd(y, 10, 0, 2).isoformat()
        if r == "CA-BC":
            out |= {
                ny,
                family,
                gf,
                victoria,
                canada,
                _nth_wd(y, 8, 0, 1).isoformat(),
                labour,
                f"{y}-09-30",
                thanks_ca,
                rem,
                xmas,
            }
        elif r == "CA-ON":
            out |= {
                ny,
                family,
                gf,
                victoria,
                canada,
                labour,
                thanks_ca,
                xmas,
                f"{y}-12-26",
            }
        elif r == "CA-AB":
            out |= {
                ny,
                family,
                gf,
                victoria,
                canada,
                _nth_wd(y, 8, 0, 1).isoformat(),
                labour,
                thanks_ca,
                rem,
                xmas,
            }
        elif r == "CA-QC":
            out |= {ny, gf, victoria, f"{y}-06-24", canada, labour, thanks_ca, xmas}
        elif r == "US-FEDERAL":
            out |= {
                ny,
                _nth_wd(y, 1, 0, 3).isoformat(),
                _nth_wd(y, 2, 0, 3).isoformat(),
                _last_wd(y, 5, 0).isoformat(),
                f"{y}-06-19",
                f"{y}-07-04",
                labour,
                _nth_wd(y, 10, 0, 2).isoformat(),
                rem,
                _nth_wd(y, 11, 3, 4).isoformat(),
                xmas,
            }
    return sorted(out)


def get(url, hdr):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=hdr), timeout=30))


def discover():
    out = {}
    hacc = os.environ.get("HARVEST_ACCOUNT_ID")
    htok = os.environ.get("HARVEST_ACCESS_TOKEN")
    if hacc and htok:
        H = {
            "Authorization": f"Bearer {htok}",
            "Harvest-Account-Id": hacc,
            "User-Agent": "harvest-discover",
        }
        me = get("https://api.harvestapp.com/v2/users/me", H)
        _name = f"{me.get('first_name', '')} {me.get('last_name', '')}".strip()
        out["harvest"] = {
            "user_id": me["id"],
            "name": _name or me.get("email", ""),
            "user_agent": f"harvest-fill ({me.get('email', '')})",
        }
        pa = get("https://api.harvestapp.com/v2/users/me/project_assignments?per_page=100", H)
        projects = {}
        for a in pa.get("project_assignments", []):
            p = a["project"]
            tasks = {t["task"]["name"].lower(): t["task"]["id"] for t in a["task_assignments"]}
            projects[p["name"]] = {
                "project_id": p["id"],
                "client": a["client"]["name"],
                "meeting_task": tasks.get("client meetings") or tasks.get("internal meetings"),
                "dev_task": tasks.get("development"),
                "all_tasks": tasks,
            }
        out["harvest_projects"] = projects
    ght = os.environ.get("GITHUB_TOKEN")
    if ght:
        H = {"Authorization": f"bearer {ght}", "User-Agent": "harvest-discover"}
        try:
            u = get("https://api.github.com/user", H)
            orgs = [o["login"] for o in get("https://api.github.com/user/orgs", H)]
            out["github"] = {
                "login": u["login"],
                "name": u.get("name"),
                "orgs": sorted(set(orgs)),
            }
        except Exception as e:
            out["github"] = {"error": str(e)}
    # Azure DevOps: with a PAT + org we can list the org's projects (for the Project dropdown);
    # with a project too, the repos in it. A Code:Read PAT can't reach profile/accounts, so the
    # org and author aren't discoverable — those stay manual.
    pat, org, proj = (
        os.environ.get("ADO_PAT"),
        os.environ.get("ADO_ORG"),
        os.environ.get("ADO_PROJECT"),
    )
    if pat and org:
        import base64

        ah = {
            "Authorization": "Basic " + base64.b64encode((":" + pat).encode()).decode(),
            "User-Agent": "harvest-discover",
        }
        ado = {}
        try:
            pr = get(f"https://dev.azure.com/{org}/_apis/projects?api-version=7.1", ah)
            ado["projects"] = sorted(p["name"] for p in pr.get("value", []))
        except Exception as e:
            ado["error"] = str(e)
        if proj:
            try:
                d = get(f"https://dev.azure.com/{org}/{proj}/_apis/git/repositories?api-version=7.1", ah)
                ado["repos"] = sorted(r["name"] for r in d.get("value", []))
            except Exception:
                pass
        out["azure_devops"] = ado
    return out


if __name__ == "__main__":
    print(json.dumps(discover(), indent=2))
