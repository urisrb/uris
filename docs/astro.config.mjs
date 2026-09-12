// @ts-check
import { defineConfig, passthroughImageService } from "astro/config";
import starlight from "@astrojs/starlight";

const clientPort = Number(process.env.DEV_CLIENT_PORT) || undefined;
const allowedHosts = process.env.DEV_ALLOWED_HOSTS?.split(",").filter(Boolean);

export default defineConfig({
  site: process.env.DOCS_SITE || "https://uris.pages.dev",
  image: { service: passthroughImageService() },
  server: allowedHosts ? { host: true, allowedHosts } : {},
  vite: clientPort
    ? {
        server: {
          allowedHosts,
          ws: { clientPort },
          watch: { usePolling: true, interval: 300 },
        },
      }
    : {},
  integrations: [
    starlight({
      title: "uris",
      description:
        "A data unifier — one searchable index across everything you own, wherever it lives, with a way back out.",
      favicon: "/icon.svg",
      logo: { src: "./src/assets/mark.svg" },
      customCss: ["./src/styles/global.css"],
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/urisrb/uris",
        },
      ],
      sidebar: [{ label: "Overview", slug: "index" }],
    }),
  ],
});
