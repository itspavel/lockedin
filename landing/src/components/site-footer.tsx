import Link from "next/link";
import { Ring } from "@/components/ring";

export function SiteFooter() {
  return (
    <footer className="mx-auto flex max-w-[1440px] flex-wrap items-center justify-between gap-4 px-6 py-6 sm:px-12">
      <Link href="/" className="flex items-center gap-2.5">
        <Ring size={20} />
        <span className="text-[15px] font-semibold">lockedin</span>
      </Link>
      <div className="flex flex-wrap gap-[22px] text-xs text-[var(--color-dimmer)]">
        <Link href="/download" className="hover:text-[var(--color-dim)]">download</Link>
        <Link href="/privacy" className="hover:text-[var(--color-dim)]">privacy</Link>
        <Link href="/changelog" className="hover:text-[var(--color-dim)]">changelog</Link>
        <Link href="/docs" className="hover:text-[var(--color-dim)]">docs</Link>
        <span>© 2026</span>
      </div>
    </footer>
  );
}
