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
"""
import os, sys, json, re, time, datetime, urllib.request, urllib.parse, urllib.error, base64
from collections import defaultdict

# ---------- config ----------
CFG_PATH = os.environ.get("CONFIG_PATH") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
try:
    CFG = json.load(open(CFG_PATH))
except Exception as e:
    sys.exit(f"cannot read config {CFG_PATH}: {e}")

def env(k):
    v = os.environ.get(k)
    if not v: sys.exit(f"missing env {k}")
    return v
HACC=env("HARVEST_ACCOUNT_ID"); HTOK=env("HARVEST_ACCESS_TOKEN")
ASURL=env("APPS_SCRIPT_URL"); ASSEC=env("APPS_SCRIPT_SECRET"); GHTOK=env("GITHUB_TOKEN")
DRY = os.environ.get("DRY_RUN","1") != "0"

TARGET      = float(CFG.get("daily_target_hours", 9.0))
WORK_START  = int(CFG.get("work_hours",{}).get("start",9))
WORK_END    = int(CFG.get("work_hours",{}).get("end",17))
GAP_CAP     = float(CFG.get("timeline",{}).get("gap_cap_min",90))
LEAD_IN     = float(CFG.get("timeline",{}).get("lead_in_min",45))

try:
    from zoneinfo import ZoneInfo
    VAN = ZoneInfo(CFG.get("timezone","America/Vancouver"))
except Exception:
    VAN = datetime.timezone(datetime.timedelta(hours=-7))
def tovan(dtutc): return dtutc.astimezone(VAN)

def http(url, headers=None, data=None, method=None):
    h=headers or {}; body=None
    if data is not None:
        body=json.dumps(data).encode(); h.setdefault("Content-Type","application/json")
    req=urllib.request.Request(url, data=body, headers=h, method=method or ("POST" if data is not None else "GET"))
    attempts = 1 if data is not None else 5   # NEVER retry writes (a lost response could double-post)
    for i in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=45) as r: return r.status, json.loads(r.read() or "null")
        except urllib.error.HTTPError as e:
            return e.code, (e.read().decode()[:400])
        except urllib.error.URLError:
            if i==attempts-1: raise
            time.sleep(2*(i+1))

def parse_iso(s): return datetime.datetime.fromisoformat(s.replace("Z","+00:00"))
def vday(s): return tovan(parse_iso(s)).date()
def vdt(s):  return tovan(parse_iso(s))
def q(x): return round(x*4)/4
def parse_ampm(s):
    m=re.match(r'(\d+):(\d+)\s*(am|pm)', s.strip().lower()); h=int(m.group(1))%12
    return (h + (12 if m.group(3)=="pm" else 0))*60 + int(m.group(2))
ANCHOR = parse_ampm(CFG.get("anchor_start","9:00am"))

# ---------- target week ----------
if os.environ.get("WEEK_START"):
    mon=datetime.date.fromisoformat(os.environ["WEEK_START"])
else:
    today=tovan(datetime.datetime.now(datetime.timezone.utc)).date()
    mon=today - datetime.timedelta(days=today.weekday())
days=[mon+datetime.timedelta(d) for d in range(5)]
fri=days[-1]
NAMES={d:d.strftime("%a %Y-%m-%d") for d in days}

# ---------- config-derived tables ----------
_holreg=CFG.get("holidays",{}).get("region","")
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from discover import gen_holidays as _genhol
    _hol=set(_genhol(_holreg, {mon.year, fri.year}))
except Exception: _hol=set()
HOLIDAYS=set(CFG.get("holidays",{}).get("dates") or []) | _hol   # region-computed, plus any explicit overrides
PROJ ={k:v["project_id"]   for k,v in CFG["projects"].items()}
MTASK={k:v["meeting_task"] for k,v in CFG["projects"].items()}
DTASK={k:v["dev_task"]     for k,v in CFG["projects"].items()}
WHEATON_NOTE = CFG["projects"].get("Wheaton",{}).get("note","")
USER = CFG["harvest"]["user_id"]
HHEAD={"Authorization":f"Bearer {HTOK}","Harvest-Account-Id":HACC,
       "User-Agent":CFG["harvest"].get("user_agent","harvest-fill")}
ORDER=CFG.get("dev_order", list(PROJ.keys()))
SOCIAL=tuple(k.lower() for k in CFG.get("social_keywords",[]))
OOO=tuple(k.lower() for k in CFG.get("ooo_keywords",["ooo","vacation","pto","out of office","day off"]))
LONG_EVENT_H=float(CFG.get("long_event_hours",5.0))
SOCIAL_DAY_H=float(CFG.get("social_day_hours",4.5))
flags=[]

def meeting_project(t):
    t=t.lower()
    for rule in CFG.get("meeting_rules",[]):
        if any(k.lower() in t for k in rule["keywords"]): return rule["project"]
    return CFG.get("meeting_default_project","Internal")
def scope_of(msg,br):
    m=re.match(r'^[a-z]+\(([^)]+)\)!?:', msg); s=(m.group(1).lower() if m else "")
    blob=s+" "+br.lower()+" "+msg.lower()
    for rule in CFG["github"].get("scope_rules",[]):
        if s.startswith(rule["keywords"][0]) or any(k.lower() in blob for k in rule["keywords"]): return rule["project"]
    return CFG["github"].get("scope_default","Internal")

# ---------- calendar ----------
cu=ASURL+"?"+urllib.parse.urlencode({"secret":ASSEC,"action":"events",
    "start":mon.isoformat(),"end":(fri+datetime.timedelta(1)).isoformat()})
st,cal=http(cu)
if st!=200 or not isinstance(cal,dict): sys.exit(f"calendar fetch failed: {st} {cal}")
def is_social(e,dur):
    t=e["title"].lower()
    if any(k in t for k in SOCIAL): return True
    if (not e["allDay"]) and dur>LONG_EVENT_H: return True   # long block/offsite — catches unnamed company events
    return False
def counts(e,dur):
    if e["allDay"] or e["status"]=="NO": return False
    if "optional" in e["title"].lower(): return False
    if is_social(e,dur): return False
    return True
meet={d:{} for d in days}; off=set(); social_h={d:0.0 for d in days}
for e in cal["events"]:
    d=vday(e["start"])
    if d not in meet: continue
    dur=(parse_iso(e["end"])-parse_iso(e["start"])).total_seconds()/3600
    if e["allDay"] and any(k in e["title"].lower() for k in OOO): off.add(d)
    if e["status"]!="NO" and not e["allDay"] and is_social(e,dur): social_h[d]+=dur
    if counts(e,dur):
        p=meeting_project(e["title"]); meet[d][p]=meet[d].get(p,0.0)+dur

# ---------- commit TIMELINE events: (datetime, project) per day ----------
# GitHub: your PR commits (authored, so rebased ancestors keep their real date). Azure DevOps:
# your merged commits + your pushes' commits (feature-branch, real-time), deduped.
day_events=defaultdict(list)    # Vancouver-date -> [(datetime_van, project)]
GH_LOGIN=CFG["github"]["login"]; GH_ORGS=CFG["github"].get("orgs",[]); EMAIL_HINTS=[h.lower() for h in CFG["github"].get("author_email_hints",[])]
def gh_mine(cm):
    u=(cm.get("author") or {}).get("user") or {}
    if u.get("login")==GH_LOGIN: return True
    em=((cm.get("author") or {}).get("email") or "").lower()
    return any(k in em for k in EMAIL_HINTS)
def gh_graphql(query,vars):
    st,r=http("https://api.github.com/graphql",
        {"Authorization":f"bearer {GHTOK}","User-Agent":"harvest-fill"},{"query":query,"variables":vars})
    return r
gh_n=0
for org in GH_ORGS:
    r=gh_graphql("""query($q:String!){search(query:$q,type:ISSUE,first:100){nodes{... on PullRequest{
      headRefName commits(last:100){nodes{commit{oid authoredDate messageHeadline author{email user{login}}}}}}}}}""",
      {"q":f"org:{org} author:{GH_LOGIN} type:pr updated:>={ (mon-datetime.timedelta(4)).isoformat() }"})
    seen={}
    for nd in (r.get("data",{}).get("search",{}).get("nodes") or []):
        if not nd: continue
        br=nd.get("headRefName") or ""
        for c in nd["commits"]["nodes"]:
            cm=c["commit"]
            if gh_mine(cm): seen[cm["oid"]]=(br,cm["messageHeadline"],cm["authoredDate"])
    for oid,(br,msg,date) in seen.items():
        dd=vday(date)
        if mon<=dd<=fri:
            day_events[dd].append((vdt(date), scope_of(msg,br))); gh_n+=1

# ---------- Azure DevOps: commits + pushes -> Wheaton events ----------
ado_n=0
def ado_events(a,b):
    global ado_n
    ado=CFG.get("azure_devops",{}); pat=os.environ.get("ADO_PAT")
    if not (ado.get("enabled",True) and pat): return
    org=ado.get("org"); proj=ado.get("project"); author=ado.get("author")
    repos=ado.get("repos",[]); bucket=ado.get("project_bucket","Wheaton")
    if not (org and proj and author and repos): return
    hdr={"Authorization":"Basic "+base64.b64encode((":"+pat).encode()).decode(),"User-Agent":"harvest-fill"}
    base=f"https://dev.azure.com/{org}/{proj}/_apis/git/repositories"
    seen_ids=set()
    def add(dt_iso, cid):
        if not dt_iso or (cid and cid in seen_ids): return
        if cid: seen_ids.add(cid)
        dd=vday(dt_iso)
        if a<=dd<=b:
            day_events[dd].append((vdt(dt_iso), bucket)); return True
    for repo in repos:
        # merged commits authored by me
        try:
            st,r=http(f"{base}/{repo}/commits?searchCriteria.author={urllib.parse.quote(author)}"
                      f"&searchCriteria.fromDate={a.isoformat()}&searchCriteria.toDate={(b+datetime.timedelta(1)).isoformat()}&api-version=7.1", hdr)
            if st==200 and isinstance(r,dict):
                for c in r.get("value",[]):
                    add((c.get("author") or {}).get("date"), c.get("commitId"))
        except Exception: pass
        # pushes by me -> their commits (feature-branch, real work times)
        try:
            st,r=http(f"{base}/{repo}/pushes?searchCriteria.fromDate={a.isoformat()}"
                      f"&searchCriteria.toDate={(b+datetime.timedelta(1)).isoformat()}&$top=200&api-version=7.1", hdr)
            pushes=(r.get("value",[]) if (st==200 and isinstance(r,dict)) else [])
            mine_pushes=[p for p in pushes if (p.get("pushedBy") or {}).get("uniqueName","").lower()==author.lower()][:80]
            for p in mine_pushes:
                st2,pr=http(f"{base}/{repo}/pushes/{p['pushId']}?api-version=7.1", hdr)
                if st2==200 and isinstance(pr,dict):
                    for c in pr.get("commits",[]):
                        add((c.get("author") or {}).get("date"), c.get("commitId"))
        except Exception: pass
    # recount ado events actually added this week
ado_events(mon,fri)
ado_n=sum(1 for d in day_events for (dt,p) in day_events[d] if p==CFG.get("azure_devops",{}).get("project_bucket","Wheaton"))
flags.append(f"per-day timeline split — GitHub {gh_n} commits, Azure DevOps {ado_n} commits/pushes (work-hours {WORK_START}:00–{WORK_END}:00)")

# ---------- timeline attribution ----------
def attribute(events, day):
    """Minutes of work per project on `day`, from commit timestamps inside work hours,
    crediting each capped inter-commit gap (+ a lead-in) to that commit's project."""
    w0=datetime.datetime.combine(day, datetime.time(WORK_START,0), VAN)
    w1=datetime.datetime.combine(day, datetime.time(WORK_END,59), VAN)
    evs=sorted([(dt,p) for dt,p in events if w0<=dt<=w1])
    t=defaultdict(float); prev=None
    for dt,p in evs:
        t[p]+= LEAD_IN if prev is None else min((dt-prev).total_seconds()/60, GAP_CAP)
        prev=dt
    return t
