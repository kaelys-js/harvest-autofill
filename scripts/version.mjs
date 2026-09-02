#!/usr/bin/env node
// Keeps VERSION and CHANGELOG.md in lockstep with the release tag. VERSION is the canonical,
// hand-maintained version string (the app + site read it from the git tag at release time, which
// this gate proves equals VERSION). Two modes:
//
//   node scripts/version.mjs --check         verify VERSION matches CHANGELOG's top released
//                                            heading; exit non-zero on drift (the pre-push/CI gate)
//   node scripts/version.mjs --notes v2.32   release gate: verify the tag matches VERSION and a
//                                            released CHANGELOG section, then print that section
//                                            to stdout as the GitHub Release body
//
// Node builtins only, so it runs on a bare runner with no install step.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const fail = (msg) => {
	console.error(`version: ${msg}`);
	process.exit(1);
};

const version = readFileSync(join(root, "VERSION"), "utf8").trim();
const changelog = readFileSync(join(root, "CHANGELOG.md"), "utf8");

// The topmost RELEASED heading (skipping "## [Unreleased]").
const topReleased = [...changelog.matchAll(/^## \[([^\]]+)\]/gm)]
	.map((m) => m[1])
	.find((v) => v.toLowerCase() !== "unreleased");

const args = process.argv.slice(2);

if (args.includes("--check")) {
	if (topReleased !== version) {
		fail(
			`VERSION (${version}) != CHANGELOG.md top released heading (${topReleased ?? "none"}) — ` +
				`bump both together, or add a "## [${version}] - <date>" section`,
		);
	}
	console.log(`version: VERSION and CHANGELOG top heading match (${version})`);
	process.exit(0);
}

const notesIdx = args.indexOf("--notes");
if (notesIdx !== -1) {
	const tag = args[notesIdx + 1];
	if (!tag) {
		fail("usage: version.mjs --notes <tag>  # tag like v1.2.3");
	}
	const tagVersion = tag.replace(/^v/, "");
	if (tagVersion !== version) {
		fail(`tag ${tag} (${tagVersion}) != VERSION (${version})`);
	}
	if (topReleased !== version) {
		fail(`tag ${tag} has no matching "## [${version}]" section at the top of CHANGELOG.md`);
	}
	const escaped = version.replaceAll(/[.*+?^${}()|[\]\\]/g, String.raw`\$&`);
	const section = changelog.match(
		new RegExp(`^## \\[${escaped}\\][^\\n]*\\n([\\s\\S]*?)(?=^## |^\\[)`, "m"),
	)?.[1];
	const notes = section?.trim();
	if (!notes) {
		fail(`the "## [${version}]" section in CHANGELOG.md is empty`);
	}
	process.stdout.write(`${notes}\n`);
	process.exit(0);
}

fail("usage: version.mjs --check | --notes <tag>");
