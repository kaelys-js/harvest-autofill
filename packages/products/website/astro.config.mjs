import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";

// GitHub Pages project site: https://kaelys-js.github.io/harvest-autofill-releases/
export default defineConfig({
	site: "https://kaelys-js.github.io",
	// Production deploys under the Pages project subpath; E2E builds set ASTRO_BASE=/ so the
	// site can be served from a static server root without a self-referential symlink.
	base: process.env.ASTRO_BASE ?? "/harvest-autofill-releases",
	integrations: [react(), sitemap()],
	vite: {
		plugins: [tailwindcss()],
		// lucide-react 1.x has no `exports` map, so a bare import resolves to its CJS entry and
		// Astro's SSR can't read the named icon exports. Point the bare specifier at the ESM
		// barrel (a re-export file, so Vite still tree-shakes to the icons actually used).
		resolve: {
			alias: [{ find: /^lucide-react$/, replacement: "lucide-react/dist/esm/lucide-react.mjs" }],
		},
	},
});