# week-level fallback (for a worked day with no in-hours commits): sum attributions across the week
week_mins=defaultdict(float)
for d in days:
    for p,m in attribute(day_events.get(d,[]), d).items(): week_mins[p]+=m
def split_props(budget, props):
    if budget<=0 or not props: return {}
    tot=sum(props.values())
    if tot<=0: return {"Wheaton":budget}
    raw={p:budget*props[p]/tot for p in props if props[p]>0}
    r={p:q(v) for p,v in raw.items()}
    drift=round(budget-sum(r.values()),2)
    if r: k=max(r,key=lambda p:raw[p]); r[k]=round(r[k]+drift,2)
    return {p:v for p,v in r.items() if v>0}

# ---------- allocate ----------
def fmt(mins):
    h,m=divmod(int(round(mins)),60); ap="am" if h<12 else "pm"; return f"{h%12 or 12}:{m:02d}{ap}"
posts=[]; plan=[]; issues=[]
for d in days:
    key=d.isoformat()
    if key in HOLIDAYS: plan.append((d,"holiday",None)); continue
    if d in off:        plan.append((d,"off",None)); continue
    if social_h[d]>=SOCIAL_DAY_H: plan.append((d,"social",None)); continue
    mt={p:q(h) for p,h in meet[d].items() if q(h)>0}
    mh=round(sum(mt.values()),2)
    if mh>TARGET:
        issues.append(f"{d.strftime('%a %b %-d')}: {mh}h of meetings exceed the {TARGET:g}h day — recorded nothing, add manually if real")
        plan.append((d,"overbooked",None)); continue
    worked = bool(mt) or gh_n>0 or ado_n>0
    if not worked: plan.append((d,"skip",None)); continue
    dev_budget=round(TARGET-mh,2)
    mins=attribute(day_events.get(d,[]), d)          # this day's in-work-hours timeline
    props=mins if mins else week_mins                # fallback to the week's mix, then residual
    dev=split_props(dev_budget, props)
    cur=ANCHOR; entries=[]
    for p in ORDER:
        if mt.get(p,0)>0:
            dur=mt[p]*60; entries.append((p,MTASK[p],"meeting",mt[p],cur,cur+dur)); cur+=dur
    for p in ORDER:
        if dev.get(p,0)>0:
            dur=dev[p]*60; entries.append((p,DTASK[p],"dev",dev[p],cur,cur+dur)); cur+=dur
    for p,task,kind,h,a,b in entries:
        posts.append({"user_id":USER,"project_id":PROJ[p],"task_id":task,"spent_date":key,
                      "started_time":fmt(a),"ended_time":fmt(b),
                      "notes":(WHEATON_NOTE if p=="Wheaton" else ("Client/Internal meetings (calendar)" if kind=="meeting" else "Development"))})
    plan.append((d,"work",entries))

