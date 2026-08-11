import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getAddressesDirectory } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function AddressesPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string | string[]; missing?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const missingOnly = valueFromParam(resolved?.missing) === "1";
  const [profile, addresses] = await Promise.all([requireStaff(), getAddressesDirectory()]);
  const withoutCoordinates = addresses.filter((address) => address.lat === null || address.lng === null);
  const normalizedQuery = query.toLocaleLowerCase("ru-RU");
  const baseRows = missingOnly ? withoutCoordinates : addresses;
  const visibleAddresses = normalizedQuery
    ? baseRows.filter((address) =>
        [address.client_name, address.client_phone, address.address, address.district]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("ru-RU").includes(normalizedQuery))
      )
    : baseRows;

  return (
    <AppShell profile={profile}>
      <PageHeader title="Адреса" description="Адресная база и координаты, накопленные из заказов." />
      <div className="mb-4 flex flex-wrap gap-4 border-b border-line">
        <Link className={`border-b-2 px-1 pb-2 text-sm font-black ${!missingOnly ? "border-brand text-brand" : "border-transparent text-ink"}`} href="/addresses">
          Все адреса {addresses.length}
        </Link>
        <Link className={`border-b-2 px-1 pb-2 text-sm font-black ${missingOnly ? "border-brand text-brand" : "border-transparent text-ink"}`} href="/addresses?missing=1">
          Без координат {withoutCoordinates.length}
        </Link>
      </div>
      <DirectorySearch action="/addresses" defaultValue={query} placeholder="Клиент, телефон, район или адрес" />
      <Panel>
        <div className="overflow-x-auto">
          <table className="min-w-[1200px] text-left text-sm">
            <thead className="bg-slate-50 text-xs font-bold text-muted">
              <tr>
                <th className="border-b border-line px-4 py-3">ФИО</th>
                <th className="border-b border-line px-4 py-3">Зона / район</th>
                <th className="border-b border-line px-4 py-3">Адрес</th>
                <th className="border-b border-line px-4 py-3">Телефон</th>
                <th className="border-b border-line px-4 py-3">Координаты</th>
                <th className="border-b border-line px-4 py-3">Заказы</th>
                <th className="border-b border-line px-4 py-3">Обновлён</th>
              </tr>
            </thead>
            <tbody>
              {visibleAddresses.map((address) => (
                <tr className="hover:bg-slate-50" key={address.key}>
                  <td className="border-b border-line px-4 py-3 font-black text-ink">{address.client_name}</td>
                  <td className="border-b border-line px-4 py-3">{address.district ?? "Не выбран"}</td>
                  <td className="max-w-md border-b border-line px-4 py-3 font-semibold">{address.address}</td>
                  <td className="border-b border-line px-4 py-3">{address.client_phone ?? "—"}</td>
                  <td className="border-b border-line px-4 py-3 font-mono text-xs">
                    {address.lat !== null && address.lng !== null ? `${address.lat}, ${address.lng}` : "Нет координат"}
                  </td>
                  <td className="border-b border-line px-4 py-3 font-black">{address.order_count}</td>
                  <td className="border-b border-line px-4 py-3">{formatDate(address.last_order_at)}</td>
                </tr>
              ))}
              {visibleAddresses.length === 0 ? (
                <tr><td className="px-4 py-10 text-center font-semibold text-muted" colSpan={7}>Адреса не найдены</td></tr>
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
