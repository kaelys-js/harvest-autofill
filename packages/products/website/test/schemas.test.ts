import { describe, expect, it } from "vitest";
import * as v from "valibot";
import {
	parseRelease,
	parseVersion,
	parseBasePath,
	parseDownloadSize,
	parseUrl,
	parseRepoSlug,
	parseNonEmpty,
	parsePositiveInt,
	StructuredDataSchema,
	DotMapSchema,
	BasePathSchema,
	FaqItemsSchema,
	FeaturesSchema,
	HowItWorksStepsSchema,
	OnboardingStepsSchema,
	PrefsTabsSchema,
	NotesSchema,
	MockupDaysSchema,
} from "@/lib/schemas";
import { faqItems } from "@/data/faq";

const ok = (schema: Parameters<typeof v.safeParse>[0], value: unknown) =>
	v.safeParse(schema, value).success;

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

describe("parseBasePath", () => {
	it("accepts the site root and a rooted deploy path", () => {
		expect(parseBasePath("")).toBe("");
		expect(parseBasePath("/harvest-autofill-releases")).toBe("/harvest-autofill-releases");
	});

	it("rejects a full URL or an unrooted path — the values that would corrupt every link", () => {
		expect(ok(BasePathSchema, "https://example.com")).toBe(false);
		expect(ok(BasePathSchema, "harvest-autofill-releases")).toBe(false);
		expect(ok(BasePathSchema, "/trailing/")).toBe(false);
		expect(ok(BasePathSchema, 42)).toBe(false);
	});
});

describe("data-const guards", () => {
	it("parseUrl accepts real URLs and rejects non-URLs", () => {
		expect(parseUrl("https://github.com/x/y")).toBe("https://github.com/x/y");
		expect(() => parseUrl("not a url")).toThrow();
		expect(() => parseUrl("/relative/path")).toThrow();
		expect(() => parseUrl(42)).toThrow();
	});

	it("parseRepoSlug accepts owner/repo and rejects a full URL or bare word", () => {
		expect(parseRepoSlug("kaelys-js/harvest-autofill-releases")).toBe(
			"kaelys-js/harvest-autofill-releases",
		);
		expect(() => parseRepoSlug("https://github.com/x/y")).toThrow();
		expect(() => parseRepoSlug("justowner")).toThrow();
	});

	it("parseNonEmpty rejects blank and non-strings", () => {
		expect(parseNonEmpty("Title")).toBe("Title");
		expect(() => parseNonEmpty("   ")).toThrow();
		expect(() => parseNonEmpty(null)).toThrow();
	});

	it("parsePositiveInt rejects zero, negatives, and non-integers", () => {
		expect(parsePositiveInt(5000)).toBe(5000);
		expect(() => parsePositiveInt(0)).toThrow();
		expect(() => parsePositiveInt(-1)).toThrow();
		expect(() => parsePositiveInt(1.5)).toThrow();
	});

	it("StructuredDataSchema requires a schema.org context and at least one typed node", () => {
		expect(
			ok(StructuredDataSchema, {
				"@context": "https://schema.org",
				"@graph": [{ "@type": "WebSite" }],
			}),
		).toBe(true);
		expect(
			ok(StructuredDataSchema, {
				"@context": "https://example.com",
				"@graph": [{ "@type": "WebSite" }],
			}),
		).toBe(false);
		expect(ok(StructuredDataSchema, { "@context": "https://schema.org", "@graph": [] })).toBe(
			false,
		);
		expect(
			ok(StructuredDataSchema, {
				"@context": "https://schema.org",
				"@graph": [{ name: "no type" }],
			}),
		).toBe(false);
	});

	it("DotMapSchema rejects an unknown project key or an empty colour class", () => {
		expect(ok(DotMapSchema, { Website: "bg-[#f2762a]", Internal: "bg-[#6b78f6]" })).toBe(true);
		expect(ok(DotMapSchema, { Marketing: "bg-red-500" })).toBe(false);
		expect(ok(DotMapSchema, { Website: "" })).toBe(false);
	});
});

