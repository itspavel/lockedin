import { NextRequest, NextResponse } from "next/server";
import { put } from "@vercel/blob";

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export async function POST(req: NextRequest) {
  const { email } = await req.json().catch(() => ({ email: "" }));
  if (typeof email !== "string" || !EMAIL.test(email)) {
    return NextResponse.json({ error: "Enter a valid email." }, { status: 400 });
  }
  try {
    // Durable capture in the private Blob store. Inspect with: vercel blob list
    await put(
      `waitlist/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.json`,
      JSON.stringify({ email, ts: new Date().toISOString() }),
      { access: "private", addRandomSuffix: false, contentType: "application/json" },
    );
  } catch (e) {
    console.error("waitlist store failed", e);
    return NextResponse.json({ error: "Couldn't save — try again." }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
