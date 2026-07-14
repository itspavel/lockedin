"use client";
import { useState } from "react";

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [msg, setMsg] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setState("loading");
    try {
      const r = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email }),
      });
      if (r.ok) { setState("done"); return; }
      const j = await r.json().catch(() => ({}));
      setMsg(j.error || "Something went wrong.");
      setState("error");
    } catch {
      setMsg("Network error — try again.");
      setState("error");
    }
  }

  if (state === "done") {
    return <div className="rounded-[9px] border border-[var(--color-line-green)] bg-[var(--color-green)]/[0.06] px-3 py-3 text-sm text-[var(--color-green)]">✓ You&apos;re on the list. We&apos;ll email you when Pro lands.</div>;
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-2">
      <div className="flex gap-2">
        <input
          type="email" required value={email} onChange={(e) => setEmail(e.target.value)}
          placeholder="you@dev.com"
          className="min-w-0 flex-1 rounded-[9px] border border-[#2a333f] bg-[var(--color-bg)] px-3 py-3 text-sm text-[var(--color-ink)] outline-none transition-colors focus:border-[var(--color-green)]"
        />
        <button type="submit" disabled={state === "loading"}
          className="rounded-[9px] border border-[#2a333f] px-4 text-sm font-semibold text-[var(--color-dim)] transition-colors hover:border-[var(--color-dim)] hover:text-[var(--color-ink)] disabled:opacity-60">
          {state === "loading" ? "…" : "join"}
        </button>
      </div>
      {state === "error" && <div className="text-xs text-[var(--color-red)]">{msg}</div>}
    </form>
  );
}
