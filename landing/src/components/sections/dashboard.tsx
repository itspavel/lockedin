"use client";
import { useMemo, useState } from "react";
import { cn } from "@/lib/utils";
import { Ticker } from "@/components/ticker";
import { SplitBar } from "@/components/bar";

type View = "dashboard" | "projects" | "calendar";

const HATCH_3 = { backgroundColor: "rgba(63,185,80,.18)", backgroundImage: "repeating-linear-gradient(45deg,#3FB950 0,#3FB950 3px,transparent 3px,transparent 9px)" };
const HATCH_2 = { backgroundColor: "rgba(63,185,80,.3)", backgroundImage: "repeating-linear-gradient(45deg,#3FB950 0,#3FB950 2px,transparent 2px,transparent 6px)" };

const PROJECTS = [
  { name: "wedding-hyperion", label: "7h 04m · 78% you", you: 0.78 },
  { name: "proofly-web", label: "4h 18m · 41% you", you: 0.41 },
  { name: "api-refactor", label: "2h 30m · 22% you", you: 0.22 },
  { name: "docs-site", label: "1h 12m · 64% you", you: 0.64 },
];

const RHYTHM = [30, 55, 80, 100, 70, 60, 90, 45, 65, 35];
const RHYTHM_HATCH = new Set([4, 6, 9]);

