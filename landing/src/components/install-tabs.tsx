"use client";
import { useState } from "react";
import { cn } from "@/lib/utils";

const CMDS: Record<string, string> = {
  curl: "curl -fsSL https://landing-zeta-coral.vercel.app/install | sh",
  brew: "brew install --cask --no-quarantine itspavel/tap/lockedin",
};

export function InstallTabs({ className }: { className?: string }) {
  const [tab, setTab] = useState<keyof typeof CMDS>("curl");
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try { await navigator.clipboard.writeText(CMDS[tab]); } catch {}
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className={cn("max-w-[430px] overflow-hidden rounded-[10px] border border-[var(--color-line)] bg-[var(--color-panel)]", className)}>
      <div className="flex border-b border-[var(--color-line)]">
        {(Object.keys(CMDS) as (keyof typeof CMDS)[]).map((k) => (
          <button
            key={k}
            onClick={() => setTab(k)}
            className={cn(
              "flex-1 cursor-pointer border-b-2 py-2.5 text-center text-[12.5px] transition-colors",
              tab === k
                ? "border-[var(--color-green)] bg-[var(--color-green)]/[0.06] text-[var(--color-green)]"
                : "border-transparent text-[var(--color-dimmer)] hover:text-[var(--color-dim)]",
            )}
          >
            {k}
          </button>
        ))}
      </div>
      <div className="flex items-center gap-2.5 px-4 py-3.5">
        <span className="text-[var(--color-green)]">$</span>
        <code className="flex-1 truncate text-[13.5px] text-[var(--color-ink)]">{CMDS[tab]}</code>
        <button
          onClick={copy}
          className="cursor-pointer rounded-md border border-[#2a333f] px-2.5 py-1.5 text-xs text-[var(--color-dim)] transition-colors hover:border-[var(--color-green)] hover:text-[var(--color-green)]"
        >
          {copied ? "copied ✓" : "copy"}
        </button>
      </div>
    </div>
  );
}
