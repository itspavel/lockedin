import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Self-contained server bundle for a small Docker image.
  output: "standalone",
  async rewrites() {
    // `curl -fsSL <site>/install | sh` — the canonical install command.
    return [{ source: "/install", destination: "/install.sh" }];
  },
};

export default nextConfig;
