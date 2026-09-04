# AGENTS.md — engineering rules + orientation

> **What this file is.** The engineering rules every agent (human or AI) follows when
> doing code work in this repo. Read these first. Below the rules is a short orientation
> to the repo's layout, build, and release.

## 13 rules

These apply to every code task in this repo unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

### Rule 1 — Think before coding

State assumptions explicitly. If uncertain, ask rather than guess. Present multiple
interpretations when ambiguity exists. Push back when a simpler approach exists. Stop
when confused. Name what's unclear.

### Rule 2 — Simplicity first

Minimum code that solves the problem. Nothing speculative. No features beyond what was
asked. No abstractions for single-use code. Test: would a senior engineer say this is
overcomplicated? If yes, simplify.

### Rule 3 — Surgical changes

Touch only what you must. Clean up only your own mess. Don't "improve" adjacent code,
comments, or formatting. Don't refactor what isn't broken. Match existing style.

### Rule 4 — Goal-driven execution

Define success criteria. Loop until verified. Don't just follow steps — define success
and iterate. Strong success criteria let you loop independently.

### Rule 5 — Use the model only for judgment calls

Use the model for classification, drafting, summarization, extraction. Do NOT use it for
routing, retries, or deterministic transforms. If code can answer, code answers.

### Rule 6 — Surface cost, don't overrun silently

Keep inline work tight. If a task is ballooning, summarize and start fresh rather than
grinding on. Surface the breach; don't silently overrun.

### Rule 7 — Surface conflicts, don't average them

If two patterns contradict, pick one (more recent / more tested). Explain why. Flag the
other for cleanup. Don't blend conflicting patterns.

### Rule 8 — Read before you write

Before adding code, read the exports, immediate callers, and shared utilities it touches.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

### Rule 9 — Tests verify intent, not just behaviour

Tests (and the verification hooks below) must encode WHY behaviour matters, not just WHAT
it does. A check that can't fail when the logic changes is worthless.

### Rule 10 — Checkpoint after every significant step

Summarize what was done, what's verified, what's left. Don't continue from a state you
can't describe back. If you lose track, stop and restate.

### Rule 11 — Match the codebase's conventions, even if you disagree

Conformance > taste inside the codebase. If you genuinely think a convention is harmful,
surface it. Don't fork silently.

### Rule 12 — Fail loud

"Completed" is wrong if anything was skipped silently. "It works" is wrong if a check was
skipped. Default to surfacing uncertainty, not hiding it.

### Rule 13 — Approved work ships fully

When you hit friction on approved work — an API mismatch, an unfamiliar config shape,
anything — the response is "investigate the docs/source until you find the right shape and
implement it fully", NOT "downgrade scope to a follow-up". Forbidden vocabulary on approved
work: `MVP`, `defer`, `out of scope`, `won't fit`, `future PR`, `follow-up`, `simplify to`,
`for now`, `punt`, `leave for now`.

## Orientation

A macOS menu-bar app that fills a Harvest timesheet from real work activity (Git commits,
Azure DevOps pushes, calendar meetings), split across projects and filed each Friday. See
[README.md](README.md) for the overview.

The app is a single SwiftUI file compiled with `swiftc`; the allocation engine is Python
(bundled, so nothing needs installing); shell scripts glue build, release, and the Friday
run together.

### Layout

The product lives under `packages/products/harvest-autofill/`:

| Path | What it is |
| --- | --- |
| `packages/products/harvest-autofill/HarvestApp.swift` | The whole app: menu-bar UI, onboarding, preferences, updater. |
| `packages/products/harvest-autofill/harvest_weekly.py` | The engine — timeline allocation of hours across projects. |
| `packages/products/harvest-autofill/discover.py` | Account/project auto-discovery and holiday generation. |
| `packages/products/harvest-autofill/engine.sh` | Runner used by the app and the Friday launchd job. |
| `packages/products/harvest-autofill/build.sh` / `release.sh` / `notarize.sh` | Build, publish a release, notarize. |
| `packages/products/harvest-autofill/Info.plist`, `icon.*`, `config.default.json` | Bundle metadata, icon, config template. |
| `.github/workflows/` | CI: build on push/PR, publish on a version tag. |

Repo-wide config (`.gitignore`, `.gitattributes`, `.editorconfig`, `LICENSE`, `AGENTS.md`,
`CLAUDE.md`) stays at the root.

### Build & run

```bash
cd packages/products/harvest-autofill
./build.sh            # -> dist/Harvest Auto-Fill.app  (compile, bundle Python, sign, verify)
```

Per-user config and secrets live under `~/Library/Application Support/HarvestAutoFill/` —
never in the bundle, never committed. `HARVEST_DATA_DIR` overrides that path for testing.

### Releasing

Cut a release in one flow: fix commits → release commit → annotated tag → push both. CI's
`release.yml` gates that the tag matches `VERSION` and a released `CHANGELOG.md` section,
then publishes the matching section as the GitHub Release body and attaches the signed app.

**Step by step:**

1. Land your fix/feat commits on `main`. Commitlint enforces one scope per header, sentence-
   case subject, and body lines ≤100 chars — wrap with a HEREDOC. See `.commitlintrc.json`.
2. Bump `VERSION` to `x.y` (major.minor; the build number derives automatically):

   ```bash
   echo 2.37 > VERSION
   ```

3. In `CHANGELOG.md`, add a `## [x.y] - YYYY-MM-DD` section directly under `## [Unreleased]`,
   moving anything that was there. The top released heading must equal the new `VERSION` or
   the release gate refuses the tag.
4. Verify the release notes render — this is exactly what CI will publish:

   ```bash
   node scripts/version.mjs --notes vX.Y
   ```

5. Commit as `chore(release): Cut the vX.Y release` and stage the two files:

   ```bash
   git add VERSION CHANGELOG.md
   git commit -m 'chore(release): Cut the vX.Y release' -m '…one-paragraph summary…'
   ```

6. Run the full pre-push gate locally so a red CI never eats the release window:

   ```bash
   ./bin/mise exec -- lefthook run pre-push
   ```

7. Push `main`, then the annotated tag:

   ```bash
   git push origin main
   NOTES="$(node scripts/version.mjs --notes vX.Y)"
   git tag -a vX.Y -m "$NOTES"
   git push origin vX.Y
   ```

8. Confirm CI + release: `gh run list -L 6` and `gh release view vX.Y`. Every `Checks`,
   `Build`, `Pages`, and `Release` run for the release commit + tag must be `success`, and
   the Release page must have the signed `.app` attached.

**Notes:**

- Build number derives from the version (`major*10000 + minor*100 + patch`) and must
  increase each release — the version bump is what enforces that.
- The CHANGELOG section becomes both the GitHub release notes and the in-app What's New; the
  tag message is a convenient duplicate but not the source of truth.
- Updates are Ed25519-signed; the app verifies each against the public key baked into it,
  so only releases signed with the matching private key install.
- CI runs on `macos-26` (the app uses the macOS 26 SDK).

### Conventions

- Keep shell output ASCII (a non-ASCII char next to `$VAR` breaks `set -u` under some CI
  locales).
- Never commit secrets. `*.env`, `config.json`, `vendor/`, and build artifacts are
  gitignored; verify with `git ls-files` before pushing.
