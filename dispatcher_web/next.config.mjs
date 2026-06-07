import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = dirname(fileURLToPath(import.meta.url));
const isProduction = process.env.NODE_ENV === "production";
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
const enableHstsPreload = process.env.ENABLE_HSTS_PRELOAD === "true";
const hstsHeaderValue = [
  "max-age=31536000",
  ...(enableHstsPreload || process.env.ENABLE_HSTS_SUBDOMAINS === "true"
    ? ["includeSubDomains"]
    : []),
  ...(enableHstsPreload ? ["preload"] : []),
].join("; ");

/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    NEXT_PUBLIC_SUPABASE_URL: supabaseUrl,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: supabaseAnonKey,
  },
  outputFileTracingRoot: appDir,
  typedRoutes: true,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          // CSP is intentionally absent here — it is set per-request with a
          // cryptographic nonce by proxy.ts to eliminate 'unsafe-inline'.
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "Referrer-Policy",
            value: "no-referrer",
          },
          {
            key: "Permissions-Policy",
            value: "camera=(), geolocation=(), microphone=()",
          },
          ...(isProduction
            ? [
                {
                  key: "Strict-Transport-Security",
                  value: hstsHeaderValue,
                },
              ]
            : []),
        ],
      },
    ];
  },
};

export default nextConfig;
