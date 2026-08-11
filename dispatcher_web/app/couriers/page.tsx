import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCourierDailySales, moscowDateKey } from "@/lib/data";
import { CourierSalesDashboard } from "./courier-sales-dashboard";

export const dynamic = "force-dynamic";

export default async function CouriersPage({
  searchParams
}: {
  searchParams: Promise<{ date?: string | string[] }>;
}) {
  const params = await searchParams;
  const requestedDate = typeof params.date === "string" ? params.date : "";
  const selectedDate = requestedDate.match(/^\d{4}-\d{2}-\d{2}$/) ? requestedDate : moscowDateKey(new Date());
  const [profile, rows] = await Promise.all([requireStaff(), getCourierDailySales(selectedDate)]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Сводка водителей"
        description="Продажи по способам оплаты, доставленные бутылки, собранная тара и остатки в машинах."
        action={
          <form className="flex items-center gap-2" method="get">
            <input
              aria-label="Дата сводки"
              className="focus-ring rounded-md border border-line bg-white px-3 py-2 text-sm font-bold text-ink"
              defaultValue={selectedDate}
              name="date"
              type="date"
            />
            <button className="rounded-md bg-brand px-4 py-2 text-sm font-black text-white hover:bg-brandDark" type="submit">
              Показать
            </button>
          </form>
        }
      />
      <CourierSalesDashboard rows={rows} selectedDate={selectedDate} />
    </AppShell>
  );
}
