import type { Metadata } from "next";
import { JetBrains_Mono } from "next/font/google";
import "./globals.css";

const jetbrains = JetBrains_Mono({
  variable: "--font-jetbrains",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

const SITE = "https://lockedin.app";
const TITLE = "LockedIn — who really wrote today's code?";
const DESC =
  "Ambient, zero-input macOS time tracker. See the real you-vs-agent split for every project, watch your Claude session/weekly/Fable limits, all local. No timers.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: TITLE,
  description: DESC,
  applicationName: "LockedIn",
  keywords: [
    "AI time tracker", "Claude Code time tracking", "Cursor time tracker",
    "human vs AI agent split", "Claude usage limits", "macOS menu bar app",
    "ambient time tracking", "developer productivity", "zero input tracker",
    "Claude session limit", "build in public",
  ],
  authors: [{ name: "LockedIn" }],
  creator: "LockedIn",
  alternates: { canonical: SITE },
  openGraph: {
    type: "website",
    url: SITE,
    siteName: "LockedIn",
    title: TITLE,
    description: DESC,
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: DESC,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  category: "technology",
};

const JSONLD = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "LockedIn",
  applicationCategory: "DeveloperApplication",
  operatingSystem: "macOS 14+",
  description: DESC,
  url: SITE,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  featureList: [
    "Zero-input time tracking",
    "Human vs AI-agent split per project",
    "Claude session, weekly and Fable usage limits with reset times",
    "Menu bar, popover and desktop widget",
    "Local-only, privacy-first",
  ],
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${jetbrains.variable} h-full antialiased`}>
      <body className="min-h-full">
        {children}
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(JSONLD) }} />
      </body>
    </html>
  );
}
