import { Ring } from "@/components/ring";
import { Ticker } from "@/components/ticker";
import { SplitBar } from "@/components/bar";

/** Stylised MacBook running a terminal with the LockedIn widget floating over it. */
export function MacBook() {
  return (
    <div className="relative mx-auto w-full max-w-[560px]">
      <div className="absolute -inset-10 -z-0 blur-2xl" style={{ background: "radial-gradient(closest-side, rgba(63,185,80,.14), transparent)" }} />

      <div className="relative">
        {/* screen */}
        <div className="relative overflow-hidden rounded-2xl border-[9px] border-[#10161c] bg-black shadow-[0_50px_100px_-35px_rgba(0,0,0,.95)]">
          {/* notch */}
          <div className="absolute left-1/2 top-0 z-30 flex h-4 w-28 -translate-x-1/2 justify-center rounded-b-[9px] bg-[#10161c]">
            <span className="mt-1 h-[5px] w-[5px] rounded-full bg-[#222b33]" />
          </div>

          <div className="relative aspect-[16/10.3] w-full" style={{ background: "radial-gradient(540px 350px at 70% 0%, #12281a 0%, #0b0f14 52%)" }}>
            <div className="pointer-events-none absolute inset-0" style={{ background: "radial-gradient(120% 90% at 50% 0%, transparent 60%, rgba(0,0,0,.35))" }} />

            {/* window titlebar */}
            <div className="flex items-center gap-2 border-b border-white/5 px-3.5 py-2">
              <span className="text-[11px] text-[#6b7684]">Ghostty — ~/lockedin</span>
              <div className="ml-auto flex items-center gap-1.5 rounded-[5px] border border-[var(--color-green)] px-1.5 py-0.5">
                <Ring size={11} stroke={8} />
                <span className="tnum text-[10px] font-semibold">6h 12m</span>
              </div>
            </div>

            {/* terminal text */}
            <div className="absolute left-4 top-[16%] hidden flex-col gap-2 opacity-55 sm:flex">
              <span className="text-[11px] text-[var(--color-green)]">$ git commit -m &quot;ship&quot;</span>
              <span className="text-[11px] text-[#6b7684]">[main 8f2a] ship</span>
              <span className="text-[11px] text-[#6b7684]">4 files changed, 218++</span>
              <span className="text-[11px] text-[var(--color-green)]">$ <span className="cur" /></span>
            </div>

            {/* floating widget */}
            <div className="absolute right-[4%] top-[15%] w-[46%] max-w-[246px] rounded-2xl border border-white/[0.09] bg-[#0b0f14]/85 p-[5%] shadow-[0_30px_60px_-25px_rgba(0,0,0,.9)] backdrop-blur-xl">
              <div className="mb-3 flex items-center gap-1.5">
                <Ring size={15} stroke={7} />
                <span className="text-[10px] tracking-[0.1em] text-[var(--color-dim)]">TODAY</span>
                <span className="live ml-auto h-[5px] w-[5px] rounded-full bg-[var(--color-green)]" />
              </div>
              <div className="tnum text-[clamp(22px,7cqw,40px)] font-bold leading-none">
                <Ticker value={372} format="hm" />
              </div>
              <div className="mb-3.5 mt-1 text-[10px] text-[var(--color-dimmer)]">+ 3h 40m agents</div>
              <SplitBar you={0.63} height={12} className="mb-2" />
              <div className="flex justify-between text-[9.5px] text-[var(--color-dim)]">
                <span>[you] 63%</span><span>[agents] 37%</span>
              </div>
            </div>
          </div>
        </div>

        {/* laptop base */}
        <div className="mx-auto h-3 w-[108%] rounded-b-[10px] shadow-[0_18px_30px_-12px_rgba(0,0,0,.8)]" style={{ background: "linear-gradient(180deg,#2a323c,#161c24)" }}>
          <div className="mx-auto h-1.5 w-28 rounded-b-[7px] bg-black/45" />
        </div>
        {/* reflection */}
        <div className="mx-auto mt-1.5 h-16 w-[94%] -scale-y-100 rounded-[50%] opacity-50 blur-md" style={{ background: "linear-gradient(180deg, rgba(63,185,80,.10), transparent)" }} />
      </div>
    </div>
  );
}
