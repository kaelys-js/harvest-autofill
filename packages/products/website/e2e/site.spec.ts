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
	const isDark = () => html.evaluate((el) => el.classList.contains("dark"));
	const before = await isDark();
	// The toggle is a plain server-rendered button, so one click is enough — no hydration wait.
	// The class flip lands inside a View Transition, so poll for it to settle before asserting
	// (and before the next click) rather than reading synchronously, which would race the frame.
	await toggle.click();
	await expect.poll(isDark).toBe(!before);
	await toggle.click();
	await expect.poll(isDark).toBe(before);
});

test("an FAQ answer expands when its question is clicked", async ({ page }) => {
	// The FAQ is a native <details>/<summary> disclosure — the question is the summary.
	const q = page.locator("#faq summary").filter({ hasText: /Where does my data go/i });
	await q.scrollIntoViewIfNeeded();
	// The phrase also appears in the FAQPage JSON-LD (in <head>); scope to the visible accordion.
	const answer = page.locator("#faq").getByText(/only the app can read/i);
	await expect(answer).toBeHidden(); // collapsed until opened
	await q.click();
	await expect(answer).toBeVisible();
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
