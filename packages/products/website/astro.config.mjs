import { execSync } from "node:child_process";
import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";

// The app version this site ships in lockstep with. On a release-tag deploy it comes from the
// tag (GITHUB_REF_NAME); otherwise from the latest git tag. Empty when neither is available
// (e.g. the E2E container, which has no .git) — components then show a neutral "latest release".
function appVersion() {
	const tag = process.env.GITHUB_REF_NAME;
	if (tag && /^v\d/.test(tag)) return tag.replace(/^v/, "");
	try {
		return execSync("git describe --tags --abbrev=0", { stdio: ["ignore", "pipe", "ignore"] })
			.toString()
			.trim()
			.replace(/^v/, "");
	} catch {
		return "";
	}
}
const APP_VERSION = appVersion();

// GitHub Pages project site: https://kaelys-js.github.io/harvest-autofill-releases/
export default defineConfig({
	site: "https://kaelys-js.github.io",
	// Production deploys under the Pages project subpath; E2E builds set ASTRO_BASE=/ so the
	// site can be served from a static server root without a self-referential symlink.
	base: process.env.ASTRO_BASE ?? "/harvest-autofill-releases",
	// Emit one canonical URL per page (with trailing slash) so the sitemap has no
	// duplicate entries, and stamp lastmod at build time.
	trailingSlash: "always",
	integrations: [
		react(),
		sitemap({
			filter: (page) => page.endsWith("/"),
			serialize(item) {
				item.lastmod = new Date().toISOString();
				return item;
			},
		}),
	],
	vite: {
		plugins: [tailwindcss()],
		// Expose the release version to components so version-referencing content stays in
		// lockstep with the app instead of being hard-coded.
		define: {
			"import.meta.env.PUBLIC_APP_VERSION": JSON.stringify(APP_VERSION),
		},
		// lucide-react 1.x has no `exports` map, so a bare import resolves to its CJS entry and
		// Astro's SSR can't read the named icon exports. Point the bare specifier at the ESM
		// barrel (a re-export file, so Vite still tree-shakes to the icons actually used).
		resolve: {
			alias: [{ find: /^lucide-react$/, replacement: "lucide-react/dist/esm/lucide-react.mjs" }],
		},
	},
});
