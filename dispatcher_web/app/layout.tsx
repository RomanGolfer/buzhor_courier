import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Buzhor Dispatcher",
  description: "Dispatcher control panel for Buzhor Courier"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru">
      <body>{children}</body>
    </html>
  );
}
