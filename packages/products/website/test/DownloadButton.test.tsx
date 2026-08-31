import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import DownloadButton from "@/components/DownloadButton";

describe("DownloadButton", () => {
	afterEach(() => vi.restoreAllMocks());

	it("links to the latest release zip", () => {
		vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));
		render(<DownloadButton />);
		const link = screen.getByRole("link");
		expect(link.getAttribute("href")).toContain("/releases/latest/download/HarvestAutoFill.zip");
	});

	it("shows the fetched version tag", async () => {
		vi.stubGlobal(
			"fetch",
			vi.fn().mockResolvedValue({ ok: true, json: async () => ({ tag_name: "v2.17" }) }),
		);
		render(<DownloadButton />);
		await waitFor(() => expect(screen.getByText(/· v2\.17/)).toBeInTheDocument());
	});
});
