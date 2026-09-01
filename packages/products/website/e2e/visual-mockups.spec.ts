import { expect, test, type Page } from "@playwright/test";

// Visual regression for every interactive mockup STATE, not just the default one the section
// shots capture: each onboarding step, each preferences tab, and the FAQ opened. reduced-motion
// pins the animated components to their end state so the shot is deterministic.
//
// The carousel and preferences mockups are fixed-width (max-w-md), so their per-state shots run
// on desktop only — the responsive section shots (visual.spec.ts) already cover both viewports at
// the default state, and only the content differs between states. The FAQ is full-width, so its
// open state is captured on both viewports.

const themes: { name: string; apply: (page: Page) => Promise<void> }[] = [
	{ name: "light", apply: (page) => page.emulateMedia({ colorScheme: "light" }) },
	{
		name: "dark",
		apply: (page) => page.evaluate(() => document.documentElement.classList.add("dark")),
	},
];

test.describe("visual — onboarding steps", () => {
	test.beforeEach(async ({ page }) => {
		test.skip(test.info().project.name !== "desktop", "fixed-width; desktop only");
		await page.emulateMedia({ reducedMotion: "reduce" });
		await page.goto("./");
		await expect(page.getByRole("heading", { name: "Welcome to Harvest Auto-Fill" })).toBeVisible();
	});

	for (let step = 0; step < 6; step++) {
		for (const theme of themes) {
			test(`step ${step + 1} — ${theme.name}`, async ({ page }) => {
				await theme.apply(page);
				await page.locator(`[data-onb-dot="${step}"]`).click();
				await expect(page.locator(`[data-onb-slide="${step}"][data-active]`)).toBeVisible();
				await expect(page.locator("[data-onb-carousel]")).toHaveScreenshot(
					`onb-step-${step + 1}-${theme.name}.png`,
					{ animations: "disabled" },
				);
			});
		}
	}
});

test.describe("visual — preferences tabs", () => {
	const TABS = ["general", "accounts", "allocation", "about"];
	test.beforeEach(async ({ page }) => {
		test.skip(test.info().project.name !== "desktop", "fixed-width; desktop only");
		await page.emulateMedia({ reducedMotion: "reduce" });
		await page.goto("./");
		await expect(page.locator("[data-prefs-mockup]")).toBeVisible();
	});

	TABS.forEach((tab, n) => {
		for (const theme of themes) {
			test(`${tab} — ${theme.name}`, async ({ page }) => {
				await theme.apply(page);
				await page.locator(`[data-prefs-tab="${n}"]`).click();
				await expect(page.locator(`[data-prefs-panel="${n}"][data-active]`)).toBeVisible();
				await expect(page.locator("[data-prefs-mockup]")).toHaveScreenshot(
					`prefs-${tab}-${theme.name}.png`,
					{ animations: "disabled" },
				);
			});
		}
	});
});

test.describe("visual — FAQ open", () => {
	test.beforeEach(async ({ page }) => {
		await page.emulateMedia({ reducedMotion: "reduce" });
		await page.goto("./");
	});

	for (const theme of themes) {
		test(`expanded — ${theme.name}`, async ({ page }) => {
			await theme.apply(page);
			const first = page.locator(".faq-item").first();
			await first.locator("summary").click();
			await expect(first).toHaveAttribute("open", "");
			await expect(page.locator("#faq")).toHaveScreenshot(`faq-open-${theme.name}.png`, {
				animations: "disabled",
			});
		});
	}
});
