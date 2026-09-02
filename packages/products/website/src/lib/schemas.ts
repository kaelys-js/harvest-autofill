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

// Internal content constants are validated at build time too, not just network payloads. A
// FAQ item drives both the on-page accordion and the FAQPage JSON-LD, so a blank question or
// answer would ship a malformed rich-result. Parsing the array at module load turns a typo
// into a build failure instead of silent bad markup.
export const FaqItemSchema = v.object({
	q: v.pipe(v.string(), v.trim(), v.minLength(1, "FAQ question must not be empty")),
	a: v.pipe(v.string(), v.trim(), v.minLength(1, "FAQ answer must not be empty")),
});

export type FaqItem = v.InferOutput<typeof FaqItemSchema>;

export const FaqItemsSchema = v.pipe(
	v.array(FaqItemSchema),
	v.minLength(1, "at least one FAQ item is required"),
);

// ---------------------------------------------------------------------------
// Internal content constants
//
// The rest of this file validates the site's own hard-coded content at build time. These
// arrays can't be "wrong" at runtime the way a network payload can, but a bad edit (a blank
// title, an unknown project key, a mistyped time range, a base path that's actually a full
// URL) would ship broken markup, a broken layout, or a broken canonical URL silently. Parsing
// each array where it's defined turns those edits into a build failure instead. Single-consumer
// content is validated in place; only cross-consumer content (the FAQ, read by both the
// accordion and the JSON-LD) is lifted into a shared data module.
// ---------------------------------------------------------------------------

const NonEmpty = v.pipe(v.string(), v.trim(), v.minLength(1, "must not be empty"));

// Reusable guards so every data const — not just external payloads — is parsed rather than
// trusted. TypeScript's types are erased at runtime; these throw at build if a value's actual
// shape drifts from what the code assumes (a mistyped URL, a blank title, a bad slug).
export const UrlSchema = v.pipe(v.string(), v.url("expected a URL"));
export function parseUrl(input: unknown): string {
	return v.parse(UrlSchema, input);
}

export const RepoSlugSchema = v.pipe(
	v.string(),
	v.regex(/^[\w.-]+\/[\w.-]+$/u, "expected an owner/repo slug"),
);
export function parseRepoSlug(input: unknown): string {
	return v.parse(RepoSlugSchema, input);
}

export function parseNonEmpty(input: unknown): string {
	return v.parse(NonEmpty, input);
}

export const PositiveIntSchema = v.pipe(v.number(), v.integer(), v.minValue(1));
export function parsePositiveInt(input: unknown): number {
	return v.parse(PositiveIntSchema, input);
}

// A schema.org JSON-LD graph — a context plus one or more typed nodes. Node shapes vary, so
// each is a loose object that only has to carry a non-empty @type; parsing guards the graph is
// well-formed before it is serialised into the page head.
export const StructuredDataSchema = v.object({
	"@context": v.literal("https://schema.org"),
	"@graph": v.pipe(
		v.array(v.looseObject({ "@type": v.pipe(v.string(), v.minLength(1)) })),
		v.minLength(1, "the graph needs at least one node"),
	),
});

// An Astro base path: either "" (site at root) or a rooted path like "/harvest-autofill".
// Never a full URL — the whole site prefixes this onto asset and canonical URLs, so a stray
// "https://…" here would corrupt every link.
export const BasePathSchema = v.pipe(
	v.string(),
	v.regex(/^(|\/[A-Za-z0-9._~-]+(\/[A-Za-z0-9._~-]+)*)$/u, "expected '' or a rooted path"),
);

export function parseBasePath(input: unknown): string {
	return v.parse(BasePathSchema, input);
}

// SVG path data for the mockups' inline icons — non-empty and limited to the path-data grammar,
// so a truncated or accidentally-HTML string fails the build instead of rendering an empty icon.
const SvgPathSchema = v.pipe(
	v.string(),
	v.trim(),
	v.minLength(1, "SVG path must not be empty"),
	v.regex(/^[MmLlHhVvCcSsQqTtAaZz0-9\s.,-]+$/u, "expected SVG path data"),
);

export const FeatureSchema = v.object({
	icon: NonEmpty, // lucide icon name rendered by Icon.astro
	title: NonEmpty,
	body: NonEmpty,
});
export const FeaturesSchema = v.pipe(v.array(FeatureSchema), v.minLength(1));

export const HowItWorksStepSchema = v.object({ n: NonEmpty, title: NonEmpty, body: NonEmpty });
export const HowItWorksStepsSchema = v.pipe(v.array(HowItWorksStepSchema), v.minLength(1));

// Onboarding wizard slides (OnboardingCarousel.tsx): copy plus a Lucide icon component that
// mirrors the matching step's SF Symbol in the app.
export const OnboardingStepSchema = v.object({
	title: NonEmpty,
	body: NonEmpty,
	icon: NonEmpty, // inline lucide SVG paths for the step, rendered in OnboardingCarousel.astro
});
export const OnboardingStepsSchema = v.pipe(v.array(OnboardingStepSchema), v.minLength(1));

export const PrefsRowSchema = v.object({ title: NonEmpty, body: NonEmpty });
export const PrefsTabSchema = v.object({
	name: NonEmpty,
	path: SvgPathSchema,
	rows: v.pipe(v.array(PrefsRowSchema), v.minLength(1)),
});
export const PrefsTabsSchema = v.pipe(v.array(PrefsTabSchema), v.minLength(1));

export const NotesSchema = v.pipe(v.array(NonEmpty), v.minLength(1));

// The "This week" window mockup (WindowMockup.astro). The project must be one of the known
// keys the dot-colour map covers, times must read "h:mm AM–h:mm PM", and hours must read "Nh".
export const MOCKUP_PROJECTS = ["Website", "Design", "Mobile App", "Internal"] as const;
export const MockupRowSchema = v.object({
	span: v.pipe(
		v.string(),
		v.regex(/^\d{1,2}:\d{2}\s(?:AM|PM)–\d{1,2}:\d{2}\s(?:AM|PM)$/u, "expected 'h:mm AM–h:mm PM'"),
	),
	project: v.picklist(MOCKUP_PROJECTS),
	task: NonEmpty,
	hours: v.pipe(v.string(), v.regex(/^\d+(?:\.\d+)?h$/u, "expected 'Nh'")),
});
export const MockupDaySchema = v.object({
	name: NonEmpty,
	total: v.string(), // "" on a skipped/holiday day
	note: v.optional(v.string()),
	rows: v.array(MockupRowSchema),
});
export const MockupDaysSchema = v.pipe(v.array(MockupDaySchema), v.minLength(1));

// The mockup's project → dot-colour map: every key must be a known project and every value a
// non-empty class, so a project can never render without a colour.
export const DotMapSchema = v.record(
	v.picklist(MOCKUP_PROJECTS),
	v.pipe(v.string(), v.minLength(1)),
);

// Props for the DownloadButton island. Astro serialises island props across the server→client
// hydration boundary, so the size is validated on mount (falling back to "lg") rather than
// trusted — and the prop type is inferred from this schema so there's a single source.
export const DownloadSizeSchema = v.picklist(["lg", "default"]);
export type DownloadSize = v.InferOutput<typeof DownloadSizeSchema>;

export function parseDownloadSize(input: unknown): DownloadSize {
	const result = v.safeParse(DownloadSizeSchema, input);
	return result.success ? result.output : "lg";
}
