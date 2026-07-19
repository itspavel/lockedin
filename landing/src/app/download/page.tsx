import type { Metadata } from "next";
import { PageShell } from "@/components/page-shell";
import { InstallTabs } from "@/components/install-tabs";
import { DownloadButton } from "@/components/download-button";
import { Ring } from "@/components/ring";

export const metadata: Metadata = {
  title: "Download LockedIn for macOS",
  description: "Install LockedIn — the ambient you-vs-agent time tracker. macOS 14+, Apple Silicon & Intel, free in beta.",
};

const STEPS = [
  ["01", "Run the install command", "The script pulls the latest release into /Applications with no Gatekeeper prompt — curl downloads carry no quarantine flag. Prefer clicking? Grab the .dmg below."],
  ["02", "First launch (DMG only)", "Beta builds aren't Developer ID signed yet. macOS 15: open the app once, then System Settings → Privacy & Security → Open Anyway. macOS 13–14: right-click → Open. One time only."],
  ["03", "Look up at the menu bar", "LockedIn lives there — no Dock icon. It starts tracking the moment you open your editor."],
];

export default function DownloadPage() {
  return (
    <PageShell>
      <div className="mb-2 flex items-center gap-2.5"><Ring size={22} /><span className="text-sm text-[var(--color-dimmer)]">$ install lockedin</span></div>
      <h1 className="text-[36px] font-extrabold tracking-[-0.02em] sm:text-[44px]">Download for macOS<span className="text-[var(--color-green)]">.</span></h1>
      <p className="mt-4 max-w-[560px] text-[15px] leading-[1.7] text-[var(--color-dim)]">
        Free while we&apos;re in beta. macOS 14+, Apple Silicon &amp; Intel. No account, ~8 MB.
      </p>

      <div className="mt-8"><InstallTabs /></div>

      <div><DownloadButton /></div>
      <p className="mt-3 text-xs text-[var(--color-dimmer)]"># apple silicon &amp; intel · macOS 14+ · no account · unsigned beta — the install script skips the Gatekeeper prompt</p>

      <div className="mt-14 grid gap-4 sm:grid-cols-3">
        {STEPS.map(([n, t, d]) => (
          <div key={n} className="rounded-2xl border border-[var(--color-line)] bg-[var(--color-panel)] p-6">
            <div className="mb-3 text-[13px] text-[var(--color-green)]">{n}</div>
            <div className="mb-2 text-[17px] font-semibold">{t}</div>
            <p className="text-[13px] leading-[1.6] text-[var(--color-dim)]">{d}</p>
          </div>
        ))}
      </div>

      <div className="mt-8 rounded-xl border border-[var(--color-line)] bg-[var(--color-panel)] px-5 py-4 text-[13px] text-[var(--color-dim)]">
        <span className="text-[var(--color-green)]">note:</span> hosted downloads are rolling out to beta users —
        if a link isn&apos;t live yet,{" "}
        <a href="/#pricing" className="text-[var(--color-green)]">join the waitlist</a>{" "}
        and we&apos;ll email you the build.
      </div>
    </PageShell>
  );
}
