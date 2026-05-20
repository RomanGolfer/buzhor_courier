import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers, getTodayOrders } from "@/lib/data";
import { OrdersDashboard } from "./orders-dashboard";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const [profile, orders, couriers] = await Promise.all([
    requireStaff(),
    getTodayOrders(),
    getCouriers()
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Заказы на сегодня"
        description="Живая диспетчерская таблица с фильтрами по статусу и курьеру."
        action={
          <Link className="rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white hover:bg-brandDark" href="/orders/new">
            Создать заказ
          </Link>
        }
      />
      <OrdersDashboard initialOrders={orders} couriers={couriers} />
    </AppShell>
  );
}
