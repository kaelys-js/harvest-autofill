import * as v from "valibot";

// A MAJOR.MINOR[.PATCH] app version, with an optional leading "v" stripped. Used to validate
// the release tag / build-injected version before it is shown anywhere.
export const VersionSchema = v.pipe(
	v.string(),
	v.transform((s) => s.replace(/^v/u, "")),
	v.regex(/^\d+\.\d+(\.\d+)?$/u, "expected MAJOR.MINOR[.PATCH]"),
);

export function parseVersion(input: unknown): string | null {
	const result = v.safeParse(VersionSchema, input);
	return result.success ? result.output : null;
}

// Shape of the GitHub "latest release" response, limited to the fields the site reads and
// validated strictly: a version-like tag, real URLs, and an ISO timestamp. v.object ignores
// the many other keys GitHub returns.
export const GithubReleaseSchema = v.object({
	tag_name: v.pipe(v.string(), v.regex(/^v?\d+\.\d+/u, "expected a version tag")),
	name: v.optional(v.nullable(v.string())),
	html_url: v.optional(v.pipe(v.string(), v.url())),
	body: v.optional(v.nullable(v.string())),
	published_at: v.optional(v.pipe(v.string(), v.isoTimestamp())),
	assets: v.optional(
		v.array(
			v.object({
				name: v.string(),
				browser_download_url: v.pipe(v.string(), v.url()),
			}),
		),
	),
});

export type GithubRelease = v.InferOutput<typeof GithubReleaseSchema>;

// Validate a fetched release; returns null on any shape mismatch so callers fall back cleanly
// rather than trusting an unverified network payload.
export function parseRelease(data: unknown): GithubRelease | null {
	const result = v.safeParse(GithubReleaseSchema, data);
	return result.success ? result.output : null;
}
