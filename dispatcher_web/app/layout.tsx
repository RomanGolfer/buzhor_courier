import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export const metadata: Metadata = {
  title: "Buzhor Dispatcher",
  description: "Dispatcher control panel for Buzhor Courier"
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // Next.js 14+ automatically applies x-nonce to its own hydration <script>
  // tags when the CSP response header contains a nonce. Reading it here makes
  // it available for any future <Script nonce={nonce}> third-party inclusions.
  const nonce = (await headers()).get("x-nonce") ?? undefined;

  return (
    <html lang="ru">
      <body>{children}</body>
    </html>
  );
}
