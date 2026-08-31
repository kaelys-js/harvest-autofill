# Harvest Auto-Fill

A macOS menu-bar app that fills your Harvest timesheet from the work you already did — your commits, pushes, and calendar meetings turned into hours, split across the right projects and filed for you every Friday.

- **Config-driven** — set up your own Harvest, GitHub, Azure DevOps, and Google Calendar in a guided onboarding wizard. Nothing is hard-coded to one person.
- **Private** — every token stays on your Mac in a locked folder; nothing is sent anywhere but the services you connect.
- **Self-contained** — Python is bundled inside the app, so there's nothing to install.
- **Auto-updating** — checks this repo's releases for a signed new version and can install it for you.

## Build

```
cd packages/products/harvest-autofill
./build.sh            # → dist/Harvest Auto-Fill.app  (compiles, bundles Python, ad-hoc signs)
```

## Release

Push an annotated version tag; CI builds, signs, and publishes it:

```
git tag -a v2.10 -m "## Changes
- …"
git push origin v2.10
```

The app verifies each update's Ed25519 signature against the public key baked into it, so only releases signed with the matching private key are accepted. See `notarize.sh` to produce a notarized (Gatekeeper-clean) build.

## Layout

The app lives under `packages/products/harvest-autofill/`:

- `HarvestApp.swift` — the app (SwiftUI menu-bar UI, onboarding, updater).
- `harvest_weekly.py` — the engine: timeline allocation of hours across projects.
- `discover.py` — auto-discovery of accounts/projects and holiday generation.
- `engine.sh` — runner used by the app and the Friday launchd job.
- `build.sh` / `release.sh` / `notarize.sh` — build, publish, notarize.

Repo-wide config and the CI workflows (`.github/workflows/`) stay at the root.
