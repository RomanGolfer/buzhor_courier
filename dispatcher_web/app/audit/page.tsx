import { AppShell } from "@/components/app-shell";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getStaffAudit } from "@/lib/data";

export const dynamic = "force-dynamic";

const entityOptions = [
  ["", "Все разделы"],
  ["orders", "Заказы"],
  ["courier_daily_inventory", "Загрузка и остатки"],
  ["courier_shifts", "Закрытие смен"],
  ["delivery_zones", "Зоны доставки"],
  ["vehicles", "Автомобили"],
  ["vehicle_assignments", "Назначения машин"],
  ["data_imports", "Импорт"],
  ["operational_issue_actions", "Проблемы"]
] as const;

export default async function AuditPage({ searchParams }: { searchParams: Promise<{ entity?: string | string[] }> }) {
  const params = await searchParams;
  const requested = typeof params.entity === "string" ? params.entity : "";
  const entity = entityOptions.some(([value]) => value === requested) ? requested : "";
  const [profile, rows] = await Promise.all([requireStaff(), getStaffAudit(500, entity || null)]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Журнал контроля"
        description="Кто, когда и какие критичные данные изменил. Записи не редактируются из панели."
        action={
          <form className="flex gap-2" method="get">
            <select className="focus-ring rounded-md border border-line bg-white px-3 py-2 text-sm font-bold" defaultValue={entity} name="entity">
              {entityOptions.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
            <button className="rounded-md bg-brand px-4 py-2 text-sm font-black text-white" type="submit">Фильтр</button>
          </form>
        }
      />
      <Panel>
        <div className="overflow-x-auto">
          <table className="min-w-[1120px] text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-[0.08em] text-muted">
              <tr><th className="border-b border-line px-5 py-3">Время</th><th className="border-b border-line px-3 py-3">Сотрудник</th><th className="border-b border-line px-3 py-3">Раздел</th><th className="border-b border-line px-3 py-3">Действие</th><th className="border-b border-line px-3 py-3">Объект</th><th className="border-b border-line px-5 py-3">Изменения</th></tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr className="align-top hover:bg-slate-50" key={row.id}>
                  <td className="whitespace-nowrap border-b border-line px-5 py-4 text-muted">{formatDateTime(row.created_at)}</td>
                  <td className="border-b border-line px-3 py-4"><div className="font-black text-ink">{row.actor_name}</div><div className="text-xs font-semibold text-muted">{roleLabel(row.actor_role)}</div></td>
                  <td className="border-b border-line px-3 py-4 font-bold text-ink">{entityLabel(row.entity_type)}</td>
                  <td className="border-b border-line px-3 py-4"><StatusPill tone={actionTone(row.action)}>{actionLabel(row.action)}</StatusPill></td>
                  <td className="max-w-52 border-b border-line px-3 py-4 font-mono text-xs text-muted">{row.entity_id ?? "—"}</td>
                  <td className="border-b border-line px-5 py-4">
                    <details><summary className="cursor-pointer font-black text-brand">Показать значения</summary><div className="mt-3 grid gap-3 xl:grid-cols-2"><JsonBox label="До" value={row.before_data} /><JsonBox label="После" value={row.after_data} /></div></details>
                  </td>
                </tr>
              ))}
              {rows.length === 0 ? <tr><td className="px-5 py-12 text-center font-semibold text-muted" colSpan={6}>Журнал пока пуст. Новые изменения появятся здесь автоматически.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </Panel>
    </AppShell>
  );
}

function JsonBox({ label, value }: { label: string; value: Record<string, unknown> | null }) {
  return <div><div className="mb-1 text-xs font-black uppercase tracking-[0.08em] text-muted">{label}</div><pre className="app-scrollbar max-h-72 max-w-xl overflow-auto rounded-md bg-slate-950 p-3 text-xs leading-relaxed text-slate-100">{value ? JSON.stringify(value, null, 2) : "—"}</pre></div>;
}
function formatDateTime(value: string) { return new Intl.DateTimeFormat("ru-RU", { dateStyle: "short", timeStyle: "medium", timeZone: "Europe/Moscow" }).format(new Date(value)); }
function entityLabel(value: string) { return entityOptions.find(([key]) => key === value)?.[1] ?? value.replaceAll("_", " "); }
function actionLabel(value: string) { return value === "insert" ? "Создание" : value === "update" ? "Изменение" : value === "delete" ? "Удаление" : value; }
function actionTone(value: string): "good" | "warn" | "bad" { return value === "insert" ? "good" : value === "delete" ? "bad" : "warn"; }
function roleLabel(value: string | null) { return value === "admin" ? "Администратор" : value === "dispatcher" ? "Диспетчер" : value === "courier" ? "Водитель" : "Системное действие"; }
