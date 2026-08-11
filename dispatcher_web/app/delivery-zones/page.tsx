import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getDeliveryZoneLearningCandidates, getDeliveryZones } from "@/lib/data";
import { RouteZonesManager } from "@/app/routes/route-zones-manager";

export const dynamic = "force-dynamic";

export default async function DeliveryZonesPage() {
  const [profile, zones, learningCandidates] = await Promise.all([
    requireStaff(),
    getDeliveryZones(),
    getDeliveryZoneLearningCandidates()
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Зоны доставки"
        description={
          profile.role === "admin"
            ? "Границы можно рисовать вручную и автоматически уточнять по повторным подтверждённым доставкам."
            : "Просмотр действующих зон доставки. Изменять границы и настройки может только администратор."
        }
      />
      <RouteZonesManager
        canManage={profile.role === "admin"}
        initialLearningCandidates={learningCandidates}
        initialZones={zones}
      />
    </AppShell>
  );
}
