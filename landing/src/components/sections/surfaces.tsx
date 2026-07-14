import { Ring } from "@/components/ring";
import { SplitBar, Meter } from "@/components/bar";

export function Surfaces() {
  return (
    <section className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-2 text-sm text-[var(--color-dimmer)]"># three quiet surfaces — glance anywhere</div>
        <h2 className="mb-8 text-[32px] font-extrabold tracking-[-0.02em] sm:text-[38px]">always a glance away.</h2>
        <div className="grid items-end gap-5 md:grid-cols-3">
          {/* menu bar */}
          <div>
            <div className="mb-3.5 text-[11px] tracking-[0.1em] text-[var(--color-dimmer)]">MENU BAR</div>
            <div className="inline-flex items-center gap-2 rounded-[7px] border border-[var(--color-green)] bg-[var(--color-panel)] px-3.5 py-2">
              <Ring size={16} stroke={8} />
              <span className="tnum text-sm font-semibold">6h 12m</span>
            </div>
            <p className="mt-4.5 max-w-[280px] text-[12.5px] leading-[1.6] text-[var(--color-dim)]">the split, one tap from every app you&apos;re in.</p>
          </div>
          {/* popover */}
          <div>
            <div className="mb-3.5 text-[11px] tracking-[0.1em] text-[var(--color-dimmer)]">POPOVER</div>
            <div className="rounded-[14px] border border-[var(--color-line)] bg-[var(--color-panel)] p-[18px] shadow-[0_30px_60px_-30px_rgba(0,0,0,.8)]">
              <div className="mb-3 flex items-center justify-between">
                <span className="text-[11px] tracking-[0.12em] text-[var(--color-dim)]">TODAY</span>
                <span className="rounded-full bg-[var(--color-green)]/[0.14] px-2 py-0.5 text-[10px] font-semibold text-[var(--color-green)]">● LIVE</span>
              </div>
              <div className="tnum mb-3 text-[38px] font-bold leading-none">6h 12m</div>
              <SplitBar you={0.63} height={12} className="mb-3.5" />
              <div className="rounded-lg bg-[var(--color-green)] py-2.5 text-center text-xs font-semibold text-[var(--color-on-green)]">Open Dashboard</div>
            </div>
          </div>
          {/* widget */}
          <div>
            <div className="mb-3.5 text-[11px] tracking-[0.1em] text-[var(--color-dimmer)]">DESKTOP WIDGET</div>
            <div className="rounded-[14px] border border-[var(--color-line)] bg-[var(--color-panel)] p-[18px] shadow-[0_30px_60px_-30px_rgba(0,0,0,.8)]">
              <div className="mb-3 flex items-center gap-2">
                <Ring size={15} stroke={8} />
                <span className="text-[11px] tracking-[0.12em] text-[var(--color-dim)]">TODAY</span>
                <span className="live ml-auto h-1.5 w-1.5 rounded-full bg-[var(--color-green)]" />
              </div>
              <div className="tnum text-[38px] font-bold leading-none">6h 12m</div>
              <div className="mb-3.5 mt-0.5 text-[10px] text-[var(--color-dimmer)]">+ 3h 40m agents · S / M / L / XL</div>
              <SplitBar you={0.63} height={12} className="mb-3" />
              <div className="mb-1.5 text-[10px] text-[var(--color-dim)]">SESSION 68% · 2H</div>
              <Meter value={0.68} height={6} />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
