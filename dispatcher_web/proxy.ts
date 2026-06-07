import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

const isProduction = process.env.NODE_ENV === "production";

export async function proxy(request: NextRequest) {
  // Generate a per-request nonce using Web-standard APIs only. The proxy runs
  // on the Edge runtime where Node's Buffer is not guaranteed, so use
  // crypto.getRandomValues + btoa (both available on Edge).
  const randomBytes = crypto.getRandomValues(new Uint8Array(16));
  const nonce = btoa(String.fromCharCode(...randomBytes));

  const csp = buildCsp(nonce);

  // The CSP must be set on the REQUEST headers too: Next.js reads the nonce
  // from the request's Content-Security-Policy header to stamp it onto its own
  // hydration/bootstrap <script> tags. Setting it only on the response is not
  // enough — with 'strict-dynamic' in production, un-nonced scripts are blocked
  // and the panel fails to hydrate. x-nonce is exposed for any future
  // first-party <Script nonce={nonce}> usage.
  const response = await updateSession(request, {
    "x-nonce": nonce,
    "Content-Security-Policy": csp,
  });
  response.headers.set("Content-Security-Policy", csp);

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
