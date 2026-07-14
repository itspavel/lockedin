import Link from "next/link";
import { Ring } from "@/components/ring";

export function SiteNav() {
  return (
    <header className="sticky top-0 z-50 border-b border-[var(--color-line)] bg-[var(--color-bg)]/85 backdrop-blur-md">
      <div className="mx-auto flex max-w-[1440px] items-center justify-between px-6 py-4 sm:px-10">
        <Link href="/" className="flex items-center gap-2.5">
          <Ring size={24} />
          <span className="text-[17px] font-semibold">lockedin</span>
          <span className="ml-1 rounded-[5px] border border-[var(--color-line-green)] px-1.5 py-0.5 text-[10px] text-[var(--color-green)]">v1.0 beta</span>
        </Link>
        <nav className="flex items-center gap-4 text-[13px] text-[var(--color-dim)] sm:gap-6">
          <Link href="/#how" className="hidden transition-colors hover:text-[var(--color-ink)] sm:inline">how_it_works</Link>
          <Link href="/#pricing" className="hidden transition-colors hover:text-[var(--color-ink)] sm:inline">pricing</Link>
          <Link href="/changelog" className="hidden transition-colors hover:text-[var(--color-ink)] md:inline">changelog</Link>
          <Link href="/privacy" className="hidden transition-colors hover:text-[var(--color-ink)] md:inline">privacy</Link>
          <Link href="/download" className="rounded-[7px] bg-[var(--color-green)] px-3.5 py-2 font-semibold text-[var(--color-on-green)] transition-colors hover:bg-[var(--color-green-hi)]">$ install</Link>
        </nav>
      </div>
    </header>
  );
}
