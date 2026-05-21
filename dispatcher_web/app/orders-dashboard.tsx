"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Courier, Order, OrderState } from "@/lib/types";
import { Panel, StatusPill } from "@/components/ui";

const stateLabels: Record<OrderState, string> = {
  draft: "Черновик",
  assigned: "Назначен",
  accepted: "Принят",
  in_progress: "В пути",
  delivered: "Выполнен",
  failed: "Проблема",
  cancelled: "Отменен"
};

const paymentLabels: Record<string, string> = {
  card: "Карта",
  cash: "Наличные",
  qr: "QR",
  online: "Онлайн",
  contract: "Договор"
};

function stateTone(state: OrderState): "good" | "warn" | "bad" | "muted" {
  if (state === "delivered") return "good";
  if (state === "failed" || state === "cancelled") return "bad";
  if (state === "in_progress" || state === "accepted") return "warn";
  return "muted";
}

export function OrdersDashboard({
  initialOrders,
  couriers
}: {
  initialOrders: Order[];
  couriers: Courier[];
}) {
  const [orders, setOrders] = useState(initialOrders);
  const [stateFilter, setStateFilter] = useState<"all" | OrderState>("all");
  const [courierFilter, setCourierFilter] = useState("all");
  const [lastUpdatedAt, setLastUpdatedAt] = useState(() => new Date());
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);

  const refreshOrders = useCallback(async () => {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);
    const { data } = await supabase
      .from("orders")
      .select(
        "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, time_slot, created_at, updated_at, couriers(id, display_name)"
      )
      .gte("created_at", start.toISOString())
      .lt("created_at", end.toISOString())
      .order("created_at", { ascending: false });

    if (data) {
      setOrders(data as unknown as Order[]);
      setLastUpdatedAt(new Date());
    }
  }, [supabase]);

  useEffect(() => {
    const channel = supabase
      .channel("dispatcher-orders")
      .on("postgres_changes", { event: "*", schema: "public", table: "orders" }, () => {
        void refreshOrders();
      })
      .subscribe();

    const intervalId = window.setInterval(() => {
      void refreshOrders();
    }, 5000);

    function refreshVisibleTab() {
      if (document.visibilityState === "visible") {
        void refreshOrders();
      }
    }

    document.addEventListener("visibilitychange", refreshVisibleTab);

    return () => {
      window.clearInterval(intervalId);
      document.removeEventListener("visibilitychange", refreshVisibleTab);
      void supabase.removeChannel(channel);
    };
  }, [refreshOrders, supabase]);

  const filtered = useMemo(() => {
    return orders.filter((order) => {
      const stateOk = stateFilter === "all" || order.state === stateFilter;
      const courierOk = courierFilter === "all" || order.assigned_courier_id === courierFilter;
      return stateOk && courierOk;
    });
  }, [orders, stateFilter, courierFilter]);

  return (
    <Panel>
      <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row md:items-center md:justify-between">
        <div>
          <div className="text-sm font-bold text-muted">{filtered.length} заказов в таблице</div>
          <div className="text-xs font-semibold text-muted">
            Обновлено{" "}
            {lastUpdatedAt.toLocaleTimeString("ru-RU", {
              hour: "2-digit",
              minute: "2-digit",
              second: "2-digit"
            })}
          </div>
        </div>
        <div className="flex flex-col gap-2 sm:flex-row">
          <select className="focus-ring rounded-md border border-line px-3 py-2 text-sm" value={stateFilter} onChange={(event) => setStateFilter(event.target.value as "all" | OrderState)}>
            <option value="all">Все статусы</option>
            {Object.entries(stateLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
          <select className="focus-ring rounded-md border border-line px-3 py-2 text-sm" value={courierFilter} onChange={(event) => setCourierFilter(event.target.value)}>
            <option value="all">Все курьеры</option>
            {couriers.map((courier) => (
              <option key={courier.id} value={courier.id}>
                {courier.display_name}
              </option>
            ))}
          </select>
          <button className="rounded-md border border-line px-3 py-2 text-sm font-bold text-ink hover:bg-slate-50" onClick={() => void refreshOrders()}>
            Обновить
          </button>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full border-separate border-spacing-0 text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase tracking-[0.12em] text-muted">
            <tr>
              {["Номер", "Клиент", "Адрес", "Курьер", "Статус", "Оплата", "Бутыли"].map((heading) => (
                <th className="border-b border-line px-4 py-3 font-black" key={heading}>
                  {heading}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map((order) => (
              <tr className="hover:bg-slate-50" key={order.id}>
                <td className="border-b border-line px-4 py-3 font-black text-ink">{order.order_number}</td>
                <td className="border-b border-line px-4 py-3">
                  <div className="font-bold text-ink">{order.client_name}</div>
                  <div className="text-xs text-muted">{order.client_phone ?? "без телефона"}</div>
                </td>
                <td className="max-w-md border-b border-line px-4 py-3 text-muted">
                  {order.address}
                  {order.time_slot ? <div className="text-xs font-semibold text-ink">{order.time_slot}</div> : null}
                </td>
                <td className="border-b border-line px-4 py-3">{order.couriers?.display_name ?? "Не назначен"}</td>
                <td className="border-b border-line px-4 py-3">
                  <StatusPill tone={stateTone(order.state)}>{stateLabels[order.state]}</StatusPill>
                </td>
                <td className="border-b border-line px-4 py-3">{paymentLabels[order.payment_method]}</td>
                <td className="border-b border-line px-4 py-3 font-bold">{order.bottles}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Panel>
  );
}
