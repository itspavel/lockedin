import { Ring } from "@/components/ring";

export function Footer() {
  return (
    <footer className="mx-auto flex max-w-[1440px] flex-wrap items-center justify-between gap-4 px-6 py-6 sm:px-12">
      <div className="flex items-center gap-2.5">
        <Ring size={20} />
        <span className="text-[15px] font-semibold">lockedin</span>
      </div>
      <div className="flex gap-[22px] text-xs text-[var(--color-dimmer)]">
        <a href="#privacy" className="text-[var(--color-dimmer)] hover:text-[var(--color-dim)]">privacy</a>
        <span>changelog</span><span>docs</span><span>© 2026</span>
      </div>
    </footer>
  );
}
