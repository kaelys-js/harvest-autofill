import { afterEach, describe, expect, it, vi } from "vitest";
import { DOWNLOAD_ZIP, fillDownloadVersions } from "@/lib/download";

describe("download", () => {
	afterEach(() => {
		vi.restoreAllMocks();
		document.body.innerHTML = "";
	});

	it("points at the latest-release zip", () => {
		expect(DOWNLOAD_ZIP).toContain("/releases/latest/download/HarvestAutoFill.zip");
	});

	it("writes the fetched tag into every version slot from one fetch", async () => {
		document.body.innerHTML =
			"<span data-download-version></span><span data-download-version></span>";
		const fetchImpl = vi
			.fn()
			.mockResolvedValue({ ok: true, json: async () => ({ tag_name: "v2.17" }) });
		await fillDownloadVersions(document, fetchImpl as unknown as typeof fetch);
		expect(fetchImpl).toHaveBeenCalledTimes(1);
		const slots = [...document.querySelectorAll("[data-download-version]")];
		expect(slots.every((s) => s.textContent === "· v2.17")).toBe(true);
	});

	it("leaves the slot empty when the fetch fails, so nothing reflows", async () => {
		document.body.innerHTML = "<span data-download-version></span>";
		const fetchImpl = vi.fn().mockRejectedValue(new Error("offline"));
		await fillDownloadVersions(document, fetchImpl as unknown as typeof fetch);
		expect(document.querySelector("[data-download-version]")?.textContent).toBe("");
	});

	it("ignores a malformed payload rather than trusting it", async () => {
		document.body.innerHTML = "<span data-download-version></span>";
		const fetchImpl = vi
			.fn()
			.mockResolvedValue({ ok: true, json: async () => ({ tag_name: "not-a-version" }) });
		await fillDownloadVersions(document, fetchImpl as unknown as typeof fetch);
		expect(document.querySelector("[data-download-version]")?.textContent).toBe("");
	});
});
