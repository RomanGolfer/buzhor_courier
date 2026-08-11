import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers, getDeliveryZones, getOrdersByDate, moscowDateKey } from "@/lib/data";
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
  const effectiveDate = selectedDate?.match(/^\d{4}-\d{2}-\d{2}$/) ? selectedDate : moscowDateKey(new Date());
  const [profile, orders, couriers, deliveryZones] = await Promise.all([
    requireStaff(),
    getOrdersByDate(effectiveDate),
    getCouriers(),
    getDeliveryZones()
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title={`Заказы ${orders.length}`}
      />
      <OrdersDashboard
        initialDate={effectiveDate}
        initialLoadedAt={new Date().toISOString()}
        initialOrders={orders}
        couriers={couriers}
        deliveryZones={deliveryZones}
      />
    </AppShell>
  );
}
