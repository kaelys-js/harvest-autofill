import { expect, test } from "@playwright/test";

// Visual regression on the hero, in both themes. Animations disabled for determinism;
// baselines are committed and regenerated on the CI runner to avoid cross-platform font drift.
test.describe("visual", () => {
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
