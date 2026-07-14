"use client";
import { useState } from "react";

const QA = [
  { q: "Does it read my code or prompts?", a: "No. Only timestamps, project paths and usage counts from local logs. Your prompts and code never leave your machine." },
  { q: "Do I have to start a timer?", a: "Never. It's fully ambient — install once and it tracks the split automatically, midnight to midnight." },
  { q: "Which tools does it detect?", a: "Claude Code and Cursor today, with VS Code, Zed, Warp and Ghostty in the mix. More by request." },
  { q: "Is it really free?", a: "Yes — free through beta, and free forever for early users. Pro adds AI insights and team features later." },
];

export function Faq() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <section className="border-b border-[var(--color-line)] px-6 py-20 sm:px-12">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-2 text-sm text-[var(--color-dimmer)]"># faq</div>
        <h2 className="mb-8 text-[30px] font-extrabold tracking-[-0.02em] sm:text-[36px]">the honest answers.</h2>
        <div className="flex flex-col">
          {QA.map((item, i) => {
            const isOpen = open === i;
            return (
              <div key={i} className="border-t border-[var(--color-line)] last:border-b">
                <button onClick={() => setOpen(isOpen ? null : i)}
                  className="flex w-full items-center justify-between gap-4 py-6 text-left">
                  <span className="text-base text-[var(--color-ink)]">{item.q}</span>
                  <span className={`shrink-0 text-[var(--color-green)] transition-transform duration-200 ${isOpen ? "rotate-45" : ""}`}>+</span>
                </button>
                <div className={`grid overflow-hidden transition-all duration-300 ${isOpen ? "grid-rows-[1fr] pb-6" : "grid-rows-[0fr]"}`}>
                  <p className="min-h-0 max-w-[640px] text-[13.5px] leading-[1.6] text-[var(--color-dim)]">{item.a}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
