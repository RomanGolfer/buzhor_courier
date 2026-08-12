import { AlertTriangle, Banknote, Box, CheckCircle2, CircleDollarSign, PackageCheck, Star, UsersRound } from "lucide-react";
import { Panel, StatusPill } from "@/components/ui";
import type { DispatcherAnalytics, PaymentMethod } from "@/lib/types";

const money = new Intl.NumberFormat("ru-RU", { currency: "RUB", maximumFractionDigits: 0, style: "currency" });
const number = new Intl.NumberFormat("ru-RU", { maximumFractionDigits: 1 });

export function AnalyticsDashboard({ data }: { data: DispatcherAnalytics }) {
  const currentSuccess = successRate(data.summary.delivered_orders, data.summary.failed_orders, data.summary.cancelled_orders);
  const previousSuccess = successRate(data.previous.delivered_orders, data.previous.failed_orders, 0);
  return (
    <div className="grid gap-5">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4 2xl:grid-cols-8">
        <Kpi icon={CircleDollarSign} label="Выручка" value={money.format(data.summary.revenue)} delta={delta(data.summary.revenue, data.previous.revenue)} />
        <Kpi icon={PackageCheck} label="Доставлено" value={String(data.summary.delivered_orders)} delta={delta(data.summary.delivered_orders, data.previous.delivered_orders)} />
        <Kpi icon={CheckCircle2} label="Успешность" value={`${number.format(currentSuccess)}%`} delta={currentSuccess - previousSuccess} suffix=" п.п." />
        <Kpi icon={Banknote} label="Средний заказ" value={money.format(data.summary.average_order)} />
        <Kpi icon={Box} label="Полных доставлено" value={number.format(data.summary.full_bottles)} delta={delta(data.summary.full_bottles, data.previous.full_bottles)} />
        <Kpi icon={PackageCheck} label="Тары собрано" value={number.format(data.summary.empty_bottles)} />
        <Kpi icon={UsersRound} label="Уникальных клиентов" value={number.format(data.summary.unique_clients)} />
        <Kpi icon={Star} label="Оценка" value={data.summary.rating_count ? number.format(data.summary.average_rating) : "—"} detail={countLabel(data.summary.rating_count, "оценка", "оценки", "оценок")} />
      </div>

      <Panel>
        <div className="flex flex-wrap items-end justify-between gap-3 border-b border-line p-5">
          <div><h2 className="font-black text-ink">Динамика продаж</h2><p className="mt-1 text-sm font-semibold text-muted">{formatDate(data.date_from)} — {formatDate(data.date_to)} · сравнение с {formatDate(data.previous_date_from)} — {formatDate(data.previous_date_to)}</p></div>
          <div className="flex gap-4 text-xs font-bold text-muted"><span><i className="mr-1 inline-block size-2 rounded-full bg-brand" />Выручка</span><span><i className="mr-1 inline-block size-2 rounded-full bg-ink" />Заказы</span></div>
        </div>
        <TrendChart rows={data.trend} />
      </Panel>

      <div className="grid gap-5 xl:grid-cols-2">
        <Panel>
          <div className="border-b border-line p-5"><h2 className="font-black text-ink">Способы оплаты</h2><p className="mt-1 text-sm font-semibold text-muted">Только выполненные доставки, по подтверждённому способу оплаты.</p></div>
          <div className="grid gap-4 p-5">{data.payments.map((payment) => {
            const share = data.summary.revenue ? payment.amount / data.summary.revenue * 100 : 0;
            return <div key={payment.method}><div className="flex items-center justify-between gap-4 text-sm"><span className="font-black text-ink">{paymentLabel(payment.method)}</span><span className="font-bold text-ink">{money.format(payment.amount)} · {countLabel(payment.orders, "заказ", "заказа", "заказов")}</span></div><div className="mt-2 h-2 overflow-hidden rounded-full bg-slate-100"><div className="h-full rounded-full bg-brand" style={{ width: `${share}%` }} /></div><div className="mt-1 text-right text-xs font-bold text-muted">{number.format(share)}%</div></div>;
          })}{data.payments.length === 0 ? <Empty text="За выбранный период нет выполненных продаж" /> : null}</div>
        </Panel>

        <Panel>
          <div className="border-b border-line p-5"><h2 className="font-black text-ink">Качество данных</h2><p className="mt-1 text-sm font-semibold text-muted">Записи, которые мешают маршрутизации, связи и точной отчётности.</p></div>
          <div className="grid gap-3 p-5 sm:grid-cols-2">
            <Quality label="Без координат" value={data.quality.missing_coordinates} />
            <Quality label="Без телефона" value={data.quality.missing_phone} />
            <Quality label="Без зоны" value={data.quality.without_zone} />
            <Quality label="Без водителя" value={data.quality.without_courier} />
            <Quality label="Оплата не подтверждена" value={data.quality.unconfirmed_payment} />
            <Quality label="Смены с расхождением" value={data.summary.shifts_with_discrepancy} />
          </div>
        </Panel>
      </div>

      <Panel>
        <div className="border-b border-line p-5"><h2 className="font-black text-ink">Эффективность водителей</h2><p className="mt-1 text-sm font-semibold text-muted">Успешность считается среди завершённых заказов; оценка клиента показана отдельно.</p></div>
        <div className="overflow-x-auto"><table className="min-w-[980px] text-left text-sm"><thead className="bg-slate-50 text-xs uppercase tracking-[0.08em] text-muted"><tr><th className="border-b border-line px-5 py-3">Водитель</th><th className="border-b border-line px-3 py-3">Доставлено</th><th className="border-b border-line px-3 py-3">Успешность</th><th className="border-b border-line px-3 py-3">Выручка</th><th className="border-b border-line px-3 py-3">Полных</th><th className="border-b border-line px-3 py-3">Средний заказ</th><th className="border-b border-line px-5 py-3">Оценка</th></tr></thead><tbody>{data.couriers.map((courier) => <tr className="hover:bg-slate-50" key={courier.id}><td className="border-b border-line px-5 py-4 font-black text-ink">{courier.display_name}</td><td className="border-b border-line px-3 py-4 font-bold">{courier.delivered_orders} из {courier.total_orders}</td><td className="border-b border-line px-3 py-4"><StatusPill tone={courier.failed_orders ? "warn" : "good"}>{number.format(successRate(courier.delivered_orders, courier.failed_orders, 0))}%</StatusPill></td><td className="border-b border-line px-3 py-4 font-black">{money.format(courier.revenue)}</td><td className="border-b border-line px-3 py-4 font-bold">{courier.full_bottles}</td><td className="border-b border-line px-3 py-4 font-bold">{money.format(courier.delivered_orders ? courier.revenue / courier.delivered_orders : 0)}</td><td className="border-b border-line px-5 py-4 font-bold">{courier.rating_count ? `${number.format(courier.average_rating)} · ${courier.rating_count}` : "—"}</td></tr>)}{data.couriers.length === 0 ? <tr><td colSpan={7}><Empty text="Нет данных по водителям за этот период" /></td></tr> : null}</tbody></table></div>
      </Panel>

      <Panel>
        <div className="border-b border-line p-5"><h2 className="font-black text-ink">Зоны доставки</h2><p className="mt-1 text-sm font-semibold text-muted">Нагрузка, успешность и выручка по географическим границам.</p></div>
        <div className="overflow-x-auto"><table className="min-w-[820px] text-left text-sm"><thead className="bg-slate-50 text-xs uppercase tracking-[0.08em] text-muted"><tr><th className="border-b border-line px-5 py-3">Зона</th><th className="border-b border-line px-3 py-3">Заказы</th><th className="border-b border-line px-3 py-3">Доставлено</th><th className="border-b border-line px-3 py-3">Не выполнено</th><th className="border-b border-line px-5 py-3">Выручка</th></tr></thead><tbody>{data.zones.map((zone) => <tr key={zone.id}><td className="border-b border-line px-5 py-4"><span className="mr-2 inline-block size-3 rounded-full align-middle" style={{ background: zone.color }} /><span className="font-black text-ink">{zone.name}</span></td><td className="border-b border-line px-3 py-4 font-bold">{zone.total_orders}</td><td className="border-b border-line px-3 py-4 font-bold text-good">{zone.delivered_orders}</td><td className="border-b border-line px-3 py-4 font-bold text-bad">{zone.failed_orders}</td><td className="border-b border-line px-5 py-4 font-black">{money.format(zone.revenue)}</td></tr>)}{data.zones.length === 0 ? <tr><td colSpan={5}><Empty text="Нет заказов для разбивки по зонам" /></td></tr> : null}</tbody></table></div>
      </Panel>
    </div>
  );
}

