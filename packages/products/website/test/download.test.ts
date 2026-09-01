import { describe, expect, it } from "vitest";
import { DOWNLOAD_ZIP } from "@/lib/download";

describe("download", () => {
	it("points at the latest-release zip", () => {
		expect(DOWNLOAD_ZIP).toContain("/releases/latest/download/HarvestAutoFill.zip");
	});
});
