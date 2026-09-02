#!/bin/bash
# Runs the website Playwright suite (E2E + visual regression) inside the pinned Playwright
# container so browser rendering is byte-identical on every machine and in CI. Install + build
# + test all happen in the container; an anonymous volume keeps the container's Linux
# node_modules from overwriting the host's. Pass --update to regenerate the -linux baselines.
#
#   ./run-web-e2e.sh            compare against committed baselines
#   ./run-web-e2e.sh --update   regenerate baselines
set -euo pipefail
cd "$(dirname "$0")"

IMG="mcr.microsoft.com/playwright:v1.62.1-noble"
UPDATE=""
[ "${1:-}" = "--update" ] && UPDATE="--update-snapshots"

# If already inside the container (CI runs the job in the image), run directly.
if [ -f /.dockerenv ] || [ -n "${PLAYWRIGHT_IN_CONTAINER:-}" ]; then
  corepack enable >/dev/null 2>&1 || true
  corepack prepare pnpm@11.24.0 --activate >/dev/null 2>&1 || true
  # The Playwright image ships its own Node (matched to the bundled browsers), which is not
  # the mise-pinned engines.node. That is correct for a test runner, so relax pnpm's strict
  # engine check here only — dev + CI installs still run on the pinned Node and enforce it.
  pnpm --config.engine-strict=false install --frozen-lockfile
  # The download button's version is baked in at build time from the release tag. The container
  # has no .git, so pin a fixed tag here to keep the version-bearing snapshots deterministic.
  ASTRO_BASE=/ GITHUB_REF_NAME=v0.0.0 pnpm --config.engine-strict=false build
  exec node_modules/.bin/playwright test $UPDATE
fi

# Anonymous volumes keep the container's Linux node_modules and pnpm store from leaking into
# (or overwriting) the host tree; dist/ and the e2e snapshots still persist via the bind mount.
exec docker run --rm --ipc=host \
  -e PLAYWRIGHT_IN_CONTAINER=1 -e PNPM_HOME=/tmp/pnpm -e npm_config_store_dir=/tmp/pnpm-store \
  -v "$PWD:/work" -v /work/node_modules -v /work/.pnpm-store \
  -w /work "$IMG" bash ./run-web-e2e.sh ${UPDATE:+--update}
