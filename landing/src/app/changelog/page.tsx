import type { Metadata } from "next";
import { PageShell } from "@/components/page-shell";

export const metadata: Metadata = {
  title: "Changelog — LockedIn",
  description: "What's new in LockedIn.",
};

const RELEASES = [
  {
    v: "0.2", date: "2026-07-18", tag: "beta",
    notes: [
      "New Console look — the app now matches the website: terminal surfaces, green accent, monospaced numerals, new icon.",
      "Limit alerts at 80% / 95% of any Claude limit (Session / Weekly / Fable).",
      "Notch fixes: the menu-bar item rescues itself from under the notch; widget + Dashboard stay reachable when the bar is full.",
      "Right-click menus on the menu-bar item and the desktop widget.",
      "Report a bug / suggest a feature straight from the Dashboard.",
    ],
  },
  {
    v: "0.1", date: "2026-07-15", tag: "beta",
    notes: [
      "First public beta.",
      "Ambient you-vs-agent time tracking — menu bar, popover and desktop widget.",
      "Per-project split, tokens & API-equivalent cost, daily rhythm.",
      "Claude usage limits (Session / Weekly / Fable) with reset times + service status.",
      "Optional Claude-generated AI insights.",
      "In-app updates with release notes.",
    ],
  },
];

export default function ChangelogPage() {
  return (
    <PageShell>
      <div className="mb-2 text-sm text-[var(--color-dimmer)]"># changelog</div>
      <h1 className="text-[34px] font-extrabold tracking-[-0.02em] sm:text-[42px]">What&apos;s new</h1>
      <p className="mt-4 text-[15px] text-[var(--color-dim)]">Every release, and what changed.</p>

      <div className="mt-12 flex flex-col gap-10">
        {RELEASES.map((r) => (
          <div key={r.v} className="border-t border-[var(--color-line)] pt-8">
            <div className="flex flex-wrap items-baseline gap-3">
              <span className="tnum text-[24px] font-extrabold">v{r.v}</span>
              <span className="rounded-[5px] border border-[var(--color-line-green)] px-1.5 py-0.5 text-[11px] text-[var(--color-green)]">{r.tag}</span>
              <span className="text-[13px] text-[var(--color-dimmer)]">{r.date}</span>
            </div>
            <ul className="mt-5 flex flex-col gap-2.5">
              {r.notes.map((n) => (
                <li key={n} className="flex gap-3 text-[14px] leading-[1.6] text-[var(--color-dim)]">
                  <span className="text-[var(--color-green)]">•</span>{n}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </PageShell>
  );
}
