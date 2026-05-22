import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getProfilesForManagement } from "@/lib/data";
import { UsersManager } from "./users-manager";

export const dynamic = "force-dynamic";

export default async function UsersPage() {
  const [profile, profiles] = await Promise.all([requireStaff(), getProfilesForManagement()]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Пользователи"
        description="Роли, активность профилей и привязка курьерских карточек к аккаунтам."
      />
      <UsersManager currentProfile={profile} profiles={profiles} />
    </AppShell>
  );
}
