import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers, getVehicleAssignmentHistory, getVehicleFleet } from "@/lib/data";
import { VehicleFleetManager } from "./vehicle-fleet-manager";

export const dynamic = "force-dynamic";

export default async function VehiclesPage() {
  const [profile, vehicles, couriers, history] = await Promise.all([
    requireStaff(),
    getVehicleFleet(),
    getCouriers(),
    getVehicleAssignmentHistory()
  ]);

  return (
    <AppShell profile={profile}>
      <PageHeader
        title={`Автомобили ${vehicles.length}`}
        description="Автопарк по госномерам, техническое состояние и текущие назначения водителей."
      />
      <VehicleFleetManager
        canManageRegistry={profile.role === "admin"}
        couriers={couriers}
        initialHistory={history}
        initialVehicles={vehicles}
      />
    </AppShell>
  );
}
