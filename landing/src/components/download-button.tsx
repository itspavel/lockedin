"use client";
import { track } from "@vercel/analytics";

export function DownloadButton() {
  return (
    <a
      href="/download/LockedIn.dmg"
      download
      onClick={() => track("download_dmg")}
      className="mt-5 inline-flex items-center gap-2 rounded-[10px] bg-[var(--color-green)] px-6 py-3.5 text-[15px] font-bold text-[var(--color-on-green)] transition-colors hover:bg-[var(--color-green-hi)]"
    >
      Download the .dmg
      <span className="tnum text-[13px] font-normal opacity-70">· 1.3 MB</span>
    </a>
  );
}
