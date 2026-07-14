import { cn } from "@/lib/utils";
import { ReactNode } from "react";

/** A card with a slowly rotating green "beam" border. */
export function BorderBeam({ children, className, radius = "1rem" }: { children: ReactNode; className?: string; radius?: string }) {
  return (
    <div className={cn("relative overflow-hidden p-[1.5px]", className)} style={{ borderRadius: radius }}>
      <span className="absolute -inset-[150%] animate-spin-slow"
        style={{ background: "conic-gradient(from 0deg, transparent 0 62%, var(--color-green) 76%, #a6f0b3 84%, transparent 94%)" }} />
      <div className="relative h-full w-full" style={{ borderRadius: `calc(${radius} - 1.5px)`, background: "var(--color-panel)" }}>
        {children}
      </div>
    </div>
  );
}
