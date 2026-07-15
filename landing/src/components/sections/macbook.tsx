import { Ring } from "@/components/ring";
import { Ticker } from "@/components/ticker";
import { SplitBar } from "@/components/bar";

/** A realistic MacBook Pro running a terminal with the LockedIn widget floating over it. */
export function MacBook() {
  return (
    <div className="relative mx-auto w-full max-w-[580px]">
      <div className="absolute -inset-12 -z-0 blur-2xl" style={{ background: "radial-gradient(closest-side, rgba(63,185,80,.13), transparent)" }} />

      <div className="relative">
        {/* ---- lid: aluminum bezel + screen ---- */}
        <div className="relative rounded-[20px] p-[11px] shadow-[0_40px_90px_-30px_rgba(0,0,0,.9)]"
          style={{ background: "linear-gradient(160deg,#3a3f46,#1c1f24 40%,#111418)" }}>
          <div className="relative overflow-hidden rounded-[11px] bg-black">
            {/* notch */}
            <div className="absolute left-1/2 top-0 z-30 flex h-[15px] w-[92px] -translate-x-1/2 items-start justify-center rounded-b-[8px] bg-black">
              <span className="mt-[5px] h-[5px] w-[5px] rounded-full bg-[#1b2a20]" />
            </div>

            <div className="relative aspect-[16/10.2] w-full" style={{ background: "radial-gradient(560px 360px at 70% -5%, #12281a 0%, #0a0d12 55%)" }}>
              {/* screen gloss */}
              <div className="pointer-events-none absolute inset-0" style={{ background: "linear-gradient(115deg, rgba(255,255,255,.05) 0%, transparent 22%, transparent 100%)" }} />
              <div className="pointer-events-none absolute inset-0" style={{ background: "radial-gradient(120% 90% at 50% 0%, transparent 58%, rgba(0,0,0,.4))" }} />

              {/* window titlebar */}
              <div className="flex items-center gap-2 border-b border-white/[0.06] px-4 py-2">
                <span className="text-[11px] text-[#6b7684]">Ghostty — ~/lockedin</span>
                <div className="ml-auto flex items-center gap-1.5 rounded-[5px] border border-[var(--color-green)]/70 px-1.5 py-0.5">
                  <Ring size={11} stroke={8} />
                  <span className="tnum text-[10px] font-semibold">6h 12m</span>
                </div>
              </div>

              {/* terminal text */}
              <div className="absolute left-[5%] top-[16%] hidden flex-col gap-2 opacity-55 sm:flex">
                <span className="text-[11px] text-[var(--color-green)]">$ git commit -m &quot;ship&quot;</span>
                <span className="text-[11px] text-[#6b7684]">[main 8f2a] ship</span>
                <span className="text-[11px] text-[#6b7684]">4 files changed, 218++</span>
                <span className="text-[11px] text-[var(--color-green)]">$ <span className="cur" /></span>
              </div>

              {/* floating widget */}
              <div className="absolute right-[5%] top-[15%] w-[47%] max-w-[248px] rounded-2xl border border-white/[0.09] bg-[#0b0f14]/85 p-[5%] shadow-[0_30px_60px_-25px_rgba(0,0,0,.9)] backdrop-blur-xl">
                <div className="mb-3 flex items-center gap-1.5">
                  <Ring size={15} stroke={7} />
                  <span className="text-[10px] tracking-[0.1em] text-[var(--color-dim)]">TODAY</span>
                  <span className="live ml-auto h-[5px] w-[5px] rounded-full bg-[var(--color-green)]" />
                </div>
                <div className="tnum text-[clamp(22px,7cqw,40px)] font-bold leading-none"><Ticker value={372} format="hm" /></div>
                <div className="mb-3.5 mt-1 text-[10px] text-[var(--color-dimmer)]">+ 3h 40m agents</div>
                <SplitBar you={0.63} height={12} className="mb-2" />
                <div className="flex justify-between text-[9.5px] text-[var(--color-dim)]"><span>[you] 63%</span><span>[agents] 37%</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* ---- base: aluminum deck + hinge + front notch ---- */}
        <div className="relative mx-auto -mt-[2px] h-[15px] w-[116%] rounded-b-[7px] rounded-t-[2px]"
          style={{ background: "linear-gradient(180deg,#4a505a 0%,#2b3038 12%,#20242b 100%)" }}>
          {/* hinge highlight */}
          <div className="absolute inset-x-0 top-0 h-px bg-white/10" />
          {/* front lip notch */}
          <div className="absolute left-1/2 top-0 h-[6px] w-[86px] -translate-x-1/2 rounded-b-[7px]" style={{ background: "linear-gradient(180deg,#171a1f,#22262d)" }} />
        </div>
        <div className="mx-auto h-[3px] w-[74%] rounded-b-[10px] bg-black/50 blur-[1px]" />
        {/* reflection */}
        <div className="mx-auto mt-2 h-14 w-[86%] -scale-y-100 rounded-[50%] opacity-40 blur-md" style={{ background: "linear-gradient(180deg, rgba(63,185,80,.10), transparent)" }} />
      </div>
    </div>
  );
}
