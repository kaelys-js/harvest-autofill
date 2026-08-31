# AGENTS.md -- engineering rules + orientation

_Part of the foundation-registry — the Business-as-Code governance workspace._

> **What this file is.** The engineering rules every AI agent follows when doing CODE work in this repo (refactors, feature work, docs, security reviews, PoC builds). It's deliberately short -- read these first. The rules apply to interactive Claude Code sessions and to any workflow sub-agents spawned from this repo.
>
> **Sections.** The **14 rules** govern authoring code. The **Security Review Protocol** and **Security POC Protocol** govern the primary job of this workspace: assessing findings against source and building reproducible proof-of-concept exploits for coordinated disclosure. A short **Workflow** at the bottom ties them into one lifecycle.

NEVER INCLUDE PII INFORMATION IN ANY FILE.
NEVER INCLUDE EMAIL, GITHUB USERNAME, GITHUB ORG, REPO NAME IN ANY FILE UNLESS AUTHORIZED BY USER.

## 14 rules

These apply to every code task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

### Rule 1 -- Think before coding

State assumptions explicitly. If uncertain, ask rather than guess.
Present multiple interpretations when ambiguity exists.
Push back when a simpler approach exists.
Stop when confused. Name what's unclear.

### Rule 2 -- Simplicity first

Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
Test: would a senior engineer say this is overcomplicated? If yes, simplify.

### Rule 3 -- Surgical changes

Touch only what you must. Clean up only your own mess.
Don't "improve" adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.

### Rule 4 -- Goal-driven execution

Define success criteria. Loop until verified.
Don't follow steps. Define success and iterate.
Strong success criteria let you loop independently.

### Rule 5 -- Use the model only for judgment calls

Use me for: classification, drafting, summarization, extraction.
Do NOT use me for: routing, retries, deterministic transforms.
If code can answer, code answers.

### Rule 6 -- Token budgets are not advisory

Inline single-agent work: 4,000 tokens per task, 30,000 per session.
Explicitly-approved multi-agent workflow runs are exempt from these numbers,
never from the duty to surface cost.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

### Rule 7 -- Surface conflicts, don't average them

If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.
Don't blend conflicting patterns.

### Rule 8 -- Read before you write

Before adding code, read exports, immediate callers, shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

### Rule 9 -- Tests verify intent, not just behaviour

Tests must encode WHY behaviour matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

### Rule 10 -- Checkpoint after every significant step

Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.
If you lose track, stop and restate.

### Rule 11 -- Match the codebase's conventions, even if you disagree

Conformance > taste inside the codebase.
If you genuinely think a convention is harmful, surface it. Don't fork silently.

### Rule 12 -- Fail loud

"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

### Rule 13 -- Approved work ships fully

When you hit friction on approved work -- an API mismatch, an unfamiliar config shape, a missing test fixture, anything -- the response is "investigate the docs/source until you find the right shape and implement it fully". NOT "downgrade scope to a follow-up".

Forbidden vocabulary on approved work:
`MVP`, `defer`, `out of scope`, `won't fit`, `future PR`, `future work`, `separate ticket`, `separate PR`, `follow-up`, `simplify to`, `for now`, `punt`, `leave for now`.

### Rule 14 -- Write like a human (no AI tells)

Prose and comments must not read as machine-generated. Applies everywhere: READMEs,
advisories, commit messages, code comments. This extends SR11 (advisory voice) to all
authored text.

- Ration em-dashes. Most sentences want a comma, a period, or parentheses. More than one
  `--`/`—` per paragraph is a smell.
- Break the rule-of-three reflex. Use two or five items when that is what is true; vary
  bullet and sentence length instead of reflexive symmetry.
- Cut filler intensifiers (genuinely, really, truly, simply, just, quite, actually) and
  LLM-favourite diction (leverage, robust, seamless, comprehensive, delve, crucial,
  ensure, utilize, streamline, showcase, underscore).
