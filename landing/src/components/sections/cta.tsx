export function Cta() {
  return (
    <section id="download" className="grid-bg border-b border-[var(--color-line)] px-6 py-24 text-center sm:py-[100px]"
      style={{ background: "radial-gradient(700px 400px at 50% 100%, rgba(63,185,80,.14), transparent 70%)" }}>
      <div className="mb-[18px] text-sm text-[var(--color-green)]">$ brew install lockedin</div>
      <h2 className="mx-auto mb-6 max-w-[700px] text-[38px] font-extrabold leading-none tracking-[-0.03em] sm:text-[56px]">stop guessing who wrote it.</h2>
      <a href="#" className="inline-block rounded-[9px] bg-[var(--color-green)] px-7 py-3.5 text-base font-semibold text-[var(--color-on-green)] transition-colors hover:bg-[var(--color-green-hi)]">install lockedin — free in beta</a>
      <div className="mt-4 text-xs text-[var(--color-dimmer)]"># apple silicon · 8.2 mb · no account</div>
    </section>
  );
}
