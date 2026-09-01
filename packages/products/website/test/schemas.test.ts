import { describe, expect, it } from "vitest";
import { parseRelease } from "@/lib/schemas";

describe("parseRelease", () => {
	it("accepts a valid GitHub release and returns the tag", () => {
		const release = parseRelease({
			tag_name: "v2.19",
			html_url: "https://github.com/x/y/releases/tag/v2.19",
			assets: [{ name: "HarvestAutoFill.zip", browser_download_url: "https://x/y.zip" }],
			// extra fields GitHub returns are ignored, not rejected
			author: { login: "octocat" },
		});
		expect(release?.tag_name).toBe("v2.19");
	});

	it("rejects a payload missing tag_name (returns null, no throw)", () => {
		expect(parseRelease({ name: "no tag here" })).toBeNull();
	});

	it("rejects a wrong-typed tag_name", () => {
		expect(parseRelease({ tag_name: 219 })).toBeNull();
	});

	it("rejects non-object payloads", () => {
		expect(parseRelease(null)).toBeNull();
		expect(parseRelease("v2.19")).toBeNull();
	});
});
