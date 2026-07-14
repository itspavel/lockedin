/**
 * Placeholder landing page — on-brand shell ready to be replaced by the real design.
 * Reusable brand pieces (RingMark, SplitBar) live here so the final build can drop them in.
 */

function RingMark({ size = 40, progress = 0.7 }: { size?: number; progress?: number }) {
  const r = 26;
  const c = 2 * Math.PI * r;
  return (
    <svg width={size} height={size} viewBox="0 0 72 72" aria-hidden>
      <circle cx="36" cy="36" r={r} fill="none" stroke="var(--color-coral)" strokeOpacity="0.25" strokeWidth="7" />
      <circle
        cx="36" cy="36" r={r} fill="none" stroke="var(--color-coral)" strokeWidth="7"
        strokeLinecap="round" strokeDasharray={c} strokeDashoffset={c * (1 - progress)}
        transform="rotate(-90 36 36)"
      />
      <circle cx="36" cy="36" r="7" fill="var(--color-coral)" />
    </svg>
  );
}

function SplitBar({ you = 0.32 }: { you?: number }) {
  return (
    <div className="flex h-3.5 w-full max-w-md overflow-hidden rounded-full ring-1 ring-white/15">
      <div style={{ width: `${you * 100}%`, background: "var(--color-you)" }} />
      <div
        className="flex-1"
        style={{
          backgroundImage:
            "repeating-linear-gradient(-45deg, var(--color-agent) 0 2px, transparent 2px 7px)",
          backgroundColor: "rgba(183,171,217,0.15)",
        }}
      />
    </div>
  );
}

export default function Home() {
  return (
    <main className="mx-auto flex max-w-3xl flex-1 flex-col items-start justify-center gap-8 px-6 py-24">
      <div className="flex items-center gap-3">
        <RingMark size={34} />
        <span className="text-lg font-semibold tracking-tight">LockedIn</span>
      </div>

      <h1 className="text-5xl font-bold leading-[1.05] tracking-tight sm:text-6xl">
        See where your hours{" "}
        <span style={{ color: "var(--color-accent)" }}>really</span> go.
      </h1>

      <p className="max-w-xl text-lg" style={{ color: "var(--color-ink-dim)" }}>
        An ambient, zero-input macOS time tracker that splits your day between{" "}
        <span style={{ color: "var(--color-you)" }}>you</span> and your{" "}
        <span style={{ color: "var(--color-agent)" }}>AI coding agents</span>. No timers to
        start. It just fills itself.
      </p>

      <SplitBar />
      <div className="flex gap-5 text-sm" style={{ color: "var(--color-ink-dim)" }}>
        <span className="flex items-center gap-2">
          <span className="inline-block h-3 w-3 rounded" style={{ background: "var(--color-you)" }} />
          You
        </span>
        <span className="flex items-center gap-2">
          <span className="inline-block h-3 w-3 rounded bg-[#b7abd9]/50" />
          Agents
        </span>
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-4">
        <a
          href="#"
          className="rounded-xl px-5 py-3 font-bold transition-opacity hover:opacity-90"
          style={{ background: "var(--color-accent)", color: "var(--color-accent-ink)" }}
        >
          Download for macOS
        </a>
        <span className="text-sm" style={{ color: "var(--color-ink-dim)" }}>
          Free · macOS 14+ · menu-bar app
        </span>
      </div>

      <p className="mt-16 text-xs" style={{ color: "var(--color-ink-dim)" }}>
        Placeholder — hand over the real design to replace this. Brand tokens live in{" "}
        <code>globals.css</code>.
      </p>
    </main>
  );
}
