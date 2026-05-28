import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { NextRequest } from "next/server";
import crypto from "node:crypto";

export const dynamic = "force-dynamic";

const COOKIE_NAME = "admin_session";
const SESSION_LABEL = "admin_session_v1";

function safeEqual(a: string, b: string) {
  const ab = Buffer.from(a, "utf8");
  const bb = Buffer.from(b, "utf8");
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

function sessionValue(secret: string) {
  return crypto
    .createHmac("sha256", secret)
    .update(SESSION_LABEL)
    .digest("hex");
}

const LOGIN_HTML = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Admin</title>
<meta name="robots" content="noindex,nofollow">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root{color-scheme:light}
body{font-family:-apple-system,system-ui,sans-serif;background:#f6f1e7;color:#1a1a1a;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px}
form{background:#fff;border:1px solid #e5e0d6;padding:32px;border-radius:16px;box-shadow:0 1px 3px rgba(0,0,0,.05);width:100%;max-width:320px}
label{display:block;font-size:12px;text-transform:uppercase;letter-spacing:.14em;color:#888;font-weight:600;margin-bottom:8px}
input{width:100%;padding:10px 12px;border:1px solid #e5e0d6;border-radius:8px;font:inherit;box-sizing:border-box;background:#fff;color:#1a1a1a}
input:focus{outline:none;border-color:#1a1a1a}
button{margin-top:12px;width:100%;padding:10px;border:0;border-radius:8px;background:#1a1a1a;color:#f6f1e7;font:inherit;font-weight:600;cursor:pointer}
</style></head><body>
<form method="POST" autocomplete="off">
<label for="t">Admin token</label>
<input id="t" name="token" type="password" autofocus required>
<button type="submit">Enter</button>
</form></body></html>`;

export async function GET() {
  return new Response(LOGIN_HTML, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
      "X-Robots-Tag": "noindex, nofollow",
    },
  });
}

export async function POST(req: NextRequest) {
  const form = await req.formData();
  const token = String(form.get("token") ?? "");
  const expected = process.env.ADMIN_TOKEN ?? "";
  if (!expected || !safeEqual(token, expected)) {
    return new Response("Not Found", { status: 404 });
  }
  const jar = await cookies();
  jar.set(COOKIE_NAME, sessionValue(expected), {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/admin",
    maxAge: 60 * 60 * 24 * 30,
  });
  redirect("/admin/downloads");
}
