import { Meter } from "@/components/bar";

const L = [
  { name: "session", meta: "68% · 2h", value: 0.68, color: "var(--color-green)" },
  { name: "weekly", meta: "41% · sun", value: 0.41, color: "var(--color-blue)" },
  { name: "fable", meta: "22% · 5h", value: 0.22, color: "var(--color-purple)" },
];

export function Limits() {
  return (
    <section className="grid grid-cols-1 items-center gap-10 border-b border-[var(--color-line)] px-6 py-20 sm:px-12 lg:grid-cols-2 lg:gap-[52px]">
      <div className="mx-auto w-full max-w-[1440px] lg:mx-0">
        <div className="mb-2 text-sm text-[var(--color-dimmer)]"># never hit a wall</div>
        <h2 className="mb-4 text-[30px] font-extrabold leading-[1.08] tracking-[-0.02em] sm:text-[36px]">
          your claude limits, before they <span className="text-[var(--color-green)]">bite.</span>
        </h2>
        <p className="max-w-[400px] text-sm leading-[1.7] text-[var(--color-dim)]">session, weekly &amp; fable limits with live reset times — plus claude service status. know when to push, when to pace.</p>
      </div>
      <div className="flex flex-col gap-[18px] rounded-xl border border-[var(--color-line)] bg-[var(--color-panel)] p-7">
        {L.map((l) => (
          <div key={l.name}>
            <div className="mb-1.5 flex justify-between text-[13px] text-[var(--color-dim)]">
              <span>{l.name}</span><span>{l.meta}</span>
            </div>
            <Meter value={l.value} color={l.color} height={7} />
          </div>
        ))}
        <div className="flex items-center gap-2 border-t border-[var(--color-line)] pt-4 text-xs text-[var(--color-dim)]">
          <span className="live h-1.5 w-1.5 rounded-full bg-[var(--color-green)]" /> claude · all systems operational
        </div>
      </div>
    </section>
  );
}
