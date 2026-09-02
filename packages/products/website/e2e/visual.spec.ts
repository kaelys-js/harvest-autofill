import { expect, test } from "@playwright/test";

// Visual regression on the hero, in both themes. Runs in CI, not skipped: the suite executes
// inside the pinned Playwright Docker container (see the web-visual gate), so rendering is
// byte-identical on every machine. The download button's version tag is baked in at build time
// (see DownloadButton.astro; the E2E build sets GITHUB_REF_NAME=v0.0.0), so the screenshot is
// deterministic with no runtime fetch to stub. Animations disabled.
test.describe("visual regression", () => {
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

// The "Native to macOS" section carries three interactive/static mockups (onboarding
// carousel, preferences, what's-new). reducedMotion pins the carousel to its first slide so the
// section renders deterministically; each mockup's landmark text is awaited so the shot is taken
// only after all three islands have hydrated.
test.describe("visual — native section", () => {
	test.beforeEach(async ({ page }) => {
		// reduced-motion pins the carousel to its first slide; set via the page method for the
		// same TS7-vs-fixtures reason as native.spec.ts.
		await page.emulateMedia({ reducedMotion: "reduce" });
	});

	async function readyNative(page: import("@playwright/test").Page) {
		await page.goto("./#native");
		await expect(page.getByRole("heading", { name: "Welcome to Harvest Auto-Fill" })).toBeVisible();
		await expect(page.getByText("Automatic logging")).toBeVisible();
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

// The #demo section is the app's "This week" window filling itself. reduced-motion shows the
// finished week (all rows in), so the snapshot is deterministic regardless of the fill timer.
test.describe("visual — demo section", () => {
	test.beforeEach(async ({ page }) => {
		await page.emulateMedia({ reducedMotion: "reduce" });
	});

	async function readyDemo(page: import("@playwright/test").Page) {
		await page.goto("./#demo");
		await expect(page.getByRole("heading", { name: "See it fill a week" })).toBeVisible();
		// Under reduced-motion the finished week is in view before the shot is taken.
		await expect(page.locator("[data-demo-summary]")).toHaveText(/36h across 4 days/);
	}

	test("demo section — light", async ({ page }) => {
		await readyDemo(page);
		await page.emulateMedia({ colorScheme: "light", reducedMotion: "reduce" });
		await expect(page.locator("#demo")).toHaveScreenshot("demo-light.png", {
			animations: "disabled",
		});
	});

	test("demo section — dark", async ({ page }) => {
		await readyDemo(page);
		await page.evaluate(() => document.documentElement.classList.add("dark"));
		await expect(page.locator("#demo")).toHaveScreenshot("demo-dark.png", {
			animations: "disabled",
		});
	});
});

// The rest of the landing page — the sections without their own snapshot until now: the
// feature grid, the "how it works" steps, the download block (its new numbered steps), the
// FAQ accordion, and the footer. Each is captured in both themes so a colour or layout
// regression anywhere on the page is caught, not just in the hero and mockups.
test.describe("visual — page sections", () => {
	// Reveal-on-scroll starts elements at opacity:0 and fades them in on intersection; force the
	// end state so a section is never captured mid-reveal regardless of scroll timing.
	const revealAll = (page: import("@playwright/test").Page) =>
		page.evaluate(() =>
			document
				.querySelectorAll("[data-reveal],[data-stagger]")
				.forEach((el) => el.classList.add("is-visible")),
		);

	const SECTIONS: { name: string; selector: string; ready?: string }[] = [
		{ name: "nav", selector: "header" },
		{ name: "trust", selector: "#trust", ready: "Your data stays on your Mac" },
		{ name: "features", selector: "#features", ready: "Logs itself every Friday" },
		{ name: "how", selector: "#how", ready: "Friday, it logs" },
		{ name: "download", selector: "#download", ready: "Get Harvest Auto-Fill" },
		{ name: "faq", selector: "#faq", ready: "Common questions" },
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
