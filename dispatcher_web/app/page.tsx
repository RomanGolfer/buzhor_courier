import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers, getOrdersByDate } from "@/lib/data";
import { OrdersDashboard } from "./orders-dashboard";

export const dynamic = "force-dynamic";

export default async function DashboardPage({
  searchParams
}: {
  searchParams?: Promise<{ date?: string | string[] }>;
}) {
  const resolvedSearchParams = await searchParams;
  const dateParam = resolvedSearchParams?.date;
  const selectedDate = Array.isArray(dateParam) ? dateParam[0] : dateParam;
  const [profile, orders, couriers] = await Promise.all([
    requireStaff(),
    getOrdersByDate(selectedDate),
    getCouriers()
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Заказы"
        description="Живая диспетчерская таблица с фильтрами по статусу и курьеру."
        action={
          <Link className="rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white hover:bg-brandDark" href="/orders/new">
            Создать заказ
          </Link>
        }
      />
      <OrdersDashboard
        initialDate={selectedDate}
        initialLoadedAt={new Date().toISOString()}
        initialOrders={orders}
        couriers={couriers}
      />
    </AppShell>
  );
}
