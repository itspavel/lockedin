export function Privacy() {
  const reads = ["timestamps", "project paths", "usage counts"];
  const never = ["your prompts", "your code", "anything that leaves your machine"];
  return (
    <section id="privacy" className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px] rounded-[14px] border border-[var(--color-line)] bg-[var(--color-panel)] p-8 sm:p-11">
        <div className="mb-4 text-sm text-[var(--color-green)]">$ lockedin --what-it-reads</div>
        <h2 className="mb-8 text-[28px] font-extrabold tracking-[-0.02em] sm:text-[34px]">reads logs, not your code.</h2>
        <div className="grid gap-8 sm:grid-cols-2">
          <div>
            <div className="mb-4 text-[11px] tracking-[0.14em] text-[var(--color-green)]">READS</div>
            <ul className="flex flex-col gap-3">
              {reads.map((r) => (
                <li key={r} className="flex items-center gap-3 text-[15px] text-[var(--color-bright)]">
                  <span className="text-[var(--color-green)]">✓</span> {r}
                </li>
              ))}
            </ul>
          </div>
          <div className="sm:border-l sm:border-[var(--color-line)] sm:pl-8">
            <div className="mb-4 text-[11px] tracking-[0.14em] text-[var(--color-red)]">NEVER</div>
            <ul className="flex flex-col gap-3">
              {never.map((r) => (
                <li key={r} className="flex items-center gap-3 text-[15px] text-[var(--color-dim)]">
                  <span className="text-[var(--color-red)]">✗</span> {r}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
