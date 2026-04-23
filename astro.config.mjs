import { defineConfig } from "astro/config";
import tailwind from "@astrojs/tailwind";
import icon from "astro-icon";

export default defineConfig({
  integrations: [tailwind(), icon({ include: { lucide: ["*"] } })],
  output: "static",
  site: "https://tapiaw38.github.io",
  base: process.env.GITHUB_ACTIONS ? "/coren-website/" : "/",
});
