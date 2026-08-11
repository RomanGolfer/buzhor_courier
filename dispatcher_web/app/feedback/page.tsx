import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getClientFeedback } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function FeedbackPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const [profile, feedback] = await Promise.all([requireStaff(), getClientFeedback()]);
  const normalizedQuery = query.toLocaleLowerCase("ru-RU");
  const visibleFeedback = normalizedQuery
    ? feedback.filter((item) =>
        [item.orders?.client_name, item.orders?.order_number, item.orders?.address, item.client_phone, item.couriers?.display_name]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("ru-RU").includes(normalizedQuery))
      )
    : feedback;

  return (
    <AppShell profile={profile}>
      <PageHeader title={`Обратная связь ${feedback.length}`} description="Оценки клиентов после завершения доставки." />
      <DirectorySearch action="/feedback" defaultValue={query} placeholder="Клиент, заказ, телефон, адрес или водитель" />
      <Panel>
        <div className="divide-y divide-line">
          {visibleFeedback.map((item) => (
            <article className="grid gap-3 px-5 py-4 hover:bg-slate-50 md:grid-cols-[minmax(0,1fr)_160px_160px] md:items-center" key={item.id}>
              <div>
                <div className="font-black text-ink">{item.orders?.client_name ?? item.client_phone ?? "Клиент"}</div>
                <div className="mt-1 text-sm text-muted">
                  {item.orders ? `${item.orders.order_number} · ${item.orders.address}` : "Заказ недоступен"}
                </div>
              </div>
              <div className="text-xl font-black text-amber-600" aria-label={`Оценка ${item.rating} из 5`}>
                {"★".repeat(item.rating)}{"☆".repeat(5 - item.rating)}
              </div>
              <div className="text-sm text-muted">
                <div>{item.couriers?.display_name ?? "Водитель не указан"}</div>
                <time>{formatDate(item.created_at)}</time>
              </div>
            </article>
          ))}
          {visibleFeedback.length === 0 ? <p className="px-5 py-12 text-center font-semibold text-muted">Оценки не найдены</p> : null}
        </div>
      </Panel>
    </AppShell>
  );
}

function valueFromParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(new Date(value));
}