# ---------- report plan ----------
print(f"\n{'='*70}\nHarvest weekly fill — {mon} … {fri}  ({CFG.get('timezone')})  {'[DRY-RUN]' if DRY else '[WRITE]'}")
for d,kind,entries in plan:
    if kind!="work": print(f"  {NAMES[d]}: {kind.upper()} — no entries"); continue
    tot=sum(e[3] for e in entries)
    print(f"  {NAMES[d]}: {tot:.2f}h — "+", ".join(f"{p} {kind2} {h}" for p,_,kind2,h,_,_ in entries))
print(f"total entries: {len(posts)}")
if flags: print("FLAGS:\n  "+"\n  ".join(flags))

# ---------- notification summary ----------
_ph=defaultdict(float)
for _d,_k,_e in plan:
    if _k=="work":
        for _p,_t,_kn,_h,_a,_b in _e: _ph[_p]+=_h
_worked=[d for d,k,e in plan if k=="work"]
_blanks=[(d,k) for d,k,e in plan if k!="work"]
_wl=f"{mon.strftime('%b')} {mon.day}–{fri.day}"
_totalh=round(sum(_ph.values()),2)
_brk=" · ".join(f"{p} {round(h,1)}h" for p,h in sorted(_ph.items(),key=lambda x:-x[1])) or "—"
_nm={"holiday":"holiday","off":"OOO","skip":"quiet","social":"event","overbooked":"overbooked"}
_bl=(" · "+", ".join(f"{d.strftime('%a')} {_nm.get(k,k)}" for d,k in _blanks)) if _blanks else ""
def emit(state,title,subtitle,message):
    print(f"SUMMARY\t{state}\t{title}\t{subtitle}\t{message}")

