"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Panel, StatusPill } from "@/components/ui";
import type { InventoryMovementRow, ShiftReconciliationRow } from "@/lib/types";
import { closeCourierShift, reopenCourierShift } from "./actions";

type ShiftEditor = {
  courierId: string;
  actualCash: string;
  actualCard: string;
  actualQr: string;
  actualOnline: string;
  actualContract: string;
  actualFullBottles: string;
  actualEmptyBottles: string;
  startMileage: string;
  endMileage: string;
  discrepancyReason: string;
  notes: string;
};

const rubles = new Intl.NumberFormat("ru-RU", { currency: "RUB", maximumFractionDigits: 0, style: "currency" });

export function ShiftReconciliationManager({
  canReopen,
  movements,
  rows,
  selectedDate
}: {
  canReopen: boolean;
  movements: InventoryMovementRow[];
  rows: ShiftReconciliationRow[];
  selectedDate: string;
}) {
  const router = useRouter();
  const [editor, setEditor] = useState<ShiftEditor | null>(null);
  const [reopenRow, setReopenRow] = useState<ShiftReconciliationRow | null>(null);
  const [reopenReason, setReopenReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const selectedRow = editor ? rows.find((row) => row.courier_id === editor.courierId) ?? null : null;

  const summary = useMemo(() => ({
    closed: rows.filter((row) => row.status === "closed").length,
    ready: rows.filter((row) => row.readiness === "ready").length,
    active: rows.filter((row) => row.readiness === "active_orders").length,
    missing: rows.filter((row) => row.readiness === "inventory_missing").length,
    cash: rows.reduce((total, row) => total + row.expected_cash, 0),
    total: rows.reduce((total, row) => total + row.expected_total, 0)
  }), [rows]);

  const preview = useMemo(() => selectedRow && editor ? {
    cash: numberValue(editor.actualCash) - selectedRow.expected_cash,
    nonCash: numberValue(editor.actualCard) + numberValue(editor.actualQr) + numberValue(editor.actualOnline) + numberValue(editor.actualContract)
      - selectedRow.expected_card - selectedRow.expected_qr - selectedRow.expected_online - selectedRow.expected_contract,
    full: numberValue(editor.actualFullBottles) - (selectedRow.expected_full_bottles ?? 0),
    empty: numberValue(editor.actualEmptyBottles) - (selectedRow.expected_empty_bottles ?? 0)
  } : null, [editor, selectedRow]);

  function openEditor(row: ShiftReconciliationRow) {
    setEditor({
      courierId: row.courier_id,
      actualCash: String(row.actual_cash ?? row.expected_cash),
      actualCard: String(row.actual_card ?? row.expected_card),
      actualQr: String(row.actual_qr ?? row.expected_qr),
      actualOnline: String(row.actual_online ?? row.expected_online),
      actualContract: String(row.actual_contract ?? row.expected_contract),
      actualFullBottles: String(row.actual_full_bottles ?? row.expected_full_bottles ?? 0),
      actualEmptyBottles: String(row.actual_empty_bottles ?? row.expected_empty_bottles ?? 0),
      startMileage: row.start_mileage === null ? "" : String(row.start_mileage),
      endMileage: row.end_mileage === null ? "" : String(row.end_mileage),
      discrepancyReason: row.discrepancy_reason ?? "",
      notes: row.notes ?? ""
    });
    setError(null);
    setNotice(null);
  }

  function submitClose() {
    if (!editor || !selectedRow) return;
    const integerFields = [editor.actualFullBottles, editor.actualEmptyBottles];
    const moneyFields = [editor.actualCash, editor.actualCard, editor.actualQr, editor.actualOnline, editor.actualContract];
    if (integerFields.some((value) => !/^\d+$/.test(value)) || moneyFields.some((value) => !validNumber(value))) {
      setError("Проверьте фактические суммы и количество бутылок.");
      return;
    }
    setError(null);
    startTransition(async () => {
      const result = await closeCourierShift({
        actualCard: numberValue(editor.actualCard),
        actualCash: numberValue(editor.actualCash),
        actualContract: numberValue(editor.actualContract),
        actualEmptyBottles: numberValue(editor.actualEmptyBottles),
        actualFullBottles: numberValue(editor.actualFullBottles),
        actualOnline: numberValue(editor.actualOnline),
        actualQr: numberValue(editor.actualQr),
        courierId: editor.courierId,
        discrepancyReason: editor.discrepancyReason.trim(),
        endMileage: optionalNumber(editor.endMileage),
        notes: editor.notes.trim(),
        startMileage: optionalNumber(editor.startMileage),
        workDate: selectedDate
      });
      if (!result.ok) { setError(result.error); return; }
      setEditor(null);
      setNotice(`Смена водителя ${selectedRow.courier_name} закрыта. Данные дня заблокированы.`);
      router.refresh();
    });
  }

  function submitReopen() {
    if (!reopenRow) return;
    setError(null);
    startTransition(async () => {
      const result = await reopenCourierShift({ courierId: reopenRow.courier_id, reason: reopenReason.trim(), workDate: selectedDate });
      if (!result.ok) { setError(result.error); return; }
      setNotice(`Смена водителя ${reopenRow.courier_name} открыта повторно.`);
      setReopenRow(null);
      setReopenReason("");
      router.refresh();
    });
  }

  return (
    <div className="grid gap-5">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
        <Summary label="Закрыто" value={`${summary.closed} из ${rows.length}`} />
        <Summary label="Готовы к закрытию" value={String(summary.ready)} tone="good" />
        <Summary label="Есть активные заказы" value={String(summary.active)} tone="warn" />
        <Summary label="Нет загрузки" value={String(summary.missing)} tone="bad" />
        <Summary label="Ожидаемая наличка" value={rubles.format(summary.cash)} />
        <Summary label="Продажи всего" value={rubles.format(summary.total)} />
      </div>
      {notice ? <p className="rounded-md bg-emerald-50 px-4 py-3 text-sm font-bold text-good">{notice}</p> : null}

      <div className={`grid gap-5 ${editor || reopenRow ? "2xl:grid-cols-[minmax(0,1fr)_420px]" : ""}`}>
        <Panel className="min-w-0">
          <div className="border-b border-line p-4"><h2 className="font-black text-ink">Сверка за {formatDate(selectedDate)}</h2><p className="mt-1 text-xs font-semibold text-muted">После закрытия заказы и складские значения этого водителя за день нельзя изменить.</p></div>
          <div className="overflow-x-auto">
            <table className="min-w-[1260px] text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-[0.08em] text-muted"><tr><th className="border-b border-line px-4 py-3">Водитель</th><th className="border-b border-line px-3 py-3">Маршрут</th><th className="border-b border-line px-3 py-3">Деньги по системе</th><th className="border-b border-line px-3 py-3">Остатки</th><th className="border-b border-line px-3 py-3">Расхождение</th><th className="border-b border-line px-3 py-3">Состояние</th><th className="border-b border-line px-4 py-3" /></tr></thead>
              <tbody>{rows.map((row) => <tr className="align-top hover:bg-slate-50" key={row.courier_id}>
                <td className="border-b border-line px-4 py-4"><div className="font-black text-ink">{row.courier_name}</div><div className="mt-1 text-xs font-bold text-muted">{row.vehicle_plate ?? "Машина не назначена"}</div></td>
                <td className="border-b border-line px-3 py-4"><div className="font-black text-ink">{row.delivered_orders} доставлено</div><div className="mt-1 text-xs font-semibold text-muted">{row.active_orders} активных · {row.failed_orders} не выполнено</div></td>
                <td className="border-b border-line px-3 py-4"><div className="font-black text-ink">{rubles.format(row.expected_total)}</div><div className="mt-1 text-xs font-semibold text-muted">наличные {rubles.format(row.expected_cash)}</div></td>
                <td className="border-b border-line px-3 py-4"><div className="font-black text-ink">Полных: {row.inventory_configured ? row.expected_full_bottles : "—"}</div><div className="mt-1 font-bold text-muted">Тары: {row.inventory_configured ? row.expected_empty_bottles : "—"}</div></td>
                <td className="border-b border-line px-3 py-4">{row.status === "closed" ? <div className="grid gap-1"><Difference label="Наличные" value={row.cash_difference} /><Difference label="Безнал" value={row.non_cash_difference} /><Difference label="Полные" value={row.full_difference} /><Difference label="Тара" value={row.empty_difference} /></div> : <span className="text-muted">После пересчёта</span>}</td>
                <td className="border-b border-line px-3 py-4"><Readiness row={row} /></td>
                <td className="border-b border-line px-4 py-4 text-right">{row.status === "closed" ? canReopen ? <button className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand" onClick={() => { setReopenRow(row); setEditor(null); setError(null); }} type="button">Открыть повторно</button> : null : row.readiness === "ready" ? <button className="rounded-md bg-brand px-3 py-2 text-xs font-black text-white hover:bg-brandDark" onClick={() => openEditor(row)} type="button">Сверить и закрыть</button> : row.readiness === "inventory_missing" ? <Link className="text-xs font-black text-brand hover:underline" href={`/couriers?date=${selectedDate}`}>Заполнить загрузку</Link> : <span className="text-xs font-bold text-muted">Завершите заказы</span>}</td>
              </tr>)}</tbody>
            </table>
          </div>
        </Panel>

        {editor && selectedRow ? <Panel className="h-fit 2xl:sticky 2xl:top-5"><div className="border-b border-line p-4"><h2 className="font-black text-ink">Фактическая сдача</h2><p className="mt-1 text-sm font-bold text-ink">{selectedRow.courier_name}</p></div><div className="grid gap-4 p-4">
          <div className="grid grid-cols-2 gap-3"><MoneyField label="Наличка" value={editor.actualCash} onChange={(value) => setEditor({ ...editor, actualCash: value })} /><MoneyField label="Терминал" value={editor.actualCard} onChange={(value) => setEditor({ ...editor, actualCard: value })} /><MoneyField label="QR-код" value={editor.actualQr} onChange={(value) => setEditor({ ...editor, actualQr: value })} /><MoneyField label="Онлайн" value={editor.actualOnline} onChange={(value) => setEditor({ ...editor, actualOnline: value })} /><MoneyField label="Договор" value={editor.actualContract} onChange={(value) => setEditor({ ...editor, actualContract: value })} /></div>
          <div className="grid grid-cols-2 gap-3"><NumberField label="Полных в машине" value={editor.actualFullBottles} onChange={(value) => setEditor({ ...editor, actualFullBottles: value })} /><NumberField label="Тары в машине" value={editor.actualEmptyBottles} onChange={(value) => setEditor({ ...editor, actualEmptyBottles: value })} /><MoneyField label="Пробег на старте" value={editor.startMileage} onChange={(value) => setEditor({ ...editor, startMileage: value })} /><MoneyField label="Пробег в конце" value={editor.endMileage} onChange={(value) => setEditor({ ...editor, endMileage: value })} /></div>
          <div className="rounded-md bg-slate-50 p-3"><div className="text-xs font-black uppercase tracking-[0.08em] text-muted">Расхождение</div><div className="mt-2 grid grid-cols-2 gap-2 text-sm"><Difference label="Наличка" value={preview?.cash ?? null} /><Difference label="Безнал" value={preview?.nonCash ?? null} /><Difference label="Полные" value={preview?.full ?? null} /><Difference label="Тара" value={preview?.empty ?? null} /></div></div>
          <TextArea label="Причина расхождения" placeholder="Обязательно, если любое значение не совпадает" value={editor.discrepancyReason} onChange={(value) => setEditor({ ...editor, discrepancyReason: value })} /><TextArea label="Комментарий смены" placeholder="Дополнительные сведения" value={editor.notes} onChange={(value) => setEditor({ ...editor, notes: value })} />
          {error ? <p className="rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</p> : null}
          <div className="flex gap-2"><button className="flex-1 rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white disabled:opacity-50" disabled={isPending} onClick={submitClose} type="button">{isPending ? "Закрываем…" : "Закрыть смену"}</button><button className="rounded-md border border-line px-4 py-2.5 text-sm font-black" disabled={isPending} onClick={() => setEditor(null)} type="button">Отмена</button></div>
        </div></Panel> : null}

        {reopenRow ? <Panel className="h-fit 2xl:sticky 2xl:top-5"><div className="border-b border-line p-4"><h2 className="font-black text-ink">Повторное открытие</h2><p className="mt-1 text-sm font-bold">{reopenRow.courier_name}</p></div><div className="p-4"><p className="text-sm font-semibold leading-relaxed text-muted">После открытия заказы и остатки снова можно изменять. Действие сохранится в журнале контроля.</p><TextArea label="Причина" placeholder="Почему требуется исправление закрытой смены" value={reopenReason} onChange={setReopenReason} />{error ? <p className="mt-3 rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</p> : null}<div className="mt-4 flex gap-2"><button className="flex-1 rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white disabled:opacity-50" disabled={isPending} onClick={submitReopen} type="button">Открыть смену</button><button className="rounded-md border border-line px-4 py-2.5 text-sm font-black" onClick={() => setReopenRow(null)} type="button">Отмена</button></div></div></Panel> : null}
      </div>

      <MovementLedger rows={movements} />
    </div>
  );
}

function MovementLedger({ rows }: { rows: InventoryMovementRow[] }) { return <Panel><div className="border-b border-line p-4"><h2 className="font-black text-ink">Журнал движения бутылок и тары</h2><p className="mt-1 text-xs font-semibold text-muted">Плюс — поступило в машину, минус — выбыло из машины. Исправления не стирают предыдущие записи.</p></div><div className="overflow-x-auto"><table className="min-w-[920px] text-left text-sm"><thead className="bg-slate-50 text-xs uppercase tracking-[0.08em] text-muted"><tr><th className="border-b border-line px-4 py-3">Время</th><th className="border-b border-line px-3 py-3">Водитель / машина</th><th className="border-b border-line px-3 py-3">Операция</th><th className="border-b border-line px-3 py-3">Полные</th><th className="border-b border-line px-3 py-3">Тара</th><th className="border-b border-line px-3 py-3">Основание</th><th className="border-b border-line px-4 py-3">Кто внёс</th></tr></thead><tbody>{rows.map((row) => <tr key={row.id}><td className="border-b border-line px-4 py-3 text-muted">{formatTime(row.created_at)}</td><td className="border-b border-line px-3 py-3"><div className="font-black">{row.courier_name}</div><div className="text-xs text-muted">{row.vehicle_plate ?? "Без машины"}</div></td><td className="border-b border-line px-3 py-3 font-bold">{movementLabel(row.event_type)}</td><DeltaCell value={row.full_bottles_delta} /><DeltaCell value={row.empty_bottles_delta} /><td className="border-b border-line px-3 py-3">{row.order_number ?? row.note ?? "Загрузка/выгрузка"}</td><td className="border-b border-line px-4 py-3 text-muted">{row.actor_name ?? "Водитель/система"}</td></tr>)}{rows.length === 0 ? <tr><td className="px-4 py-10 text-center font-semibold text-muted" colSpan={7}>Движений за этот день пока нет</td></tr> : null}</tbody></table></div></Panel>; }
function Summary({ label, value, tone = "ink" }: { label: string; value: string; tone?: "ink" | "good" | "warn" | "bad" }) { const colors = { ink: "text-ink", good: "text-good", warn: "text-warn", bad: "text-bad" }; return <Panel className="p-4"><div className="text-xs font-black uppercase tracking-[0.08em] text-muted">{label}</div><div className={`mt-2 text-2xl font-black ${colors[tone]}`}>{value}</div></Panel>; }
function Readiness({ row }: { row: ShiftReconciliationRow }) { if (row.status === "closed") return <StatusPill tone="good">Закрыта{row.was_reopened ? " после исправления" : ""}</StatusPill>; if (row.readiness === "ready") return <StatusPill tone="good">Готова</StatusPill>; if (row.readiness === "inventory_missing") return <StatusPill tone="bad">Нет загрузки</StatusPill>; return <StatusPill tone="warn">Есть активные заказы</StatusPill>; }
function Difference({ label, value }: { label: string; value: number | null }) { return <div className={`font-bold ${value === null ? "text-muted" : value === 0 ? "text-good" : "text-bad"}`}>{label}: {value === null ? "—" : value > 0 ? `+${value}` : value}</div>; }
function DeltaCell({ value }: { value: number }) { return <td className={`border-b border-line px-3 py-3 font-black ${value > 0 ? "text-good" : value < 0 ? "text-bad" : "text-muted"}`}>{value > 0 ? `+${value}` : value}</td>; }
function MoneyField({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) { return <label className="grid gap-1 text-xs font-black text-ink">{label}<input className="focus-ring rounded-md border border-line bg-white px-3 py-2 text-sm font-bold" min="0" onChange={(event) => onChange(event.target.value)} step="0.01" type="number" value={value} /></label>; }
function NumberField({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) { return <label className="grid gap-1 text-xs font-black text-ink">{label}<input className="focus-ring rounded-md border border-line bg-white px-3 py-2 text-sm font-bold" min="0" onChange={(event) => onChange(event.target.value)} step="1" type="number" value={value} /></label>; }
function TextArea({ label, placeholder, value, onChange }: { label: string; placeholder: string; value: string; onChange: (value: string) => void }) { return <label className="mt-3 grid gap-1.5 text-sm font-black text-ink">{label}<textarea className="focus-ring min-h-20 resize-y rounded-md border border-line bg-white p-3 text-sm font-semibold" maxLength={2000} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} value={value} /></label>; }
function validNumber(value: string) { const parsed = Number(value); return value.trim() !== "" && Number.isFinite(parsed) && parsed >= 0; }
function numberValue(value: string) { const parsed = Number(value); return Number.isFinite(parsed) ? parsed : 0; }
function optionalNumber(value: string) { return value.trim() === "" ? null : numberValue(value); }
function movementLabel(value: InventoryMovementRow["event_type"]) { return value === "dispatcher_inventory" ? "Загрузка/выгрузка" : value === "delivery" ? "Доставка клиенту" : value === "delivery_correction" ? "Корректировка доставки" : value === "shift_close" ? "Закрытие смены" : "Ручная корректировка"; }
function formatDate(value: string) { return new Intl.DateTimeFormat("ru-RU", { dateStyle: "long", timeZone: "Europe/Moscow" }).format(new Date(`${value}T12:00:00+03:00`)); }
function formatTime(value: string) { return new Intl.DateTimeFormat("ru-RU", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Moscow" }).format(new Date(value)); }
