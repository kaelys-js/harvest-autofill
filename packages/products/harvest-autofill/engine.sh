#!/bin/bash
# Shared engine runner (menu-bar app preview + Log-now, and the Friday launchd job).
# Arg1: dry (default) | write | auto.   Arg2: optional WEEK_START=YYYY-MM-DD.
#   auto  = launchd Friday run; honors the config `auto_record` flag then behaves like write.
#   write = explicit (app "Log now"), always writes.
# Scripts live next to this file (app Resources). Data (config + secrets + logs) is per-user
# under Application Support, so the app can live in /Applications and anyone can use it.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# HARVEST_DATA_DIR override (isolated testing/demo); defaults to the real per-user path.
DATA_DIR="${HARVEST_DATA_DIR:-$HOME/Library/Application Support/HarvestAutoFill}"
export HARVEST_DATA_DIR="$DATA_DIR"
# Bundled relocatable Python (ships in the app); fall back to a system python3 if absent.
PY="$SCRIPT_DIR/python/bin/python3"; [ -x "$PY" ] || PY="python3"
# Never write .pyc into the (code-signed, possibly read-only) app bundle — it would break the seal.
export PYTHONDONTWRITEBYTECODE=1
export CONFIG_PATH="$DATA_DIR/config.json"
# Tool discovery: cover Homebrew (arm+intel), system, and mise. Requires python3 + gh (+ optional az).
export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
mkdir -p "$DATA_DIR/logs"
MODE="${1:-dry}"
if [ "$MODE" = "auto" ]; then
  if grep -Eq '"auto_record"[[:space:]]*:[[:space:]]*false' "$CONFIG_PATH" 2>/dev/null; then
    echo "auto-record disabled — nothing written"; exit 0
  fi
  MODE="write"
fi
set -a
[ -f "$DATA_DIR/harvest.env" ]  && . "$DATA_DIR/harvest.env"
[ -f "$DATA_DIR/calendar.env" ] && . "$DATA_DIR/calendar.env"
[ -f "$DATA_DIR/ado.env" ]      && . "$DATA_DIR/ado.env"
[ -f "$DATA_DIR/github.env" ]   && . "$DATA_DIR/github.env"
set +a
# GitHub token: a pasted token (github.env) takes precedence; else fall back to the gh CLI if present.
export GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null)}"
export DRY_RUN=$([ "$MODE" = "write" ] && echo 0 || echo 1)
[ -n "$2" ] && export WEEK_START="$2"
if [ "$MODE" = "write" ]; then
  for i in $(seq 1 18); do
    code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' https://api.harvestapp.com/ 2>/dev/null || echo 000)
    [ "$code" != "000" ] && break; sleep 10
  done
fi
"$PY" "$SCRIPT_DIR/harvest_weekly.py" > "$DATA_DIR/logs/last.log" 2>&1
code=$?
cp "$DATA_DIR/logs/last.log" "$DATA_DIR/logs/latest.log"
exit $code
