import { SiteNav } from "@/components/site-nav";
import { SiteFooter } from "@/components/site-footer";

export function PageShell({ children }: { children: React.ReactNode }) {
  return (
    <>
      <SiteNav />
      <main className="mx-auto min-h-[70vh] max-w-[900px] px-6 py-16 sm:px-10 sm:py-20">{children}</main>
      <SiteFooter />
    </>
  );
}