describe("parseDownloadSize", () => {
	it("passes through the two valid sizes", () => {
		expect(parseDownloadSize("lg")).toBe("lg");
		expect(parseDownloadSize("default")).toBe("default");
	});

	it("falls back to 'lg' for anything a bad hydration payload could carry", () => {
		expect(parseDownloadSize("huge")).toBe("lg");
		expect(parseDownloadSize(undefined)).toBe("lg");
		expect(parseDownloadSize(null)).toBe("lg");
		expect(parseDownloadSize(3)).toBe("lg");
	});
});

describe("content constants", () => {
	it("the shipped FAQ validates and drives at least one question", () => {
		expect(faqItems.length).toBeGreaterThan(0);
		expect(ok(FaqItemsSchema, faqItems)).toBe(true);
	});

	it("FAQ rejects a blank question, blank answer, or empty list", () => {
		expect(ok(FaqItemsSchema, [{ q: "  ", a: "real" }])).toBe(false);
		expect(ok(FaqItemsSchema, [{ q: "real", a: "" }])).toBe(false);
		expect(ok(FaqItemsSchema, [])).toBe(false);
	});

	it("features and how-it-works steps reject blank copy", () => {
		// icon is now a lucide name rendered by Icon.astro (a non-empty string), not a component.
		expect(ok(FeaturesSchema, [{ icon: "calendar-check", title: "t", body: "b" }])).toBe(true);
		expect(ok(FeaturesSchema, [{ icon: "calendar-check", title: "", body: "b" }])).toBe(false);
		expect(ok(FeaturesSchema, [{ icon: "", title: "t", body: "b" }])).toBe(false); // blank icon
		expect(ok(FeaturesSchema, [{ title: "t", body: "b" }])).toBe(false); // missing icon
		expect(ok(HowItWorksStepsSchema, [{ n: "1", title: "t", body: "b" }])).toBe(true);
		expect(ok(HowItWorksStepsSchema, [{ n: "1", title: "t", body: " " }])).toBe(false);
	});

	it("onboarding and preferences reject a missing icon and empty rows", () => {
		// onboarding icon is now an inline SVG string, not a component.
		expect(ok(OnboardingStepsSchema, [{ title: "t", body: "b", icon: "<path/>" }])).toBe(true);
		expect(ok(OnboardingStepsSchema, [{ title: "t", body: "b" }])).toBe(false); // missing icon
		expect(
			ok(PrefsTabsSchema, [{ name: "General", path: "M1 2", rows: [{ title: "t", body: "b" }] }]),
		).toBe(true);
		expect(ok(PrefsTabsSchema, [{ name: "General", path: "M1 2", rows: [] }])).toBe(false);
	});

	it("what's-new notes reject a blank line and an empty list", () => {
		expect(ok(NotesSchema, ["a change"])).toBe(true);
		expect(ok(NotesSchema, ["a change", "  "])).toBe(false);
		expect(ok(NotesSchema, [])).toBe(false);
	});
});

describe("MockupDaysSchema", () => {
	const day = (rows: unknown[]) => [{ name: "Mon Aug 31", total: "9h", rows }];

	it("accepts a real day and a skipped (empty-total, no-rows) day", () => {
		expect(
			ok(
				MockupDaysSchema,
				day([{ span: "9:00 AM–1:30 PM", project: "Website", task: "Development", hours: "4.5h" }]),
			),
		).toBe(true);
		expect(
			ok(MockupDaysSchema, [{ name: "Wed Sep 2", total: "", note: "Holiday", rows: [] }]),
		).toBe(true);
	});

	it("rejects an unknown project key (it would render with no dot colour)", () => {
		expect(
			ok(
				MockupDaysSchema,
				day([{ span: "9:00 AM–1:30 PM", project: "Marketing", task: "x", hours: "1h" }]),
			),
		).toBe(false);
	});

	it("rejects a 24h-style time range and an hours value missing its 'h'", () => {
		expect(
			ok(
				MockupDaysSchema,
				day([{ span: "9:00–13:30", project: "Website", task: "x", hours: "4.5h" }]),
			),
		).toBe(false);
		expect(
			ok(
				MockupDaysSchema,
				day([{ span: "9:00 AM–1:30 PM", project: "Website", task: "x", hours: "4.5" }]),
			),
		).toBe(false);
	});
});
