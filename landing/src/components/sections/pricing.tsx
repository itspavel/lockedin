import Link from "next/link";
import { BorderBeam } from "@/components/border-beam";
import { WaitlistForm } from "@/components/waitlist-form";

export function Pricing() {
  return (
    <section id="pricing" className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-2 text-sm text-[var(--color-dimmer)]"># pricing</div>
        <h2 className="mb-8 text-[32px] font-extrabold tracking-[-0.02em] sm:text-[38px]">free while we&apos;re in beta.</h2>
        <div className="grid items-stretch gap-5 md:grid-cols-2">
          {/* Beta — border beam highlight */}
          <BorderBeam radius="1rem">
            <div className="h-full rounded-2xl p-8 sm:p-[34px]">
              <div className="mb-1.5 flex items-baseline gap-2.5">
                <span className="text-[22px] font-bold">Beta</span>
                <span className="rounded-[5px] border border-[var(--color-line-green)] px-1.5 py-0.5 text-[11px] text-[var(--color-green)]">now</span>
              </div>
              <div className="tnum mb-[18px] text-[44px] font-extrabold">$0<span className="text-[15px] font-normal text-[var(--color-dimmer)]"> / forever for early users</span></div>
              <div className="mb-6 flex flex-col gap-2.5 text-[13px] text-[var(--color-bright)]">
                {["menu bar · popover · desktop widget", "unlimited projects & history", "claude limits + service status", "csv export"].map((f) => (
                  <span key={f}><span className="text-[var(--color-green)]">✓</span> {f}</span>
                ))}
              </div>
              <Link href="/download" className="block rounded-[9px] bg-[var(--color-green)] py-3 text-center text-sm font-semibold text-[var(--color-on-green)] transition-colors hover:bg-[var(--color-green-hi)]">install lockedin</Link>
            </div>
          </BorderBeam>

          {/* Pro — working waitlist */}
          <div className="rounded-2xl border border-[var(--color-line)] bg-[var(--color-panel)] p-8 sm:p-[34px]">
            <div className="mb-1.5 flex items-baseline gap-2.5">
              <span className="text-[22px] font-bold">Pro</span>
              <span className="rounded-[5px] border border-[#2a333f] px-1.5 py-0.5 text-[11px] text-[var(--color-dimmer)]">soon</span>
            </div>
            <div className="tnum mb-[18px] text-[44px] font-extrabold text-[var(--color-dim)]">$6<span className="text-[15px] font-normal text-[var(--color-dimmer)]"> / mo</span></div>
            <div className="mb-6 flex flex-col gap-2.5 text-[13px] text-[var(--color-dim)]">
              {["everything in Beta", "claude-generated AI insights", "team split & shared reports", "shareable focus cards"].map((f) => (
                <span key={f}><span className="text-[var(--color-green)]">✓</span> {f}</span>
              ))}
            </div>
            <WaitlistForm />
          </div>
        </div>
      </div>
    </section>
  );
}
