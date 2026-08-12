import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getDispatcherOperations, moscowDateKey } from "@/lib/data";
import { OperationsDashboard } from "./operations-dashboard";

export const dynamic = "force-dynamic";

export default async function OperationsPage({
  searchParams
}: {
  searchParams: Promise<{ date?: string | string[] }>;
}) {
  const params = await searchParams;
  const requested = typeof params.date === "string" ? params.date : "";
  const today = moscowDateKey(new Date());
  const selectedDate = /^\d{4}-\d{2}-\d{2}$/.test(requested) ? requested : today;
  const displayDate = selectedDate.split("-").reverse().join(".");
  const [profile, operations] = await Promise.all([requireStaff(), getDispatcherOperations(selectedDate)]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title={selectedDate === today ? "Диспетчерская сегодня" : `Диспетчерская за ${displayDate}`}
        description="Заказы, водители, маршруты и проблемы в одном оперативном экране."
        action={
          <div className="flex flex-wrap items-center gap-2">
            <Link className="rounded-md border border-line px-4 py-2 text-sm font-black text-ink hover:border-brand hover:text-brand" href={`/shifts?date=${selectedDate}`}>
              Закрытие смен
            </Link>
            <form className="flex items-center gap-2" method="get">
              <input className="focus-ring rounded-md border border-line bg-white px-3 py-2 text-sm font-bold" defaultValue={selectedDate} name="date" type="date" />
              <button className="rounded-md bg-brand px-4 py-2 text-sm font-black text-white hover:bg-brandDark" type="submit">Показать</button>
            </form>
          </div>
        }
      />
      <OperationsDashboard data={operations} loadedAt={new Date().toISOString()} />
    </AppShell>
  );
}
