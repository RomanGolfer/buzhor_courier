import { AppShell } from "@/components/app-shell";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getDriverStats, getVehicleFleet } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function CouriersPage() {
  const [profile, couriers, vehicles] = await Promise.all([requireStaff(), getDriverStats(), getVehicleFleet()]);
  const vehicleByCourier = new Map(
    vehicles.flatMap((vehicle) => vehicle.current_courier_id ? [[vehicle.current_courier_id, vehicle]] : [])
  );

  return (
    <AppShell profile={profile}>
      <PageHeader title={`Водители ${couriers.length}`} description="Водители, их рабочий статус и нагрузка на сегодня." />
      <Panel>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-[0.12em] text-muted">
              <tr>
                <th className="border-b border-line px-4 py-3">Водитель</th>
                <th className="border-b border-line px-4 py-3">Телефон</th>
                <th className="border-b border-line px-4 py-3">Регион</th>
                <th className="border-b border-line px-4 py-3">Автомобиль</th>
                <th className="border-b border-line px-4 py-3">Заказов сегодня</th>
                <th className="border-b border-line px-4 py-3">Выполнено</th>
                <th className="border-b border-line px-4 py-3">Статус</th>
              </tr>
            </thead>
            <tbody>
              {couriers.map((courier) => {
                const vehicle = vehicleByCourier.get(courier.id);
                return <tr className="hover:bg-slate-50" key={courier.id}>
                  <td className="border-b border-line px-4 py-3 font-black text-ink">{courier.display_name}</td>
                  <td className="border-b border-line px-4 py-3 text-muted">{courier.phone ?? "не указан"}</td>
                  <td className="border-b border-line px-4 py-3">{courier.region ?? "Анапа"}</td>
                  <td className="border-b border-line px-4 py-3">
                    {vehicle ? <span className="font-black tracking-wide text-ink">{vehicle.license_plate}</span> : <span className="text-muted">не назначен</span>}
                  </td>
                  <td className="border-b border-line px-4 py-3 font-bold">{courier.ordersToday}</td>
                  <td className="border-b border-line px-4 py-3 font-bold">{courier.deliveredToday}</td>
                  <td className="border-b border-line px-4 py-3">
                    <StatusPill tone={courier.is_active ? "good" : "muted"}>
                      {courier.is_active ? "Активен" : "Выключен"}
                    </StatusPill>
                  </td>
                </tr>;
              })}
            </tbody>
          </table>
        </div>
      </Panel>
    </AppShell>
  );
}