# ---------- exact per-entry breakdown (for the desktop popup) ----------
print("DETAIL_BEGIN")
print(f"{_wl} · {_totalh}h across {len(_worked)} day{'s' if len(_worked)!=1 else ''}")
for d,kind,entries in plan:
    dn=d.strftime('%a %b %-d')
    if kind!="work":
        lab={'holiday':'holiday','off':'time off','skip':'no activity','social':'company / social event','overbooked':'meetings exceed target — needs review'}.get(kind,kind)
        print(f"\n{dn}   —  {lab}, skipped"); continue
    tot=sum(e[3] for e in entries)
    print(f"\n{dn}   ({tot:.2f}h)")
    for p,task,knd,h,a,b in entries:
        print(f"   {fmt(a)}–{fmt(b)}   ·   {p} {'Development' if knd=='dev' else ('Internal meetings' if p=='Internal' else 'Client Meetings')}   ·   {h}h")
print("DETAIL_END")

# ---------- JSON payload for the native popup ----------
def _span(a,b):
    def nice(m): return fmt(m).replace("am"," AM").replace("pm"," PM")
    return f"{nice(a)}–{nice(b)}"
def plain_task(p,kind):
    return "Development" if kind!="meeting" else ("Internal meetings" if p=="Internal" else "Client Meetings")
