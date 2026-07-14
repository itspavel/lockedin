"use client";
import { motion } from "motion/react";
import { ReactNode } from "react";

/** Fade-and-rise on scroll into view. */
export function Reveal({ children, delay = 0, y = 20, className }:
  { children: ReactNode; delay?: number; y?: number; className?: string }) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-12%" }}
      transition={{ duration: 0.6, delay, ease: [0.22, 1, 0.36, 1] }}
    >
      {children}
    </motion.div>
  );
}
