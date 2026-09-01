# Security Policy

## Reporting a vulnerability

Please report security issues **privately** through GitHub's
[Report a vulnerability](https://github.com/kaelys-js/harvest-autofill/security/advisories/new)
form (Security → Advisories). Private vulnerability reporting is enabled on this
repository, so you can disclose the details without them being public.

Please do not open a public issue for a security problem.

When you report, include where you can:

- what the issue is and the impact you think it has,
- the version (the app's About tab shows it) and macOS version,
- steps to reproduce, and a proof of concept if you have one.

You can expect an initial response within a few days. If a fix is warranted, it
ships as a normal signed release and the advisory is published once users have had
a chance to update.

## Supported versions

Only the latest release receives fixes. The app auto-updates itself to the latest
signed release by default (Preferences → About), so staying current is the
supported path.

## How updates are trusted

Updates are delivered through GitHub Releases. Each release ships a manifest that is
signed with an **Ed25519** key; the app verifies that signature and the download's
SHA-256 before installing. The signing key never leaves CI — it lives only as the
`ED25519_PRIVATE_KEY` repository secret. If signature or checksum verification fails,
the update is refused.

## Scope

This project is a personal, open-source utility. Credentials (Harvest, GitHub, Azure
DevOps, calendar) are stored only on the user's Mac, in files scoped to that user; the
app has no backend and sends nothing to a server it controls. Reports about token
handling, the update pipeline, or the bundled runtime are all in scope.
