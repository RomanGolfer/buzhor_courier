import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getInventoryMovements, getShiftReconciliation, moscowDateKey } from "@/lib/data";
import { ShiftReconciliationManager } from "./shift-reconciliation-manager";

export const dynamic = "force-dynamic";

export default async function ShiftsPage({ searchParams }: { searchParams: Promise<{ date?: string | string[] }> }) {
  const params = await searchParams;
  const requested = typeof params.date === "string" ? params.date : "";
  const selectedDate = /^\d{4}-\d{2}-\d{2}$/.test(requested) ? requested : moscowDateKey(new Date());
  const [profile, rows, movements] = await Promise.all([
    requireStaff(),
    getShiftReconciliation(selectedDate),
    getInventoryMovements(selectedDate, selectedDate)
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Закрытие смен"
        description="Сверка денег, бутылок, тары и пробега с блокировкой подтверждённого дня."
        action={
          <form className="flex items-center gap-2" method="get">
            <input className="focus-ring rounded-md border border-line bg-white px-3 py-2 text-sm font-bold" defaultValue={selectedDate} name="date" type="date" />
            <button className="rounded-md bg-brand px-4 py-2 text-sm font-black text-white hover:bg-brandDark" type="submit">Показать</button>
          </form>
        }
      />
      <ShiftReconciliationManager canReopen={profile.role === "admin"} movements={movements} rows={rows} selectedDate={selectedDate} />
    </AppShell>
  );
}
