import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { toggleTheme } from "@/lib/theme";

// The toggle control is now a plain server-rendered button; its behaviour lives in toggleTheme,
// tested here directly. jsdom reports no reduced-motion and has no View Transitions API, so this
// exercises the fallback (theme-anim) path — the one real browsers without startViewTransition use.
describe("toggleTheme", () => {
	beforeEach(() => {
		document.documentElement.classList.remove("dark", "theme-anim");
		localStorage.clear();
	});
	afterEach(() => localStorage.clear());

	it("turns dark mode on and persists it", () => {
		toggleTheme();
		expect(document.documentElement.classList.contains("dark")).toBe(true);
		expect(localStorage.getItem("theme")).toBe("dark");
	});

	it("toggles back to light on a second call", () => {
		toggleTheme();
		toggleTheme();
		expect(document.documentElement.classList.contains("dark")).toBe(false);
		expect(localStorage.getItem("theme")).toBe("light");
	});
});
