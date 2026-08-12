"use client";

import {
  Bell,
  BriefcaseBusiness,
  CarFront,
  ChartNoAxesCombined,
  ClipboardCheck,
  ClipboardList,
  FileUp,
  LayoutDashboard,
  Map,
  MapPin,
  MessageCircleReply,
  MessagesSquare,
  ShieldCheck,
  Store,
  Truck,
  UserCog,
  UsersRound,
  type LucideIcon
} from "lucide-react";
import Link from "next/link";
import type { Route } from "next";
import { usePathname } from "next/navigation";
import type { Role } from "@/lib/types";

const links: {
  href: Route;
  icon: LucideIcon;
  label: string;
  match: (pathname: string) => boolean;
  adminOnly?: boolean;
}[] = [
  { href: "/operations", icon: LayoutDashboard, label: "Диспетчерская", match: (pathname) => pathname.startsWith("/operations") },
  { href: "/shifts", icon: ClipboardCheck, label: "Закрытие смен", match: (pathname) => pathname.startsWith("/shifts") },
  { href: "/analytics", icon: ChartNoAxesCombined, label: "Аналитика", match: (pathname) => pathname.startsWith("/analytics") },
  { href: "/notifications", icon: Bell, label: "Оповещения", match: (pathname) => pathname.startsWith("/notifications") },
  { href: "/", icon: ClipboardList, label: "Заказы", match: (pathname) => pathname === "/" },
  { href: "/routes", icon: Map, label: "Маршрутные листы", match: (pathname) => pathname.startsWith("/routes") },
  { href: "/clients", icon: UsersRound, label: "Клиенты", match: (pathname) => pathname.startsWith("/clients") },
  { href: "/organizations", icon: BriefcaseBusiness, label: "Организации", match: (pathname) => pathname.startsWith("/organizations") },
  { href: "/addresses", icon: MapPin, label: "Адреса", match: (pathname) => pathname.startsWith("/addresses") },
  { href: "/couriers", icon: Truck, label: "Водители", match: (pathname) => pathname.startsWith("/couriers") },
  { href: "/vehicles", icon: CarFront, label: "Автомобили", match: (pathname) => pathname.startsWith("/vehicles") },
  { href: "/chat", icon: MessagesSquare, label: "Чат", match: (pathname) => pathname.startsWith("/chat") },
  { href: "/feedback", icon: MessageCircleReply, label: "Обратная связь", match: (pathname) => pathname.startsWith("/feedback") },
  { href: "/micro-markets", icon: Store, label: "Микромаркеты", match: (pathname) => pathname.startsWith("/micro-markets") },
  { href: "/delivery-zones", icon: Map, label: "Зоны доставки", match: (pathname) => pathname.startsWith("/delivery-zones") },
  { href: "/import", icon: FileUp, label: "Импорт", match: (pathname) => pathname.startsWith("/import"), adminOnly: true },
  { href: "/audit", icon: ShieldCheck, label: "Журнал контроля", match: (pathname) => pathname.startsWith("/audit") },
  { href: "/users", icon: UserCog, label: "Пользователи", match: (pathname) => pathname.startsWith("/users"), adminOnly: true }
];

export function ShellNav({ role }: { role: Role }) {
  const pathname = usePathname();
  const visibleLinks = links.filter((link) => !link.adminOnly || role === "admin");

  return (
    <nav className="app-scrollbar flex-1 overflow-y-auto py-3">
      {visibleLinks.map((link) => {
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
