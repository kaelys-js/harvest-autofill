import { describe, expect, it } from "vitest";
import { parseRelease, parseVersion } from "@/lib/schemas";

describe("parseVersion", () => {
	it("accepts MAJOR.MINOR[.PATCH] and strips a leading v", () => {
		expect(parseVersion("v2.19")).toBe("2.19");
		expect(parseVersion("2.19.1")).toBe("2.19.1");
	});

	it("rejects non-version strings and non-strings", () => {
		expect(parseVersion("garbage")).toBeNull();
		expect(parseVersion("v2")).toBeNull();
		expect(parseVersion("")).toBeNull();
		expect(parseVersion(219)).toBeNull();
		expect(parseVersion(undefined)).toBeNull();
	});
});

describe("parseRelease", () => {
	it("accepts a well-formed release and returns the tag", () => {
		const release = parseRelease({
			tag_name: "v2.19",
			html_url: "https://github.com/x/y/releases/tag/v2.19",
			published_at: "2026-08-31T21:01:08Z",
			assets: [{ name: "HarvestAutoFill.zip", browser_download_url: "https://x/y.zip" }],
			author: { login: "octocat" }, // extra fields are ignored
		});
		expect(release?.tag_name).toBe("v2.19");
	});

	it("rejects a non-version tag", () => {
		expect(parseRelease({ tag_name: "nightly" })).toBeNull();
		expect(parseRelease({ tag_name: 219 })).toBeNull();
	});

	it("rejects a non-URL html_url or asset url", () => {
		expect(parseRelease({ tag_name: "v2.19", html_url: "not a url" })).toBeNull();
		expect(
			parseRelease({ tag_name: "v2.19", assets: [{ name: "z", browser_download_url: "nope" }] }),
		).toBeNull();
	});

	it("rejects a non-ISO published_at", () => {
		expect(parseRelease({ tag_name: "v2.19", published_at: "yesterday" })).toBeNull();
	});

	it("rejects missing tag or non-objects", () => {
		expect(parseRelease({ name: "no tag" })).toBeNull();
		expect(parseRelease(null)).toBeNull();
		expect(parseRelease("v2.19")).toBeNull();
	});
});
