import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

// End-to-end accessibility gate. axe-core runs against WCAG 2.0/2.1/2.2 A + AA (the standard as of
// 2026) plus axe's best-practice rules, under both the desktop and mobile Playwright projects (so
// touch-target and small-viewport rules are exercised too). Any violation fails the build. axe
// covers the machine-checkable ~57%; the human-judgement rules (focus order, meaningful sequence,
// real alt text) are held by the review rubric, not this gate.
const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"];

async function scan(page: Page, label: string) {
	// Settle the page so axe measures final colours, never a mid-animation frame: kill every
	// animation/transition outright, and force the reveal/stagger/hero elements to their opaque
	// end state. (reducedMotion already disables them, but forcing the end state too removes any
	// render-timing flake in the contrast numbers.)
	await page.addStyleTag({
		content: "*,*::before,*::after{animation:none!important;transition:none!important}",
	});
	await page.evaluate(() =>
		document
			.querySelectorAll("[data-reveal],[data-stagger],[data-hero]")
			.forEach((el) => el.classList.add("is-visible")),
	);
	// The "This Week" and "What's New" windows are role="img" with descriptive aria-labels —
	// decorative recreations exposed to AT as a single image. Their inner pixel-text is
	// presentational (like text inside a screenshot, which WCAG exempts from contrast), so exclude
	// them; every real UI surface (nav, buttons, links, copy, FAQ, the interactive mockups) is
	// still scanned.
	const { violations } = await new AxeBuilder({ page })
		.withTags(TAGS)
		.exclude('[role="img"]')
		.analyze();
	// One line per failing node — rule, element, and any contrast data — so a failure names
	// exactly what to fix.
	const summary = violations.flatMap((v) =>
		v.nodes.map((n) => {
			const data = n.any?.[0]?.data;
			const extra = data?.contrastRatio
				? ` [ratio ${data.contrastRatio} < ${data.expectedContrastRatio}, fg ${data.fgColor} on ${data.bgColor}]`
				: "";
			return `${v.id} (${v.impact}) ${n.target.join(" ")}${extra}`;
		}),
	);
	expect(summary, `${label} — axe violations:\n${summary.join("\n")}`).toEqual([]);
}

test("a11y — landing page (light)", async ({ page }) => {
	await page.emulateMedia({ colorScheme: "light", reducedMotion: "reduce" });
	await page.goto("./");
	await scan(page, "light");
});

test("a11y — landing page (dark)", async ({ page }) => {
	await page.emulateMedia({ reducedMotion: "reduce" });
	await page.goto("./");
	await page.evaluate(() => document.documentElement.classList.add("dark"));
	await scan(page, "dark");
});

test("a11y — FAQ expanded", async ({ page }) => {
	await page.emulateMedia({ reducedMotion: "reduce" });
	await page.goto("./");
	await page.locator("#faq summary").first().click();
	await scan(page, "faq-open");
});