- No "it's not just X, it's Y" antithesis, no templated pep or sign-offs, no hedging
  clusters ("it's worth noting that", "it's important to note").
- Don't over-format. Not every bullet needs a bold label; not every section the same
  scaffold. No decorative emoji.
- Vary a repeated metaphor before it hardens into a signature tic.

### Rule 15 -- Lefthook gates are unskippable

Every hook in `packages/shared/config/lefthook/base.yml` collapses to ONE
dispatcher command, `pnpm tool foundation-hooks run <hook>`. The runner
(`packages/shared/utils/cli/src/tools/foundation-hooks/index.ts`) is the
authoritative source of stages; its `MANIFEST` maps each hook name to
the ordered sequence of stages, and each stage spawns its binary
directly. The collapse pays pnpm's ~0.5s boot floor once per hook
instead of once per stage (nine pre-push stages was ~4.5s of pure
dispatch overhead before the collapse).

Pre-commit stages in fail-fast order: no-bypass, sync, schema-updater
(guarded on staged schema sources), contributors (guarded on staged
contributors base), format, test-unit, test-coverage, lint,
format-check.

Pre-push stages in fail-fast order: no-bypass, sync-drift, lint,
format-check, boundaries, test-unit, test-e2e, benchmark,
test-coverage. `test-e2e` is live — the earlier PRE1n step-level mute
was removed when the locale-loader regression was repaired and the
runner adopted the manifest as source of truth. No stage in the
current MANIFEST carries a mute; every hook stage runs.

`test-coverage` joined pre-commit at p5 in PRE3d — recursive proof that
foundation-test's aggregate cache stays hot. On a config-only commit it
completes in ~2.5-2.8s (aggregate cache hit); on a change that touches
nothing under any `qa:test:coverage`-emitting package it stays under 3s
because the root pre-filter returns empty and turbo never spawns. After
PRE7b the warm no-change coverage path runs zero vitest spawns even at
per-package granularity (`.foundation/test-cache.json` fully answers the
run).

The `lint` step is live as of TT6c (and LT3/LT4 wired format-check + oxlint
mute). All foundation-lint rules are muted (severity=off from LT2 + TT2)
and tsgo + oxlint + lychee are muted at tool level via TT6b's `tools:`
block in `.foundation-lint.jsonc` — see the
`TODO(re-enable-muted-lint-tools)` header in that file for the cleanup
path (~2,500 tsgo errors, ~11,650 oxlint findings after the pedantic
category broadened, and a lychee backlog pending the 0.24 config
migration). svelte-check was unmuted once its 30 real residuals and 81
UI casing errors were resolved. Every OTHER registered lint tool (reuse,
jsonlint, syncpack, dependency-cruiser, …) enforces as configured; the
gate is not a placeholder.

The runner exposes `stageCommandResolves` (same file) as the
compensating check for what PRE1t's stripped-PATH validation used to
assert per-lefthook-step. Its companion unit tests confirm every
manifest stage points at a resolvable binary and that base.yml's
per-hook dispatchers map 1:1 to `MANIFEST` keys, so the contract
survived the collapse without a lefthook-level equivalent.

