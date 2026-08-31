import { expect, test } from "@playwright/test";

// Visual regression on the hero, in both themes. Animations disabled for determinism.
// Browser font rendering differs machine-to-machine, so these pixel baselines are for LOCAL
// runs (they match the dev's Mac); in CI the deterministic app-render visual gate covers
// visual regression, and the E2E specs above cover website behaviour.
test.describe("visual", () => {
	test.skip(!!process.env.CI, "pixel baselines are machine-specific; run locally");

	test("hero — light", async ({ page }) => {
		await page.goto("./");
		await page.emulateMedia({ colorScheme: "light" });
		await expect(page.locator("section").first()).toHaveScreenshot("hero-light.png", {
			animations: "disabled",
		});
	});

	test("hero — dark", async ({ page }) => {
		await page.goto("./");
		await page.evaluate(() => document.documentElement.classList.add("dark"));
		await expect(page.locator("section").first()).toHaveScreenshot("hero-dark.png", {
			animations: "disabled",
		});
	});
});
