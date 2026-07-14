import { Reveal } from "@/components/reveal";

const QUOTES = [
  { q: "Turns out my agents wrote 71% of last week. LockedIn just tells you the truth, quietly.", a: "@indiehacker", r: "shipping proofly" },
  { q: "First tracker I haven't quit by day 3. Zero input is the whole game.", a: "@devbuilds", r: "solo founder" },
  { q: "The you-vs-agent split is the stat I didn't know I needed. Now it's my morning glance.", a: "@nightlybuild", r: "building w/ claude code" },
];

export function Social() {
  return (
    <section className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-2 text-sm text-[var(--color-dimmer)]"># from the build-in-public crowd</div>
        <h2 className="mb-9 text-[30px] font-extrabold tracking-[-0.02em] sm:text-[36px]">devs who stopped guessing.</h2>
        <div className="grid gap-4 md:grid-cols-3">
          {QUOTES.map((c, i) => (
            <Reveal key={i} delay={i * 0.08}>
              <figure className="h-full rounded-xl border border-[var(--color-line)] bg-[var(--color-panel)] p-6">
                <blockquote className="text-[14px] leading-[1.65] text-[var(--color-bright)]">&ldquo;{c.q}&rdquo;</blockquote>
                <figcaption className="mt-5 text-[12px] text-[var(--color-dim)]">
                  <span className="text-[var(--color-green)]">{c.a}</span> · {c.r}
                </figcaption>
              </figure>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
