"use client";

import { useMemo, useState, useTransition } from "react";
import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { AlertTriangle, CheckCircle2, Clock3, MapPinOff, PackageOpen, Truck } from "lucide-react";
import { Panel, StatusPill } from "@/components/ui";
import type { DispatcherOperations, OperationalIssue, OperationsOrder } from "@/lib/types";
import { updateOperationalIssue } from "./actions";

const OperationsMap = dynamic(
  () => import("./operations-map").then((module) => module.OperationsMap),
  {
    loading: () => <div className="h-[440px] animate-pulse bg-surface-soft" aria-label="Карта загружается" />,
    ssr: false
  }
);

const money = new Intl.NumberFormat("ru-RU", { currency: "RUB", maximumFractionDigits: 0, style: "currency" });

export function OperationsDashboard({ data, loadedAt }: { data: DispatcherOperations; loadedAt: string }) {
  const router = useRouter();
  const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null);
  const [selectedIssueKey, setSelectedIssueKey] = useState<string | null>(null);
  const [issueFilter, setIssueFilter] = useState<"active" | "all" | "resolved">("active");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const visibleIssues = useMemo(() => data.issues.filter((issue) => {
    if (issueFilter === "active") return !["resolved", "dismissed"].includes(issue.status);
    if (issueFilter === "resolved") return ["resolved", "dismissed"].includes(issue.status);
    return true;
  }), [data.issues, issueFilter]);
  const selectedIssue = data.issues.find((issue) => issue.issue_key === selectedIssueKey) ?? null;
  const selectedOrder = data.orders.find((order) => order.id === selectedOrderId) ?? null;

  function chooseIssue(issue: OperationalIssue) {
    setSelectedIssueKey(issue.issue_key);
    setSelectedOrderId(issue.order_id);
    setNote(issue.note ?? "");
    setError(null);
  }

  function changeIssue(status: OperationalIssue["status"]) {
    if (!selectedIssue) return;
    setError(null);
    startTransition(async () => {
      const result = await updateOperationalIssue({
        courierId: selectedIssue.courier_id,
        issueKey: selectedIssue.issue_key,
        issueType: selectedIssue.issue_type,
        note: note.trim(),
        orderId: selectedIssue.order_id,
        status
      });
      if (!result.ok) {
        setError(result.error);
        return;
      }
      setSelectedIssueKey(null);
      setNote("");
      router.refresh();
    });
  }

  return (
    <div className="grid gap-5">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
        <Metric label="Все заказы" value={data.summary.total_orders} />
        <Metric label="Доставлено" tone="good" value={data.summary.delivered_orders} />
        <Metric label="В работе" tone="brand" value={data.summary.active_orders} />
        <Metric label="Без водителя" tone={data.summary.unassigned_orders ? "warn" : "muted"} value={data.summary.unassigned_orders} />
        <Metric label="Опаздывают" tone={data.summary.overdue_orders ? "bad" : "muted"} value={data.summary.overdue_orders} />
        <Metric label="Открытые проблемы" tone={data.summary.open_issues ? "bad" : "good"} value={data.summary.open_issues} />
      </div>

      <div className="grid gap-5 2xl:grid-cols-[minmax(0,1.65fr)_minmax(340px,0.75fr)]">
        <Panel className="min-w-0 overflow-hidden">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line p-4">
            <div>
              <h2 className="font-black text-ink">Карта заказов и водителей</h2>
              <p className="mt-1 text-xs font-semibold text-muted">Красный — проблема, жёлтый — без водителя, синий — в пути, зелёный — доставлен.</p>
            </div>
            <div className="text-right">
              <div className="font-black text-ink">{money.format(data.summary.revenue)}</div>
              <div className="text-xs font-semibold text-muted">выручка · {data.summary.planned_bottles} бутылок в маршрутах</div>
            </div>
          </div>
          <OperationsMap couriers={data.couriers} onSelectOrder={setSelectedOrderId} orders={data.orders} selectedOrderId={selectedOrderId} />
          {selectedOrder ? <OrderStrip order={selectedOrder} /> : null}
        </Panel>

        <Panel className="min-w-0">
          <div className="border-b border-line p-4">
            <h2 className="font-black text-ink">Маршруты водителей</h2>
            <p className="mt-1 text-xs font-semibold text-muted">Прогресс, загрузка, остаток и свежесть геопозиции.</p>
          </div>
          <div className="app-scrollbar max-h-[585px] divide-y divide-line overflow-y-auto">
            {data.couriers.map((courier) => {
              const progress = courier.total_orders ? Math.round(courier.delivered_orders / courier.total_orders * 100) : 0;
              const stale = !courier.location_at || new Date(loadedAt).valueOf() - new Date(courier.location_at).valueOf() > 30 * 60 * 1000;
              const overload = courier.inventory_configured && courier.loaded_full_bottles !== null && courier.planned_bottles > courier.loaded_full_bottles;
              return (
                <article className="p-4" key={courier.id}>
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="font-black text-ink">{courier.name}</div>
                      <div className="mt-1 text-xs font-bold text-muted">{courier.vehicle_plate ?? "Машина не назначена"}</div>
                    </div>
                    <StatusPill tone={overload ? "bad" : courier.active_orders ? "warn" : "muted"}>
                      {courier.estimated_finish ? `до ${courier.estimated_finish}` : courier.active_orders ? "В работе" : "Без маршрута"}
                    </StatusPill>
                  </div>
                  <div className="mt-3 h-2 overflow-hidden rounded-full bg-slate-100">
                    <div className="h-full rounded-full bg-brand" style={{ width: `${progress}%` }} />
                  </div>
                  <div className="mt-1 flex justify-between text-xs font-bold text-muted">
                    <span>{courier.delivered_orders} из {courier.total_orders}</span><span>{progress}%</span>
                  </div>
                  <div className="mt-3 grid grid-cols-2 gap-2 text-xs font-semibold">
                    <span className={overload ? "text-bad" : "text-ink"}>План: {courier.planned_bottles} бут.</span>
                    <span className={courier.remaining_full_bottles !== null && courier.remaining_full_bottles < 0 ? "text-bad" : "text-ink"}>
                      Остаток: {courier.inventory_configured ? courier.remaining_full_bottles : "не внесён"}
                    </span>
                    <span className={stale && courier.active_orders ? "text-bad" : "text-muted"}>
                      GPS: {courier.location_at ? relativeTime(courier.location_at, loadedAt) : "нет данных"}
                    </span>
                    <span className="text-muted">Тара: {courier.inventory_configured ? courier.remaining_empty_bottles : "—"}</span>
                  </div>
                </article>
              );
            })}
          </div>
        </Panel>
      </div>

      <Panel>
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line p-4">
          <div>
            <h2 className="font-black text-ink">Центр проблем</h2>
            <p className="mt-1 text-xs font-semibold text-muted">Проблема остаётся видимой, пока диспетчер не подтвердит решение.</p>
          </div>
          <div className="flex gap-1 rounded-md bg-slate-100 p-1">
            <FilterButton active={issueFilter === "active"} onClick={() => setIssueFilter("active")}>Открытые</FilterButton>
            <FilterButton active={issueFilter === "all"} onClick={() => setIssueFilter("all")}>Все</FilterButton>
            <FilterButton active={issueFilter === "resolved"} onClick={() => setIssueFilter("resolved")}>Закрытые</FilterButton>
          </div>
        </div>
        <div className={`grid ${selectedIssue ? "xl:grid-cols-[minmax(0,1fr)_380px]" : ""}`}>
          <div className="divide-y divide-line">
            {visibleIssues.map((issue) => (
              <button className={`grid w-full gap-3 px-4 py-4 text-left hover:bg-slate-50 md:grid-cols-[28px_140px_minmax(0,1fr)_auto] md:items-center ${selectedIssue?.issue_key === issue.issue_key ? "bg-brand/5" : ""}`} key={issue.issue_key} onClick={() => chooseIssue(issue)} type="button">
                <IssueIcon type={issue.issue_type} />
                <StatusPill tone={severityTone(issue.severity)}>{severityLabel(issue.severity)}</StatusPill>
                <span><span className="block font-black text-ink">{issue.title}</span><span className="mt-1 block text-sm font-semibold text-muted">{issue.detail}</span></span>
                <StatusPill tone={issue.status === "resolved" ? "good" : issue.status === "acknowledged" ? "warn" : "muted"}>{issueStatusLabel(issue.status)}</StatusPill>
              </button>
            ))}
            {visibleIssues.length === 0 ? <div className="p-10 text-center"><CheckCircle2 className="mx-auto size-9 text-good" /><p className="mt-3 font-black text-ink">Открытых проблем нет</p></div> : null}
          </div>
          {selectedIssue ? (
            <aside className="border-t border-line bg-slate-50 p-5 xl:border-l xl:border-t-0">
              <h3 className="font-black text-ink">{selectedIssue.title}</h3>
              <p className="mt-2 text-sm font-semibold leading-relaxed text-muted">{selectedIssue.detail}</p>
              <label className="mt-5 block text-sm font-black text-ink">Комментарий диспетчера
                <textarea className="focus-ring mt-2 min-h-28 w-full resize-y rounded-md border border-line bg-white p-3 text-sm font-semibold" maxLength={1000} onChange={(event) => setNote(event.target.value)} value={note} />
              </label>
              {error ? <p className="mt-3 rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</p> : null}
              <div className="mt-4 grid grid-cols-2 gap-2">
                <button className="rounded-md border border-line bg-white px-3 py-2.5 text-sm font-black text-ink hover:border-brand disabled:opacity-50" disabled={isPending} onClick={() => changeIssue("acknowledged")} type="button">Принять в работу</button>
                <button className="rounded-md bg-good px-3 py-2.5 text-sm font-black text-white disabled:opacity-50" disabled={isPending} onClick={() => changeIssue("resolved")} type="button">Проблема решена</button>
              </div>
            </aside>
          ) : null}
        </div>
      </Panel>
    </div>
  );
}

