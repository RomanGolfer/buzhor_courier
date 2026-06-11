"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Phone, X } from "lucide-react";
import { formatPhoneForDisplay, normalizePhone } from "@/lib/phone";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { CallEvent, Courier, Order, OrderState } from "@/lib/types";
import { todayDateKey } from "./orders-dashboard/date-utils";
import { OrderInspector } from "./orders-dashboard/order-inspector";
import {
  loadCallEventsForOrder,
  loadOrdersForDate,
  requestTelephonyCall,
  saveDispatcherOrderUpdate
} from "./orders-dashboard/orders-data-client";
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
  const [isCalling, setIsCalling] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [callEvents, setCallEvents] = useState<CallEvent[]>([]);
  const [incomingCall, setIncomingCall] = useState<CallEvent | null>(null);
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

  const loadSelectedCallEvents = useCallback(() => {
    return loadCallEventsForOrder(supabase, selectedOrder);
  }, [selectedOrder, supabase]);

  const refreshCallEvents = useCallback(async () => {
    setCallEvents(await loadSelectedCallEvents());
  }, [loadSelectedCallEvents]);

  useEffect(() => {
    let isActive = true;

    void loadSelectedCallEvents().then((nextCallEvents) => {
      if (isActive) {
        setCallEvents(nextCallEvents);
      }
    });

    return () => {
      isActive = false;
    };
  }, [loadSelectedCallEvents]);

  useEffect(() => {
    const channel = supabase
      .channel("dispatcher-call-events")
      .on("postgres_changes", { event: "*", schema: "public", table: "call_events" }, (payload) => {
        const nextEvent = payload.new as CallEvent | null;
        if (nextEvent?.direction === "inbound" && ["ringing", "answered"].includes(nextEvent.event_type)) {
          setIncomingCall(nextEvent);
        }
        void refreshCallEvents();
      })
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [refreshCallEvents, supabase]);

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

  async function callSelectedOrder() {
    if (!selectedOrder) return;

    setIsCalling(true);
    setSaveMessage(null);
    setSaveError(null);

    const result = await requestTelephonyCall({ order: selectedOrder });
    if (result.error) {
      setSaveError(result.error);
      setIsCalling(false);
      await refreshCallEvents();
      return;
    }

    setSaveMessage("Звонок поставлен в очередь АТС");
    setIsCalling(false);
    await refreshCallEvents();
  }

  function selectOrderFromCall(call: CallEvent) {
    const order = findOrderForCall(call, orders);
    if (order) {
      selectOrder(order);
    }
  }

  const inspectorProps = {
    callEvents,
    couriers,
    draftComment,
    draftCourierId,
    draftFailureReason,
    draftState,
    error: saveError,
    isCalling,
    isSaving,
    message: saveMessage,
    order: selectedOrder,
    onCommentChange: (value: string) => setDraftComment(value),
    onCourierChange: (value: string) => setDraftCourierId(value),
    onFailureReasonChange: (value: string) => setDraftFailureReason(value),
    onSave: saveSelectedOrder,
    onStateChange: (value: OrderState) => setDraftState(value),
    onTelephonyCall: callSelectedOrder
  };

  const incomingOrder = incomingCall ? findOrderForCall(incomingCall, orders) : null;

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

      {incomingCall && (
        <IncomingCallToast
          call={incomingCall}
          order={incomingOrder}
          onClose={() => setIncomingCall(null)}
          onOpenOrder={() => selectOrderFromCall(incomingCall)}
        />
      )}

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

function IncomingCallToast({
  call,
  order,
  onClose,
  onOpenOrder
}: {
  call: CallEvent;
  order: Order | null;
  onClose: () => void;
  onOpenOrder: () => void;
}) {
  const phone = call.client_phone ?? call.client_phone_normalized;

  return (
    <section className="fixed bottom-5 right-5 z-50 w-[min(420px,calc(100vw-40px))] border border-line bg-white p-4 shadow-2xl">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-3">
          <div className="flex size-9 shrink-0 items-center justify-center rounded-full bg-emerald-50 text-good">
            <Phone size={18} />
          </div>
          <div className="min-w-0">
            <div className="text-xs font-black uppercase tracking-[0.14em] text-muted">Входящий звонок</div>
            <div className="mt-1 truncate text-lg font-black text-ink">{formatPhoneForDisplay(phone)}</div>
            <div className="text-sm font-semibold text-muted">
              {order ? `${order.order_number} · ${order.client_name}` : "Клиент не найден в заказах на экране"}
            </div>
          </div>
        </div>
        <button className="rounded-md p-1.5 text-muted hover:bg-slate-100 hover:text-ink" onClick={onClose} type="button">
          <X size={16} strokeWidth={2.5} />
        </button>
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        {order ? (
          <button className="rounded-md bg-brand px-3 py-2 text-sm font-black text-white hover:bg-brandDark" onClick={onOpenOrder} type="button">
            Открыть заказ
          </button>
        ) : null}
        {phone ? (
          <a className="rounded-md border border-line px-3 py-2 text-sm font-bold text-ink hover:border-brand hover:text-brand" href={`/orders/new?phone=${encodeURIComponent(phone)}`}>
            Новый заказ
          </a>
        ) : null}
      </div>
    </section>
  );
}

function findOrderForCall(call: CallEvent, orders: Order[]) {
  if (call.order_id) {
    const byId = orders.find((order) => order.id === call.order_id);
    if (byId) return byId;
  }

  const phone = normalizePhone(call.client_phone ?? call.client_phone_normalized);
  if (!phone) return null;
  return orders.find((order) => normalizePhone(order.client_phone) === phone) ?? null;
}
