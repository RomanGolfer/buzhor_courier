"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Courier, Order, OrderState } from "@/lib/types";
import { Panel, StatusPill } from "@/components/ui";

const orderSelect =
  "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, time_slot, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name)";

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

const editableStates: OrderState[] = [
  "draft",
  "assigned",
  "accepted",
  "in_progress",
  "delivered",
  "failed",
  "cancelled"
];

const moscowOffsetMs = 3 * 60 * 60 * 1000;

function todayDateKey() {
  const parts = new Intl.DateTimeFormat("en", {
    day: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Moscow",
    year: "numeric"
  }).formatToParts(new Date());
  const getPart = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  return `${getPart("year")}-${getPart("month")}-${getPart("day")}`;
}

function dateRangeForKey(dateKey: string) {
  const selectedDate = dateKey.match(/^\d{4}-\d{2}-\d{2}$/) ? dateKey : todayDateKey();
  const [year, month, day] = selectedDate.split("-").map(Number);
  const start = new Date(Date.UTC(year, month - 1, day) - moscowOffsetMs);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { start: start.toISOString(), end: end.toISOString() };
}

function formatDateLabel(dateKey: string) {
  const date = new Date(`${dateKey}T00:00:00`);
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    month: "long",
    year: "numeric"
  }).format(date);
}

function stateTone(state: OrderState): "good" | "warn" | "bad" | "muted" {
  if (state === "delivered") return "good";
  if (state === "failed" || state === "cancelled") return "bad";
  if (state === "in_progress" || state === "accepted") return "warn";
  return "muted";
}

function formatMoney(value: number) {
  return new Intl.NumberFormat("ru-RU", {
    maximumFractionDigits: 0,
    style: "currency",
    currency: "RUB"
  }).format(value);
}

