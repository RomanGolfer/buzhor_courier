import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getDispatcherAnalytics, moscowDateKey } from "@/lib/data";
import { AnalyticsDashboard } from "./analytics-dashboard";

export const dynamic = "force-dynamic";

export default async function AnalyticsPage({
  searchParams
}: {
  searchParams: Promise<{ from?: string | string[]; to?: string | string[] }>;
}) {
  const params = await searchParams;
  const today = moscowDateKey(new Date());
  const requestedTo = typeof params.to === "string" ? params.to : "";
  const requestedFrom = typeof params.from === "string" ? params.from : "";
  const dateTo = validDate(requestedTo) ? requestedTo : today;
  const fallbackFrom = shiftDate(dateTo, -29);
  let dateFrom = validDate(requestedFrom) ? requestedFrom : fallbackFrom;
  if (dateFrom > dateTo || daysBetween(dateFrom, dateTo) > 365) dateFrom = fallbackFrom;
  const [profile, analytics] = await Promise.all([requireStaff(), getDispatcherAnalytics(dateFrom, dateTo)]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Аналитика"
        description="Продажи, качество доставки, водители, зоны, тара и состояние данных."
        action={
          <form className="flex flex-wrap items-center gap-2" method="get">
            <label className="text-xs font-black text-muted">С<input className="focus-ring ml-2 rounded-md border border-line px-3 py-2 text-sm font-bold text-ink" defaultValue={dateFrom} name="from" type="date" /></label>
            <label className="text-xs font-black text-muted">По<input className="focus-ring ml-2 rounded-md border border-line px-3 py-2 text-sm font-bold text-ink" defaultValue={dateTo} name="to" type="date" /></label>
            <button className="rounded-md bg-brand px-4 py-2 text-sm font-black text-white hover:bg-brandDark" type="submit">Построить</button>
          </form>
        }
      />
      <AnalyticsDashboard data={analytics} />
    </AppShell>
  );
}

function validDate(value: string) { return /^\d{4}-\d{2}-\d{2}$/.test(value); }
function shiftDate(value: string, days: number) { const date = new Date(`${value}T12:00:00Z`); date.setUTCDate(date.getUTCDate() + days); return date.toISOString().slice(0, 10); }
function daysBetween(from: string, to: string) { return Math.round((new Date(`${to}T12:00:00Z`).valueOf() - new Date(`${from}T12:00:00Z`).valueOf()) / 86400000); }
