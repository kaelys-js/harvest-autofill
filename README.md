# Harvest Auto-Fill

A macOS menu-bar app that fills your Harvest timesheet from the work you already did. Your commits, pushes, and calendar meetings become hours, split across the right projects and filed for you every Friday.

[![Build](https://github.com/kaelys-js/harvest-autofill/actions/workflows/build.yml/badge.svg)](https://github.com/kaelys-js/harvest-autofill/actions/workflows/build.yml)
[![Checks](https://github.com/kaelys-js/harvest-autofill/actions/workflows/lint.yml/badge.svg)](https://github.com/kaelys-js/harvest-autofill/actions/workflows/lint.yml)
[![Web E2E](https://github.com/kaelys-js/harvest-autofill/actions/workflows/web-e2e.yml/badge.svg)](https://github.com/kaelys-js/harvest-autofill/actions/workflows/web-e2e.yml)
[![Pages](https://github.com/kaelys-js/harvest-autofill/actions/workflows/pages.yml/badge.svg)](https://github.com/kaelys-js/harvest-autofill/actions/workflows/pages.yml)
![macOS](https://img.shields.io/badge/macOS-26-000000?logo=apple)
![Swift](https://img.shields.io/badge/swift-6.0-F05138?logo=swift)
![Python](https://img.shields.io/badge/python-3.12.14-3776AB?logo=python&logoColor=white)
![Node](https://img.shields.io/badge/node-26.8.1-339933?logo=node.js)
![License](https://img.shields.io/badge/license-MIT-blue)

- **Config-driven.** Connect your own Harvest, GitHub, Azure DevOps, and Google Calendar in a guided onboarding wizard. Nothing is hard-coded to one person.
- **Private.** Every token stays on your Mac in a locked folder. Data goes only to the services you connect, nowhere else.
- **Self-contained.** Python is bundled inside the app. There is nothing to install alongside it.
- **Auto-updating.** The app checks this repo's releases for a signed new version and can install it for you, verifying an Ed25519 signature before it trusts anything.

## TL;DR

```shell
# 1. Install the workspace toolchain (mise-pinned: node, python, pnpm, uv, ruff,
#    swiftlint, swiftformat, lefthook, gh, and the lint/format tools CI runs)
./bin/mise install

# 2. Wire the git hooks (pre-commit format, pre-push gate, commit-msg lint)
./bin/mise exec -- lefthook install

# 3. Build the app → dist/Harvest Auto-Fill.app (compiles Swift, bundles Python, ad-hoc signs)
cd packages/products/harvest-autofill && ./build.sh

# 4. Run the whole gate locally (what CI runs): format, lint, tests, coverage, visual regression
./bin/mise exec -- lefthook run pre-push --all-files
```

## Contents

- [How it works](#how-it-works)
- [Layout](#layout)
- [Prerequisites](#prerequisites)
- [Local development](#local-development)
- [Testing and coverage](#testing-and-coverage)
- [Pre-push and CI gates](#pre-push-and-ci-gates)
- [Release process](#release-process)
- [Marketing website](#marketing-website)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## How it works

The Swift app is the menu-bar shell: onboarding, preferences, the Friday nudge, and the auto-updater. The hours themselves come from a Python engine the app bundles and runs.

1. **Discover.** `discover.py` reads your connected accounts and projects and generates the holiday calendar, so the engine knows what it is allowed to fill and when not to.
2. **Allocate.** `harvest_weekly.py` turns the week's real activity, your Git commits and pushes plus calendar meetings, into an hours-per-project timeline for each worked weekday.
3. **File.** `engine.sh` is the single runner both the app and a Friday `launchd` job call. It posts the allocated entries to Harvest.

Everything is config-driven. The `*.env` files and `config.json` in the app directory hold your connection settings, seeded from `config.default.json` during onboarding. No account, project, or person is baked into the code.

## Layout

A small monorepo: the macOS app and its Python engine under `packages/products/harvest-autofill/`, the marketing site under `packages/products/website/`, and the shared toolchain and CI at the root.

```text
.                                   # workspace root
├── AGENTS.md                       # engineering rules the whole project follows
├── SECURITY.md                     # signing model + how to report a vulnerability
├── LICENSE                         # MIT
├── mise.toml + mise.lock           # exact tool version pins (node, python, pnpm, linters, …)
├── package.json + turbo.json       # turbo qa:* tasks that cache every gate stage (+ .turbo/config.json)
├── lefthook.yml                    # git hooks: pre-commit format, pre-push gate (via turbo), commit-msg lint
├── bin/
│   ├── mise                        # self-bootstrapping, workspace-scoped mise wrapper
│   ├── git                         # refuses --no-verify / LEFTHOOK bypasses (gates are unskippable)
│   └── preflight.sh                # asserts lefthook == CI parity + no test input is gitignored
├── .github/workflows/
│   ├── build.yml                   # compile + bundle + sign + verify signature (push, PR)
│   ├── lint.yml                    # the full pre-push gate + commitlint (push, PR)
│   ├── web-e2e.yml                 # website Playwright E2E + visual regression, in a pinned container
│   ├── pages.yml                   # build + deploy the website to GitHub Pages
│   └── release.yml                 # on a vX.Y tag: build, sign, publish the release
└── packages/products/
    ├── harvest-autofill/           # the macOS app + Python engine
    │   ├── HarvestApp.swift         #   @main app: MenuBarExtra UI, onboarding, updater
    │   ├── HarvestCore.swift        #   pure logic (unit-tested library target)
    │   ├── HarvestSideEffects.swift #   filesystem / network / process effects
    │   ├── SwiftTests/              #   Swift Testing suite for HarvestCore
    │   ├── harvest_weekly.py        #   engine: allocate hours across projects
    │   ├── discover.py              #   account/project discovery + holiday generation
    │   ├── engine.sh                #   runner used by the app and the Friday launchd job
    │   ├── tests/                   #   pytest suite for the engine
    │   ├── visual-check.py          #   renders every screen and pixel-diffs vs visual-baseline/
    │   ├── build.sh                 #   compile, bundle Python, ad-hoc sign
    │   ├── release.sh               #   cut + sign a release artifact
    │   ├── notarize.sh              #   produce a notarized, Gatekeeper-clean build
    │   ├── swift-coverage-gate.sh   #   run Swift tests + enforce the coverage floor
    │   ├── vendor/                  #   bundled CPython runtime
    │   ├── Package.swift            #   SwiftPM manifest (library + test targets)
    │   └── config.default.json      #   onboarding seed for the per-user config
    └── website/                    # the marketing site (Astro + React + Tailwind)
        ├── src/{components,layouts,lib,pages,styles}
        ├── test/                    #   Vitest unit + component tests (jsdom)
        ├── e2e/                     #   Playwright E2E + hero visual regression
        └── run-web-e2e.sh           #   runs e2e in the pinned Playwright container
```

## Prerequisites

- **[mise](https://mise.jdx.dev/)** — bootstrapped by `./bin/mise`, which self-installs the pinned version if it is absent. Every other tool (node, python, pnpm, uv, ruff, swiftlint, swiftformat, lefthook, gh, and the format/lint tools) comes from `./bin/mise install`. Installs are scoped to `.mise/installs` inside the repo, so nothing touches your global setup.
- **Xcode or the Command Line Tools** — the Swift compiler comes from Apple's toolchain, not mise. `xcode-select --install` is enough to build; SwiftLint's strict rules need a full Xcode for SourceKit, and the pre-push hook falls back to any installed `Xcode.app` when only the Command Line Tools are selected.
- **macOS 26 or newer, Apple Silicon** — the app uses macOS 26 (Liquid Glass) APIs at runtime.
- **Docker** — only for the website's containerized visual regression. If Docker is absent locally, that one check defers to the `web-e2e.yml` CI job; everything else runs without it.

## Local development

```shell
git clone https://github.com/kaelys-js/harvest-autofill
cd harvest-autofill
./bin/mise install
./bin/mise exec -- lefthook install
```

Build and run the app:

```shell
cd packages/products/harvest-autofill
./build.sh
open "dist/Harvest Auto-Fill.app"
```

On first launch the onboarding wizard writes your connection settings into the app directory's `*.env` and `config.json`. To iterate on the engine alone, run it the way the app does:

```shell
./engine.sh            # discover + allocate + file, using the local config
```

## Testing and coverage

Three suites, each with a 75% coverage floor and its own visual or behavioural check. All of them run in the pre-push gate and in CI.

| Suite | Command | Covers |
| --- | --- | --- |
| Python engine | `uv run --python 3.12 --group dev pytest --cov` | `harvest_weekly.py`, `discover.py` — allocation, discovery, holidays |
| Swift core | `./swift-coverage-gate.sh` | `HarvestCore.swift` via the Swift Testing suite |
| Website | `pnpm exec vitest run --coverage` | React components + `src/lib` helpers (jsdom) |

Visual regression guards the rendered surfaces:

- **App** — `visual-check.py` renders every screen through the app's `--render` hook and pixel-diffs each against `visual-baseline/`. The `app-visual` gate rebuilds the app first, so a UI change that shifts any screen fails until the baseline is updated deliberately.
- **Website** — `e2e/visual.spec.ts` screenshots the hero in light and dark and compares against committed `-linux` baselines. It runs inside the pinned `mcr.microsoft.com/playwright` container (see `run-web-e2e.sh`) so rendering is byte-identical on every machine and in CI. Regenerate baselines on purpose with `./run-web-e2e.sh --update`.

## Pre-push and CI gates

Every `git push` runs the same battery CI runs, configured in [`lefthook.yml`](lefthook.yml). The [`lint.yml`](.github/workflows/lint.yml) "Checks" job is literally `lefthook run pre-push --all-files`, so local and CI stay in parity by construction; [`build.yml`](.github/workflows/build.yml) additionally compiles, bundles, signs, and verifies the app, and [`web-e2e.yml`](.github/workflows/web-e2e.yml) runs the website E2E container.

Each tool stage runs through [turbo](https://turborepo.com/) (`turbo run qa:<name>`, defined in [`turbo.json`](turbo.json) + the root [`package.json`](package.json) `qa:*` scripts). Inputs are scoped per language, so an unchanged surface — swift, python, or web — is a cache hit rather than a re-run: a warm gate is `>>> FULL TURBO`. CI restores a `.turbo` cache via `actions/cache` and reads the shared Vercel remote cache.

The gate is unskippable by design. [`bin/git`](bin/git) refuses `git push --no-verify` / `-n`, and the `no-bypass` stage refuses the `LEFTHOOK=0` and `LEFTHOOK_EXCLUDE` environment bypasses. Fix the failing check; do not skip it.

| Stage | Purpose |
| --- | --- |
| `no-bypass` | Refuses `LEFTHOOK=0` / `LEFTHOOK_EXCLUDE` |
| `preflight` | Asserts lefthook == CI parity and that no test input is hidden by `.gitignore` |
| `swift-format` / `swift-lint` | `swiftformat --lint` + `swiftlint --strict` |
| `python-format` / `python-lint` | `ruff format --check` + `ruff check` |
| `shell-format` / `shell-lint` | `shfmt -d` + `shellcheck` over tracked shell scripts |
| `toml` | `taplo lint` on `mise.toml` |
| `json-format` | `oxfmt --check` on the config |
| `yaml-lint` / `workflow-lint` | `yamllint` + `actionlint` on the workflows |
| `markdown-lint` | `markdownlint-cli2` on the root docs |
| `web-format` / `web-lint` | `oxfmt --check` + `oxlint` on the website source |
| `astro-format` / `css-lint` | `prettier --check` on `.astro` + `stylelint` on CSS |
| `python-test` | pytest with the coverage floor |
| `swift-test` | `swift-coverage-gate.sh` — Swift Testing suite with the coverage floor |
| `web-test` | Vitest with the coverage floor |
| `app-visual` | Rebuilds the app and pixel-diffs every screen vs baseline (scoped to app sources) |
| `web-e2e` | Website Playwright E2E + visual regression in the pinned container (scoped to website sources) |

The toolchain is pinned to exact versions in [`mise.toml`](mise.toml) and locked in [`mise.lock`](mise.lock); website dependencies are pinned exactly in [`package.json`](packages/products/website/package.json) (`.npmrc` sets `save-exact=true`), and every workflow `uses:` is pinned to a full 40-character commit SHA.

## Release process

Releases are cut by pushing an annotated version tag. [`release.yml`](.github/workflows/release.yml) builds, signs, and publishes it.

```shell
git tag -a v2.19 -m "## Changes
- …"
git push origin v2.19
```

The app verifies each update's **Ed25519** signature against the public key baked into the binary, so it only accepts releases signed with the matching private key. `notarize.sh` produces a notarized, Gatekeeper-clean build for distribution outside the auto-updater. The signing model and vulnerability-reporting process are documented in [`SECURITY.md`](SECURITY.md). The same tag also redeploys the website (see below), so the site ships in lockstep with the app.

## Marketing website

The site under `packages/products/website/` is an [Astro](https://astro.build/) project (React islands, Tailwind v4) that presents the app and links to the latest signed release. It deploys to GitHub Pages via [`pages.yml`](.github/workflows/pages.yml) on every push to `main` **and on every `v*` release tag** — a tag rebuilds the site with that version baked in (injected from the tag in [`astro.config.mjs`](packages/products/website/astro.config.mjs)), so the version it shows never drifts from the app. The download button validates the GitHub release response with [valibot](https://valibot.dev/) before trusting it, structured data (schema.org JSON-LD) describes the app, and the "Made to feel native" section is an interactive recreation of the six-step onboarding wizard and all four Preferences tabs.

```shell
cd packages/products/website
pnpm dev            # local dev server
pnpm build          # production build → dist/
pnpm test:unit      # Vitest + coverage
./run-web-e2e.sh    # Playwright E2E + visual regression (Docker)
```

## Troubleshooting

**`mise` reports `missing:` and a build or hook stalls**
The tool was installed to the global mise directory instead of the workspace one. Always invoke the pinned wrapper (`./bin/mise …`); it scopes installs to `.mise/installs` inside the repo via `MISE_INSTALLS_DIR`. Re-run `./bin/mise install` to land everything in the workspace.

**SwiftLint fails with a SourceKit error**
SwiftLint's strict rules need a full Xcode, not just the Command Line Tools. Install Xcode, or let the pre-push hook's fallback find an `Xcode.app` automatically. `xcode-select -p` shows which toolchain is selected.

**`git push` is blocked by a failing gate**
That is the gate working. Read the failing stage's output, fix it, and push again. `--no-verify` is deliberately refused by `bin/git`; there is no bypass.

**The website's visual gate is skipped locally**
Docker is not available on your machine, so `web-e2e` deferred to CI. Install Docker to run it locally, or let the `web-e2e.yml` job cover it.

**`astro check` fails with a TypeScript API error**
`astro check` needs a TypeScript version that still exposes the legacy programmatic API. TypeScript 7's native compiler does not yet ship it (tracked in withastro/roadmap#1321). The build, tests, and linters do not depend on `astro check`, so this does not affect the gate.

## Contributing

- Read [`AGENTS.md`](AGENTS.md) — the engineering rules the whole project follows.
- Commit messages are Conventional Commits, enforced by commitlint through lefthook's `commit-msg` hook (`fix: …`, `feat(scope): …`).
- Install the hooks once with `./bin/mise exec -- lefthook install`, then let the pre-push gate keep you honest. Do not bypass it.
- Every push runs the `build.yml`, `lint.yml`, and (for website changes) `web-e2e.yml` checks shown in the badges above. Get them green locally first.

## License

[MIT](LICENSE).
