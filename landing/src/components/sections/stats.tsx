const STATS = [
  { v: "0", l: "timers to start · ever" },
  { v: "<1%", l: "cpu · idle in the background" },
  { v: "100%", l: "local · nothing leaves your mac" },
];

export function Stats() {
  return (
    <div className="grid grid-cols-1 border-y border-[var(--color-line)] bg-[var(--color-panel)] sm:grid-cols-3">
      {STATS.map((s, i) => (
        <div key={s.l}
          className={`group px-8 py-8 transition-colors hover:bg-[var(--color-green)]/[0.04] sm:px-10 ${i < 2 ? "border-b border-[var(--color-line)] sm:border-b-0 sm:border-r" : ""}`}>
          <div className="tnum text-[34px] font-extrabold text-[var(--color-green)]">{s.v}</div>
          <div className="mt-1.5 text-xs text-[var(--color-dimmer)] transition-colors group-hover:text-[var(--color-dim)]">{s.l}</div>
        </div>
      ))}
    </div>
  );
}
