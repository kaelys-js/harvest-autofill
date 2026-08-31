# AGENTS.md

Engineering notes for anyone (human or AI) working in this repository.

## What this is

A macOS menu-bar app that fills a Harvest timesheet from real work activity (Git
commits, Azure DevOps pushes, and calendar meetings), split across projects and
filed automatically each Friday. See [README.md](README.md) for the overview.

The app is a single SwiftUI file compiled with `swiftc`; the time-allocation
engine is Python (bundled, so nothing needs installing); a few shell scripts glue
build, release, and the scheduled run together.

## Layout

| Path | What it is |
|---|---|
| `HarvestApp.swift` | The whole app: menu-bar UI, onboarding wizard, preferences, updater. |
| `harvest_weekly.py` | The engine — timeline allocation of hours across projects. |
| `discover.py` | Account/project auto-discovery and statutory-holiday generation. |
| `engine.sh` | Runner used by the app and by the Friday launchd job. |
| `config.default.json` | Sanitized config template seeded on first run. |
| `build.sh` / `release.sh` / `notarize.sh` | Build, publish a release, notarize. |
| `Info.plist`, `icon.*` | Bundle metadata and icon. |
| `.github/workflows/` | CI: build on push/PR, publish on a version tag. |

## Build & run

```
./build.sh            # -> dist/Harvest Auto-Fill.app  (compile, bundle Python, sign, verify)
```

The app stores per-user config and secrets under
`~/Library/Application Support/HarvestAutoFill/` — never in the bundle and never
committed. `HARVEST_DATA_DIR` overrides that path for isolated testing.

## Releasing

Push an annotated version tag; CI builds, signs, and publishes it:

```
git tag -a v2.11 -m "## Changelog
- ..."
git push origin v2.11
```

- The build number is derived from the version (`major*10000 + minor*100 + patch`)
  and must increase each release.
- The tag message becomes both the GitHub release notes and the in-app What's New.
- Updates are Ed25519-signed; the app verifies each one against the public key
  baked into it, so only releases signed with the matching private key install.
- CI must run on a `macos-26` (or newer) runner — the app uses the macOS 26 SDK.

## Conventions

- Keep shell output ASCII (a non-ASCII char next to `$VAR` breaks `set -u` under
  some CI locales).
- Never commit secrets. `*.env`, `config.json`, `vendor/`, and build artifacts are
  gitignored; verify with `git ls-files` before pushing.
- Match the surrounding style; keep changes surgical.
