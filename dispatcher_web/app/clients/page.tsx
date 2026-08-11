import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getClientsDirectory } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function ClientsPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const [profile, clients] = await Promise.all([requireStaff(), getClientsDirectory()]);
  const normalizedQuery = query.toLocaleLowerCase("ru-RU");
  const visibleClients = normalizedQuery
    ? clients.filter((client) =>
        [client.name, client.phone, client.address, client.district, client.last_order_number]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("ru-RU").includes(normalizedQuery))
      )
    : clients;

  return (
    <AppShell profile={profile}>
      <PageHeader
        title={`Клиенты ${clients.length}`}
        description="Клиентская база собрана из реальных заказов и объединена по номеру телефона."
      />
      <DirectorySearch action="/clients" defaultValue={query} placeholder="ФИО, телефон, адрес или номер заказа" />
      <Panel>
        <div className="overflow-x-auto">
          <table className="min-w-[1200px] text-left text-sm">
            <thead className="bg-slate-50 text-xs font-bold text-muted">
              <tr>
                <th className="border-b border-line px-4 py-3">№</th>
                <th className="border-b border-line px-4 py-3">ФИО</th>
                <th className="border-b border-line px-4 py-3">Адрес</th>
                <th className="border-b border-line px-4 py-3">Телефон</th>
                <th className="border-b border-line px-4 py-3">Email</th>
                <th className="border-b border-line px-4 py-3">Заказы</th>
                <th className="border-b border-line px-4 py-3">Оценка</th>
                <th className="border-b border-line px-4 py-3">Последний заказ</th>
                <th className="border-b border-line px-4 py-3">Дата</th>
              </tr>
            </thead>
            <tbody>
              {visibleClients.map((client, index) => (
                <tr className="hover:bg-slate-50" key={client.key}>
                  <td className="border-b border-line px-4 py-3 text-muted">{index + 1}</td>
                  <td className="border-b border-line px-4 py-3 font-black text-brand">{client.name}</td>
                  <td className="max-w-sm border-b border-line px-4 py-3">
                    <div className="font-semibold text-ink">{client.address}</div>
                    <div className="text-xs text-muted">{client.district ?? "Район не указан"}</div>
                  </td>
                  <td className="border-b border-line px-4 py-3">{client.phone ?? "—"}</td>
                  <td className="border-b border-line px-4 py-3 text-muted">—</td>
                  <td className="border-b border-line px-4 py-3 font-black">{client.order_count}</td>
                  <td className="border-b border-line px-4 py-3 font-black text-amber-700">
                    {client.rating_average ? `${client.rating_average.toFixed(1)} / 5 (${client.rating_count})` : "—"}
                  </td>
                  <td className="border-b border-line px-4 py-3 font-bold text-brand">{client.last_order_number}</td>
                  <td className="border-b border-line px-4 py-3">{formatDate(client.last_order_at)}</td>
                </tr>
              ))}
              {visibleClients.length === 0 ? (
                <tr><td className="px-4 py-10 text-center font-semibold text-muted" colSpan={9}>Клиенты не найдены</td></tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </Panel>
    </AppShell>
  );
}

function valueFromParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "2-digit", year: "numeric" }).format(new Date(value));
}
