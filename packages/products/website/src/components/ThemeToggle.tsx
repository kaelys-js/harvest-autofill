import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { Button } from "@/components/ui/button";
import { writeTheme } from "@/lib/theme";

export default function ThemeToggle() {
	const [dark, setDark] = useState(false);
	// Sync the button icon to the theme the pre-paint inline script already set on <html>
	// (an external system) after hydration — starting false keeps SSR and first client render
	// matched, so this is the correct use of an effect despite the rule.
	// oxlint-disable-next-line react/set-state-in-effect
	useEffect(() => setDark(document.documentElement.classList.contains("dark")), []);

	function toggle() {
		const root = document.documentElement;
		const next = !root.classList.contains("dark");
		const apply = () => {
			root.classList.toggle("dark", next);
			writeTheme(next ? "dark" : "light");
			setDark(next);
		};

		const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
		if (reduce) {
			apply();
			return;
		}

		// Preferred: a whole-viewport crossfade via the View Transitions API.
		const startVT = (document as unknown as { startViewTransition?: (cb: () => void) => unknown })
			.startViewTransition;
		if (typeof startVT === "function") {
			startVT.call(document, apply);
			return;
		}

		// Fallback for browsers without View Transitions: briefly transition surface colors.
		root.classList.add("theme-anim");
		apply();
		window.setTimeout(() => root.classList.remove("theme-anim"), 320);
	}

	return (
		<Button variant="ghost" size="icon" onClick={toggle} aria-label="Toggle dark mode">
			{dark ? <Sun /> : <Moon />}
		</Button>
	);
}
