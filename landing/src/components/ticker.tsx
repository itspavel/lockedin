"use client";
import { useEffect, useRef, useState } from "react";
import { useInView } from "motion/react";

export const fmtHM = (n: number) => {
  const total = Math.round(n), h = Math.floor(total / 60), m = total % 60;
  return h > 0 ? `${h}h ${String(m).padStart(2, "0")}m` : `${m}m`;
};

// String-keyed formats so this client component can be used from server components
// (functions can't be passed as props across the server/client boundary).
type Fmt = "int" | "hm" | "pct";
const FORMATTERS: Record<Fmt, (n: number) => string> = {
  int: (n) => String(Math.round(n)),
  hm: fmtHM,
  pct: (n) => `${Math.round(n)}%`,
};

/** Counts up to `value` when in view. */
export function Ticker({ value, format = "int", duration = 1300, className }:
  { value: number; format?: Fmt; duration?: number; className?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true, margin: "-10%" });
  const [n, setN] = useState(0);
  useEffect(() => {
    if (!inView) return;
    let raf = 0;
    const t0 = performance.now();
    const step = (now: number) => {
      const t = Math.min(1, (now - t0) / duration);
      setN(value * (1 - Math.pow(1 - t, 3)));
      if (t < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [inView, value, duration]);
  return <span ref={ref} className={className}>{FORMATTERS[format](n)}</span>;
}