function Metric({ label, value, tone = "muted" }: { label: string; value: number; tone?: "muted" | "brand" | "good" | "warn" | "bad" }) {
  const colors = { muted: "text-ink", brand: "text-brand", good: "text-good", warn: "text-warn", bad: "text-bad" };
  return <Panel className="p-4"><div className="text-xs font-black uppercase tracking-[0.08em] text-muted">{label}</div><div className={`mt-2 text-3xl font-black ${colors[tone]}`}>{value}</div></Panel>;
}

function OrderStrip({ order }: { order: OperationsOrder }) {
  return <div className="grid gap-3 border-t border-line bg-white p-4 md:grid-cols-[auto_minmax(0,1fr)_auto_auto] md:items-center"><StatusPill tone={order.state === "delivered" ? "good" : order.state === "failed" || order.is_overdue ? "bad" : "warn"}>{order.order_number}</StatusPill><div><div className="font-black text-ink">{order.client_name}</div><div className="text-xs font-semibold text-muted">{order.address}</div></div><div className="font-bold text-ink">{order.time_slot ?? "Без интервала"}</div><div className="font-black text-ink">{order.bottles} бут.</div></div>;
}

function FilterButton({ active, children, onClick }: { active: boolean; children: React.ReactNode; onClick: () => void }) {
  return <button className={`rounded px-3 py-1.5 text-xs font-black ${active ? "bg-white text-brand shadow-sm" : "text-muted"}`} onClick={onClick} type="button">{children}</button>;
}

function IssueIcon({ type }: { type: string }) {
  const className = "size-5 text-bad";
  if (type === "missing_coordinates") return <MapPinOff className={className} />;
  if (type === "stale_location") return <Clock3 className={className} />;
  if (type.includes("inventory") || type === "capacity_overload") return <PackageOpen className={className} />;
  if (type === "unassigned_order") return <Truck className={className} />;
  return <AlertTriangle className={className} />;
}

function severityTone(value: OperationalIssue["severity"]): "bad" | "warn" { return value === "medium" ? "warn" : "bad"; }
function severityLabel(value: OperationalIssue["severity"]) { return value === "critical" ? "Критично" : value === "high" ? "Важно" : "Проверить"; }
function issueStatusLabel(value: OperationalIssue["status"]) { return value === "acknowledged" ? "В работе" : value === "resolved" ? "Решено" : value === "dismissed" ? "Скрыто" : "Новое"; }

function relativeTime(value: string, referenceTime: string) {
  const minutes = Math.max(0, Math.round((new Date(referenceTime).valueOf() - new Date(value).valueOf()) / 60000));
  if (minutes < 1) return "сейчас";
  if (minutes < 60) return `${minutes} мин назад`;
  return `${Math.floor(minutes / 60)} ч назад`;
}
