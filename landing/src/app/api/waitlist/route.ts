import { NextRequest, NextResponse } from "next/server";
import { appendFile } from "node:fs/promises";

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export async function POST(req: NextRequest) {
  const { email } = await req.json().catch(() => ({ email: "" }));
  if (typeof email !== "string" || !EMAIL.test(email)) {
    return NextResponse.json({ error: "Enter a valid email." }, { status: 400 });
  }
  // Best-effort local capture. Swap for Resend/Loops/DB when you have one.
  try {
    await appendFile("/tmp/lockedin-waitlist.jsonl", JSON.stringify({ email, ts: new Date().toISOString() }) + "\n");
  } catch {}
  return NextResponse.json({ ok: true });
}
