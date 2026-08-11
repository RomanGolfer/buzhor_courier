import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { getDataImportHistory } from "@/lib/data";
import { LegacyImportManager } from "./legacy-import-manager";

export const dynamic = "force-dynamic";

export default async function ImportPage() {
  const [profile, history] = await Promise.all([requireAdmin(), getDataImportHistory()]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Импорт предыдущего поставщика"
        description="Перенос клиентов, телефонов, адресов, организаций и заказов с предварительной проверкой данных. Доступно только администратору."
      />
      <LegacyImportManager history={history} />
    </AppShell>
  );
}
