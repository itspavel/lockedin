import { Reveal } from "@/components/reveal";

const STEPS = [
  { n: "01", t: "drop it in", d: "lives in your menu bar. 8 MB. no account. watching in seconds.", hot: false },
  { n: "02", t: "just code", d: "use cursor & claude code like always. it reads local logs.", hot: false },
  { n: "03", t: "glance", d: "bar, popover or desktop widget — the split is always right there.", hot: true },
];

export function How() {
  return (
    <section id="how" className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12 sm:py-20">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-2 text-sm text-[var(--color-dimmer)]"># live in three steps — zero input</div>
        <h2 className="mb-9 text-[32px] font-extrabold tracking-[-0.02em] sm:text-[38px]">install &amp; forget<span className="text-[var(--color-green)]">.</span></h2>
        <div className="grid gap-4 md:grid-cols-3">
          {STEPS.map((s, i) => (
            <Reveal key={s.n} delay={i * 0.08}>
              <div className={`h-full rounded-xl border p-7 ${s.hot ? "border-[var(--color-green)] bg-[var(--color-green)]/[0.05]" : "border-[var(--color-line)] bg-[var(--color-panel)]"}`}>
                <div className="mb-3.5 text-[13px] text-[var(--color-green)]">{s.n}</div>
                <div className="mb-2 text-[19px] font-semibold">{s.t}</div>
                <p className={`text-[13px] leading-[1.65] ${s.hot ? "text-[#a8d8b4]" : "text-[var(--color-dim)]"}`}>{s.d}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
