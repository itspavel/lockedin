"use client";
import { useRef } from "react";
import { motion, useInView } from "motion/react";
import { cn } from "@/lib/utils";

const hatch = {
  backgroundColor: "rgba(63,185,80,.18)",
  backgroundImage: "repeating-linear-gradient(45deg,#3FB950 0,#3FB950 3px,transparent 3px,transparent 9px)",
};

/** A you/agent split bar that fills left-to-right on scroll into view. */
export function SplitBar({ you, height = 20, className }: { you: number; height?: number; className?: string }) {
  const ref = useRef(null);
  const inView = useInView(ref, { once: true, margin: "-15%" });
  return (
    <div ref={ref} className={cn("flex overflow-hidden rounded-[5px] bg-[#161c24]", className)} style={{ height }}>
      <motion.div initial={{ width: 0 }} animate={{ width: inView ? `${you * 100}%` : 0 }}
        transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }} className="bg-[var(--color-green)]" />
      <motion.div initial={{ width: 0 }} animate={{ width: inView ? `${(1 - you) * 100}%` : 0 }}
        transition={{ duration: 1, delay: 0.05, ease: [0.22, 1, 0.36, 1] }} style={hatch} />
    </div>
  );
}

/** A single-value meter bar that fills on scroll. */
export function Meter({ value, color = "var(--color-green)", height = 7 }:
  { value: number; color?: string; height?: number }) {
  const ref = useRef(null);
  const inView = useInView(ref, { once: true, margin: "-15%" });
  return (
    <div ref={ref} className="overflow-hidden rounded-[4px] bg-[#161c24]" style={{ height }}>
      <motion.div initial={{ width: 0 }} animate={{ width: inView ? `${value * 100}%` : 0 }}
        transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }} className="h-full rounded-[4px]" style={{ background: color }} />
    </div>
  );
}
