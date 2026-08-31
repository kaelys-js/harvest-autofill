import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import CopyCommand from "@/components/CopyCommand";

describe("CopyCommand", () => {
	it("shows the command and copies it on click", async () => {
		const writeText = vi.fn().mockResolvedValue(undefined);
		Object.assign(navigator, { clipboard: { writeText } });
		render(<CopyCommand cmd="xattr -cr MyApp.app" />);
		expect(screen.getByText("xattr -cr MyApp.app")).toBeInTheDocument();
		fireEvent.click(screen.getByRole("button", { name: /copy command/i }));
		await waitFor(() => expect(writeText).toHaveBeenCalledWith("xattr -cr MyApp.app"));
	});
});
