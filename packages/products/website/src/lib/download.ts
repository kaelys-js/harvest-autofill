import { parseRelease, parseRepoSlug, parseUrl } from "@/lib/schemas";

// The releases repo the app ships from. The download link points at GitHub's stable
// "latest release" redirect so it never needs updating; the version tag beside it is filled
// in from the API after the page loads.
export const DOWNLOAD_REPO: string = parseRepoSlug("kaelys-js/harvest-autofill-releases");
export const DOWNLOAD_ZIP: string = parseUrl(
	`https://github.com/${DOWNLOAD_REPO}/releases/latest/download/HarvestAutoFill.zip`,
);
const LATEST_RELEASE_API = `https://api.github.com/repos/${DOWNLOAD_REPO}/releases/latest`;

// Fetch the latest release tag once and write it into every download button's version slot.
// The payload is validated with valibot before it's trusted; any failure (offline, blocked,
// malformed) leaves the slots as rendered — empty, with their width already reserved in CSS,
// so the download link always works and nothing reflows (zero CLS).
export async function fillDownloadVersions(
	root: ParentNode = document,
	fetchImpl: typeof fetch = fetch,
): Promise<void> {
	const slots = root.querySelectorAll<HTMLElement>("[data-download-version]");
	if (!slots.length) return;
	try {
		const res = await fetchImpl(LATEST_RELEASE_API);
		const release = parseRelease(res.ok ? await res.json() : null);
		if (release) slots.forEach((slot) => (slot.textContent = `· ${release.tag_name}`));
	} catch {
		/* offline or blocked — leave the reserved-width slot empty */
	}
}