If any hook fails, the response is "fix the failing check". NEVER
`--no-verify`. NEVER `LEFTHOOK=0`. The `no-bypass` guard at p0 of every
hook's manifest blocks the LEFTHOOK env-var routes; `--no-verify` is banned by
convention (git skips the hook entirely, so the guard can't fire). If a
hook is genuinely broken (not a real failure but a tooling regression),
fix the tool first, do not commit through the bypass.

The `test-unit` and `test-coverage` steps route through **foundation-test**
(PRE2 series, `packages/shared/utils/cli/src/tools/test-cache/`). Root
`qa:test:unit` and `qa:test:coverage` pre-filter via
`pnpm --silent tool test-cache affected-packages --format turbo-filter`,
so a no-change re-run skips turbo entirely; per-package `qa:test:unit`
scripts invoke `pnpm -w tool test-cache unit --project <name>`, which
keys each test file on the sha256 of its transitive dep-graph and
re-runs only what changed. Cache lives at `.foundation/test-cache.json`
(gitignored) — delete it to force a cold rebuild.

Coverage caches at case granularity (PRE5a-c). Each cache entry
carries a `cases` map keyed on the describe-chain + `it` name; every
case stores its body-AST hash, hostility flag, and per-source-file
istanbul counters captured by the custom TestRunner
(`test-cache/case-runner.mjs`). A warm coverage run merges cached
per-case counters and only spawns vitest for files with at least one
needs-run case. Coverage uses the istanbul provider (PRE5d-1); the
earlier v8 provider mis-attributed transformed line counts under the
per-case delta model. PRE7a-2 consolidated the earlier two-spawn
dispatch (hostile on threads, changed on forks) into ONE spawn per
subcommand under `--pool=threads --isolate` — enabled by PRE7a-1
removing the last `process.chdir()` in the format pipeline (workers
cannot chdir). `isolate: true` still keeps each test file in its
own worker context, so the `vi.mock` state leak that broke
foundation-lint under `isolate: false` (PRE5d-1) cannot recur. The
hostile / changed split survives as a logging signal in the
summary line. A skip manifest passed via `FOUNDATION_TEST_SKIP_CASES`
lists cached case keys per file; the custom runner flips
`task.mode = 'skip'` before the case body runs.

PRE6 extended the pipeline in three places. **PRE6a**: the AST parser
statically expands `describe.each` / `it.each` when the data
argument is an array literal, a readonly tuple, or a tagged template
row, so each iteration gets its own case key and body-AST hash
instead of collapsing under the outer describe. Dynamic arguments
(function call, spread, bare identifier) still fall back to
file-level. **PRE6b**: the cache-safe marker's fixture-path
extension is no longer regex-only — an AST-based extractor resolves
`readFileSync(join(__dirname, ...literals))`, file-scope const
bindings whose initializer statically evaluates, and `readdirSync`
targets whose enumeration expands into the fixture set. Five
locale-companion test files carry the marker + justification and
their tool-source reads now invalidate the cache in step with the
files they actually read. **PRE6c**: the sync-template CI workflow
carries an `actions/cache@v4` step keyed on lockfile + config +
commit SHA, so CI runners restore the workspace's
`.foundation/test-cache.json` instead of rebuilding it every push.
The same pass fixed a shell-tokenization bug in
`affected-packages --format turbo-filter` (root workspace names
with spaces broke `--filter=<name>` under bash word split); the
tool POSIX-quotes those names and the templated root `qa:test:*`
scripts wrap the turbo invocation in `eval` to honor the quoting.

PRE7 completed the caching arc. **PRE7a** consolidated dispatch
(above) and removed the format pipeline's `process.chdir()` so
workers could host the changed subset. **PRE7b** taught the AST
fixture extractor to resolve `it.each`-derived template literals
(`join(HERE, \`${row.id}.ts\`)`and friends) by walking
iteration-callback destructuring bindings back to the data literal,
so`format/formatters/behavior.test.ts`— the last file that
spawned on every warm no-change run — folded into the per-case
cache. Warm no-change coverage now runs zero vitest spawns.
**PRE7c** converted five tool flags tests (`vscode-setup`,
`schema-updater`,`format`,`sync`,`onboard`) from
subprocess-per-case to in-process`parseFlags`+`command.data.invoke`calls, keeping two smoke subprocess cases
per file (`--help`end-to-end +`--json + unknown` for the
problem+json wire). Cold single-file wall time dropped 44-78%
per converted file (30s+ tsx cold-starts collapsed to 6-14s);
cold coverage for the utils-cli suite dropped ~50s.

See `packages/shared/utils/cli/src/tools/test-cache/README.md`
for the consolidated-spawn architecture note, the in-process
flags-test pattern, and the current wall-time table (measured
post-PRE7d).

Case-level caching is disabled per file when the beforeEach heuristic
detects unsafe patterns (state mutation across cases the runner can't
prove idempotent); the parser reports the reason and the file falls
back to file-level caching. When every case in a file is cached the
file contributes nothing to the spawn.

Three expansion-scale invariants govern how the pipeline responds
to workspace growth, each pinned by its own module in
`packages/shared/utils/cli/src/tools/test-cache/`:

- Warm zero-diff wall stays O(1) in workspace size — pinned by
  `warm-wall-invariant.ts` (ceiling + observations in
  `pre-push-baselines.json`).
- Cold full-purge wall stays O(N-packages) — pinned by
  `cold-wall-invariant.ts` (ceiling + cold observations).
- Diff-scoped runs stay O(K) in the changed set — pinned by
  `expansion-scale-invariant.ts` (pure projection over
  `computeAffectedPackages`; the empty-diff and single-file-diff
  properties are asserted across three workspace sizes so a super-
  linear leak surfaces as a size-dependent breach).

Cache-hostile escape hatch: a test file (or a single case within it)
that reads state outside its import graph (`process.env.*`, `fetch(`,
`spawnSync(`, `readFileSync`, dynamic `import(nonliteral)`) is
auto-detected at classification time and always re-executes. The
`testing/no-untracked-side-effects` rule mirrors the same detector
and flags any hit at lint time so the mismatch surfaces before the
cache silently thrashes. Opt out by adding `// foundation-test:
cache-safe` in the first 40 lines of the test file with a comment
justifying why the pattern reads only inputs that ARE in the
dep-graph (fixture path inside `depFiles`, subprocess with fixed
stdin, etc.). Never add the marker to silence a warning without the
justification — a wrongly-marked file causes stale test results.

## Toolchain notes: pnpm resolution

The pnpm binary version reported by `which pnpm` and by `pnpm --version` can
disagree, and that is expected, not a bug. Two layers own the answer:

- `which pnpm` returns whatever mise resolved for the current cwd. Mise's
  answer comes from the nearest `mise.toml` up the tree, falling back to the
  global `~/.config/mise/config.toml`. In this repo, `[tools]` does not
  declare pnpm (there is no `.pnpmrc`-equivalent idiomatic version file for
  it either), so mise falls back to the global pin. That is the "installed
  base" — the binary on disk.
- `pnpm --version` is what pnpm self-routes to at runtime. With
  `.npmrc: manage-package-manager-versions = true` and
  `packageManager: pnpm@<version>` in `package.json`, the on-disk pnpm
  downloads the exact requested version on first invocation and shells out
  to it. Every subsequent call runs the requested version. That is
  authoritative.

Rule: to change the runtime pnpm every developer runs, edit the
`packageManager` field in `package.json` (and keep `engines.pnpm` in step).
To change the mise-cached base, edit `mise.toml`. They are independent
knobs and do not need to match.

Cross-repo variance is fine on the same principle. This machine's global
mise pins pnpm 11.10.0 and a sibling workspace's `mise.toml` pins 11.13.1;
each workspace's own `packageManager` still wins at runtime. A "drift"
report that quotes those base numbers next to a different `pnpm --version`
is describing three metadata sources, not a version that shifts between
calls. If `pnpm --version` is stable across repeated invocations from the
same cwd, the runtime is reproducible.

## Commit message discipline (commitlint-enforced)

Every commit passes commitlint at the pre-commit gate (Rule 15). Rules live in
`packages/shared/config/commitlint/base.json` — that JSON is the source of truth;
this section reflects it so a drafter can pass the gate first try.

### The silent trap: `#N` inline in the body

The parser is `conventional-changelog-conventionalcommits`. It treats a line
starting with `#N` (or containing `#N` on its own line) as a footer trailer,
even when the drafter wrote it as a mid-body reference. That flips
`footer-leading-blank` on: the "footer" is missing a blank line above it and
the commit is rejected. This is the single biggest reason a well-formed message
gets bounced.

Two ways to avoid it:

- Refer to issues by name or label in body prose: `LYCHEE-BROKEN-LINKS-SWEEP
issue`, `the branding-agnostic refactor`, etc. Never `See #98` or `part of
#115` inside a paragraph.
- If the reference belongs in a proper footer, put it there with a blank line
  above and one trailer per line: `Refs: #98` or `Closes: #115`. The blank
  line is what makes it a valid footer.

### Header (`type(scope): subject`)

- `type` (required, lower-case, from the enum): `feat`, `fix`, `docs`, `style`,
  `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`, `wip`.
- `scope` (kebab-case, from the enum in `base.json`): common values include
  `adr`, `ci`, `cli`, `config`, `deps`, `docs`, `format`, `hooks`, `lint`,
  `memory`, `readme`, `release`, `scripts`, `security`, `sync`, `workspace`,
  and the nested `config/tooling/*`, `schemas/*`, `secrets/*`, `utils/*`
  paths. Read `base.json` when in doubt; an unlisted scope fails the gate.
- `subject` is sentence-case (first word capitalized), no trailing period,
  10-72 characters. The whole header line is capped at 100 and floored at 15.

### Body

- One blank line between header and body (`body-leading-blank`).
- Wrap at 100 columns (`body-max-line-length`). Long URLs and code fences are
  still bound by this cap.
- Prose only; no `#N` trailers here (see the silent trap above).

### Footer

- One blank line between body and footer (`footer-leading-blank`).
- 100-column cap per line.
- Standard trailers: `Refs:`, `Closes:`, `BREAKING CHANGE:`, `Co-authored-by:`.
- `references-empty` warns at level 1: a warning, not a failure, but flags
  commits with no issue reference at all.

### Quick sanity

Before staging: type in the enum, scope in the enum, subject reads as a
sentence (Capital first word, no period, under 72 chars), no `#N` mid-body,
blank line above the footer. That covers the failures this repo actually
hits.

## Security Review Protocol

Applies whenever the task is assessing code, config, or infrastructure for
vulnerabilities and producing a finding (not building the PoC -- that's the next
protocol). The 13 rules above still hold; these add disclosure-specific
discipline. Bias: worst-plausible until source or deployment proves otherwise,
and a finding you can't refute is worth more than three you never tried to.
Best practice as of May 2026: coordinated vulnerability disclosure (CVD), CVSS
4.0, OWASP 2025, RFC 9116.

### SR1 -- Private first, always

Never a public issue, a PR title, a branch name, or a screenshot in an open
channel. A finding that describes how to take over a client account cannot sit
in a searchable thread. Draft privately and migrate each finding into a private
GitHub Security Advisory (GHSA) before it circulates. Coordinated disclosure is
the default posture, not a courtesy.

### SR2 -- One record per finding, scored

Stable ID (`SEC-nn`), affected component + the exact commit it was read at,
private repro, impact, remediation. Score with **CVSS 4.0** (fall back to 3.1
only when a consumer requires it) so severity is comparable and defensible
rather than a gut call. No finding ships without a vector; when deployment could
move it, publish the vector marked "proposed -- ratify in advisory" rather than
fabricating a precise number you can't stand behind.

### SR3 -- Verify against source at an exact commit; cite `file:line`

Every claim traces to lines you actually read, at a pinned SHA -- not a moving
branch. Read the whole path: exports, callers, the verifier AND the controller
that trusts it. Trace end-to-end before you rate. "Confirmed in source" and
"depends on deployment" are different evidence tiers; never present the second
as the first.

### SR4 -- Rate worst-plausible, then state the caveat that moves it

Source shows code and config, not running state. Assume the surface is reachable
and that nothing in front of it already neutralises the flaw -- then list the
exact deployment questions that would drop or raise the rating (edge/WAF,
network posture, storage access tier, whether a dangerous env value can reach a
live host). Terraform in the repo is not proof of running infrastructure; say so.

### SR5 -- Adversarially self-review; stand-downs stay visible

Before surfacing, try to DISPROVE each finding -- assume false positive until
you fail to refute it. Re-check against the pinned library version actually
deployed, not the latest docs. When a finding does not hold, re-rate it in place
with the verification shown ("stood down on the deployed version, here's why"),
never silently drop it. A visible stand-down is a stronger signal than a
confident bug.

### SR6 -- Route to an owner and to the account

Send each finding to the domain owner (`CODEOWNERS` / the service registry) AND
to whoever owns the client relationship, because several of these expose that
client's data. A finding with no named owner and no clock rots.

### SR7 -- Severity sets the clock

Tie a remediation SLA to severity in the advisory: Critical 24-72h · High <=7d ·
Medium <=30d · Low <=90d or an explicit, dated backlog entry. State it in the
record. A High with no date is how these rot. Sequence remediation by
exploitability, not by the severity label alone.

### SR8 -- Security checklist (OWASP 2025)

Secrets committed (keys/tokens/connection strings, default creds); injection
across every input vector (params, headers, bodies, uploads); authN + object-
level authZ on every endpoint (hunt IDOR / privilege escalation); token hygiene
-- issuer/audience/tenant pinning, identity keyed on an immutable `oid`/`sub`
never on a mutable email claim, explicit `algorithms` allow-lists; server-side
validation (reject over sanitise); network posture (public endpoints, allow-all
firewall rules, missing segmentation / private endpoints); supply chain (new or
updated deps, lockfile and CI/build edits, typosquatted or hallucinated
packages, build provenance); PII in logs and errors; every failure fails closed.

### SR9 -- Give outsiders a front door

Every client-facing repo and site carries a `SECURITY.md` (how to report, what's
in scope) and a `security.txt` (RFC 9116, served at `/.well-known/`). Without a
private channel, a researcher or the client's own team has nowhere to go but a
public thread.

### SR10 -- A decision, not a shrug (ADR / risk acceptance)

If you fix, the approach is a normal architecture decision -- record it as an
ADR. If the owner knowingly does not fix now, that is a dated risk-acceptance
record with an owner and an expiry, so "we accepted this" is never an unwritten
shrug. Some teams label these SDRs; it is an ADR with a threat in the context
section.

### SR11 -- Voice and evidence discipline

Distinguish evidence tiers explicitly ("I traced X and confirmed Y" vs. "this
reads as though"). Don't inflate a hunch into a confirmed bug, don't nit-flood
to look thorough, and write the advisory like a person: ration em-dashes, cut
filler intensifiers, no decorative emoji. An advisory is a record, not a chat
message.

## Security POC Protocol

Applies whenever the task is building or running a proof-of-concept that
demonstrates a finding (the `sec*-poc/` folders, `run-poc.sh`, evidence, the
`templates/security-poc` scaffold). The 13 rules and the Security Review
Protocol still hold; these add PoC-specific discipline. Bias: a PoC proves a
claim to a skeptic -- if the evidence can't be re-derived, it's a demo, not proof.

### SP1 -- Evidence by provenance, not by copy

A finding's evidence (the real Terraform, config, or source) must be
re-derivable, not a file you hand-typed. Pull it from the canonical repo at an
exact commit SHA and verify a recorded `sha256` -- that is the chain of custody.
Store only a pointer in the PoC repo (`repo@commit@path` + checksum), fetch on
demand, and gitignore the cache. Reference-not-copy also keeps the client's
source out of your repo, which is the correct confidentiality and licensing
posture for disclosure work. A hand-copied snapshot silently drifts and proves
nothing about the real system.

### SP2 -- One command, full cycle, always tears down

`./run-poc.sh` with no args runs the whole story: verify (provenance) -> up ->
attack -> fix-demo -> down. Expose the same stages as sub-commands. Teardown
(`docker compose down -v`, `terraform destroy`) is mandatory, idempotent, and
never skipped -- a PoC that leaves infrastructure running is a live cost and a
real exposed surface, not a proof.

### SP3 -- State what the model represents, and what proves the rest

When a local model stands in for the real system (Docker networks modelling
Azure reachability, a mock IdP modelling a real tenant), say so in one breath
and name the layer the model cannot prove -- then point at the thing that does
(the pinned real Terraform, a genuine signed token). A PoC that hides its
abstraction over-claims.

### SP4 -- Prove the consequence AND the fix

Demonstrate the exploit (read / wipe / impersonate) and then demonstrate the
remediation blocking the same actor (segmentation refusing the connection,
tenant pinning rejecting the forged token). A finding without a shown fix is
half a record; the fix demo is what makes the remediation credible.

### SP5 -- Least harm, throwaway only

Real-infrastructure modes deploy to a throwaway subscription/tenant, never to
production or anything sharing a client id / tenant / database with it, with the
cost stated and an explicit scope line. Any "leaked" credential in the repo is
obviously synthetic and labelled as such; no real secret is ever committed, and
the PoC never points at a client's running environment.

### SP6 -- Reproducible and self-contained runtime

Requires only documented tooling (Docker, and whatever the README pins). Pin
container images by tag or digest and seed deterministic data so the same
command yields the same observable result every run (N rows dumped,
`DELETE N` -> `0 rows`, `BLOCKED`). Non-determinism in a PoC reads as a flaky
claim.

### SP7 -- Stamp from the template; improve the template, don't fork it

Every PoC starts from `templates/security-poc` (the `run-poc.sh` skeleton,
`evidence.lock`, `fetch-evidence.sh`, the README standard, `SECURITY.md`,
`security.txt`, advisory + CVSS rubric, severity->SLA table). Don't reinvent the
harness per finding. When the harness needs to change, change it in the template
and migrate the existing PoCs, so every finding gets the same disclosure path by
default.

### SP8 -- README to the disclosure standard

Each PoC's `README.md` carries, faithfully from the private advisory with no
detail dropped in translation: the finding summary · severity + proposed CVSS
vector · affected component + exact commit · one-command repro · what you'll see
· the model/layer explanation (SP3) · the fix · a provenance block (SP1) ·
scope and safety · and a footer mapping the PoC to its GHSA advisory and
severity->SLA (SR7).

### SP9 -- Adversarial review before results are trusted

Sub-agents and workflows that build or verify a PoC get an adversarial review
pass -- a second agent tasked to refute the result (the exploit didn't really
run, the checksum wasn't really checked, the teardown didn't really happen)
before the finding is reported as confirmed. Applies only where the build is
large enough to warrant it; a one-line fix does not need a panel.

## Workflow: from finding to disclosed PoC

The lifecycle these protocols serve, end to end. Each step names the rule that governs it.

1. Read the source at a pinned commit; trace the whole path, the verifier and the caller
   that trusts it (SR3).
2. State the finding worst-plausible, with the deployment questions that would move the
   rating (SR4).
3. Try to refute it; re-check against the version actually deployed; keep a stand-down
   visible rather than dropping it (SR5).
4. Score it (CVSS 4.0, marked "proposed -- ratify" when deployment could move it) and open
   a private GHSA advisory with a stable `SEC-nn` id, an owner, and an SLA (SR1, SR2, SR6,
   SR7).
5. Stamp a PoC from `templates/security-poc`: fill `evidence.lock` with the pinned
   `repo@commit` + sha256, then adapt `run-poc.sh` and the compose model to the finding
   class -- network model for reachability findings, mock-service model for auth findings
   (SP1, SP3, SP7).
6. Prove it. `./run-poc.sh` fetches and verifies the evidence, demonstrates the
   consequence, then demonstrates the fix refusing the same actor, and tears down (SP2,
   SP4).
7. Write the README to the disclosure standard (SP8), then run an adversarial review of the
   result before calling it confirmed (SP9).
8. Record the decision: an ADR for the fix, a dated risk-acceptance record if the owner
   defers (SR10). Disclose per the SLA.
