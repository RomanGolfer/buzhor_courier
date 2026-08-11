"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Panel, StatusPill } from "@/components/ui";
import { notifyOrderPush } from "@/lib/order-push";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Courier, Order } from "@/lib/types";

type RouteTab = "unassigned" | "assigned" | "failed";

type RouteGroup = {
  key: string;
  district: string;
  timeSlot: string;
  orders: Order[];
  bottles: number;
};

export function RouteSheetsBoard({
  couriers,
  initialOrders,
  selectedDate
}: {
  couriers: Courier[];
  initialOrders: Order[];
  selectedDate: string;
}) {
  const router = useRouter();
  const [orders, setOrders] = useState(initialOrders);
  const [tab, setTab] = useState<RouteTab>("unassigned");
  const [selectedGroupKey, setSelectedGroupKey] = useState("");
  const [courierId, setCourierId] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const tabOrders = useMemo(() => {
    if (tab === "failed") {
      return orders.filter((order) => order.state === "failed" || order.state === "cancelled");
    }

    const operational = orders.filter((order) => !["delivered", "failed", "cancelled"].includes(order.state));
    return tab === "assigned"
      ? operational.filter((order) => Boolean(order.assigned_courier_id))
      : operational.filter((order) => !order.assigned_courier_id);
  }, [orders, tab]);

  const groups = useMemo(() => groupOrders(tabOrders), [tabOrders]);
  const selectedGroup = groups.find((group) => group.key === selectedGroupKey) ?? groups[0] ?? null;

  function changeTab(nextTab: RouteTab) {
    setTab(nextTab);
    setSelectedGroupKey("");
    setCourierId("");
    setNotice(null);
    setError(null);
  }

  function changeDate(nextDate: string) {
    if (!nextDate) return;
    router.push(`/routes?date=${encodeURIComponent(nextDate)}`);
  }

  async function assignGroup() {
    if (!selectedGroup || !courierId || tab === "failed") return;

    setIsSaving(true);
    setNotice(null);
    setError(null);

    const supabase = createBrowserSupabaseClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const orderIds = selectedGroup.orders.map((order) => order.id);
    const { data: updatedOrders, error: updateError } = await supabase
      .from("orders")
      .update({
        assigned_courier_id: courierId,
        state: "assigned",
        updated_by: user?.id ?? null
      })
      .in("id", orderIds)
      .select("id");

    if (updateError || (updatedOrders?.length ?? 0) !== orderIds.length) {
      setError("Не удалось назначить все заказы водителю. Обновите страницу и повторите попытку.");
      setIsSaving(false);
      return;
    }

    await supabase.from("order_events").insert(
      orderIds.map((orderId) => ({
        order_id: orderId,
        actor_profile_id: user?.id ?? null,
        event_type: "route_sheet_assigned",
        payload: { courier_id: courierId }
      }))
    );

    await Promise.all(orderIds.map((orderId) => notifyOrderPush(supabase, orderId, "assigned")));

    setOrders((current) =>
      current.map((order) =>
        orderIds.includes(order.id)
          ? { ...order, assigned_courier_id: courierId, state: "assigned" }
          : order
      )
    );
    setSelectedGroupKey("");
    setCourierId("");
    setNotice(`Назначено заказов: ${orderIds.length}`);
    setIsSaving(false);
  }

  const counts = {
    assigned: orders.filter(
      (order) => Boolean(order.assigned_courier_id) && !["delivered", "failed", "cancelled"].includes(order.state)
    ).length,
    failed: orders.filter((order) => order.state === "failed" || order.state === "cancelled").length,
    unassigned: orders.filter(
      (order) => !order.assigned_courier_id && !["delivered", "failed", "cancelled"].includes(order.state)
    ).length
  };

  return (
    <div className="grid min-h-[680px] gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(380px,0.75fr)]">
      <Panel className="min-w-0 p-4">
        <div className="flex flex-wrap items-center gap-2 border-b border-line pb-4">
          <TabButton active={tab === "unassigned"} onClick={() => changeTab("unassigned")}>
            Неразобранные заказы {counts.unassigned}
          </TabButton>
          <TabButton active={tab === "assigned"} onClick={() => changeTab("assigned")}>
            Маршруты {counts.assigned}
          </TabButton>
          <TabButton active={tab === "failed"} onClick={() => changeTab("failed")}>
            Недоставленные {counts.failed}
          </TabButton>
          <input
            className="focus-ring ml-auto h-9 border border-line px-3 text-sm"
            onChange={(event) => changeDate(event.target.value)}
            type="date"
            value={selectedDate}
          />
        </div>

        <div className="mt-4 overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-xs font-bold text-muted">
              <tr>
                <th className="border-b border-line px-3 py-3">Район</th>
                <th className="border-b border-line px-3 py-3">Интервал</th>
                <th className="border-b border-line px-3 py-3">Заказы</th>
                <th className="border-b border-line px-3 py-3">Бутыли</th>
              </tr>
            </thead>
            <tbody>
              {groups.map((group) => (
                <tr
                  className={`cursor-pointer hover:bg-slate-50 ${selectedGroup?.key === group.key ? "bg-brand/5" : ""}`}
                  key={group.key}
                  onClick={() => setSelectedGroupKey(group.key)}
                >
                  <td className="border-b border-line px-3 py-3 font-black text-ink">{group.district}</td>
                  <td className="border-b border-line px-3 py-3 text-ink">{group.timeSlot}</td>
                  <td className="border-b border-line px-3 py-3 font-bold">{group.orders.length}</td>
                  <td className="border-b border-line px-3 py-3 font-bold">{group.bottles}</td>
                </tr>
              ))}
              {groups.length === 0 ? (
                <tr>
                  <td className="px-4 py-10 text-center font-semibold text-muted" colSpan={4}>
                    В этой группе заказов нет
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </Panel>

      <Panel className="flex min-w-0 flex-col p-5">
        {selectedGroup ? (
          <>
            <div className="flex items-start justify-between gap-3">
              <div>
                <h2 className="text-lg font-black text-ink">{selectedGroup.district}</h2>
                <p className="text-sm font-semibold text-muted">{selectedGroup.timeSlot}</p>
              </div>
              <StatusPill tone={tab === "failed" ? "bad" : tab === "assigned" ? "good" : "warn"}>
                {selectedGroup.orders.length} заказов
              </StatusPill>
            </div>

            <div className="app-scrollbar mt-4 grid max-h-[440px] gap-2 overflow-y-auto pr-1">
              {selectedGroup.orders.map((order) => (
                <div className="border border-line p-3" key={order.id}>
                  <div className="flex items-center justify-between gap-3">
                    <span className="font-black text-ink">{order.order_number}</span>
                    <span className="font-black text-ink">{order.bottles} бут.</span>
                  </div>
                  <div className="mt-1 text-sm font-semibold text-ink">{order.client_name}</div>
                  <div className="mt-1 text-xs text-muted">{order.address}</div>
                </div>
              ))}
            </div>

            {tab !== "failed" ? (
              <div className="mt-auto border-t border-line pt-4">
                <label className="block text-sm font-bold text-ink" htmlFor="route-courier">
                  Водитель
                </label>
                <select
                  className="focus-ring mt-1 h-11 w-full border border-line bg-white px-3 text-sm"
                  id="route-courier"
                  onChange={(event) => setCourierId(event.target.value)}
                  value={courierId}
                >
                  <option value="">Выбрать водителя</option>
                  {couriers.map((courier) => (
                    <option key={courier.id} value={courier.id}>{courier.display_name}</option>
                  ))}
                </select>
                <button
                  className="mt-3 w-full bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!courierId || isSaving}
                  onClick={assignGroup}
                  type="button"
                >
                  {isSaving ? "Назначаем..." : tab === "assigned" ? "Переназначить водителя" : "Создать маршрутный лист"}
                </button>
              </div>
            ) : null}
          </>
        ) : (
          <div className="m-auto max-w-sm text-center">
            <div className="text-5xl">🚚</div>
            <p className="mt-4 font-semibold text-muted">Выберите группу заказов слева</p>
          </div>
        )}
        {notice ? <p className="mt-3 bg-emerald-50 px-3 py-2 text-sm font-bold text-good">{notice}</p> : null}
        {error ? <p className="mt-3 bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</p> : null}
      </Panel>
    </div>
  );
}

function TabButton({ active, children, onClick }: { active: boolean; children: React.ReactNode; onClick: () => void }) {
  return (
    <button
      className={`border-b-2 px-2 py-2 text-sm font-black ${active ? "border-brand text-brand" : "border-transparent text-ink hover:text-brand"}`}
      onClick={onClick}
      type="button"
    >
      {children}
    </button>
  );
}

function groupOrders(orders: Order[]) {
  const groups = new Map<string, RouteGroup>();

  for (const order of orders) {
    const district = order.district?.trim() || "Без района";
    const timeSlot = order.time_slot?.trim() || "Без интервала";
    const key = `${district}|${timeSlot}`;
    const current = groups.get(key);
    if (current) {
      current.orders.push(order);
      current.bottles += order.bottles;
    } else {
      groups.set(key, { key, district, timeSlot, orders: [order], bottles: order.bottles });
    }
  }

  return [...groups.values()].sort((left, right) =>
    left.district.localeCompare(right.district, "ru-RU") || left.timeSlot.localeCompare(right.timeSlot, "ru-RU")
  );
}
