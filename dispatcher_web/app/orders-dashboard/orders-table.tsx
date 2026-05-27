import Link from "next/link";
import type { Courier, Order, OrderState } from "@/lib/types";
import { Panel, StatusPill } from "@/components/ui";
import { isOrderOverdue } from "./date-utils";
import {
  clientRatingShortLabel,
  fiscalReceiptLabel,
  orderRowClassName,
  paymentLabels,
  stateLabels,
  stateTone
} from "./order-formatters";

export function OrdersTable({
  courierFilter,
  couriers,
  lastUpdatedAt,
  onCourierFilterChange,
  onDateChange,
  onRefresh,
  onSelectOrder,
  onStateFilterChange,
  orders,
  selectedDate,
  selectedOrderId,
  stateFilter
}: {
  courierFilter: string;
  couriers: Courier[];
  lastUpdatedAt: Date;
  onCourierFilterChange: (value: string) => void;
  onDateChange: (value: string) => void;
  onRefresh: () => void;
  onSelectOrder: (order: Order) => void;
  onStateFilterChange: (value: "all" | OrderState) => void;
  orders: Order[];
  selectedDate: string;
  selectedOrderId: string;
  stateFilter: "all" | OrderState;
}) {
  return (
    <Panel className="min-w-0 border-0">
      <div className="mb-3 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <select
            className="focus-ring h-8 min-w-36 border border-line bg-white px-3 text-sm text-muted"
            value={stateFilter}
            onChange={(event) => onStateFilterChange(event.target.value as "all" | OrderState)}
          >
            <option value="all">Тип заказа</option>
            {Object.entries(stateLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
          <select
            className="focus-ring h-8 min-w-48 border border-line bg-white px-3 text-sm text-muted"
            value={courierFilter}
            onChange={(event) => onCourierFilterChange(event.target.value)}
          >
            <option value="all">Все водители</option>
            {couriers.map((courier) => (
              <option key={courier.id} value={courier.id}>
                {courier.display_name}
              </option>
            ))}
          </select>
          <button className="h-8 border border-line px-3 text-sm text-muted hover:text-ink" onClick={onRefresh}>
            Обновить
          </button>
          <span className="text-xs text-muted" suppressHydrationWarning>
            {lastUpdatedAt.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" })}
          </span>
        </div>
        <div className="flex items-center gap-4">
          <button className="flex size-8 items-center justify-center rounded-full bg-slate-200 text-lg font-black text-white" type="button">
            ...
          </button>
          <Link className="bg-brand px-4 py-2 text-sm font-bold text-white hover:bg-brandDark" href="/orders/new">
            Новый заказ
          </Link>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-[1500px] border-separate border-spacing-0 text-left text-sm">
          <thead className="text-muted">
            <tr className="bg-slate-50">
              <th className="w-9 border-b border-line px-2 py-3">
                <input className="size-4 border-line" type="checkbox" />
              </th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="№" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="ФИО, тел, email" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Адрес" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Район" /></th>
              <th className="border-b border-line px-2 py-3">
                <input
                  className="focus-ring h-8 w-full min-w-36 border border-line bg-white px-3 text-sm text-ink"
                  type="date"
                  value={selectedDate}
                  onChange={(event) => onDateChange(event.target.value)}
                />
              </th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Интервал" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Состав" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Водитель" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Ст" /></th>
              <th className="border-b border-line px-2 py-3"><FilterInput placeholder="Дата создания" /></th>
            </tr>
            <tr>
              {["", "№", "Клиент", "Адрес", "Район", "Дата доставки", "Интервал", "Состав", "Водитель", "Ст", "Дата создания"].map((heading) => (
                <th className="border-b border-line px-2 py-2 text-xs font-semibold" key={heading}>
                  {heading}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {orders.map((order) => {
              const overdue = isOrderOverdue(order);
              const ratingLabel = clientRatingShortLabel(order);
              const courierName =
                order.couriers?.display_name ??
                couriers.find((courier) => courier.id === order.assigned_courier_id)?.display_name ??
                "Не выбран";

              return (
                <tr className={orderRowClassName(order, order.id === selectedOrderId)} key={order.id}>
                  <td className="border-b border-line px-2 py-3">
                    <input className="size-4 border-line" type="checkbox" />
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top font-medium text-ink">
                    <button className="text-left hover:text-brand" onClick={() => onSelectOrder(order)}>
                      {order.order_number.replace("#", "")}
                    </button>
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top">
                    <div className="font-medium text-ink">{order.client_name}</div>
                    <div className="text-xs text-muted">{order.client_phone ?? ""}</div>
                    {ratingLabel ? <div className="mt-1 text-xs font-black text-amber-700">{ratingLabel}</div> : null}
                  </td>
                  <td className="max-w-sm border-b border-line px-2 py-3 align-top">
                    <div className="font-medium text-ink">{order.address}</div>
                    <div className="mt-1 text-xs text-muted">Зона доставки — Анапа</div>
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top text-ink">{order.district ?? ""}</td>
                  <td className="border-b border-line px-2 py-3 align-top text-ink">
                    <div>{formatDateCell(order.delivery_date ?? order.created_at)}</div>
                    {overdue ? <div className="text-xs font-semibold text-red-600">просрочен</div> : null}
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top text-ink">{order.time_slot ?? ""}</td>
                  <td className="border-b border-line px-2 py-3 align-top">
                    <span className="font-bold text-ink">{order.bottles}</span>
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top">
                    <button
                      className="h-8 w-40 border border-line bg-white px-3 text-left text-sm text-ink hover:border-brand"
                      onClick={() => onSelectOrder(order)}
                      type="button"
                    >
                      {courierName}
                    </button>
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top">
                    <StatusPill tone={stateTone(order.state)}>{stateLabels[order.state].slice(0, 1)}</StatusPill>
                    <div className="mt-1 text-xs text-muted">{paymentLabels[order.payment_method]}</div>
                    <div className="text-xs text-muted">{fiscalReceiptLabel(order)}</div>
                  </td>
                  <td className="border-b border-line px-2 py-3 align-top text-ink">
                    <div>{formatDateCell(order.created_at)}</div>
                    <div className="text-xs text-muted">{formatTimeCell(order.created_at)}</div>
                  </td>
                </tr>
              );
            })}
            {orders.length === 0 ? (
              <tr>
                <td className="sticky left-0 bg-white px-4 py-10 text-center text-sm font-semibold text-muted" colSpan={11}>
                  Заказов по выбранным фильтрам нет
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </Panel>
  );
}

function FilterInput({ placeholder }: { placeholder: string }) {
  return (
    <input
      className="focus-ring h-8 w-full border border-line bg-white px-3 text-sm text-ink placeholder:text-slate-400"
      placeholder={placeholder}
    />
  );
}

function formatDateCell(value: string) {
  const date = value.includes("T") ? new Date(value) : new Date(`${value}T00:00:00`);
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric"
  }).format(date);
}

function formatTimeCell(value: string) {
  return new Intl.DateTimeFormat("ru-RU", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit"
  }).format(new Date(value));
}
