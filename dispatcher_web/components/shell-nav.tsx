"use client";

import { ClipboardList, Plus, Truck, UsersRound, type LucideIcon } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

const links: {
  href: "/" | "/orders/new" | "/couriers" | "/users";
  icon: LucideIcon;
  label: string;
  match: (pathname: string) => boolean;
}[] = [
  { href: "/", icon: ClipboardList, label: "Заказы", match: (pathname) => pathname === "/" },
  { href: "/orders/new", icon: Plus, label: "Новый", match: (pathname) => pathname.startsWith("/orders/new") },
  { href: "/couriers", icon: Truck, label: "Курьеры", match: (pathname) => pathname.startsWith("/couriers") },
  { href: "/users", icon: UsersRound, label: "Пользователи", match: (pathname) => pathname.startsWith("/users") }
];

export function ShellNav() {
  const pathname = usePathname();

  return (
    <nav className="app-scrollbar flex-1 overflow-y-auto py-3">
      {links.map((link) => {
        const Icon = link.icon;
        const isActive = link.match(pathname);

        return (
          <Link
            className={`group flex min-h-[76px] flex-col items-center justify-center gap-2 border-l-2 px-2 text-center text-xs font-semibold transition ${
              isActive
                ? "border-brand bg-brand/5 text-brand"
                : "border-transparent text-ink hover:border-brand/60 hover:bg-slate-50 hover:text-brand"
            }`}
            href={link.href}
            key={link.href}
          >
            <Icon aria-hidden className="size-6 stroke-[2.4]" />
            <span className="leading-tight">{link.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
