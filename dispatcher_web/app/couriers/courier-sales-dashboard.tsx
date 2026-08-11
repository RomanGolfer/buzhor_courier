"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Panel, StatusPill } from "@/components/ui";
import type { CourierDailySalesRow } from "@/lib/types";
import { saveCourierInventory } from "./actions";

type InventoryEditor = {
  courierId: string;
  loadedFullBottles: string;
  openingEmptyBottles: string;
  unloadedFullBottles: string;
  unloadedEmptyBottles: string;
  notes: string;
};

const moneyFormatter = new Intl.NumberFormat("ru-RU", {
  currency: "RUB",
  maximumFractionDigits: 0,
  style: "currency"
});

export function CourierSalesDashboard({
  rows,
  selectedDate
}: {
  rows: CourierDailySalesRow[];
  selectedDate: string;
}) {
  const router = useRouter();
  const [editor, setEditor] = useState<InventoryEditor | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const selectedCourier = editor ? rows.find((row) => row.courier_id === editor.courierId) ?? null : null;
  const summary = useMemo(
    () => ({
      deliveredOrders: rows.reduce((total, row) => total + row.delivered_orders, 0),
      totalAmount: rows.reduce((total, row) => total + row.total_amount, 0),
      soldFullBottles: rows.reduce((total, row) => total + row.sold_full_bottles, 0),
      collectedEmptyBottles: rows.reduce((total, row) => total + row.collected_empty_bottles, 0),
      configuredVehicles: rows.filter((row) => row.inventory_configured).length
    }),
    [rows]
  );

  const preview = useMemo(() => {
    if (!editor || !selectedCourier) return null;
    const loadedFull = parseQuantity(editor.loadedFullBottles);
    const openingEmpty = parseQuantity(editor.openingEmptyBottles);
    const unloadedFull = parseQuantity(editor.unloadedFullBottles);
    const unloadedEmpty = parseQuantity(editor.unloadedEmptyBottles);
    if ([loadedFull, openingEmpty, unloadedFull, unloadedEmpty].some((value) => value === null)) return null;
    return {
      full: loadedFull! - selectedCourier.sold_full_bottles - unloadedFull!,
      empty: openingEmpty! + selectedCourier.collected_empty_bottles - unloadedEmpty!
    };
  }, [editor, selectedCourier]);

  function openEditor(row: CourierDailySalesRow) {
    setEditor({
      courierId: row.courier_id,
      loadedFullBottles: String(row.loaded_full_bottles),
      openingEmptyBottles: String(row.opening_empty_bottles),
      unloadedFullBottles: String(row.unloaded_full_bottles),
      unloadedEmptyBottles: String(row.unloaded_empty_bottles),
      notes: row.inventory_notes ?? ""
    });
    setNotice(null);
    setError(null);
  }

  function submitInventory() {
    if (!editor || !selectedCourier) return;
    const loadedFull = parseQuantity(editor.loadedFullBottles);
    const openingEmpty = parseQuantity(editor.openingEmptyBottles);
    const unloadedFull = parseQuantity(editor.unloadedFullBottles);
    const unloadedEmpty = parseQuantity(editor.unloadedEmptyBottles);
    if ([loadedFull, openingEmpty, unloadedFull, unloadedEmpty].some((value) => value === null)) {
      setError("Количество должно быть целым числом от 0 до 100000.");
      return;
    }

    setError(null);
    setNotice(null);
    startTransition(async () => {
      const result = await saveCourierInventory({
        courierId: editor.courierId,
        loadedFullBottles: loadedFull!,
        notes: editor.notes.trim(),
        openingEmptyBottles: openingEmpty!,
        unloadedEmptyBottles: unloadedEmpty!,
        unloadedFullBottles: unloadedFull!,
        workDate: selectedDate
      });
      if (!result.ok) {
        setError(result.error);
        return;
      }
      setEditor(null);
      setNotice(`Загрузка и остатки водителя ${selectedCourier.courier_name} сохранены.`);
      router.refresh();
    });
  }

  return (
    <div className="grid gap-5">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <SummaryCard label="Выполнено заказов" value={String(summary.deliveredOrders)} />
        <SummaryCard label="Продажи за день" value={formatMoney(summary.totalAmount)} />
        <SummaryCard label="Продано полных" value={String(summary.soldFullBottles)} />
        <SummaryCard label="Собрано тары" value={String(summary.collectedEmptyBottles)} />
        <SummaryCard label="Загрузка заполнена" value={`${summary.configuredVehicles} из ${rows.length}`} />
      </div>

      {notice ? <p className="rounded-md bg-emerald-50 px-4 py-3 text-sm font-bold text-good">{notice}</p> : null}
      {error && !editor ? <p className="rounded-md bg-red-50 px-4 py-3 text-sm font-bold text-bad">{error}</p> : null}

      <div className={`grid gap-5 ${editor ? "2xl:grid-cols-[minmax(0,1fr)_400px]" : ""}`}>
        <Panel>
          <div className="border-b border-line p-4">
            <h2 className="font-black text-ink">Водители за {formatDate(selectedDate)}</h2>
            <p className="mt-1 text-xs font-semibold text-muted">
              Суммы и количество заказов считаются по выполненным доставкам и подтверждённому водителем способу оплаты.
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-[1420px] text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-[0.1em] text-muted">
                <tr>
                  <th className="border-b border-line px-4 py-3">Водитель / машина</th>
                  <th className="border-b border-line px-3 py-3">Наличные</th>
                  <th className="border-b border-line px-3 py-3">Терминал</th>
                  <th className="border-b border-line px-3 py-3">QR-код</th>
                  <th className="border-b border-line px-3 py-3">Онлайн</th>
                  <th className="border-b border-line px-3 py-3">Договор</th>
                  <th className="border-b border-line px-3 py-3">Итого</th>
                  <th className="border-b border-line px-3 py-3">Бутылки / тара</th>
                  <th className="border-b border-line px-3 py-3">В машине</th>
                  <th className="border-b border-line px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr className="align-top hover:bg-slate-50" key={row.courier_id}>
                    <td className="border-b border-line px-4 py-4">
                      <div className="font-black text-ink">{row.courier_name}</div>
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-xs font-semibold text-muted">
                        {row.vehicle_plate ? <VehiclePlate plate={row.vehicle_plate} /> : <span>Машина не назначена</span>}
                        {!row.courier_active ? <StatusPill tone="muted">Выключен</StatusPill> : null}
                      </div>
                      <div className="mt-2 text-xs font-semibold text-muted">
                        В работе: {row.active_orders} · не выполнено: {row.failed_orders}
                      </div>
                    </td>
                    <PaymentCell amount={row.cash_amount} orders={row.cash_orders} />
                    <PaymentCell amount={row.card_amount} orders={row.card_orders} />
                    <PaymentCell amount={row.qr_amount} orders={row.qr_orders} />
                    <PaymentCell amount={row.online_amount} orders={row.online_orders} />
                    <PaymentCell amount={row.contract_amount} orders={row.contract_orders} />
                    <td className="border-b border-line px-3 py-4">
                      <div className="font-black text-ink">{formatMoney(row.total_amount)}</div>
                      <div className="mt-1 text-xs font-semibold text-muted">{ordersLabel(row.delivered_orders)}</div>
                    </td>
                    <td className="border-b border-line px-3 py-4">
                      <div className="font-black text-ink">Продано: {row.sold_full_bottles} полных</div>
                      <div className="mt-1 font-bold text-good">Собрано: {row.collected_empty_bottles} тары</div>
                    </td>
                    <td className="border-b border-line px-3 py-4">
                      {row.inventory_configured ? (
                        <div className="grid gap-1">
                          <Balance label="Полных" value={row.remaining_full_bottles ?? 0} />
                          <Balance label="Тары" value={row.remaining_empty_bottles ?? 0} />
                        </div>
                      ) : (
                        <StatusPill tone="warn">Заполните загрузку</StatusPill>
                      )}
                    </td>
                    <td className="border-b border-line px-4 py-4 text-right">
                      <button
                        className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand hover:text-brand"
                        onClick={() => openEditor(row)}
                        type="button"
                      >
                        Загрузка и остатки
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {rows.length === 0 ? (
            <div className="p-8 text-center">
              <p className="font-black text-ink">Водители пока не созданы</p>
              <p className="mt-2 text-sm font-semibold text-muted">После добавления профилей здесь появится дневная сводка.</p>
            </div>
          ) : null}
        </Panel>

        {editor && selectedCourier ? (
          <Panel className="h-fit 2xl:sticky 2xl:top-5">
            <div className="border-b border-line p-4">
              <h2 className="font-black text-ink">Загрузка и выгрузка</h2>
              <p className="mt-1 text-sm font-bold text-ink">{selectedCourier.courier_name}</p>
              <p className="mt-1 text-xs font-semibold text-muted">
                {formatDate(selectedDate)}{selectedCourier.vehicle_plate ? ` · ${selectedCourier.vehicle_plate}` : " · машина не назначена"}
              </p>
            </div>
            <div className="grid gap-4 p-4">
              <InventoryField
                help="Сколько полных бутылок выдано водителю перед рейсом"
                label="Полных загружено"
                onChange={(value) => setEditor({ ...editor, loadedFullBottles: value })}
                value={editor.loadedFullBottles}
              />
              <InventoryField
                help="Пустая тара, уже находившаяся в машине на начало дня"
                label="Тара на начало дня"
                onChange={(value) => setEditor({ ...editor, openingEmptyBottles: value })}
                value={editor.openingEmptyBottles}
              />
              <InventoryField
                help="Непроданные полные бутылки, возвращённые на склад"
                label="Полных выгружено"
                onChange={(value) => setEditor({ ...editor, unloadedFullBottles: value })}
                value={editor.unloadedFullBottles}
              />
              <InventoryField
                help="Пустая тара, принятая складом из машины"
                label="Тары выгружено"
                onChange={(value) => setEditor({ ...editor, unloadedEmptyBottles: value })}
                value={editor.unloadedEmptyBottles}
              />
              <label className="grid gap-1.5 text-sm font-black text-ink">
                Комментарий
                <textarea
                  className="focus-ring min-h-20 resize-y rounded-md border border-line px-3 py-2 text-sm font-semibold"
                  maxLength={500}
                  onChange={(event) => setEditor({ ...editor, notes: event.target.value })}
                  placeholder="Например: часть тары осталась у водителя"
                  value={editor.notes}
                />
              </label>

              <div className="rounded-md bg-slate-50 p-3">
                <div className="text-xs font-black uppercase tracking-[0.1em] text-muted">Расчётный остаток в машине</div>
                <div className="mt-3 grid grid-cols-2 gap-3">
                  <PreviewBalance label="Полных" value={preview?.full ?? null} />
                  <PreviewBalance label="Тары" value={preview?.empty ?? null} />
                </div>
                <p className="mt-3 text-xs font-semibold text-muted">
                  Уже реализовано: {selectedCourier.sold_full_bottles} полных · собрано: {selectedCourier.collected_empty_bottles} тары.
                </p>
              </div>

              {error ? <p className="rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</p> : null}

              <div className="flex gap-2">
                <button
                  className="flex-1 rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white hover:bg-brandDark disabled:cursor-wait disabled:opacity-60"
                  disabled={isPending}
                  onClick={submitInventory}
                  type="button"
                >
                  {isPending ? "Сохраняем…" : "Сохранить"}
                </button>
                <button
                  className="rounded-md border border-line px-4 py-2.5 text-sm font-black text-ink hover:border-brand disabled:opacity-60"
                  disabled={isPending}
                  onClick={() => {
                    setEditor(null);
                    setError(null);
                  }}
                  type="button"
                >
                  Отмена
                </button>
              </div>
            </div>
          </Panel>
        ) : null}
      </div>
    </div>
  );
}

function SummaryCard({ label, value }: { label: string; value: string }) {
  return (
    <Panel className="p-4">
      <div className="text-xs font-black uppercase tracking-[0.1em] text-muted">{label}</div>
      <div className="mt-2 text-2xl font-black text-ink">{value}</div>
    </Panel>
  );
}

function PaymentCell({ amount, orders }: { amount: number; orders: number }) {
  return (
    <td className="border-b border-line px-3 py-4">
      <div className="font-black text-ink">{formatMoney(amount)}</div>
      <div className="mt-1 text-xs font-semibold text-muted">{ordersLabel(orders)}</div>
    </td>
  );
}

function VehiclePlate({ plate }: { plate: string }) {
  return <span className="rounded border border-ink bg-white px-1.5 py-0.5 font-black tracking-[0.1em] text-ink">{plate}</span>;
}

function Balance({ label, value }: { label: string; value: number }) {
  return (
    <div className={`font-black ${value < 0 ? "text-bad" : "text-ink"}`}>
      {label}: {value}
      {value < 0 ? <span className="ml-1 text-xs">расхождение</span> : null}
    </div>
  );
}

function PreviewBalance({ label, value }: { label: string; value: number | null }) {
  return (
    <div>
      <div className="text-xs font-bold text-muted">{label}</div>
      <div className={`mt-1 text-xl font-black ${value !== null && value < 0 ? "text-bad" : "text-ink"}`}>{value ?? "—"}</div>
    </div>
  );
}

function InventoryField({
  help,
  label,
  onChange,
  value
}: {
  help: string;
  label: string;
  onChange: (value: string) => void;
  value: string;
}) {
  return (
    <label className="grid gap-1.5 text-sm font-black text-ink">
      {label}
      <input
        className="focus-ring rounded-md border border-line px-3 py-2 text-sm font-bold"
        inputMode="numeric"
        max={100000}
        min={0}
        onChange={(event) => onChange(event.target.value)}
        step={1}
        type="number"
        value={value}
      />
      <span className="text-xs font-semibold leading-relaxed text-muted">{help}</span>
    </label>
  );
}

function parseQuantity(value: string) {
  if (!/^\d+$/.test(value.trim())) return null;
  const quantity = Number(value);
  return Number.isSafeInteger(quantity) && quantity >= 0 && quantity <= 100000 ? quantity : null;
}

function formatMoney(value: number) {
  return moneyFormatter.format(value);
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("ru-RU", {
    day: "numeric",
    month: "long",
    timeZone: "Europe/Moscow",
    year: "numeric"
  }).format(new Date(`${value}T12:00:00+03:00`));
}

function ordersLabel(value: number) {
  const mod100 = value % 100;
  const mod10 = value % 10;
  const noun = mod100 >= 11 && mod100 <= 14 ? "заказов" : mod10 === 1 ? "заказ" : mod10 >= 2 && mod10 <= 4 ? "заказа" : "заказов";
  return `${value} ${noun}`;
}
