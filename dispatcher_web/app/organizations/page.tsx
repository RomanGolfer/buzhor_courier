import { AppShell } from "@/components/app-shell";
import { DirectorySearch } from "@/components/directory-search";
import { PageHeader, Panel } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getOrganizationsDirectory } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function OrganizationsPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const query = valueFromParam(resolved?.q).trim();
  const [profile, organizations] = await Promise.all([requireStaff(), getOrganizationsDirectory()]);
  const normalizedQuery = query.toLocaleLowerCase("ru-RU");
  const visibleOrganizations = normalizedQuery
    ? organizations.filter((organization) =>
        [organization.name, organization.inn, organization.kpp, organization.phone, organization.email, organization.address, organization.legacy_id]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("ru-RU").includes(normalizedQuery))
      )
    : organizations;

  return (
    <AppShell profile={profile}>
      <PageHeader
        title={`Организации ${organizations.length}`}
        description="Организации из договорных заказов и импортов предыдущего поставщика."
      />
      <DirectorySearch action="/organizations" defaultValue={query} placeholder="Название, телефон или адрес" />
      <Panel>
        <div className="overflow-x-auto">
          <table className="min-w-[1000px] text-left text-sm">
            <thead className="bg-slate-50 text-xs font-bold text-muted">
              <tr>
                <th className="border-b border-line px-4 py-3">Название организации</th>
                <th className="border-b border-line px-4 py-3">ИНН</th>
                <th className="border-b border-line px-4 py-3">КПП</th>
                <th className="border-b border-line px-4 py-3">Телефон</th>
                <th className="border-b border-line px-4 py-3">Email</th>
                <th className="border-b border-line px-4 py-3">Заказы</th>
                <th className="border-b border-line px-4 py-3">Долг по таре</th>
                <th className="border-b border-line px-4 py-3">Последний заказ</th>
              </tr>
            </thead>
            <tbody>
              {visibleOrganizations.map((organization) => (
                <tr className="hover:bg-slate-50" key={organization.key}>
                  <td className="border-b border-line px-4 py-3">
                    <div className="font-black text-ink">{organization.name}</div>
                    <div className="mt-1 text-xs text-muted">{organization.address}</div>
                  </td>
                  <td className="border-b border-line px-4 py-3">{organization.inn ?? "—"}</td>
                  <td className="border-b border-line px-4 py-3">{organization.kpp ?? "—"}</td>
                  <td className="border-b border-line px-4 py-3">{organization.phone ?? "—"}</td>
                  <td className="border-b border-line px-4 py-3">{organization.email ?? "—"}</td>
                  <td className="border-b border-line px-4 py-3 font-black">{organization.order_count}</td>
                  <td className="border-b border-line px-4 py-3 font-semibold">{organization.tare_debt}</td>
                  <td className="border-b border-line px-4 py-3">{formatDate(organization.last_order_at)}</td>
                </tr>
              ))}
              {visibleOrganizations.length === 0 ? (
                <tr><td className="px-4 py-10 text-center font-semibold text-muted" colSpan={8}>Организации не найдены</td></tr>
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
