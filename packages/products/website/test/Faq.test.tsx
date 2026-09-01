import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import Faq from "@/components/Faq";

describe("Faq", () => {
	it("renders every question", () => {
		render(<Faq />);
		expect(screen.getByText(/How does it know what I worked on/i)).toBeInTheDocument();
		expect(screen.getAllByRole("button").length).toBeGreaterThanOrEqual(6);
	});

	it("expands an answer when its question is clicked", () => {
		render(<Faq />);
		fireEvent.click(screen.getByRole("button", { name: /Where does my data go/i }));
		expect(screen.getByText(/only the app can read/i)).toBeVisible();
	});
});
