import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getDeliveryZones } from "@/lib/data";
import { RouteZonesManager } from "@/app/routes/route-zones-manager";

export const dynamic = "force-dynamic";

export default async function DeliveryZonesPage() {
  const [profile, zones] = await Promise.all([requireStaff(), getDeliveryZones()]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Зоны доставки"
        description={
          profile.role === "admin"
            ? "Нарисуйте границы на карте. Адрес заказа будет автоматически отнесён к подходящей зоне."
            : "Просмотр действующих зон доставки. Изменять границы и настройки может только администратор."
        }
      />
      <RouteZonesManager canManage={profile.role === "admin"} initialZones={zones} />
    </AppShell>
  );
}
