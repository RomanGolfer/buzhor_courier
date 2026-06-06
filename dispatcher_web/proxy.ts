import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

const isProduction = process.env.NODE_ENV === "production";

export async function proxy(request: NextRequest) {
  // Generate a per-request nonce. Buffer is available in the Next.js proxy
  // runtime; the nonce is passed to server components via x-nonce so that
  // any <Script nonce={nonce}> tags get the correct value, and Next.js 16
  // automatically applies it to its own hydration <script> tags.
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64");

  const response = await updateSession(request, { "x-nonce": nonce });
  response.headers.set("Content-Security-Policy", buildCsp(nonce));

  return response;
}

function buildCsp(nonce: string): string {
  return [
    "default-src 'self'",
    "base-uri 'self'",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "frame-src 'none'",
    "form-action 'self'",
    "img-src 'self' data:",
    // unsafe-inline is unavoidable for Tailwind utility classes.
    "style-src 'self' 'unsafe-inline'",
    // In production: strict-dynamic trusts dynamically loaded chunks from any
    // nonced script (RSC payloads, code-split bundles). No unsafe-eval needed.
    // In dev: unsafe-eval is required for Next.js HMR.
    isProduction
      ? `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'`
      : `script-src 'self' 'nonce-${nonce}' 'unsafe-eval'`,
    "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
    "manifest-src 'self'",
    "worker-src 'self'",
    ...(isProduction ? ["upgrade-insecure-requests"] : []),
  ].join("; ");
}

export const config = {
  matcher: [
    {
      source: "/((?!_next/static|_next/image|favicon.ico).*)",
      missing: [
        { type: "header", key: "next-router-prefetch" },
        { type: "header", key: "purpose", value: "prefetch" },
      ],
    },
  ],
};
