import { InstallTabs } from "@/components/install-tabs";
import { MacBook } from "@/components/sections/macbook";
import { TOOLS } from "@/components/brand-logos";

export function Hero() {
  return (
    <section className="grid-bg relative" style={{ background: "radial-gradient(760px 480px at 50% -6%, rgba(63,185,80,.14), transparent 70%)" }}>
      <div className="mx-auto grid max-w-[1440px] items-center gap-12 px-6 pb-8 pt-16 sm:px-10 sm:pt-20 lg:grid-cols-[1fr_1.05fr]">
        {/* copy */}
        <div>
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-[var(--color-green)]/[0.22] bg-[var(--color-green)]/[0.08] px-3.5 py-1.5 text-xs text-[var(--color-green)]">
            <span className="live h-1.5 w-1.5 rounded-full bg-[var(--color-green)]" /> ambient · macOS menu bar
          </div>

          <h1 className="text-[40px] font-extrabold leading-[1.04] tracking-[-0.03em] sm:text-[52px]">
            Who really wrote<br />today&apos;s <span className="text-[var(--color-green)]">code?<span className="cur" /></span>
          </h1>

          <p className="mt-6 max-w-[480px] text-[15px] leading-[1.85] text-[var(--color-dim)]">
            <span className="text-[var(--color-dimmer)]"># </span>you think you wrote most of it today.<br />
            <span className="text-[var(--color-dimmer)]"># </span>lockedin knows the real you-vs-agent split.<br />
            <span className="text-[var(--color-dimmer)]"># </span>per project · all day · zero input.
          </p>

          <div className="mt-8">
            <InstallTabs />
          </div>
          <div className="mt-4 text-xs text-[var(--color-dimmer)]"># apple silicon · 8.2 mb · no account</div>
        </div>

        {/* device */}
        <div className="min-w-0">
          <MacBook />
        </div>
      </div>

      {/* proof band · logo wall (real official logos) */}
      <div className="mx-auto max-w-[1440px] px-6 pb-8 pt-4 sm:px-10">
        <div className="mb-4 text-xs text-[var(--color-dimmer)]"># reads your stack — works with:</div>
        <div className="flex flex-wrap gap-3">
          {TOOLS.map((t) => (
            <div key={t.name}
              className={`flex items-center gap-2.5 rounded-[9px] border px-3.5 py-2.5 transition-colors ${
                "tag" in t ? "border-[var(--color-line-green)] bg-[var(--color-green)]/[0.05]" : "border-[var(--color-line)] bg-[var(--color-panel)] hover:border-[#2a333f]"
              }`}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={t.src} alt={t.name} width={17} height={17} className="h-[17px] w-[17px] object-contain" />
              <span className="text-[13px] font-medium text-[var(--color-bright)]">
                {t.name}{"tag" in t && <span className="ml-1 text-[10px] text-[var(--color-green)]">{t.tag}</span>}
              </span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
