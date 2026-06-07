import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Buzhor Dispatcher",
  description: "Dispatcher control panel for Buzhor Courier"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // The nonce is applied automatically by Next.js to its own hydration
  // <script> tags, because proxy.ts puts a nonce-bearing Content-Security-Policy
  // on the request headers. Nothing to wire up here.
  return (
    <html lang="ru">
      <body>{children}</body>
    </html>
  );
}
