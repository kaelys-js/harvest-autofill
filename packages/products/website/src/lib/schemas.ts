import * as v from "valibot";

// Shape of the GitHub "latest release" response, limited to the fields the site reads.
// v.object ignores unknown keys, so the many other fields GitHub returns pass through
// harmlessly while the ones we depend on are validated.
export const GithubReleaseSchema = v.object({
	tag_name: v.string(),
	name: v.optional(v.nullable(v.string())),
	html_url: v.optional(v.string()),
	body: v.optional(v.nullable(v.string())),
	published_at: v.optional(v.string()),
	assets: v.optional(
		v.array(
			v.object({
				name: v.string(),
				browser_download_url: v.string(),
			}),
		),
	),
});

export type GithubRelease = v.InferOutput<typeof GithubReleaseSchema>;

// Validate a fetched release; returns null on any shape mismatch so callers fall back
// cleanly rather than trusting an unverified network payload.
export function parseRelease(data: unknown): GithubRelease | null {
	const result = v.safeParse(GithubReleaseSchema, data);
	return result.success ? result.output : null;
}
