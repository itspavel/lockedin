import type { Metadata } from "next";
import { PageShell } from "@/components/page-shell";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Docs — LockedIn",
  description: "Getting started with LockedIn: install, how tracking works, Claude limits, AI insights.",
};

export default function DocsPage() {
  return (
    <PageShell>
      <div className="mb-2 text-sm text-[var(--color-dimmer)]"># docs</div>
      <h1 className="text-[34px] font-extrabold tracking-[-0.02em] sm:text-[42px]">Getting started</h1>

      <div className="mt-10 flex flex-col gap-9 text-[14px] leading-[1.8] text-[var(--color-dim)]">
        <Doc t="Install">
          Grab it from the <Link href="/download" className="text-[var(--color-green)]">download page</Link>. It&apos;s a menu-bar
          app — no Dock icon. On first launch, right-click → Open (beta signing).
        </Doc>
        <Doc t="How tracking works">
          Every few seconds LockedIn checks which app is frontmost and whether you&apos;ve given input, and watches Claude
          Code&apos;s local logs for active agents. Your time and agent time accrue per project — no timers, midnight to midnight.
        </Doc>
        <Doc t="What counts as work">
          By default: editors, terminals, browsers, Figma, and a few design/chat tools. Add or remove any app under
          <span className="text-[var(--color-bright)]"> Settings → Time tracking → Counts as work</span>. Choose Engaged
          (counts reading/thinking during agent runs) or Strict (input only).
        </Doc>
        <Doc t="Claude usage limits">
          Paste your claude.ai session cookie in <span className="text-[var(--color-bright)]">Settings → Claude usage limits</span> to
          see Session / Weekly / Fable limits and reset times in the menu bar. The cookie stays on your Mac.
        </Doc>
        <Doc t="AI insights">
          Add an Anthropic API key in <span className="text-[var(--color-bright)]">Settings → AI insights</span> and Claude turns
          your numbers into plain-English observations. Only aggregate numbers and project names are sent — never code.
        </Doc>
        <Doc t="Updates">
          LockedIn checks for updates automatically and shows a banner + notification when one&apos;s available, with the
          release notes. See the <Link href="/changelog" className="text-[var(--color-green)]">changelog</Link>.
        </Doc>
      </div>
    </PageShell>
  );
}

function Doc({ t, children }: { t: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="mb-2 text-[18px] font-semibold text-[var(--color-ink)]">{t}</h2>
      <p className="max-w-[700px]">{children}</p>
    </div>
  );
}
