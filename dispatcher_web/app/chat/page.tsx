import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getRecentOrderEvents } from "@/lib/data";
import type { OrderEventFeedRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function ChatPage({
  searchParams
}: {
  searchParams?: Promise<{ id?: string | string[]; q?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const selectedId = valueFromParam(resolved?.id);
  const [profile, events] = await Promise.all([requireStaff(), getRecentOrderEvents(300)]);
  const normalizedQuery = query.toLocaleLowerCase("ru-RU");
  const visibleEvents = normalizedQuery
    ? events.filter((event) =>
        [event.orders?.client_name, event.orders?.order_number, event.orders?.address, chatMessage(event)]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("ru-RU").includes(normalizedQuery))
      )
    : events;
  const selectedEvent = visibleEvents.find((event) => event.id === selectedId) ?? visibleEvents[0] ?? null;

  return (
    <AppShell profile={profile}>
      <PageHeader title="Чат" description="Системные сообщения по заказам и действиям водителей." />
      <div className="grid min-h-[680px] gap-5 xl:grid-cols-[minmax(360px,0.8fr)_minmax(0,1.2fr)]">
        <Panel className="min-w-0 p-4">
          <DirectorySearch action="/chat" defaultValue={query} placeholder="Клиент, заказ или сообщение" />
          <div className="app-scrollbar grid max-h-[580px] gap-2 overflow-y-auto pr-1">
            {visibleEvents.map((event) => (
              <Link
                className={`border px-4 py-3 hover:border-brand ${selectedEvent?.id === event.id ? "border-brand bg-brand/5" : "border-line"}`}
                href={`/chat?id=${encodeURIComponent(event.id)}${query ? `&q=${encodeURIComponent(query)}` : ""}`}
                key={event.id}
              >
                <div className="flex items-start justify-between gap-3">
                  <span className="font-black text-ink">{event.orders?.client_name ?? "Системное сообщение"}</span>
                  <time className="shrink-0 text-xs text-muted">{formatDate(event.created_at)}</time>
                </div>
                <p className="mt-2 line-clamp-2 text-sm text-ink">{chatMessage(event)}</p>
              </Link>
            ))}
            {visibleEvents.length === 0 ? <p className="py-10 text-center font-semibold text-muted">Сообщения не найдены</p> : null}
          </div>
        </Panel>

        <Panel className="flex min-w-0 flex-col p-6">
          {selectedEvent ? (
            <>
              <div className="border-b border-line pb-4">
                <h2 className="font-black text-ink">{selectedEvent.orders?.client_name ?? "Система"}</h2>
                <p className="text-sm text-muted">{selectedEvent.orders?.order_number ?? "Без привязки к заказу"}</p>
              </div>
              <div className="flex flex-1 items-end py-8">
                <div className="max-w-xl rounded-2xl rounded-bl-sm bg-brand/10 px-5 py-4">
                  <p className="font-semibold text-ink">{chatMessage(selectedEvent)}</p>
                  <time className="mt-2 block text-xs text-muted">{formatDateTime(selectedEvent.created_at)}</time>
                </div>
              </div>
              <p className="border-t border-line pt-4 text-xs font-semibold text-muted">
                Сейчас этот раздел показывает подтверждённые системные события. Двусторонняя переписка потребует подключения отдельного SMS/мессенджер-провайдера.
              </p>
            </>
          ) : (
            <p className="m-auto font-semibold text-muted">Выберите сообщение</p>
          )}
        </Panel>
      </div>
    </AppShell>
  );
}

function chatMessage(event: OrderEventFeedRow) {
  const number = event.orders?.order_number ?? "Заказ";
  switch (event.event_type) {
    case "delivered": return `${number} доставлен.`;
    case "failed": return `${number} не доставлен. Проверьте причину в карточке заказа.`;
    case "route_sheet_assigned": return `${number} назначен водителю и добавлен в маршрутный лист.`;
    case "dispatcher_update": return `${number} обновлён диспетчером.`;
    default: return `${number}: ${event.event_type.replaceAll("_", " ")}.`;
  }
}

function valueFromParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "2-digit", year: "2-digit" }).format(new Date(value));
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(new Date(value));
}
