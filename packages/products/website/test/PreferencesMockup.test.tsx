import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import PreferencesMockup from "@/components/PreferencesMockup";

describe("PreferencesMockup", () => {
	it("shows the General tab first", () => {
		render(<PreferencesMockup />);
		expect(screen.getByText("Automatic recording")).toBeInTheDocument();
		expect(screen.getByRole("tab", { name: "General" })).toHaveAttribute("aria-selected", "true");
	});

	it("switches content when each tab is clicked", () => {
		render(<PreferencesMockup />);
		const cases: [string, string][] = [
			["Accounts", "Where your hours are written — the one account the app truly needs."],
			["Allocation", "How commits, pushes, and meetings weight across your projects."],
			["About", "Everything stays on this Mac and is never sent anywhere."],
			["General", "Files your week to Harvest every Friday at 6pm, even if the app is closed."],
		];
		for (const [tab, marker] of cases) {
			fireEvent.click(screen.getByRole("tab", { name: tab }));
			expect(screen.getByText(marker)).toBeInTheDocument();
			expect(screen.getByRole("tab", { name: tab })).toHaveAttribute("aria-selected", "true");
		}
	});

	it("exposes all four tabs", () => {
		render(<PreferencesMockup />);
		for (const name of ["General", "Accounts", "Allocation", "About"]) {
			expect(screen.getByRole("tab", { name })).toBeInTheDocument();
		}
	});
});
