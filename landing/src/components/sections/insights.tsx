import { Reveal } from "@/components/reveal";

const CARDS = [
  { hot: true, t: "You shipped 41% faster on days you kept agent time under 40%. Your deep-work window is 9–11am — protect it." },
  { hot: false, t: "api-refactor is 78% agent-driven. Worth a human review pass before it merges." },
];

export function Insights() {
  return (
    <section id="insights" className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12"
      style={{ background: "radial-gradient(700px 400px at 80% 0%, rgba(63,185,80,.08), transparent 70%)" }}>
      <div className="mx-auto grid max-w-[1440px] items-center gap-10 lg:grid-cols-[1fr_1.1fr] lg:gap-[52px]">
        <div>
          <div className="mb-2 text-sm text-[var(--color-dimmer)]"># optional · claude-generated</div>
          <h2 className="mb-4 text-[30px] font-extrabold leading-[1.08] tracking-[-0.02em] sm:text-[36px]">
            not just the numbers.<br />the <span className="text-[var(--color-green)]">read</span> on them.
          </h2>
          <p className="max-w-[400px] text-sm leading-[1.7] text-[var(--color-dim)]">drop in a claude key and lockedin turns your day into plain-english insight — when you ship fastest, when agents help most, when to step in.</p>
        </div>
        <div className="flex flex-col gap-3.5">
          {CARDS.map((c, i) => (
            <Reveal key={i} delay={i * 0.1}>
              <div className={`rounded-xl border p-[22px] ${c.hot ? "border-[var(--color-line-green)]" : "border-[var(--color-line)]"} bg-[var(--color-panel)]`}>
                <div className="mb-2.5 text-[11px] text-[var(--color-green)]">✦ AI INSIGHT</div>
                <p className="text-sm leading-[1.6] text-[var(--color-bright)]">{c.t}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
