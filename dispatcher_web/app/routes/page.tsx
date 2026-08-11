import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getDeliveryZones } from "@/lib/data";
import { RouteZonesManager } from "./route-zones-manager";

export const dynamic = "force-dynamic";

export default async function RoutesPage() {
  const [profile, zones] = await Promise.all([requireStaff(), getDeliveryZones()]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Маршруты и зоны доставки"
        description="Нарисуйте границы на карте. Адрес заказа будет автоматически проверяться и относиться к подходящей зоне."
      />
      <RouteZonesManager initialZones={zones} />
    </AppShell>
  );
}
