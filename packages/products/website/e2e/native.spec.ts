import { expect, test } from "@playwright/test";

// reduced-motion disables the carousel's auto-advance, so step assertions are deterministic.
// Set on the page before each test's own navigation (the page method is precisely typed,
// unlike `test.use({ reducedMotion })` which TS7 can't resolve through Playwright's fixtures).
test.beforeEach(async ({ page }) => {
	await page.emulateMedia({ reducedMotion: "reduce" });
});

// Every slide/panel stays in the DOM (only the active one is opaque + interactive), so assertions
// target the [data-active] element rather than mere text presence: Playwright treats opacity:0
// elements as visible, so a text-presence check would pass without the switch happening. The
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

	// The demo is the app's "This week" window (in #demo) filling itself day by day. Days carry
	// an .is-shown class as they fill in, so assertions count that class rather than visibility.
	test("demo: reduced-motion shows the finished week and does not autoplay", async ({ page }) => {
		await page.goto("./#demo"); // beforeEach emulates reduced-motion
		const demo = page.locator("[data-demo]");
		await expect(demo.locator("[data-demo-summary]")).toHaveText(/36h across 4 days/);
		await expect(demo.locator("[data-demo-day].is-shown")).toHaveCount(5);
		await expect(demo.locator("[data-demo-toggle]")).toHaveAttribute("aria-label", "Play demo");
	});

	test("demo: the Play/Pause control stops and restarts the fill", async ({ page }) => {
		// Motion allowed so the week autoplays; the control must be able to stop it (WCAG 2.2.2).
		await page.emulateMedia({ reducedMotion: "no-preference" });
		await page.goto("./#demo");
		const toggle = page.locator("[data-demo] [data-demo-toggle]");
		await expect(toggle).toHaveAttribute("aria-label", "Pause demo");
		await toggle.click();
		await expect(toggle).toHaveAttribute("aria-label", "Play demo");
		await toggle.click();
		await expect(toggle).toHaveAttribute("aria-label", "Pause demo");
	});

	test("demo starts filling the week only after it scrolls into view", async ({ page }) => {
		await page.emulateMedia({ reducedMotion: "no-preference" });
		// A short viewport keeps #demo below the fold on load so the lazy-start gate is exercised.
		await page.setViewportSize({ width: 1280, height: 600 });
		await page.goto("./");
		const demo = page.locator("[data-demo]");
		const shown = demo.locator("[data-demo-day].is-shown");
		await expect(shown).toHaveCount(0);
		await page.waitForTimeout(1600);
		await expect(shown).toHaveCount(0); // still empty while below the fold
		await demo.scrollIntoViewIfNeeded();
		// Once visible, the week fills in day by day up to all five rows.
		await expect.poll(() => shown.count(), { timeout: 6000 }).toBeGreaterThan(0);
		await expect.poll(() => shown.count(), { timeout: 12000 }).toBe(5);
	});

	// The auto-advance must skip the timer while the mockup is off-screen and start it once the
	// mockup is visible. Motion is allowed here so the timer is live.
	test("carousel auto-advances only after it scrolls into view", async ({ page }) => {
		await page.emulateMedia({ reducedMotion: "no-preference" });
		await page.goto("./");
		const carousel = page.locator("[data-onb-carousel]");
		const step = carousel.locator("[data-onb-step]");
		// Below the fold on load: still on step 1 after more than one auto-advance interval (5s).
		await expect(step).toHaveText("Step 1 of 6");
		await page.waitForTimeout(5600);
		await expect(step).toHaveText("Step 1 of 6");
		// Scroll it into view so the interval elapses and it advances.
		await carousel.scrollIntoViewIfNeeded();
		await expect(step).toHaveText("Step 2 of 6", { timeout: 7000 });
	});
});
