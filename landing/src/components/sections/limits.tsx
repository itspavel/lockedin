import { Meter } from "@/components/bar";
import { Ticker } from "@/components/ticker";
import { Reveal } from "@/components/reveal";

const LIMITS = [
  { name: "SESSION", pct: 68, reset: "resets in 2h", color: "var(--color-green)", glow: "rgba(63,185,80,.14)" },
  { name: "WEEKLY", pct: 41, reset: "resets sunday", color: "var(--color-blue)", glow: "rgba(74,163,216,.14)" },
  { name: "FABLE", pct: 22, reset: "resets in 5h", color: "var(--color-purple)", glow: "rgba(201,140,216,.14)" },
];

export function Limits() {
  return (
    <section className="border-b border-[var(--color-line)] px-6 py-24 sm:px-12"
      style={{ background: "radial-gradient(900px 460px at 50% -10%, rgba(63,185,80,.06), transparent 70%)" }}>
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-3 flex flex-wrap items-center gap-2 text-sm">
          <span className="rounded-[5px] border border-[var(--color-line-green)] bg-[var(--color-green)]/[0.06] px-2 py-0.5 text-[11px] text-[var(--color-green)]">★ the standout</span>
          <span className="text-[var(--color-dimmer)]"># the feature builders keep asking for</span>
        </div>
        <h2 className="max-w-[760px] text-[34px] font-extrabold leading-[1.06] tracking-[-0.02em] sm:text-[46px]">
          your Claude limits, <span className="text-[var(--color-green)]">before they bite.</span>
        </h2>
        <p className="mt-4 max-w-[560px] text-[15px] leading-[1.7] text-[var(--color-dim)]">
          Session, Weekly and Fable limits — live percentage, exact reset times, and Claude service status,
          right in your menu bar. Never get cut off mid-ship again. Know when to push, and when to pace.
        </p>

        <div className="mt-10 grid gap-4 md:grid-cols-3">
          {LIMITS.map((l, i) => (
            <Reveal key={l.name} delay={i * 0.08}>
              <div className="group relative overflow-hidden rounded-2xl border border-[var(--color-line)] bg-[var(--color-panel)] p-7 transition-colors hover:border-[#2a333f]">
                <div className="pointer-events-none absolute -right-16 -top-16 h-40 w-40 rounded-full opacity-0 blur-2xl transition-opacity duration-500 group-hover:opacity-100" style={{ background: l.glow }} />
                <div className="relative z-10">
                  <div className="mb-4 flex items-center justify-between">
                    <span className="text-[11px] tracking-[0.16em] text-[var(--color-dim)]">{l.name}</span>
                    <span className="text-[11px] text-[var(--color-dimmer)]">{l.reset}</span>
                  </div>
                  <div className="tnum mb-4 text-[52px] font-extrabold leading-none" style={{ color: l.color }}>
                    <Ticker value={l.pct} format={(n) => `${Math.round(n)}%`} />
                  </div>
                  <Meter value={l.pct / 100} color={l.color} height={9} />
                </div>
              </div>
            </Reveal>
          ))}
        </div>

        <div className="mt-5 flex flex-wrap items-center gap-x-3 gap-y-1 rounded-xl border border-[var(--color-line)] bg-[var(--color-panel)] px-5 py-4 text-[13px] text-[var(--color-dim)]">
          <span className="live h-2 w-2 rounded-full bg-[var(--color-green)]" />
          <span className="text-[var(--color-ink)]">claude · all systems operational</span>
          <span className="text-[var(--color-dimmer)]">— status polled with your limits, so an outage never looks like your bug.</span>
        </div>
      </div>
    </section>
  );
}
