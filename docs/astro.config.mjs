// @ts-check
import { defineConfig, passthroughImageService } from "astro/config";
import starlight from "@astrojs/starlight";

export default defineConfig({
  site: process.env.DOCS_SITE || "https://uris.pages.dev",
  image: { service: passthroughImageService() },
  integrations: [
    starlight({
      title: "uris",
      description:
        "A data unifier — one searchable index across everything you own, wherever it lives, with a way back out.",
      customCss: ["./src/styles/global.css"],
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/urisrb/uris",
        },
      ],
      sidebar: [
        {
          label: "Start here",
          items: [
            { label: "Overview", slug: "index" },
            { label: "Running it", slug: "start/running" },
            { label: "The four movements", slug: "start/movements" },
          ],
        },
        {
          label: "Concepts",
          items: [
            { label: "Items", slug: "concepts/items" },
            { label: "Resources", slug: "concepts/resources" },
            { label: "Tenancy", slug: "concepts/tenancy" },
            { label: "Analysis", slug: "concepts/analysis" },
            { label: "Jobs and failure", slug: "concepts/jobs" },
          ],
        },
        {
          label: "Guides",
          items: [
            { label: "Sync a resource", slug: "guides/sync" },
            { label: "Search the catalog", slug: "guides/search" },
            { label: "Export items back out", slug: "guides/export" },
            { label: "Drive it from Claude", slug: "guides/connector" },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "MCP tools", slug: "reference/tools" },
            { label: "GraphQL", slug: "reference/graphql" },
            { label: "Configuration", slug: "reference/configuration" },
          ],
        },
      ],
    }),
  ],
});
