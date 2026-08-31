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
  vite: { plugins: [tailwindcss()] },
});
