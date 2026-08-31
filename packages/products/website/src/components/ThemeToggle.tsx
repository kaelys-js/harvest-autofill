import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function ThemeToggle() {
	const [dark, setDark] = useState(false);
	useEffect(() => setDark(document.documentElement.classList.contains("dark")), []);
	function toggle() {
		const next = !document.documentElement.classList.contains("dark");
		document.documentElement.classList.toggle("dark", next);
		localStorage.setItem("theme", next ? "dark" : "light");
		setDark(next);
	}
	return (
		<Button variant="ghost" size="icon" onClick={toggle} aria-label="Toggle dark mode">
			{dark ? <Sun /> : <Moon />}
		</Button>
	);
}
