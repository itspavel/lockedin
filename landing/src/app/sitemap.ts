import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://lockedin.app";
  return [
    { url: base, lastModified: new Date("2026-07-15"), changeFrequency: "weekly", priority: 1 },
  ];
}
