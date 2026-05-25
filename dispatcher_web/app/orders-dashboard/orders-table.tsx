import type { Courier, Order, OrderState } from "@/lib/types";
import { Panel, StatusPill } from "@/components/ui";
import { formatDateLabel, isOrderOverdue } from "./date-utils";
import {
  clientRatingShortLabel,
  fiscalReceiptLabel,
  formatMoney,
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
    <Panel className="min-w-0">
      <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row md:items-center md:justify-between">
        <div>
          <div className="text-sm font-bold text-muted">
            {orders.length} заказов за {formatDateLabel(selectedDate)}
          </div>
          <div className="text-xs font-semibold text-muted" suppressHydrationWarning>
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
            onChange={(event) => onDateChange(event.target.value)}
          />
          <select
            className="focus-ring rounded-md border border-line px-3 py-2 text-sm"
            value={stateFilter}
            onChange={(event) => onStateFilterChange(event.target.value as "all" | OrderState)}
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
            onChange={(event) => onCourierFilterChange(event.target.value)}
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
            onClick={onRefresh}
          >
            Обновить
          </button>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-[1040px] border-separate border-spacing-0 text-left text-sm">
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
            {orders.map((order) => {
              const overdue = isOrderOverdue(order);
              const ratingLabel = clientRatingShortLabel(order);

              return (
                <tr className={orderRowClassName(order, order.id === selectedOrderId)} key={order.id}>
                  <td className="border-b border-line px-4 py-3 font-black text-ink">{order.order_number}</td>
                  <td className="border-b border-line px-4 py-3">
                    <div className="font-bold text-ink">{order.client_name}</div>
                    <div className="text-xs text-muted">{order.client_phone ?? "без телефона"}</div>
                    {ratingLabel ? <div className="mt-1 text-xs font-black text-amber-700">{ratingLabel}</div> : null}
                  </td>
                  <td className="max-w-sm border-b border-line px-4 py-3 text-muted">
                    <div>{order.address}</div>
                    <div className="mt-1 flex flex-wrap gap-2 text-xs font-semibold text-ink">
                      {order.district ? <span>{order.district}</span> : null}
                      {order.time_slot ? <span>{order.time_slot}</span> : null}
                      {overdue ? <span className="rounded bg-red-100 px-2 py-0.5 font-black text-bad">просрочен</span> : null}
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
                    <div className="text-xs font-semibold text-muted">{fiscalReceiptLabel(order)}</div>
                  </td>
                  <td className="border-b border-line px-4 py-3 text-right">
                    <button
                      className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand hover:text-brand"
                      onClick={() => onSelectOrder(order)}
                    >
                      Открыть
                    </button>
                  </td>
                </tr>
              );
            })}
            {orders.length === 0 ? (
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
  );
}
