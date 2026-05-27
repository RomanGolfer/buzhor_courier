"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Courier, Order, OrderState } from "@/lib/types";
import { todayDateKey } from "./orders-dashboard/date-utils";
import { OrderInspector } from "./orders-dashboard/order-inspector";
import { loadOrdersForDate, saveDispatcherOrderUpdate } from "./orders-dashboard/orders-data-client";
import { OrdersTable } from "./orders-dashboard/orders-table";

export function OrdersDashboard({
  initialDate,
  initialLoadedAt,
  initialOrders,
  couriers
}: {
  initialDate?: string;
  initialLoadedAt: string;
  initialOrders: Order[];
  couriers: Courier[];
}) {
  const [orders, setOrders] = useState(initialOrders);
  const [selectedDate, setSelectedDate] = useState(
    initialDate?.match(/^\d{4}-\d{2}-\d{2}$/) ? initialDate : todayDateKey()
  );
  const [stateFilter, setStateFilter] = useState<"all" | OrderState>("all");
  const [courierFilter, setCourierFilter] = useState("all");
  const [selectedOrderId, setSelectedOrderId] = useState(initialOrders[0]?.id ?? "");
  const [draftState, setDraftState] = useState<OrderState>(initialOrders[0]?.state ?? "assigned");
  const [draftCourierId, setDraftCourierId] = useState(initialOrders[0]?.assigned_courier_id ?? "");
  const [draftComment, setDraftComment] = useState(initialOrders[0]?.delivery_comment ?? "");
  const [draftFailureReason, setDraftFailureReason] = useState(initialOrders[0]?.failure_reason ?? "");
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [lastUpdatedAt, setLastUpdatedAt] = useState(() => new Date(initialLoadedAt));
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);

  const syncDraftFromOrder = useCallback((order: Order | null) => {
    setDraftState(order?.state ?? "assigned");
    setDraftCourierId(order?.assigned_courier_id ?? "");
    setDraftComment(order?.delivery_comment ?? "");
    setDraftFailureReason(order?.failure_reason ?? "");
  }, []);

  const loadOrders = useCallback(async (dateKey: string, currentSelectedOrderId: string) => {
    const nextOrders = await loadOrdersForDate(supabase, dateKey);
    if (!nextOrders) return;

    const currentSelectedOrder = nextOrders.find((order) => order.id === currentSelectedOrderId) ?? null;
    const nextSelectedOrder = currentSelectedOrder ?? nextOrders[0] ?? null;
    setOrders(nextOrders);
    if (!currentSelectedOrder) {
      setSelectedOrderId(nextSelectedOrder?.id ?? "");
      syncDraftFromOrder(nextSelectedOrder);
    }
    setLastUpdatedAt(new Date());
  }, [supabase, syncDraftFromOrder]);

  const refreshOrders = useCallback(async () => {
    await loadOrders(selectedDate, selectedOrderId);
  }, [loadOrders, selectedDate, selectedOrderId]);

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

  useEffect(() => {
    const mediaQuery = window.matchMedia("(min-width: 1280px)");
    const closeDrawerOnWideLayout = () => {
      if (mediaQuery.matches) {
        setIsDrawerOpen(false);
      }
    };

    mediaQuery.addEventListener("change", closeDrawerOnWideLayout);

    return () => {
      mediaQuery.removeEventListener("change", closeDrawerOnWideLayout);
    };
  }, []);

  const filtered = useMemo(() => {
    return orders.filter((order) => {
      const stateOk = stateFilter === "all" || order.state === stateFilter;
      const courierOk = courierFilter === "all" || order.assigned_courier_id === courierFilter;
      return stateOk && courierOk;
    });
  }, [orders, stateFilter, courierFilter]);

  const selectedOrder = useMemo(() => {
    return orders.find((order) => order.id === selectedOrderId) ?? filtered[0] ?? null;
  }, [filtered, orders, selectedOrderId]);

  function selectOrder(order: Order) {
    setSelectedOrderId(order.id);
    syncDraftFromOrder(order);
    setSaveMessage(null);
    setSaveError(null);
    setIsDrawerOpen(true);
  }

  function closeDrawer() {
    setIsDrawerOpen(false);
  }

  function changeSelectedDate(value: string) {
    const nextDate = value || todayDateKey();
    const params = new URLSearchParams(window.location.search);
    params.set("date", nextDate);
    window.history.replaceState(null, "", `${window.location.pathname}?${params.toString()}`);
    setSelectedDate(nextDate);
    setSelectedOrderId("");
    void loadOrders(nextDate, "");
  }

  async function saveSelectedOrder() {
    if (!selectedOrder) return;

    setIsSaving(true);
    setSaveMessage(null);
    setSaveError(null);

    const result = await saveDispatcherOrderUpdate({
      draftComment,
      draftCourierId,
      draftFailureReason,
      draftState,
      order: selectedOrder,
      supabase
    });

    if (result.error) {
      setSaveError(result.error);
      setIsSaving(false);
      return;
    }

    await refreshOrders();
    setSaveMessage("Изменения сохранены");
    setIsSaving(false);
  }

  const inspectorProps = {
    couriers,
    draftComment,
    draftCourierId,
    draftFailureReason,
    draftState,
    error: saveError,
    isSaving,
    message: saveMessage,
    order: selectedOrder,
    onCommentChange: (value: string) => setDraftComment(value),
    onCourierChange: (value: string) => setDraftCourierId(value),
    onFailureReasonChange: (value: string) => setDraftFailureReason(value),
    onSave: saveSelectedOrder,
    onStateChange: (value: OrderState) => setDraftState(value)
  };

  return (
    <>
      <div className="min-w-0">
        <OrdersTable
          courierFilter={courierFilter}
          couriers={couriers}
          lastUpdatedAt={lastUpdatedAt}
          onCourierFilterChange={setCourierFilter}
          onDateChange={changeSelectedDate}
          onRefresh={() => void refreshOrders()}
          onSelectOrder={selectOrder}
          onStateFilterChange={setStateFilter}
          orders={filtered}
          selectedDate={selectedDate}
          selectedOrderId={selectedOrder?.id ?? ""}
          stateFilter={stateFilter}
        />
      </div>

      {isDrawerOpen && (
        <>
          <div
            aria-hidden
            className="fixed inset-0 z-40 bg-black/40"
            onClick={closeDrawer}
          />
          <div className="fixed inset-y-0 right-0 z-50 w-full max-w-[440px] overflow-y-auto bg-white shadow-2xl">
            <OrderInspector {...inspectorProps} onClose={closeDrawer} />
          </div>
        </>
      )}
    </>
  );
}
