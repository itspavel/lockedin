import { SplitBar } from "@/components/bar";

const ROWS = [
  { name: "wedding-hyperion", label: "7h 04m  ·  78% you", you: 0.78 },
  { name: "proofly-web", label: "4h 18m  ·  41% you", you: 0.41 },
  { name: "api-refactor", label: "2h 30m  ·  22% you", you: 0.22 },
];

export function Split() {
  return (
    <section className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-5 text-sm text-[var(--color-green)]">$ lockedin --projects --today</div>
        <h2 className="mb-8 text-[32px] font-extrabold leading-tight tracking-[-0.02em] sm:text-[38px]">
          one bar per project.<br />
          <span className="text-[18px] font-normal text-[var(--color-dim)]"># solid = you · hatched = agents</span>
        </h2>
        <div className="flex flex-col gap-[18px]">
          {ROWS.map((r) => (
            <div key={r.name}>
              <div className="mb-2 flex justify-between text-[13px] text-[var(--color-dim)]">
                <span>{r.name}</span><span className="tnum text-[var(--color-ink)]">{r.label}</span>
              </div>
              <SplitBar you={r.you} height={20} />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
