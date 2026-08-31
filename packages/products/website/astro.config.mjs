import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";

// GitHub Pages project site: https://kaelys-js.github.io/harvest-autofill-releases/
export default defineConfig({
  site: "https://kaelys-js.github.io",
  base: "/harvest-autofill-releases",
  integrations: [react(), sitemap()],
  vite: { plugins: [tailwindcss()] },
});