export function Dashboard() {
  const [view, setView] = useState<View>("dashboard");

  // deterministic 13w × 7d focus-contribution heatmap (seeded LCG — matches the design)
  const heat = useMemo(() => {
    const cols = ["#161c24", "rgba(63,185,80,.35)", "rgba(63,185,80,.65)", "#3FB950"];
    const out: string[] = [];
    let s = 7;
    for (let i = 0; i < 91; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      const r = (s % 100) / 100;
      out.push(cols[r < 0.22 ? 0 : r < 0.5 ? 1 : r < 0.78 ? 2 : 3]);
    }
    return out;
  }, []);

  const items: { id: View; label: string }[] = [
    { id: "dashboard", label: "◈ dashboard" },
    { id: "projects", label: "▤ projects" },
    { id: "calendar", label: "▦ calendar" },
  ];

  return (
    <section className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-2 text-sm text-[var(--color-green)]">$ lockedin --dashboard</div>
        <h2 className="mb-3 text-[30px] font-extrabold tracking-[-0.02em] sm:text-[36px]">the full picture, one window.</h2>
        <p className="mb-8 text-[13px] text-[var(--color-dimmer)]"># click the sidebar — it&apos;s live</p>

        <div className="overflow-hidden rounded-[14px] border border-[var(--color-line)] bg-[var(--color-panel)] shadow-[0_40px_90px_-50px_rgba(0,0,0,.9)]">
          {/* titlebar */}
          <div className="flex items-center gap-2 border-b border-[var(--color-line)] bg-[var(--color-panel-2)] px-4 py-2.5">
            <span className="h-[11px] w-[11px] rounded-full bg-[#ff5f57]" />
            <span className="h-[11px] w-[11px] rounded-full bg-[#febc2e]" />
            <span className="h-[11px] w-[11px] rounded-full bg-[#28c840]" />
            <span className="ml-3 text-[11px] text-[var(--color-dimmer)]">LockedIn — Dashboard</span>
          </div>

          <div className="grid min-h-[320px] grid-cols-1 sm:grid-cols-[180px_1fr]">
            {/* sidebar */}
            <div className="flex gap-1.5 overflow-x-auto border-b border-[var(--color-line)] p-3 text-xs sm:flex-col sm:gap-1.5 sm:border-b-0 sm:border-r sm:p-5">
              {items.map((it) => (
                <button key={it.id} onClick={() => setView(it.id)}
                  className={cn("cursor-pointer whitespace-nowrap rounded-lg border px-3 py-2.5 text-left transition-colors",
                    view === it.id ? "border-[var(--color-line-green)] bg-[var(--color-green)]/[0.08] text-[var(--color-green)]" : "border-transparent text-[var(--color-dim)] hover:text-[var(--color-ink)]")}>
                  {it.label}
                </button>
              ))}
              {["◇ agents & tokens", "↧ reports", "⚙ settings"].map((s) => (
                <span key={s} className="hidden whitespace-nowrap rounded-lg px-3 py-2.5 text-[var(--color-dimmer)] sm:block">{s}</span>
              ))}
            </div>

            {/* panel */}
            <div className="p-6">
              {view === "dashboard" && (
                <div>
                  <div className="mb-[18px] grid gap-4 sm:grid-cols-[1.3fr_1fr]">
                    <div className="rounded-[10px] border border-[var(--color-line)] p-5">
                      <div className="mb-1.5 text-[10px] tracking-[0.12em] text-[var(--color-dimmer)]">FOCUSED TODAY</div>
                      <div className="tnum mb-3.5 text-[44px] font-bold leading-none"><Ticker value={372} format="hm" /></div>
                      <SplitBar you={0.63} height={12} />
                    </div>
                    <div className="rounded-[10px] border border-[var(--color-line-green)] bg-[var(--color-green)]/[0.05] p-5">
                      <div className="mb-2.5 text-[10px] tracking-[0.1em] text-[var(--color-green)]">✦ AI INSIGHT</div>
                      <p className="text-xs leading-[1.5] text-[var(--color-bright)]">Deep-work window: 9–11am. Agents peaked after 3pm.</p>
                    </div>
                  </div>
                  <div className="mb-2 text-[10px] tracking-[0.12em] text-[var(--color-dimmer)]">TODAY&apos;S RHYTHM</div>
                  <div className="flex h-[52px] items-end gap-[3px]">
                    {RHYTHM.map((h, i) => (
                      <div key={i} className="flex-1" style={{ height: `${h}%`, ...(RHYTHM_HATCH.has(i) ? HATCH_2 : { background: "var(--color-green)" }) }} />
                    ))}
                  </div>
                </div>
              )}

              {view === "projects" && (
                <div className="flex flex-col gap-4">
                  <div className="text-[10px] tracking-[0.12em] text-[var(--color-dimmer)]">ALL PROJECTS · TODAY</div>
                  {PROJECTS.map((p) => (
                    <div key={p.name}>
                      <div className="mb-1.5 flex justify-between text-xs text-[var(--color-dim)]">
                        <span>{p.name}</span><span className="tnum text-[var(--color-ink)]">{p.label}</span>
                      </div>
                      <div className="flex h-4 overflow-hidden rounded-[5px] bg-[#161c24]">
                        <div style={{ width: `${p.you * 100}%`, background: "var(--color-green)" }} />
                        <div style={{ width: `${(1 - p.you) * 100}%`, ...HATCH_3 }} />
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {view === "calendar" && (
                <div>
                  <div className="mb-3.5 flex flex-wrap items-center justify-between gap-2">
                    <div className="text-[10px] tracking-[0.12em] text-[var(--color-dimmer)]">FOCUS CONTRIBUTIONS · 13 WEEKS</div>
                    <div className="flex items-center gap-1.5 text-[10px] text-[var(--color-dimmer)]">
                      less
                      {["#161c24", "rgba(63,185,80,.35)", "rgba(63,185,80,.65)", "#3FB950"].map((c) => (
                        <span key={c} className="h-2.5 w-2.5 rounded-[2px]" style={{ background: c }} />
                      ))}
                      more
                    </div>
                  </div>
                  <div className="grid w-max grid-flow-col grid-rows-7 gap-1">
                    {heat.map((c, i) => (
                      <div key={i} className="h-[13px] w-[13px] rounded-[3px]" style={{ background: c }} />
                    ))}
                  </div>
                  <div className="mt-4 text-[11px] text-[var(--color-dim)]">Longest streak <span className="text-[var(--color-green)]">21 days</span> · current <span className="text-[var(--color-green)]">12 days</span></div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
