import { expect, test } from "@playwright/test";

// Visual regression on the hero, in both themes. Runs in CI, not skipped: the suite executes
// inside the pinned Playwright Docker container (see the web-visual gate), so rendering is
// byte-identical on every machine. The live GitHub version fetch is stubbed to a fixed tag so
// the download button — and therefore the screenshot — is deterministic. Animations disabled.
test.describe("visual", () => {
	test.beforeEach(async ({ page }) => {
		await page.route("**/api.github.com/**", (route) =>
			route.fulfill({
				status: 200,
				contentType: "application/json",
				body: JSON.stringify({ tag_name: "v0.0.0" }),
			}),
		);
	});

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

	// The "This week" window is the site's headline mockup and the app's UI is matched to it
	// pixel-for-pixel (dots, AM/PM time ranges, per-project colours). A dedicated snapshot
	// catches a regression in the mockup itself, not just as a slice of the whole hero.
	const windowMockup = (page: import("@playwright/test").Page) =>
		page.getByRole("img", { name: /This Week window/ });

	test("window mockup — light", async ({ page }) => {
		await page.goto("./");
		await page.emulateMedia({ colorScheme: "light" });
		await expect(windowMockup(page)).toHaveScreenshot("window-mockup-light.png", {
			animations: "disabled",
		});
	});

	test("window mockup — dark", async ({ page }) => {
		await page.goto("./");
		await page.evaluate(() => document.documentElement.classList.add("dark"));
		await expect(windowMockup(page)).toHaveScreenshot("window-mockup-dark.png", {
			animations: "disabled",
		});
	});
});

// The "Made to feel native" section carries three interactive/static mockups (onboarding
// carousel, preferences, what's-new). reducedMotion pins the carousel to its first slide so the
// section renders deterministically; each mockup's landmark text is awaited so the shot is taken
// only after all three islands have hydrated.
test.describe("visual — native section", () => {
	test.use({ reducedMotion: "reduce" });

	test.beforeEach(async ({ page }) => {
		// The hero's download button lives on the same page; stub its release fetch so no real
		// network call runs while this section renders.
		await page.route("**/api.github.com/**", (route) =>
			route.fulfill({
				status: 200,
				contentType: "application/json",
				body: JSON.stringify({ tag_name: "v0.0.0" }),
			}),
		);
	});

	async function readyNative(page: import("@playwright/test").Page) {
		await page.goto("./#native");
		await expect(page.getByRole("heading", { name: "Welcome to Harvest Auto-Fill" })).toBeVisible();
		await expect(page.getByText("Automatic recording")).toBeVisible();
		await expect(page.getByRole("img", { name: /What's New window/ })).toBeVisible();
	}

	test("native section — light", async ({ page }) => {
		await readyNative(page);
		await page.emulateMedia({ colorScheme: "light" });
		await expect(page.locator("#native")).toHaveScreenshot("native-light.png", {
			animations: "disabled",
		});
	});

	test("native section — dark", async ({ page }) => {
		await readyNative(page);
		await page.evaluate(() => document.documentElement.classList.add("dark"));
		await expect(page.locator("#native")).toHaveScreenshot("native-dark.png", {
			animations: "disabled",
		});
	});
});

// The rest of the landing page — the sections without their own snapshot until now: the
// feature grid, the "how it works" steps, the download block (its new numbered steps), the
// FAQ accordion, and the footer. Each is captured in both themes so a colour or layout
// regression anywhere on the page is caught, not just in the hero and mockups.
test.describe("visual — page sections", () => {
	test.beforeEach(async ({ page }) => {
		await page.route("**/api.github.com/**", (route) =>
			route.fulfill({
				status: 200,
				contentType: "application/json",
				body: JSON.stringify({ tag_name: "v0.0.0" }),
			}),
		);
	});

	// Reveal-on-scroll starts elements at opacity:0 and fades them in on intersection; force the
	// end state so a section is never captured mid-reveal regardless of scroll timing.
	const revealAll = (page: import("@playwright/test").Page) =>
		page.evaluate(() =>
			document
				.querySelectorAll("[data-reveal],[data-stagger]")
				.forEach((el) => el.classList.add("is-visible")),
		);

	const SECTIONS: { name: string; selector: string; ready?: string }[] = [
		{ name: "features", selector: "#features", ready: "Files itself every Friday" },
		{ name: "how", selector: "#how", ready: "Friday, it files" },
		{ name: "download", selector: "#download", ready: "Get Harvest Auto-Fill" },
		{ name: "faq", selector: "#faq", ready: "Questions" },
		{ name: "footer", selector: "footer" },
	];

	for (const { name, selector, ready } of SECTIONS) {
		test(`${name} — light`, async ({ page }) => {
			await page.goto("./");
			await page.emulateMedia({ colorScheme: "light" });
			await revealAll(page);
			if (ready) await expect(page.getByText(ready).first()).toBeVisible();
			await expect(page.locator(selector)).toHaveScreenshot(`${name}-light.png`, {
				animations: "disabled",
			});
		});

		test(`${name} — dark`, async ({ page }) => {
			await page.goto("./");
			await page.evaluate(() => document.documentElement.classList.add("dark"));
			await revealAll(page);
			if (ready) await expect(page.getByText(ready).first()).toBeVisible();
			await expect(page.locator(selector)).toHaveScreenshot(`${name}-dark.png`, {
				animations: "disabled",
			});
		});
	}
});
