import { fireEvent, render, screen, within } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import OnboardingCarousel from "@/components/OnboardingCarousel";

// Force reduced-motion so auto-advance is disabled and step assertions are deterministic.
beforeEach(() => {
	window.matchMedia = vi.fn().mockImplementation((query: string) => ({
		matches: query.includes("reduce"),
		media: query,
		addEventListener: vi.fn(),
		removeEventListener: vi.fn(),
		addListener: vi.fn(),
		removeListener: vi.fn(),
		dispatchEvent: vi.fn(),
	}));
});

describe("OnboardingCarousel", () => {
	it("starts on the welcome step of six", () => {
		render(<OnboardingCarousel />);
		expect(
			screen.getByRole("heading", { name: "Welcome to Harvest Auto-Fill" }),
		).toBeInTheDocument();
		expect(screen.getByText("Step 1 of 6")).toBeInTheDocument();
	});

	it("jumps to a step when its dot is clicked", () => {
		render(<OnboardingCarousel />);
		fireEvent.click(screen.getByRole("tab", { name: /Step 4:/ }));
		expect(screen.getByRole("heading", { name: "Where your work lives" })).toBeInTheDocument();
		expect(screen.getByText("Step 4 of 6")).toBeInTheDocument();
	});

	it("advances with Continue and wraps from the last step", () => {
		render(<OnboardingCarousel />);
		const next = screen.getByRole("button", { name: "Next step" });
		for (let s = 2; s <= 6; s++) {
			fireEvent.click(next);
			expect(screen.getByText(`Step ${s} of 6`)).toBeInTheDocument();
		}
		// One more wraps back to step 1.
		fireEvent.click(next);
		expect(screen.getByText("Step 1 of 6")).toBeInTheDocument();
	});

	it("wraps backwards and exercises the pause handlers", () => {
		const { container } = render(<OnboardingCarousel />);
		const root = container.firstChild as HTMLElement;
		// Back from the first step wraps to the last.
		fireEvent.click(screen.getByRole("button", { name: "Previous step" }));
		expect(screen.getByText("Step 6 of 6")).toBeInTheDocument();
		// Exercise the hover/focus pause handlers (auto-advance is disabled here by reduced-motion).
		fireEvent.mouseEnter(root);
		fireEvent.mouseLeave(root);
		fireEvent.focus(root);
		fireEvent.blur(root);
		expect(screen.getByText("Step 6 of 6")).toBeInTheDocument();
	});

	it("marks exactly one dot selected", () => {
		render(<OnboardingCarousel />);
		const tablist = screen.getByRole("tablist", { name: "Onboarding steps" });
		fireEvent.click(screen.getByRole("button", { name: "Next step" }));
		const selected = within(tablist)
			.getAllByRole("tab")
			.filter((t) => t.getAttribute("aria-selected") === "true");
		expect(selected).toHaveLength(1);
	});
});