function Kpi({ icon: Icon, label, value, delta: change, suffix = "%", detail }: { icon: typeof CircleDollarSign; label: string; value: string; delta?: number | null; suffix?: string; detail?: string }) { return <Panel className="p-4"><div className="flex items-center justify-between gap-2"><span className="text-xs font-black uppercase tracking-[0.08em] text-muted">{label}</span><Icon className="size-5 text-brand" /></div><div className="mt-3 text-2xl font-black text-ink">{value}</div>{change !== undefined && change !== null ? <div className={`mt-2 text-xs font-black ${change > 0 ? "text-good" : change < 0 ? "text-bad" : "text-muted"}`}>{change > 0 ? "▲" : change < 0 ? "▼" : "•"} {number.format(Math.abs(change))}{suffix} к прошлому периоду</div> : detail ? <div className="mt-2 text-xs font-bold text-muted">{detail}</div> : null}</Panel>; }
function TrendChart({ rows }: { rows: DispatcherAnalytics["trend"] }) {
  const maxRevenue = Math.max(...rows.map((row) => row.revenue), 1);
  const maxOrders = Math.max(...rows.map((row) => row.orders), 1);
  const totalOrders = rows.reduce((total, row) => total + row.orders, 0);

  return <div className="overflow-x-auto p-5">
    <div className="flex h-64 min-w-[760px] items-end gap-1 border-b border-line px-1">
      {rows.map((row, index) => <div
        className="group relative flex h-full min-w-3 flex-1 items-end justify-center"
        key={row.day}
        title={`${formatDate(row.day)}: ${money.format(row.revenue)}, ${countLabel(row.orders, "заказ", "заказа", "заказов")}`}
      >
        <div className="w-full max-w-7 rounded-t bg-brand/80 transition group-hover:bg-brand" style={{ height: `${Math.max(row.revenue / maxRevenue * 88, row.revenue ? 3 : 0)}%` }} />
        {row.orders ? <span className="absolute left-1/2 size-2 -translate-x-1/2 rounded-full bg-ink" style={{ bottom: `${Math.max(row.orders / maxOrders * 88, 3)}%` }} /> : null}
        {(rows.length <= 31 || index % Math.ceil(rows.length / 16) === 0) ? <span className="absolute -bottom-6 left-1/2 -translate-x-1/2 whitespace-nowrap text-[10px] font-bold text-muted">{shortDate(row.day)}</span> : null}
      </div>)}
    </div>
    <div className="mt-10 flex flex-wrap justify-between gap-3 text-sm font-bold text-muted"><span>Всего {countLabel(totalOrders, "заказ", "заказа", "заказов")}</span><span>Пиковая выручка {money.format(maxRevenue)}</span></div>
  </div>;
}
function Quality({ label, value }: { label: string; value: number }) { return <div className={`flex items-center justify-between gap-3 rounded-md px-4 py-3 ${value ? "bg-amber-50" : "bg-emerald-50"}`}><span className="flex items-center gap-2 text-sm font-bold text-ink">{value ? <AlertTriangle className="size-4 text-warn" /> : <CheckCircle2 className="size-4 text-good" />}{label}</span><span className={`text-xl font-black ${value ? "text-warn" : "text-good"}`}>{value}</span></div>; }
function Empty({ text }: { text: string }) { return <div className="p-10 text-center font-semibold text-muted">{text}</div>; }
function successRate(delivered: number, failed: number, cancelled: number) { const completed = delivered + failed + cancelled; return completed ? delivered / completed * 100 : 0; }
function delta(current: number, previous: number) { if (!previous) return current ? 100 : 0; return (current - previous) / previous * 100; }
function paymentLabel(value: PaymentMethod) { return value === "cash" ? "Наличные" : value === "card" ? "Терминал" : value === "qr" ? "QR-код" : value === "online" ? "Онлайн" : "Договор"; }
function formatDate(value: string) { return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "short", year: "numeric", timeZone: "Europe/Moscow" }).format(new Date(`${value}T12:00:00+03:00`)); }
function shortDate(value: string) { return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "2-digit", timeZone: "Europe/Moscow" }).format(new Date(`${value}T12:00:00+03:00`)); }
function countLabel(value: number, one: string, few: string, many: string) { const mod100 = Math.abs(value) % 100; const mod10 = mod100 % 10; const word = mod100 > 10 && mod100 < 20 ? many : mod10 === 1 ? one : mod10 > 1 && mod10 < 5 ? few : many; return `${number.format(value)} ${word}`; }
