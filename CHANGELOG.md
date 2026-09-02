# Changelog

All notable changes to Harvest Auto-Fill are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

`VERSION` and the topmost released heading below move in lockstep with the `v*` release tag:
bump the version, move what accumulated under `## [Unreleased]` into a new `## [x.y] - date`
heading, commit, then tag `vx.y`. A release gate rejects any tag whose version does not match
`VERSION` and this file, and `release.yml` publishes the matching section here as the GitHub
Release notes. Every version is also a downloadable build on the
[Releases](https://github.com/kaelys-js/harvest-autofill/releases) page.

## [Unreleased]

## [2.36] - 2026-09-02

- Added a "See it fill a week" demo to the website: the app's This Week window plays through a
  whole week filling itself day by day — the same window you use — with play, pause, and replay,
  and it holds still for anyone who prefers reduced motion. The demo fits phone screens cleanly.
  The app itself is unchanged from 2.35.

## [2.35] - 2026-09-02

- Polished the wording across the whole app to one voice: a single verb for filing your week
  ("log"), clearer onboarding and Settings copy, a consistent privacy statement, plain-language
  update and error messages, and one time format. No behaviour changes.
- Brought the marketing site's copy in line with the app, and tidied the documentation and
  in-code comments behind the scenes.

## [2.34] - 2026-09-01

- A housekeeping release with no changes to the app itself: the project's documentation and release process were refreshed behind the scenes. The app behaves exactly as 2.33.

## [2.33] - 2026-09-01

- Added a curated CHANGELOG.md and a VERSION file, kept in lockstep with the release tag (a gate rejects any tag whose version does not match both), and pointed the site's Changelog link here.

## [2.32] - 2026-09-01

- Website now meets WCAG 2.2 AA end to end, verified automatically by axe: stronger button and text contrast (a deeper brand orange), larger touch targets, and better high-contrast and reduced-transparency support. The app is unchanged from 2.31.

## [2.31] - 2026-09-01

- Website polish: correct blur in Safari, cleaner heading and body wrapping, and more faithful support for the system theme and accessibility settings (high-contrast focus, reduced transparency). The app is unchanged from 2.30.

## [2.30] - 2026-09-01

- Housekeeping: moved to a cleaner repository name (auto-update keeps working through GitHub's redirect), tightened the build to current macOS signing best practices, and refreshed the website footer. The app behaves exactly as 2.29.

## [2.29] - 2026-09-01

- Website refresh: the onboarding preview and preferences tabs now animate, and FAQ answers glide open and closed. The app is unchanged from 2.28.

## [2.28] - 2026-09-01

- Setup now names what it finds — your Harvest account, each mapped project, your GitHub organization, and your Azure DevOps repositories — instead of bare counts.
- Help tips open when you click the "?" icons (they were unreliable on hover); Accounts reuses what it already knows (drops the GitHub username and token fields when you are signed in via the gh CLI, and lists your real Azure DevOps projects); work hours can be set to the half-hour; and a week that crosses a month now reads clearly.
- The website loads lighter — its icons are about 85% smaller and it no longer calls GitHub on every visit.

## [2.27] - 2026-09-01

- The current day is marked "projected" — its hours are filled in ahead and recalculated up to the Friday post — so it is clear the day is not finished.
- Faster and gentler on battery: Azure DevOps activity is fetched in parallel, and background updates ease off when you are unplugged.

## [2.26] - 2026-08-31

- The Window menu lists only the windows you have open, with the active one checked, and Settings wording is tightened further for plain language.

## [2.25] - 2026-08-31

- Onboarding shows the same clean icons as the site in an orange badge; the window content sits flush under the controls; the Settings tab highlight slides smoothly; and the wording is reviewed for plain, jargon-free language.

## [2.24] - 2026-08-31

- Update checks now report what actually happened (a temporary rate limit, no connection, or no new release) instead of always saying "no updates available".
- What's New reopens reliably; right-clicking the Dock icon lists your open windows; the Help menu's Website and GitHub links work; and the General and Accounts tabs are explained in plain language.

## [2.23] - 2026-08-31

- Cleaner windows without the redundant title bar; Settings sections stand out and the tabs slide between panels; and the app menu gains Settings, This Week, an About that opens Settings, and a Quit that confirms first.
- Onboarding shows the icon beside each step and spells out what Discover scans; "Preferences" is renamed "Settings" throughout; and the TypeScript configuration is stricter.

## [2.22] - 2026-08-31

- The Dock icon is fixed (no stray white edge, and clicking it brings the window forward); the menu offers Check for Updates, What's New, Website, and GitHub.
- Disabled buttons look disabled, onboarding re-runs cleanly, and What's New shows the real release notes; plain-language copy throughout; and a TypeScript typecheck joins the build gate.

## [2.21] - 2026-08-31

- The app matches the site exactly — the same clock icon everywhere, the orange palette across windows and buttons, solid cards, and an 8px status dot.
- Website: a sharper favicon, runtime valibot validation on every data value, and visual-regression coverage extended to the nav and trust bar.

## [2.20] - 2026-08-31

- The menu-bar window matches the site pixel-for-pixel (clock icon, colours, dated day rows with per-project dots and AM/PM times); all demo data is generic.
- Website: the FAQ is rebuilt with FAQPage structured data, clearer numbered download steps, valibot validation over every constant and input, and full-section visual regression.
- Privacy: the bundled default config and engine carry no real client names, identity, or account IDs.

## [2.19] - 2026-08-31

- Marketing website: an interactive onboarding and preferences preview, schema.org structured data, SEO fixes, and a deploy that runs in lockstep with each release.
- Tooling: turbo caching across the whole gate and the app and website builds, with valibot validation over every untrusted input on the site.

## [2.18] - 2026-08-31

- The What's New button reads "Got It" when shown right after an update.

## [2.17] - 2026-08-31

- The Save button appears only when you have changed something, and never on the About tab.

## [2.16] - 2026-08-31

- What's New lists every earlier release with its notes and date, under the latest one.

## [2.15] - 2026-08-31

- New: keep the app icon in the Dock (and the ⌘-Tab switcher) from Preferences → General, or stay menu-bar-only as before.

## [2.14] - 2026-08-31

- Workspace-scoped mise with a lockfile; commitlint on commit messages; and lefthook covering commit-msg, pre-commit format, the pre-push gate, and post-merge sync.

## [2.13] - 2026-08-31

- Added a mise-pinned toolchain (every formatter and linter pinned and workspace-scoped), a lefthook pre-push gate that format-checks and lints the whole project and runs identically in CI, and a reformat with all lint findings fixed to zero.

## [2.12] - 2026-08-31

- Reorganized the app under `packages/products/harvest-autofill/` and adapted the engineering rules (AGENTS.md) for this repo.

## [2.11] - 2026-08-31

- See What's New any time from About; each release now shows its date and a link to the GitHub release.

## [2.10] - 2026-08-31

- Auto-update from GitHub Releases — signed manifests, checksum-verified, with a What's New changelog after each update. The entire source now lives in this repo, built and released by CI.

## [2.9] - 2026-08-31

- Bootstrapped the public releases repository.

## [2.8] - 2026-08-31

- Bootstrapped the public releases repository.

[Unreleased]: https://github.com/kaelys-js/harvest-autofill/compare/v2.34...HEAD
[2.34]: https://github.com/kaelys-js/harvest-autofill/compare/v2.33...v2.34
[2.33]: https://github.com/kaelys-js/harvest-autofill/compare/v2.32...v2.33
[2.8]: https://github.com/kaelys-js/harvest-autofill/releases/tag/v2.8
[2.9]: https://github.com/kaelys-js/harvest-autofill/compare/v2.8...v2.9
[2.10]: https://github.com/kaelys-js/harvest-autofill/compare/v2.9...v2.10
[2.11]: https://github.com/kaelys-js/harvest-autofill/compare/v2.10...v2.11
[2.12]: https://github.com/kaelys-js/harvest-autofill/compare/v2.11...v2.12
[2.13]: https://github.com/kaelys-js/harvest-autofill/compare/v2.12...v2.13
[2.14]: https://github.com/kaelys-js/harvest-autofill/compare/v2.13...v2.14
[2.15]: https://github.com/kaelys-js/harvest-autofill/compare/v2.14...v2.15
[2.16]: https://github.com/kaelys-js/harvest-autofill/compare/v2.15...v2.16
[2.17]: https://github.com/kaelys-js/harvest-autofill/compare/v2.16...v2.17
[2.18]: https://github.com/kaelys-js/harvest-autofill/compare/v2.17...v2.18
[2.19]: https://github.com/kaelys-js/harvest-autofill/compare/v2.18...v2.19
[2.20]: https://github.com/kaelys-js/harvest-autofill/compare/v2.19...v2.20
[2.21]: https://github.com/kaelys-js/harvest-autofill/compare/v2.20...v2.21
[2.22]: https://github.com/kaelys-js/harvest-autofill/compare/v2.21...v2.22
[2.23]: https://github.com/kaelys-js/harvest-autofill/compare/v2.22...v2.23
[2.24]: https://github.com/kaelys-js/harvest-autofill/compare/v2.23...v2.24
[2.25]: https://github.com/kaelys-js/harvest-autofill/compare/v2.24...v2.25
[2.26]: https://github.com/kaelys-js/harvest-autofill/compare/v2.25...v2.26
[2.27]: https://github.com/kaelys-js/harvest-autofill/compare/v2.26...v2.27
[2.28]: https://github.com/kaelys-js/harvest-autofill/compare/v2.27...v2.28
[2.29]: https://github.com/kaelys-js/harvest-autofill/compare/v2.28...v2.29
[2.30]: https://github.com/kaelys-js/harvest-autofill/compare/v2.29...v2.30
[2.31]: https://github.com/kaelys-js/harvest-autofill/compare/v2.30...v2.31
[2.32]: https://github.com/kaelys-js/harvest-autofill/compare/v2.31...v2.32
