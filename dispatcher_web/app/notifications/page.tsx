import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getRecentOrderEvents } from "@/lib/data";
import type { OrderEventFeedRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function NotificationsPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const [profile, events] = await Promise.all([requireStaff(), getRecentOrderEvents()]);
  const normalizedQuery = query.toLocaleLowerCase("ru-RU");
  const visibleEvents = normalizedQuery
    ? events.filter((event) =>
        [eventLabel(event), event.orders?.order_number, event.orders?.client_name, event.orders?.address]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("ru-RU").includes(normalizedQuery))
      )
    : events;

  return (
    <AppShell profile={profile}>
      <PageHeader title={`Оповещения ${events.length}`} description="Последние изменения заказов из системного журнала." />
      <DirectorySearch action="/notifications" defaultValue={query} placeholder="Номер заказа, клиент, адрес или событие" />
      <Panel>
        <div className="divide-y divide-line">
          {visibleEvents.map((event) => (
            <article className="grid gap-3 px-5 py-4 hover:bg-slate-50 md:grid-cols-[160px_minmax(0,1fr)_auto] md:items-center" key={event.id}>
              <time className="text-sm font-semibold text-muted">{formatDateTime(event.created_at)}</time>
              <div>
                <div className="font-black text-ink">{eventLabel(event)}</div>
                <div className="mt-1 text-sm text-muted">
                  {event.orders ? `${event.orders.order_number} · ${event.orders.client_name}` : "Заказ удалён или недоступен"}
                </div>
              </div>
              <StatusPill tone={eventTone(event.event_type)}>{eventTypeLabel(event.event_type)}</StatusPill>
            </article>
          ))}
          {visibleEvents.length === 0 ? <p className="px-5 py-12 text-center font-semibold text-muted">Оповещения не найдены</p> : null}
        </div>
      </Panel>
    </AppShell>
  );
}

function eventLabel(event: OrderEventFeedRow) {
  const number = event.orders?.order_number ?? "Заказ";
  switch (event.event_type) {
    case "delivered": return `${number} доставлен`;
    case "failed": return `${number} не доставлен`;
    case "route_sheet_assigned": return `${number} включён в маршрутный лист`;
    case "dispatcher_update": return `${number} изменён диспетчером`;
    case "fiscal_receipt_issued": return `${number}: сформирован чек`;
    case "fiscal_receipt_failed": return `${number}: ошибка чека`;
    default: return `${number}: ${eventTypeLabel(event.event_type)}`;
  }
}

function eventTypeLabel(value: string) {
  return value.replaceAll("_", " ");
}

function eventTone(value: string): "good" | "warn" | "bad" | "muted" {
  if (value.includes("failed")) return "bad";
  if (value === "delivered" || value.includes("issued")) return "good";
  if (value.includes("assigned")) return "warn";
  return "muted";
}

function valueFromParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "2-digit", year: "2-digit", hour: "2-digit", minute: "2-digit" }).format(new Date(value));
}
