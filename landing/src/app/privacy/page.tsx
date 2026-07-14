import type { Metadata } from "next";
import { PageShell } from "@/components/page-shell";

export const metadata: Metadata = {
  title: "Privacy — LockedIn",
  description: "LockedIn reads timestamps, project paths and usage counts only — never your code or prompts. Everything stays on your Mac.",
};

const READS = ["Timestamps of editor & agent activity", "Project folder paths (to name projects)", "Token & prompt counts from local Claude Code logs", "Which app is frontmost (to attribute time)"];
const NEVER = ["Your prompts or conversations", "Your code or file contents", "Your keystrokes' content", "Anything sent to a server we run (there is no server)"];

export default function PrivacyPage() {
  return (
    <PageShell>
      <div className="mb-2 text-sm text-[var(--color-green)]">$ lockedin --what-it-reads</div>
      <h1 className="text-[34px] font-extrabold tracking-[-0.02em] sm:text-[42px]">Privacy</h1>
      <p className="mt-4 max-w-[640px] text-[15px] leading-[1.8] text-[var(--color-dim)]">
        LockedIn is local-first by design. It turns activity you already generate on your Mac into a picture of your day —
        without reading anything sensitive, and without a backend.
      </p>

      <div className="mt-10 grid gap-8 sm:grid-cols-2">
        <div>
          <div className="mb-4 text-[11px] tracking-[0.14em] text-[var(--color-green)]">READS</div>
          <ul className="flex flex-col gap-3">
            {READS.map((r) => <li key={r} className="flex gap-3 text-[14px] leading-[1.5] text-[var(--color-bright)]"><span className="text-[var(--color-green)]">✓</span>{r}</li>)}
          </ul>
        </div>
        <div className="sm:border-l sm:border-[var(--color-line)] sm:pl-8">
          <div className="mb-4 text-[11px] tracking-[0.14em] text-[var(--color-red)]">NEVER</div>
          <ul className="flex flex-col gap-3">
            {NEVER.map((r) => <li key={r} className="flex gap-3 text-[14px] leading-[1.5] text-[var(--color-dim)]"><span className="text-[var(--color-red)]">✗</span>{r}</li>)}
          </ul>
        </div>
      </div>

      <div className="mt-14 flex flex-col gap-8 text-[14px] leading-[1.8] text-[var(--color-dim)]">
        <Section t="Where your data lives">
          Everything is stored on your Mac, under <code className="text-[var(--color-bright)]">~/Library/Application Support/LockedIn</code>.
          There is no cloud sync and no account. Delete the folder and it&apos;s gone.
        </Section>
        <Section t="Claude usage limits (optional)">
          If you connect your claude.ai session cookie, LockedIn calls claude.ai&apos;s usage endpoint to show your
          Session / Weekly / Fable limits. The cookie is stored locally and sent only to claude.ai — never to us.
        </Section>
        <Section t="AI insights (optional)">
          If you add an Anthropic API key, the Insights feature sends aggregate numbers and project names
          (never code, prompts, or message content) to the Anthropic API when you press Generate. Each call is billed to your key.
        </Section>
        <Section t="Analytics">
          None. LockedIn ships with no third-party analytics or telemetry.
        </Section>
      </div>
    </PageShell>
  );
}

function Section({ t, children }: { t: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="mb-2 text-[18px] font-semibold text-[var(--color-ink)]">{t}</h2>
      <p className="max-w-[680px]">{children}</p>
    </div>
  );
}
