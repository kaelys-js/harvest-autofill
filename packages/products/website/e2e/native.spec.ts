import { expect, test } from "@playwright/test";

// reduced-motion disables the carousel's auto-advance, so step assertions are deterministic.
test.use({ reducedMotion: "reduce" });

// The mockups are client:visible islands; a click can land before hydration completes, so the
// first interaction is retried until the handler is attached.
async function clickUntil(
	page: import("@playwright/test").Page,
	role: "tab",
	name: string | RegExp,
	marker: RegExp | string,
) {
	await expect(async () => {
		await page.getByRole(role, { name }).click();
		await expect(page.getByText(marker)).toBeVisible({ timeout: 1000 });
	}).toPass({ timeout: 10000 });
}

test.describe("made to feel native", () => {
	test("onboarding carousel steps through all six screens", async ({ page }) => {
		await page.goto("./");
		const titles = [
			"Connect your Harvest account",
			"Find your projects automatically",
			"Where your work lives",
			"Your workday",
			"Here's your week",
		];
		for (let i = 0; i < titles.length; i++) {
			await clickUntil(page, "tab", new RegExp(`^Step ${i + 2}:`), titles[i]);
		}
		// Next from the last step wraps back to Welcome.
		await page.getByRole("button", { name: "Next step" }).click();
		await expect(page.getByRole("heading", { name: "Welcome to Harvest Auto-Fill" })).toBeVisible();
	});

	test("preferences mockup switches between all four tabs", async ({ page }) => {
		await page.goto("./");
		await expect(page.getByText("Automatic recording")).toBeVisible();
		const tabs: [string, string][] = [
			["Accounts", "Where your hours are written — the one account the app truly needs."],
			["Allocation", "How commits, pushes, and meetings weight across your projects."],
			["About", "Every token stays on this Mac and is never sent anywhere."],
			["General", "Files your week to Harvest every Friday at 6pm, even if the app is closed."],
		];
		for (const [tab, marker] of tabs) {
			await clickUntil(page, "tab", tab, marker);
		}
	});
});