export function OrdersDashboard({
  initialDate,
  initialOrders,
  couriers
}: {
  initialDate?: string;
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
  const [lastUpdatedAt, setLastUpdatedAt] = useState(() => new Date());
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);

  const loadOrders = useCallback(async (dateKey: string, currentSelectedOrderId: string) => {
    const { start, end } = dateRangeForKey(dateKey);
    const { data } = await supabase
      .from("orders")
      .select(orderSelect)
      .gte("created_at", start)
      .lt("created_at", end)
      .order("created_at", { ascending: false });

    if (data) {
      const nextOrders = data as unknown as Order[];
      const currentSelectedOrder = nextOrders.find((order) => order.id === currentSelectedOrderId) ?? null;
      const nextSelectedOrder = currentSelectedOrder ?? nextOrders[0] ?? null;
      setOrders(nextOrders);
      if (!currentSelectedOrder) {
        setSelectedOrderId(nextSelectedOrder?.id ?? "");
        setDraftState(nextSelectedOrder?.state ?? "assigned");
        setDraftCourierId(nextSelectedOrder?.assigned_courier_id ?? "");
        setDraftComment(nextSelectedOrder?.delivery_comment ?? "");
        setDraftFailureReason(nextSelectedOrder?.failure_reason ?? "");
      }
      setLastUpdatedAt(new Date());
    }
  }, [supabase]);

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
    setDraftState(order.state);
    setDraftCourierId(order.assigned_courier_id ?? "");
    setDraftComment(order.delivery_comment ?? "");
    setDraftFailureReason(order.failure_reason ?? "");
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

    const {
      data: { user }
    } = await supabase.auth.getUser();
    const needsFailureReason = draftState === "failed" || draftState === "cancelled";
    const failureReason = needsFailureReason ? draftFailureReason.trim() || null : null;
    const deliveryComment = draftComment.trim() || null;
    const nextCourierId = draftCourierId || null;

    const { error } = await supabase
      .from("orders")
      .update({
        assigned_courier_id: nextCourierId,
        state: draftState,
        delivery_comment: deliveryComment,
        failure_reason: failureReason,
        updated_by: user?.id ?? null
      })
      .eq("id", selectedOrder.id);

    if (error) {
      setSaveError(error.message);
      setIsSaving(false);
      return;
    }

    await supabase.from("order_events").insert({
      order_id: selectedOrder.id,
      actor_profile_id: user?.id ?? null,
      event_type: "dispatcher_update",
      payload: {
        state: draftState,
        assigned_courier_id: nextCourierId,
        delivery_comment: deliveryComment,
        failure_reason: failureReason
      }
    });

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
    onStateChange: (value: OrderState) => setDraftState(value),
  };

  return (
    <>
    <div className="grid gap-5 2xl:grid-cols-[minmax(0,1fr)_380px]">
      <Panel>
        <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row md:items-center md:justify-between">
          <div>
            <div className="text-sm font-bold text-muted">
              {filtered.length} заказов за {formatDateLabel(selectedDate)}
            </div>
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
            <label className="sr-only" htmlFor="orders-date-filter">
              Дата заказов
            </label>
            <input
              className="focus-ring rounded-md border border-line px-3 py-2 text-sm font-semibold text-ink"
              id="orders-date-filter"
              type="date"
              value={selectedDate}
              onChange={(event) => {
                changeSelectedDate(event.target.value);
              }}
            />
            <select
              className="focus-ring rounded-md border border-line px-3 py-2 text-sm"
              value={stateFilter}
              onChange={(event) => setStateFilter(event.target.value as "all" | OrderState)}
            >
              <option value="all">Все статусы</option>
              {Object.entries(stateLabels).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
            <select
              className="focus-ring rounded-md border border-line px-3 py-2 text-sm"
              value={courierFilter}
              onChange={(event) => setCourierFilter(event.target.value)}
            >
              <option value="all">Все курьеры</option>
              {couriers.map((courier) => (
                <option key={courier.id} value={courier.id}>
                  {courier.display_name}
                </option>
              ))}
            </select>
            <button
              className="rounded-md border border-line px-3 py-2 text-sm font-bold text-ink hover:bg-slate-50"
              onClick={() => void refreshOrders()}
            >
              Обновить
            </button>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full border-separate border-spacing-0 text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-[0.12em] text-muted">
              <tr>
                {["Номер", "Клиент", "Адрес", "Курьер", "Статус", "Комментарий", "Оплата", ""].map((heading) => (
                  <th className="border-b border-line px-4 py-3 font-black" key={heading}>
                    {heading}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((order) => (
                <tr
                  className={order.id === selectedOrder?.id ? "bg-blue-50/70" : "hover:bg-slate-50"}
                  key={order.id}
                >
                  <td className="border-b border-line px-4 py-3 font-black text-ink">{order.order_number}</td>
                  <td className="border-b border-line px-4 py-3">
                    <div className="font-bold text-ink">{order.client_name}</div>
                    <div className="text-xs text-muted">{order.client_phone ?? "без телефона"}</div>
                  </td>
                  <td className="max-w-sm border-b border-line px-4 py-3 text-muted">
                    <div>{order.address}</div>
                    <div className="mt-1 flex flex-wrap gap-2 text-xs font-semibold text-ink">
                      {order.district ? <span>{order.district}</span> : null}
                      {order.time_slot ? <span>{order.time_slot}</span> : null}
                    </div>
                  </td>
                  <td className="border-b border-line px-4 py-3">
                    {order.couriers?.display_name ?? "Не назначен"}
                  </td>
                  <td className="border-b border-line px-4 py-3">
                    <StatusPill tone={stateTone(order.state)}>{stateLabels[order.state]}</StatusPill>
                  </td>
                  <td className="max-w-56 border-b border-line px-4 py-3 text-muted">
                    <div className="line-clamp-2">
                      {order.failure_reason || order.delivery_comment || "нет"}
                    </div>
                  </td>
                  <td className="border-b border-line px-4 py-3">
                    <div className="font-bold text-ink">{formatMoney(order.price)}</div>
                    <div className="text-xs text-muted">
                      {paymentLabels[order.payment_method]}, {order.bottles} бут.
                    </div>
                  </td>
                  <td className="border-b border-line px-4 py-3 text-right">
                    <button
                      className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand hover:text-brand"
                      onClick={() => selectOrder(order)}
                    >
                      Открыть
                    </button>
                  </td>
                </tr>
              ))}
              {filtered.length === 0 ? (
                <tr>
                  <td className="px-4 py-10 text-center text-sm font-semibold text-muted" colSpan={8}>
                    Заказов по выбранным фильтрам нет
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </Panel>

      {/* Wide screens: inspector always visible in grid */}
      <div className="hidden 2xl:block">
        <OrderInspector {...inspectorProps} />
      </div>
    </div>

    {/* Narrow screens: drawer overlay */}
    {isDrawerOpen && (
      <>
        <div
          aria-hidden
          className="fixed inset-0 z-40 bg-black/40 2xl:hidden"
          onClick={closeDrawer}
        />
        <div className="fixed inset-y-0 right-0 z-50 w-full max-w-[400px] overflow-y-auto shadow-2xl 2xl:hidden">
          <OrderInspector {...inspectorProps} onClose={closeDrawer} />
        </div>
      </>
    )}
    </>
  );
}

function OrderInspector({
  order,
  couriers,
  draftState,
  draftCourierId,
  draftComment,
  draftFailureReason,
  isSaving,
  message,
  error,
  onStateChange,
  onCourierChange,
  onCommentChange,
  onFailureReasonChange,
  onSave,
  onClose
}: {
  order: Order | null;
  couriers: Courier[];
  draftState: OrderState;
  draftCourierId: string;
  draftComment: string;
  draftFailureReason: string;
  isSaving: boolean;
  message: string | null;
  error: string | null;
  onStateChange: (value: OrderState) => void;
  onCourierChange: (value: string) => void;
  onCommentChange: (value: string) => void;
  onFailureReasonChange: (value: string) => void;
  onSave: () => void;
  onClose?: () => void;
}) {
  if (!order) {
    return (
      <Panel className="p-5">
        <div className="text-sm font-semibold text-muted">Выберите заказ, чтобы открыть диспетчерские действия.</div>
      </Panel>
    );
  }

  const mapHref =
    order.lat !== null && order.lng !== null
      ? `https://yandex.ru/maps/?pt=${order.lng},${order.lat}&z=16&l=map`
      : null;

  return (
    <Panel className="h-fit p-5 2xl:sticky 2xl:top-6">
      <div className="mb-4 flex items-start justify-between gap-3">
        <div>
          <div className="text-xs font-black uppercase tracking-[0.16em] text-muted">Заказ</div>
          <h2 className="mt-1 text-xl font-black text-ink">{order.order_number}</h2>
        </div>
        <div className="flex items-center gap-2">
          <StatusPill tone={stateTone(order.state)}>{stateLabels[order.state]}</StatusPill>
          {onClose && (
            <button
              aria-label="Закрыть"
              className="rounded-md p-1.5 text-muted hover:bg-slate-100 hover:text-ink"
              onClick={onClose}
            >
              <svg fill="none" height="16" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" viewBox="0 0 24 24" width="16">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>
      </div>

      <div className="space-y-3 border-b border-line pb-4 text-sm">
        <InfoRow label="Клиент" value={order.client_name} />
        <InfoRow label="Телефон" value={order.client_phone ?? "не указан"} href={order.client_phone ? `tel:${order.client_phone}` : undefined} />
        <InfoRow label="Адрес" value={order.address} />
        <InfoRow label="Район" value={order.district ?? "не указан"} />
        <InfoRow label="Слот" value={order.time_slot ?? "без слота"} />
        <InfoRow label="Оплата" value={`${paymentLabels[order.payment_method]} · ${formatMoney(order.price)}`} />
        <InfoRow label="Бутыли" value={String(order.bottles)} />
        {mapHref ? <InfoRow label="Карта" value="Открыть точку" href={mapHref} /> : null}
      </div>

      <div className="mt-4 space-y-4">
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Статус</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            value={draftState}
            onChange={(event) => onStateChange(event.target.value as OrderState)}
          >
            {editableStates.map((state) => (
              <option key={state} value={state}>
                {stateLabels[state]}
              </option>
            ))}
          </select>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Курьер</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            value={draftCourierId}
            onChange={(event) => onCourierChange(event.target.value)}
          >
            <option value="">Не назначен</option>
            {couriers.map((courier) => (
              <option key={courier.id} value={courier.id}>
                {courier.display_name}
              </option>
            ))}
          </select>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Комментарий диспетчера</span>
          <textarea
            className="focus-ring min-h-28 w-full resize-y rounded-md border border-line px-3 py-3 text-sm"
            placeholder="Код домофона, уточнения по клиенту, что передать курьеру"
            value={draftComment}
            onChange={(event) => onCommentChange(event.target.value)}
          />
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Причина проблемы</span>
          <textarea
            className="focus-ring min-h-20 w-full resize-y rounded-md border border-line px-3 py-3 text-sm"
            placeholder="Заполняется для проблемных или отмененных заказов"
            value={draftFailureReason}
            onChange={(event) => onFailureReasonChange(event.target.value)}
          />
        </label>

        {message ? <div className="rounded-md bg-emerald-50 px-3 py-2 text-sm font-bold text-good">{message}</div> : null}
        {error ? <div className="rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</div> : null}

        <button
          className="w-full rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:opacity-60"
          disabled={isSaving}
          onClick={() => void onSave()}
        >
          {isSaving ? "Сохраняем..." : "Сохранить изменения"}
        </button>
      </div>
    </Panel>
  );
}

function InfoRow({ label, value, href }: { label: string; value: string; href?: string }) {
  return (
    <div>
      <div className="text-xs font-bold uppercase tracking-[0.12em] text-muted">{label}</div>
      {href ? (
        <a className="font-bold text-brand hover:text-brandDark" href={href} rel="noreferrer" target={href.startsWith("http") ? "_blank" : undefined}>
          {value}
        </a>
      ) : (
        <div className="font-semibold text-ink">{value}</div>
      )}
    </div>
  );
}
