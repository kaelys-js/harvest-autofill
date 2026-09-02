import { expect, test } from "@playwright/test";

// reduced-motion disables the carousel's auto-advance, so step assertions are deterministic.
// Set on the page before each test's own navigation (the page method is precisely typed,
// unlike `test.use({ reducedMotion })` which TS7 can't resolve through Playwright's Fixtures).
test.beforeEach(async ({ page }) => {
	await page.emulateMedia({ reducedMotion: "reduce" });
});

// Every slide/panel stays in the DOM (only the active one is opaque + interactive), so assertions
// target the [data-active] element rather than mere text presence — opacity:0 still counts as
// "visible" to Playwright, so a text-presence check would pass without the switch happening. The
// click is retried until the active slide/panel has actually switched, to ride out hydration.
async function switchTo(
	scope: import("@playwright/test").Locator,
	tab: string | RegExp,
	activeSelector: string,
	marker: string,
) {
	await expect(async () => {
		await scope.getByRole("tab", { name: tab }).click();
		await expect(scope.locator(`${activeSelector}[data-active]`)).toContainText(marker, {
			timeout: 1000,
		});
	}).toPass({ timeout: 10000 });
}

test.describe("made to feel native", () => {
	test("onboarding carousel steps through all six screens", async ({ page }) => {
		await page.goto("./");
		const carousel = page.locator("[data-onb-carousel]");
		const titles = [
			"Connect your Harvest account",
			"Find your projects automatically",
			"Where your work lives",
			"Your workday",
			"Here's your week",
		];
		for (const [i, title] of titles.entries()) {
			await switchTo(carousel, new RegExp(`^Step ${i + 2}:`), "[data-onb-slide]", title);
		}
		// Next from the last step wraps back to Welcome.
		await carousel.getByRole("button", { name: "Next step" }).click();
		await expect(carousel.locator("[data-onb-slide][data-active]")).toContainText(
			"Welcome to Harvest Auto-Fill",
		);
	});

	test("preferences mockup switches between all four tabs", async ({ page }) => {
		await page.goto("./");
		const prefs = page.locator("[data-prefs-mockup]");
		await expect(prefs.locator("[data-prefs-panel][data-active]")).toContainText(
			"Automatic logging",
		);
		const tabs: [string, string][] = [
			["Accounts", "Where your hours are written."],
			["Allocation", "How commits, pushes, and meetings are weighted across your projects."],
			["About", "Stored on this Mac, in a spot only the app can read."],
			["General", "Logs your week to Harvest every Friday at 6:00 PM, even if the app is closed."],
		];
		for (const [tab, marker] of tabs) {
			await switchTo(prefs, tab, "[data-prefs-panel]", marker);
		}
	});

	// The auto-advance must not run until the mockup is on screen (a carousel nobody's looking at
	// shouldn't burn cycles), and must run once it is. Motion is allowed here so the timer is live.
	test("carousel auto-advances only once scrolled into view", async ({ page }) => {
		await page.emulateMedia({ reducedMotion: "no-preference" });
		await page.goto("./");
		const carousel = page.locator("[data-onb-carousel]");
		const step = carousel.locator("[data-onb-step]");
		// Below the fold on load: still on step 1 after more than one auto-advance interval (5s).
		await expect(step).toHaveText("Step 1 of 6");
		await page.waitForTimeout(5600);
		await expect(step).toHaveText("Step 1 of 6");
		// Scroll it into view; now the interval elapses and it advances.
		await carousel.scrollIntoViewIfNeeded();
		await expect(step).toHaveText("Step 2 of 6", { timeout: 7000 });
	});
});