_days_json=[]
for d,kind,entries in plan:
    dn=d.strftime('%a %b %-d')
    if kind!="work":
        note={"holiday":"holiday · skipped","off":"time off · skipped","skip":"no activity · skipped",
              "social":"company / social event · skipped","overbooked":"meetings exceed target · needs review"}.get(kind,kind)
        _days_json.append({"name":dn,"total":None,"note":note,"entries":[]})
    else:
        _days_json.append({"name":dn,"total":round(sum(e[3] for e in entries),2),"note":None,
            "entries":[{"span":_span(a,b),"project":p,"task":plain_task(p,knd),"hours":h} for p,task,knd,h,a,b in entries]})
def write_json(state,message=""):
    obj={"state":state,"week":_wl,"total":_totalh,"daysWorked":len(_worked),"days":_days_json,"flags":flags,"issues":issues,"message":message}
    try:
        pth=os.path.join(os.environ.get("HARVEST_DATA_DIR", os.path.dirname(os.path.abspath(__file__))),"logs","summary.json")
        os.makedirs(os.path.dirname(pth),exist_ok=True); open(pth,"w").write(json.dumps(obj,indent=2))
    except Exception: pass

# ---------- dedup pre-flight ----------
st,ex=http(f"https://api.harvestapp.com/v2/time_entries?user_id={USER}&from={mon}&to={fri}",HHEAD)
n_ex=ex.get("total_entries") if isinstance(ex,dict) else "?"
print(f"\ndedup pre-flight: {n_ex} existing entries in window")
if n_ex not in (0,None) and os.environ.get("SKIP_DEDUP")!="1":
    emit("dedup","Harvest · Already filled",f"{_wl} left untouched",f"{n_ex} entries already there — nothing written"); write_json("dedup",f"{n_ex} entries already there — nothing written")
    print("ABORT: entries already exist for this window — not double-booking."); sys.exit(0)
if os.environ.get("SKIP_DEDUP")=="1": print("SKIP_DEDUP=1 — dedup override (use only when you've verified the window is empty)")

if DRY:
    emit("dryrun","Harvest · Dry run",f"{_wl} · would log {_totalh}h",_brk+_bl); write_json("dryrun")
    print("\nDRY-RUN — no writes performed."); sys.exit(0)

# ---------- write + verify ----------
created=[]
for p in posts:
    st,r=http("https://api.harvestapp.com/v2/time_entries",HHEAD,p)
    if st not in (200,201) or r.get("is_running") or abs(r.get("hours",0)-((datetime.datetime.strptime(p['ended_time'],'%I:%M%p')-datetime.datetime.strptime(p['started_time'],'%I:%M%p')).seconds/3600))>0.01:
        emit("fail","Harvest · Run failed","couldn't write the week",f"stopped on {p['spent_date']} — see latest.log"); write_json("fail","stopped mid-write — see latest.log")
        print(f"WRITE FAIL on {p['spent_date']} {p['started_time']}-{p['ended_time']}: {st} {r}")
        print("Stopping. Created so far:",created); sys.exit(1)
    created.append(r["id"])
print(f"\nwrote {len(created)} entries: {created}")
st,ver=http(f"https://api.harvestapp.com/v2/time_entries?user_id={USER}&from={mon}&to={fri}",HHEAD)
byday={}; ok=True
for te in ver.get("time_entries",[]):
    if te.get("is_running"): ok=False; print("VERIFY FAIL: running timer",te["id"])
    byday[te["spent_date"]]=byday.get(te["spent_date"],0)+te["hours"]
for d,kind,entries in plan:
    dn=d.strftime('%a %b %-d')
    if kind=="work":
        s=round(byday.get(d.isoformat(),0),2)
        if abs(s-TARGET)>0.01: ok=False; issues.append(f"{dn}: recorded {s}h but expected {TARGET:g}h"); print(f"VERIFY FAIL: {d} sums to {s}h, expected {TARGET:g}")
    else:
        if byday.get(d.isoformat()): ok=False; issues.append(f"{dn}: should be blank ({kind}) but has entries"); print(f"VERIFY FAIL: {d} is {kind} but has entries")
print("VERIFY:", "PASS ✅" if ok else "FAIL ❌")
if ok:
    sub=f"{_wl} · {len(_worked)} days · {_totalh}h" + (f" · {len(issues)} to review" if issues else "")
    emit("written","Harvest · Week logged",sub,_brk+_bl); write_json("written")
else:
    emit("fail","Harvest · Needs a look","written but verification failed","; ".join(issues) or "see latest.log")
    write_json("fail","; ".join(issues) or "see latest.log")
