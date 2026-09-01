import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
	await page.goto("./");
});

test("loads with the right title and a skip link", async ({ page }) => {
	await expect(page).toHaveTitle(/Harvest Auto-Fill/);
	await expect(page.getByRole("link", { name: /skip to content/i })).toBeAttached();
});

test("the theme toggle flips light and dark", async ({ page }) => {
	const html = page.locator("html");
	const toggle = page.getByRole("button", { name: /toggle dark mode/i });
	// Retry until the island has hydrated (a click before hydration is a no-op). Reading the
	// before-state fresh each attempt keeps a pre-hydration click from being double-counted.
	await expect(async () => {
		const before = await html.evaluate((el) => el.classList.contains("dark"));
		await toggle.click();
		const after = await html.evaluate((el) => el.classList.contains("dark"));
		expect(after).toBe(!before);
	}).toPass({ timeout: 10000 });
});

test("an FAQ answer expands when its question is clicked", async ({ page }) => {
	const q = page.getByRole("button", { name: /Where do my tokens and data go/i });
	await q.scrollIntoViewIfNeeded();
	await q.click();
	await expect(page.getByText(/Every token lives only on your Mac/i)).toBeVisible();
});

test("the download button points at the latest release zip", async ({ page }) => {
	const link = page.locator('a[href*="/releases/latest/download/HarvestAutoFill.zip"]').first();
	await expect(link).toBeAttached();
});

test("external GitHub links open in a new tab safely", async ({ page }) => {
	const gh = page
		.locator('a[href="https://github.com/kaelys-js/harvest-autofill-releases"]')
		.first();
	await expect(gh).toHaveAttribute("target", "_blank");
	await expect(gh).toHaveAttribute("rel", /noopener/);
});
