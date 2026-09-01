import { parseRepoSlug, parseUrl } from "@/lib/schemas";

// The releases repo the app ships from. The download link points at GitHub's stable
// "latest release" redirect so it never needs updating; the version tag beside it is baked in
// at build time from the release tag (see DownloadButton.astro), so nothing is fetched at runtime.
export const DOWNLOAD_REPO: string = parseRepoSlug("kaelys-js/harvest-autofill");
export const DOWNLOAD_ZIP: string = parseUrl(
	`https://github.com/${DOWNLOAD_REPO}/releases/latest/download/HarvestAutoFill.zip`,
);
