import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getNotificationOutbox, getRecentOrderEvents } from "@/lib/data";
import type { NotificationOutboxRow, OrderEventFeedRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function NotificationsPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const [profile, events, outbox] = await Promise.all([requireStaff(), getRecentOrderEvents(), getNotificationOutbox()]);
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
      <PageHeader title={`Оповещения ${events.length + outbox.length}`} description="Оперативные события и очередь сообщений клиентам." />
      <DirectorySearch action="/notifications" defaultValue={query} placeholder="Номер заказа, клиент, адрес или событие" />
      <NotificationQueue rows={outbox} />
      <h2 className="mb-3 mt-6 font-black text-ink">Системная история заказов</h2>
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

function NotificationQueue({ rows }: { rows: NotificationOutboxRow[] }) {
  const waiting = rows.filter((row) => row.status === "waiting_provider");
  return (
    <Panel>
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line p-5">
        <div><h2 className="font-black text-ink">Очередь уведомлений</h2><p className="mt-1 text-sm font-semibold text-muted">Сообщения создаются автоматически при изменении состояния заказа.</p></div>
        <StatusPill tone={waiting.length ? "warn" : "good"}>{waiting.length ? `${waiting.length} ждут провайдера` : "Очередь обработана"}</StatusPill>
      </div>
      {waiting.length > 0 ? <p className="border-b border-amber-200 bg-amber-50 px-5 py-3 text-sm font-semibold text-amber-900">SMS или мессенджер пока не подключён: сообщения сохранены, но не помечаются как отправленные.</p> : null}
      <div className="divide-y divide-line">
        {rows.slice(0, 50).map((row) => <article className="grid gap-3 px-5 py-4 hover:bg-slate-50 md:grid-cols-[150px_minmax(0,1fr)_160px_auto] md:items-center" key={row.id}><time className="text-sm font-semibold text-muted">{formatDateTime(row.created_at)}</time><div><div className="font-black text-ink">{row.title}</div><div className="mt-1 text-sm font-semibold text-muted">{row.body}</div><div className="mt-1 text-xs text-muted">{row.orders ? `${row.orders.order_number} · ${row.orders.client_name}` : "Системное уведомление"}</div></div><div className="text-xs font-bold text-muted">{channelLabel(row.channel)}{row.recipient ? ` · ${maskRecipient(row.recipient)}` : ""}</div><StatusPill tone={notificationTone(row.status)}>{notificationStatus(row.status)}</StatusPill></article>)}
        {rows.length === 0 ? <p className="px-5 py-10 text-center font-semibold text-muted">Новых уведомлений пока нет</p> : null}
      </div>
    </Panel>
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

function channelLabel(value: NotificationOutboxRow["channel"]) { return value === "sms" ? "SMS" : value === "messenger" ? "Мессенджер" : value === "push" ? "Push" : "Панель"; }
function notificationStatus(value: NotificationOutboxRow["status"]) { return value === "waiting_provider" ? "Ждёт подключения" : value === "sent" ? "Отправлено" : value === "failed" ? "Ошибка" : value === "cancelled" ? "Отменено" : "Готово"; }
function notificationTone(value: NotificationOutboxRow["status"]): "good" | "warn" | "bad" | "muted" { return value === "sent" ? "good" : value === "waiting_provider" ? "warn" : value === "failed" ? "bad" : "muted"; }
function maskRecipient(value: string) { const digits = value.replace(/\D/g, ""); return digits.length >= 4 ? `••• ${digits.slice(-4)}` : "получатель"; }
