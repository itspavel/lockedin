import type { Metadata } from "next";
import { PageShell } from "@/components/page-shell";
import { InstallTabs } from "@/components/install-tabs";
import { Ring } from "@/components/ring";

export const metadata: Metadata = {
  title: "Download LockedIn for macOS",
  description: "Install LockedIn — the ambient you-vs-agent time tracker. macOS 14+, Apple Silicon & Intel, free in beta.",
};

const STEPS = [
  ["01", "Run the install command", "Or download the .dmg and drag LockedIn to Applications."],
  ["02", "First launch", "It's beta-signed, so on first open: right-click the app → Open → Open. macOS remembers after that."],
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

      <a href="/download/LockedIn.dmg"
        className="mt-5 inline-flex items-center gap-2 rounded-[10px] bg-[var(--color-green)] px-6 py-3.5 text-[15px] font-bold text-[var(--color-on-green)] transition-colors hover:bg-[var(--color-green-hi)]">
        Download the .dmg
      </a>
      <p className="mt-3 text-xs text-[var(--color-dimmer)]"># apple silicon &amp; intel · macOS 14+ · no account</p>

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
        if a link isn&apos;t live yet, <a href="/#pricing" className="text-[var(--color-green)]">join the waitlist</a> and we&apos;ll email you the build.
      </div>
    </PageShell>
  );
}
