import { Ring } from "@/components/ring";
import { SplitBar } from "@/components/bar";
import { Reveal } from "@/components/reveal";

export function ShareCard() {
  return (
    <section className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto grid max-w-[1440px] items-center gap-10 lg:grid-cols-[1fr_1.05fr] lg:gap-[52px]">
        <div>
          <div className="mb-2 text-sm text-[var(--color-dimmer)]"># build in public</div>
          <h2 className="mb-4 text-[30px] font-extrabold leading-[1.08] tracking-[-0.02em] sm:text-[36px]">
            flex your day<span className="text-[var(--color-green)]">.</span>
          </h2>
          <p className="max-w-[400px] text-sm leading-[1.7] text-[var(--color-dim)]">
            one tap turns today into a share card — the hero number, the you-vs-agent split, your streak.
            drop it on X and let the numbers do the talking.
          </p>
        </div>
        <Reveal>
          <div className="rounded-[18px] border border-[var(--color-line)] bg-[var(--color-panel)] p-7 shadow-[0_40px_90px_-50px_rgba(0,0,0,.9)] sm:p-9">
            <div className="mb-4 flex items-center gap-2 text-[11px] tracking-[0.18em] text-[var(--color-dimmer)]">
              <Ring size={16} stroke={8} /> DAY 12 — WEDDING-HYPERION
            </div>
            <div className="tnum text-[56px] font-extrabold leading-none sm:text-[64px]">7h 04m</div>
            <div className="mb-5 mt-2 text-[13px] text-[var(--color-dim)]">locked in · you 5h 30m + agents 1h 34m</div>
            <SplitBar you={0.78} height={16} className="mb-5" />
            <div className="flex flex-wrap gap-2.5 text-[11px] font-semibold">
              {["12-day streak", "146h total", "312 prompts"].map((b) => (
                <span key={b} className="rounded-full border border-[#2a333f] px-3 py-1.5 text-[var(--color-bright)]">{b}</span>
              ))}
            </div>
            <div className="mt-6 flex justify-between text-[11px] text-[var(--color-dimmer)]">
              <span>building in public</span><span className="font-bold">lockedin</span>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
