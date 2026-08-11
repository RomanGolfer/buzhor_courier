import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers, getOrdersByDate, moscowDateKey } from "@/lib/data";
import { RouteSheetsBoard } from "./route-sheets-board";

export const dynamic = "force-dynamic";

export default async function RoutesPage({
  searchParams
}: {
  searchParams?: Promise<{ date?: string | string[] }>;
}) {
  const resolvedSearchParams = await searchParams;
  const dateParam = resolvedSearchParams?.date;
  const selectedDate = Array.isArray(dateParam) ? dateParam[0] : dateParam;
  const effectiveDate = selectedDate?.match(/^\d{4}-\d{2}-\d{2}$/) ? selectedDate : moscowDateKey(new Date());
  const [profile, orders, couriers] = await Promise.all([
    requireStaff(),
    getOrdersByDate(effectiveDate),
    getCouriers()
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Маршрутные листы"
        description="Сгруппируйте заказы по району и интервалу, затем назначьте выбранную группу водителю."
      />
      <RouteSheetsBoard couriers={couriers} initialOrders={orders} key={effectiveDate} selectedDate={effectiveDate} />
    </AppShell>
  );
}
