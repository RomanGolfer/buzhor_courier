"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Panel, StatusPill } from "@/components/ui";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type {
  Courier,
  VehicleAssignmentHistoryRow,
  VehicleFleetRow,
  VehicleServiceStatus
} from "@/lib/types";

type VehicleEditor = {
  id: string | null;
  licensePlate: string;
  make: string;
  model: string;
  color: string;
  serviceStatus: VehicleServiceStatus;
  notes: string;
};

const emptyEditor: VehicleEditor = {
  id: null,
  licensePlate: "",
  make: "",
  model: "",
  color: "",
  serviceStatus: "ready",
  notes: ""
};

const serviceStatusLabels: Record<VehicleServiceStatus, string> = {
  ready: "Готов к работе",
  maintenance: "На обслуживании",
  inactive: "Выведен из эксплуатации"
};

export function VehicleFleetManager({
  initialVehicles,
  initialHistory,
  couriers,
  canManageRegistry
}: {
  initialVehicles: VehicleFleetRow[];
  initialHistory: VehicleAssignmentHistoryRow[];
  couriers: Courier[];
  canManageRegistry: boolean;
}) {
  const router = useRouter();
  const [vehicles, setVehicles] = useState(initialVehicles);
  const [history, setHistory] = useState(initialHistory);
  const [editor, setEditor] = useState<VehicleEditor | null>(null);
  const [busyVehicleId, setBusyVehicleId] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const summary = useMemo(() => ({
    assigned: vehicles.filter((vehicle) => vehicle.current_courier_id).length,
    available: vehicles.filter((vehicle) => vehicle.service_status === "ready" && !vehicle.current_courier_id).length,
    maintenance: vehicles.filter((vehicle) => vehicle.service_status === "maintenance").length,
    inactive: vehicles.filter((vehicle) => vehicle.service_status === "inactive").length
  }), [vehicles]);

  function startCreate() {
    if (!canManageRegistry) return;
    setEditor({ ...emptyEditor });
    setNotice(null);
    setError(null);
  }

  function startEdit(vehicle: VehicleFleetRow) {
    if (!canManageRegistry) return;
    setEditor({
      id: vehicle.id,
      licensePlate: vehicle.license_plate,
      make: vehicle.make ?? "",
      model: vehicle.model ?? "",
      color: vehicle.color ?? "",
      serviceStatus: vehicle.service_status,
      notes: vehicle.notes ?? ""
    });
    setNotice(null);
    setError(null);
  }

  async function refreshData() {
    const supabase = createBrowserSupabaseClient();
    const [fleetResult, historyResult] = await Promise.all([
      supabase.rpc("list_vehicle_fleet"),
      supabase.rpc("list_vehicle_assignment_history", { p_limit: 100, p_vehicle_id: null })
    ]);

    if (fleetResult.error) throw fleetResult.error;
    if (historyResult.error) throw historyResult.error;
    setVehicles((fleetResult.data ?? []) as VehicleFleetRow[]);
    setHistory((historyResult.data ?? []) as VehicleAssignmentHistoryRow[]);
  }

  async function saveVehicle() {
    if (!canManageRegistry || !editor) return;
    const normalizedPlate = normalizeLicensePlate(editor.licensePlate);
    if (normalizedPlate.length < 5 || normalizedPlate.length > 15) {
      setError("Введите корректный государственный номер автомобиля.");
      return;
    }
    if (
      editor.id
      && editor.serviceStatus !== "ready"
      && vehicles.find((vehicle) => vehicle.id === editor.id)?.current_courier_id
      && !window.confirm("При переводе машины на обслуживание или выводе из эксплуатации текущий водитель будет автоматически снят. Продолжить?")
    ) {
      return;
    }

    setIsSaving(true);
    setNotice(null);
    setError(null);
    const supabase = createBrowserSupabaseClient();
    const { error: saveError } = await supabase.rpc("save_vehicle", {
      p_color: editor.color,
      p_id: editor.id,
      p_license_plate: editor.licensePlate,
      p_make: editor.make,
      p_model: editor.model,
      p_notes: editor.notes,
      p_service_status: editor.serviceStatus
    });

    if (saveError) {
      console.warn("Vehicle save failed", saveError);
      setError(
        saveError.code === "23505"
          ? "Автомобиль с таким государственным номером уже есть в базе."
          : saveError.message.includes("invalid_vehicle_license_plate")
            ? "Введите корректный государственный номер автомобиля."
            : "Не удалось сохранить автомобиль. Попробуйте ещё раз."
      );
      setIsSaving(false);
      return;
    }

    try {
      await refreshData();
      router.refresh();
      setEditor(null);
      setNotice(editor.id ? "Карточка автомобиля обновлена" : "Автомобиль добавлен в автопарк");
    } catch (refreshError) {
      console.warn("Vehicle fleet refresh failed", refreshError);
      setError("Автомобиль сохранён, но список не удалось обновить.");
    } finally {
      setIsSaving(false);
    }
  }

  async function changeAssignment(vehicle: VehicleFleetRow, courierId: string) {
    if (vehicle.service_status !== "ready" || busyVehicleId) return;
    if (courierId === (vehicle.current_courier_id ?? "")) return;
    const courier = couriers.find((candidate) => candidate.id === courierId);
    if (
      vehicle.current_courier_name
      && courier
      && !window.confirm(`Переназначить ${vehicle.license_plate}: ${vehicle.current_courier_name} → ${courier.display_name}?`)
    ) {
      return;
    }

    setBusyVehicleId(vehicle.id);
    setNotice(null);
    setError(null);
    const supabase = createBrowserSupabaseClient();
    const result = courierId
      ? await supabase.rpc("assign_vehicle", {
          p_courier_id: courierId,
          p_note: null,
          p_vehicle_id: vehicle.id
        })
      : await supabase.rpc("release_vehicle", {
          p_note: null,
          p_vehicle_id: vehicle.id
        });

    if (result.error) {
      console.warn("Vehicle assignment failed", result.error);
      setError(
        result.error.message.includes("vehicle_not_ready")
          ? "Эта машина сейчас недоступна для назначения."
          : result.error.message.includes("active_courier_not_found")
            ? "Выбранный водитель выключен или больше недоступен."
            : "Не удалось изменить назначение автомобиля."
      );
      setBusyVehicleId(null);
      return;
    }

    try {
      await refreshData();
      router.refresh();
      setNotice(courier ? `${vehicle.license_plate} назначен водителю ${courier.display_name}` : `${vehicle.license_plate} освобождён`);
    } catch (refreshError) {
      console.warn("Vehicle assignment refresh failed", refreshError);
      setError("Назначение сохранено, но список не удалось обновить.");
    } finally {
      setBusyVehicleId(null);
    }
  }

  return (
    <div className="grid gap-5">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <SummaryCard label="Свободны" value={summary.available} tone="good" />
        <SummaryCard label="На линии" value={summary.assigned} tone="brand" />
        <SummaryCard label="На обслуживании" value={summary.maintenance} tone="warn" />
        <SummaryCard label="Выведены" value={summary.inactive} tone="muted" />
      </div>

      <div className={`grid gap-5 ${editor ? "xl:grid-cols-[minmax(0,1fr)_380px]" : ""}`}>
        <Panel>
          <div className="flex flex-col justify-between gap-3 border-b border-line p-4 sm:flex-row sm:items-center">
            <div>
              <h2 className="font-black text-ink">Автопарк</h2>
              <p className="mt-1 text-xs font-semibold text-muted">Госномер уникален; водитель может быть назначен только на одну машину.</p>
            </div>
            {canManageRegistry ? (
              <button className="rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white hover:bg-brandDark" onClick={startCreate} type="button">
                Добавить автомобиль
              </button>
            ) : null}
          </div>

          {notice ? <p className="m-4 rounded-md bg-emerald-50 px-3 py-2 text-sm font-semibold text-good">{notice}</p> : null}
          {error ? <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm font-semibold text-bad">{error}</p> : null}

          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-[0.12em] text-muted">
                <tr>
                  <th className="border-b border-line px-4 py-3">Госномер</th>
                  <th className="border-b border-line px-4 py-3">Автомобиль</th>
                  <th className="border-b border-line px-4 py-3">Состояние</th>
                  <th className="border-b border-line px-4 py-3">Водитель</th>
                  <th className="border-b border-line px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {vehicles.map((vehicle) => (
                  <tr className="hover:bg-slate-50" key={vehicle.id}>
                    <td className="border-b border-line px-4 py-4">
                      <div className="inline-flex rounded border-2 border-ink bg-white px-3 py-1.5 font-black tracking-[0.14em] text-ink">
                        {vehicle.license_plate}
                      </div>
                      {vehicle.color ? <div className="mt-1 text-xs font-semibold text-muted">{vehicle.color}</div> : null}
                    </td>
                    <td className="border-b border-line px-4 py-4">
                      <div className="font-bold text-ink">{vehicleName(vehicle)}</div>
                      {vehicle.notes ? <div className="mt-1 max-w-xs text-xs font-semibold text-muted">{vehicle.notes}</div> : null}
                    </td>
                    <td className="border-b border-line px-4 py-4">
                      <VehicleStatus vehicle={vehicle} />
                    </td>
                    <td className="min-w-64 border-b border-line px-4 py-4">
                      <select
                        className="focus-ring w-full rounded-md border border-line bg-white px-3 py-2 text-sm font-bold disabled:bg-slate-100 disabled:text-muted"
                        disabled={vehicle.service_status !== "ready" || Boolean(busyVehicleId)}
                        onChange={(event) => void changeAssignment(vehicle, event.target.value)}
                        value={vehicle.current_courier_id ?? ""}
                      >
                        <option value="">Не назначен</option>
                        {vehicle.current_courier_id && !couriers.some((courier) => courier.id === vehicle.current_courier_id) ? (
                          <option value={vehicle.current_courier_id}>{vehicle.current_courier_name ?? "Текущий водитель"}</option>
                        ) : null}
                        {couriers.map((courier) => (
                          <option key={courier.id} value={courier.id}>{courier.display_name}</option>
                        ))}
                      </select>
                      {vehicle.assigned_at ? <div className="mt-1 text-xs font-semibold text-muted">с {formatDateTime(vehicle.assigned_at)}</div> : null}
                    </td>
                    <td className="border-b border-line px-4 py-4 text-right">
                      {canManageRegistry ? (
                        <button className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand hover:text-brand" onClick={() => startEdit(vehicle)} type="button">
                          Изменить
                        </button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {vehicles.length === 0 ? (
            <div className="p-8 text-center">
              <p className="font-black text-ink">Автомобили пока не добавлены</p>
              <p className="mt-2 text-sm font-semibold text-muted">Добавьте реальные государственные номера машин, которые есть в наличии.</p>
              {canManageRegistry ? (
                <button className="mt-4 rounded-md bg-brand px-4 py-2.5 text-sm font-black text-white hover:bg-brandDark" onClick={startCreate} type="button">
                  Добавить первый автомобиль
                </button>
              ) : null}
            </div>
          ) : null}
        </Panel>

        {editor ? (
          <VehicleEditorPanel
            editor={editor}
            isSaving={isSaving}
            onCancel={() => setEditor(null)}
            onChange={setEditor}
            onSave={() => void saveVehicle()}
          />
        ) : null}
      </div>

      <AssignmentHistory history={history} />
    </div>
  );
}

function VehicleEditorPanel({
  editor,
  isSaving,
  onChange,
  onCancel,
  onSave
}: {
  editor: VehicleEditor;
  isSaving: boolean;
  onChange: (editor: VehicleEditor) => void;
  onCancel: () => void;
  onSave: () => void;
}) {
  return (
    <Panel className="h-fit p-5 xl:sticky xl:top-6">
      <div>
        <div className="text-xs font-black uppercase tracking-[0.16em] text-muted">{editor.id ? "Карточка" : "Новый автомобиль"}</div>
        <h2 className="mt-1 text-xl font-black text-ink">{editor.licensePlate || "Государственный номер"}</h2>
      </div>
      <div className="mt-5 grid gap-4">
        <EditorField
          label="Госномер *"
          onChange={(value) => onChange({ ...editor, licensePlate: value.toUpperCase() })}
          placeholder="А123ВС123"
          value={editor.licensePlate}
        />
        <div className="grid grid-cols-2 gap-3">
          <EditorField label="Марка" onChange={(value) => onChange({ ...editor, make: value })} placeholder="ГАЗ" value={editor.make} />
          <EditorField label="Модель" onChange={(value) => onChange({ ...editor, model: value })} placeholder="Газель" value={editor.model} />
        </div>
        <EditorField label="Цвет" onChange={(value) => onChange({ ...editor, color: value })} placeholder="Белый" value={editor.color} />
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Техническое состояние</span>
          <select
            className="focus-ring w-full rounded-md border border-line bg-white px-3 py-3 text-sm"
            onChange={(event) => onChange({ ...editor, serviceStatus: event.target.value as VehicleServiceStatus })}
            value={editor.serviceStatus}
          >
            {Object.entries(serviceStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </label>
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Примечание</span>
          <textarea
            className="focus-ring min-h-24 w-full rounded-md border border-line px-3 py-3 text-sm"
            onChange={(event) => onChange({ ...editor, notes: event.target.value })}
            placeholder="Особенности, комплектность, обслуживание"
            value={editor.notes}
          />
        </label>
        <div className="grid grid-cols-2 gap-2">
          <button className="rounded-md border border-line px-4 py-3 text-sm font-black text-ink hover:border-brand" disabled={isSaving} onClick={onCancel} type="button">
            Отмена
          </button>
          <button className="rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:opacity-50" disabled={isSaving || normalizeLicensePlate(editor.licensePlate).length < 5} onClick={onSave} type="button">
            {isSaving ? "Сохраняем..." : "Сохранить"}
          </button>
        </div>
      </div>
    </Panel>
  );
}

function AssignmentHistory({ history }: { history: VehicleAssignmentHistoryRow[] }) {
  return (
    <Panel>
      <div className="border-b border-line p-4">
        <h2 className="font-black text-ink">История назначений</h2>
        <p className="mt-1 text-xs font-semibold text-muted">Кто, на какой машине и в какой период работал.</p>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase tracking-[0.12em] text-muted">
            <tr>
              <th className="border-b border-line px-4 py-3">Автомобиль</th>
              <th className="border-b border-line px-4 py-3">Водитель</th>
              <th className="border-b border-line px-4 py-3">Назначен</th>
              <th className="border-b border-line px-4 py-3">Освобождён</th>
              <th className="border-b border-line px-4 py-3">Причина</th>
            </tr>
          </thead>
          <tbody>
            {history.map((item) => (
              <tr className="hover:bg-slate-50" key={item.id}>
                <td className="border-b border-line px-4 py-3 font-black tracking-wide text-ink">{item.license_plate}</td>
                <td className="border-b border-line px-4 py-3 font-bold text-ink">{item.courier_name}</td>
                <td className="border-b border-line px-4 py-3 text-muted">
                  <div>{formatDateTime(item.assigned_at)}</div>
                  <div className="text-xs">{item.assigned_by_name ?? "система"}</div>
                </td>
                <td className="border-b border-line px-4 py-3 text-muted">
                  {item.released_at ? (
                    <><div>{formatDateTime(item.released_at)}</div><div className="text-xs">{item.released_by_name ?? "система"}</div></>
                  ) : <StatusPill tone="good">Сейчас на линии</StatusPill>}
                </td>
                <td className="border-b border-line px-4 py-3 text-xs font-semibold text-muted">{item.release_note ?? item.assignment_note ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {history.length === 0 ? <div className="p-6 text-sm font-semibold text-muted">История появится после первого назначения автомобиля.</div> : null}
    </Panel>
  );
}

function VehicleStatus({ vehicle }: { vehicle: VehicleFleetRow }) {
  if (vehicle.current_courier_id) return <StatusPill tone="good">На линии</StatusPill>;
  if (vehicle.service_status === "maintenance") return <StatusPill tone="warn">На обслуживании</StatusPill>;
  if (vehicle.service_status === "inactive") return <StatusPill tone="muted">Выведен</StatusPill>;
  return <StatusPill tone="good">Свободен</StatusPill>;
}

function SummaryCard({ label, value, tone }: { label: string; value: number; tone: "good" | "brand" | "warn" | "muted" }) {
  const colors = {
    good: "border-emerald-200 bg-emerald-50 text-good",
    brand: "border-blue-200 bg-blue-50 text-brand",
    warn: "border-amber-200 bg-amber-50 text-warn",
    muted: "border-line bg-slate-50 text-muted"
  };
  return (
    <div className={`border p-4 ${colors[tone]}`}>
      <div className="text-3xl font-black">{value}</div>
      <div className="mt-1 text-xs font-black uppercase tracking-[0.12em]">{label}</div>
    </div>
  );
}

function EditorField({ label, value, placeholder, onChange }: { label: string; value: string; placeholder?: string; onChange: (value: string) => void }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-bold text-ink">{label}</span>
      <input className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm" onChange={(event) => onChange(event.target.value)} placeholder={placeholder} value={value} />
    </label>
  );
}

function normalizeLicensePlate(value: string) {
  return value.toUpperCase().replace(/[^0-9A-ZА-Я]/g, "");
}

function vehicleName(vehicle: VehicleFleetRow) {
  return [vehicle.make, vehicle.model].filter(Boolean).join(" ") || "Марка и модель не указаны";
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Moscow",
    year: "numeric"
  }).format(new Date(value));
}
