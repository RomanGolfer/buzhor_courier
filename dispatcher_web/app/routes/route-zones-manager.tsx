"use client";

import dynamic from "next/dynamic";
import { useState } from "react";
import { Panel } from "@/components/ui";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { DeliveryZone, GeoJsonPolygon } from "@/lib/types";
import type { ZoneMapPoint } from "./route-zone-map";

const RouteZoneMap = dynamic(() => import("./route-zone-map").then((module) => module.RouteZoneMap), {
  loading: () => <div className="flex h-[620px] items-center justify-center bg-slate-100 text-sm font-bold text-muted">Загружаем карту...</div>,
  ssr: false
});

const zoneColors = ["#e8720c", "#15945b", "#2563eb", "#7c3aed", "#db2777", "#0891b2", "#ca8a04"];

type EditorState = {
  id: string | null;
  name: string;
  color: string;
  priority: number;
  isActive: boolean;
  customerOrderEnabled: boolean;
  points: ZoneMapPoint[];
};

export function RouteZonesManager({ initialZones }: { initialZones: DeliveryZone[] }) {
  const [zones, setZones] = useState(initialZones);
  const [editor, setEditor] = useState<EditorState | null>(() => initialZones[0] ? editorFromZone(initialZones[0]) : null);
  const [drawingEnabled, setDrawingEnabled] = useState(initialZones.length === 0);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function selectZone(zoneId: string) {
    const zone = zones.find((candidate) => candidate.id === zoneId);
    if (!zone) return;
    setEditor(editorFromZone(zone));
    setDrawingEnabled(false);
    setError(null);
    setNotice(null);
  }

  function createZone() {
    setEditor({
      id: null,
      name: `Маршрут ${zones.length + 1}`,
      color: zoneColors[zones.length % zoneColors.length],
      priority: Math.min(999, (zones.at(-1)?.priority ?? 90) + 10),
      isActive: true,
      customerOrderEnabled: true,
      points: []
    });
    setDrawingEnabled(true);
    setError(null);
    setNotice(null);
  }

  async function saveZone() {
    if (!editor) return;
    const name = editor.name.trim();
    if (!name) {
      setError("Введите название маршрута");
      return;
    }
    if (editor.points.length < 3) {
      setError("Поставьте на карте минимум три точки границы");
      return;
    }

    setIsSaving(true);
    setError(null);
    setNotice(null);

    const supabase = createBrowserSupabaseClient();
    const { data, error: saveError } = await supabase.rpc("save_delivery_zone", {
      p_boundary: pointsToBoundary(editor.points),
      p_color: editor.color,
      p_customer_order_enabled: editor.customerOrderEnabled,
      p_id: editor.id,
      p_is_active: editor.isActive,
      p_name: name,
      p_priority: editor.priority
    });

    if (saveError) {
      console.warn("Delivery zone save failed", saveError);
      setError(
        saveError.message.includes("invalid_delivery_zone_boundary")
          ? "Граница пересекает сама себя или содержит ошибку. Передвиньте точки и сохраните снова."
          : "Не удалось сохранить маршрут. Попробуйте ещё раз."
      );
      setIsSaving(false);
      return;
    }

    const refreshedZones = await loadZones();
    if (!refreshedZones) {
      setError("Маршрут сохранён, но список не удалось обновить");
      setIsSaving(false);
      return;
    }

    setZones(refreshedZones);
    const savedZone = refreshedZones.find((zone) => zone.id === data);
    if (savedZone) setEditor(editorFromZone(savedZone));
    setDrawingEnabled(false);
    setNotice("Границы маршрута сохранены");
    setIsSaving(false);
  }

  async function deleteZone() {
    if (!editor?.id) return;
    if (!window.confirm(`Удалить маршрут «${editor.name}»? Заказы останутся в системе без этой привязки.`)) return;

    setIsSaving(true);
    setError(null);
    setNotice(null);
    const supabase = createBrowserSupabaseClient();
    const { error: deleteError } = await supabase.from("delivery_zones").delete().eq("id", editor.id);
    if (deleteError) {
      console.warn("Delivery zone delete failed", deleteError);
      setError("Не удалось удалить маршрут");
      setIsSaving(false);
      return;
    }

    const refreshedZones = (await loadZones()) ?? zones.filter((zone) => zone.id !== editor.id);
    setZones(refreshedZones);
    setEditor(refreshedZones[0] ? editorFromZone(refreshedZones[0]) : null);
    setDrawingEnabled(false);
    setNotice("Маршрут удалён");
    setIsSaving(false);
  }

  async function loadZones() {
    const supabase = createBrowserSupabaseClient();
    const { data, error: loadError } = await supabase.rpc("list_delivery_zones");
    if (loadError) {
      console.warn("Delivery zones reload failed", loadError);
      return null;
    }
    return (data ?? []) as DeliveryZone[];
  }

  return (
    <div className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
      <div className="grid content-start gap-4">
        <Panel className="p-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="font-black text-ink">Зоны обслуживания</h2>
              <p className="mt-1 text-xs font-semibold text-muted">Приоритет определяет выбор, если зоны пересекаются.</p>
            </div>
            <button className="rounded-md bg-brand px-3 py-2 text-xs font-black text-white hover:bg-brandDark" onClick={createZone} type="button">
              Новая
            </button>
          </div>

          <div className="mt-4 grid max-h-64 gap-2 overflow-y-auto pr-1 app-scrollbar">
            {zones.length === 0 ? (
              <button className="rounded-md border border-dashed border-brand/50 bg-brand/5 px-4 py-5 text-left text-sm font-bold text-brand" onClick={createZone} type="button">
                Создайте первую зону и отметьте её границы на карте
              </button>
            ) : (
              zones.map((zone) => (
                <button
                  className={`flex items-center gap-3 rounded-md border px-3 py-3 text-left transition ${
                    editor?.id === zone.id ? "border-brand bg-brand/5" : "border-line hover:border-brand/50"
                  }`}
                  key={zone.id}
                  onClick={() => selectZone(zone.id)}
                  type="button"
                >
                  <span className="size-4 shrink-0 rounded-full" style={{ backgroundColor: zone.color }} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-black text-ink">{zone.name}</span>
                    <span className="block text-xs font-semibold text-muted">
                      {zone.is_active ? "Активна" : "Выключена"} · приоритет {zone.priority}
                    </span>
                  </span>
                </button>
              ))
            )}
          </div>
        </Panel>

        {editor ? (
          <Panel className="grid gap-4 p-4">
            <label className="block">
              <span className="mb-1 block text-sm font-bold text-ink">Название маршрута</span>
              <input
                className="focus-ring w-full rounded-md border border-line px-3 py-2.5 text-sm"
                maxLength={80}
                onChange={(event) => setEditor({ ...editor, name: event.target.value })}
                value={editor.name}
              />
            </label>

            <div className="grid grid-cols-[1fr_92px] gap-3">
              <label className="block">
                <span className="mb-1 block text-sm font-bold text-ink">Цвет</span>
                <div className="flex gap-1.5">
                  {zoneColors.slice(0, 5).map((color) => (
                    <button
                      aria-label={`Цвет ${color}`}
                      className={`size-8 rounded-full border-2 ${editor.color === color ? "border-ink" : "border-white"}`}
                      key={color}
                      onClick={() => setEditor({ ...editor, color })}
                      style={{ backgroundColor: color }}
                      type="button"
                    />
                  ))}
                </div>
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-bold text-ink">Приоритет</span>
                <input
                  className="focus-ring w-full rounded-md border border-line px-3 py-2 text-sm"
                  max={999}
                  min={0}
                  onChange={(event) => setEditor({ ...editor, priority: Number(event.target.value) })}
                  type="number"
                  value={editor.priority}
                />
              </label>
            </div>

            <label className="flex items-start gap-3 rounded-md border border-line p-3">
              <input
                checked={editor.isActive}
                className="mt-0.5 size-4 accent-brand"
                onChange={(event) => setEditor({ ...editor, isActive: event.target.checked })}
                type="checkbox"
              />
              <span>
                <span className="block text-sm font-black text-ink">Активная зона</span>
                <span className="block text-xs font-semibold text-muted">Использовать для автоматической привязки заказов</span>
              </span>
            </label>

            <label className="flex items-start gap-3 rounded-md border border-line p-3">
              <input
                checked={editor.customerOrderEnabled}
                className="mt-0.5 size-4 accent-brand"
                onChange={(event) => setEditor({ ...editor, customerOrderEnabled: event.target.checked })}
                type="checkbox"
              />
              <span>
                <span className="block text-sm font-black text-ink">Принимать заказы клиентов</span>
                <span className="block text-xs font-semibold text-muted">Адрес внутри этой зоны доступен в клиентской форме</span>
              </span>
            </label>

            <div className="rounded-md bg-slate-50 p-3 text-xs font-semibold text-muted">
              Точек границы: <strong className="text-ink">{editor.points.length}</strong>. Включите рисование и кликайте по карте. Уже поставленные точки можно перетаскивать.
            </div>

            <div className="grid grid-cols-2 gap-2">
              <button
                className={`rounded-md border px-3 py-2 text-xs font-black ${drawingEnabled ? "border-brand bg-brand text-white" : "border-line text-ink hover:border-brand"}`}
                onClick={() => setDrawingEnabled((value) => !value)}
                type="button"
              >
                {drawingEnabled ? "Рисование включено" : "Добавлять точки"}
              </button>
              <button
                className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand"
                disabled={editor.points.length === 0}
                onClick={() => setEditor({ ...editor, points: editor.points.slice(0, -1) })}
                type="button"
              >
                Убрать последнюю
              </button>
              <button
                className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand"
                disabled={editor.points.length === 0}
                onClick={() => setEditor({ ...editor, points: [] })}
                type="button"
              >
                Очистить границу
              </button>
              {editor.id ? (
                <button className="rounded-md border border-red-200 px-3 py-2 text-xs font-black text-bad hover:bg-red-50" disabled={isSaving} onClick={deleteZone} type="button">
                  Удалить
                </button>
              ) : <span />}
            </div>

            {error ? <p className="rounded-md bg-red-50 px-3 py-2 text-sm font-semibold text-bad">{error}</p> : null}
            {notice ? <p className="rounded-md bg-emerald-50 px-3 py-2 text-sm font-semibold text-good">{notice}</p> : null}

            <button
              className="rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:opacity-50"
              disabled={isSaving || editor.points.length < 3 || !editor.name.trim()}
              onClick={saveZone}
              type="button"
            >
              {isSaving ? "Сохраняем..." : "Сохранить маршрут"}
            </button>
          </Panel>
        ) : null}
      </div>

      <Panel className="relative overflow-hidden">
        <RouteZoneMap
          drawingEnabled={drawingEnabled && Boolean(editor)}
          editingZoneId={editor?.id ?? null}
          onAddPoint={(point) => editor && setEditor({ ...editor, points: [...editor.points, point] })}
          onMovePoint={(index, point) => {
            if (!editor) return;
            const points = editor.points.map((candidate, candidateIndex) => candidateIndex === index ? point : candidate);
            setEditor({ ...editor, points });
          }}
          onSelectZone={selectZone}
          points={editor?.points ?? []}
          zones={zones}
        />
        {drawingEnabled ? (
          <div className="pointer-events-none absolute left-1/2 top-4 z-[500] -translate-x-1/2 rounded-full bg-ink/90 px-4 py-2 text-xs font-black text-white shadow-panel">
            Кликайте по карте, чтобы поставить точки границы
          </div>
        ) : null}
      </Panel>
    </div>
  );
}

function editorFromZone(zone: DeliveryZone): EditorState {
  return {
    id: zone.id,
    name: zone.name,
    color: zone.color,
    priority: zone.priority,
    isActive: zone.is_active,
    customerOrderEnabled: zone.customer_order_enabled,
    points: boundaryToPoints(zone.boundary)
  };
}

function boundaryToPoints(boundary: GeoJsonPolygon): ZoneMapPoint[] {
  const ring = boundary?.coordinates?.[0] ?? [];
  const points = ring.flatMap((coordinate): ZoneMapPoint[] => {
    const [lng, lat] = coordinate;
    return Number.isFinite(lat) && Number.isFinite(lng) ? [{ lat, lng }] : [];
  });

  if (points.length > 1 && samePoint(points[0], points.at(-1)!)) points.pop();
  return points;
}

function pointsToBoundary(points: ZoneMapPoint[]): GeoJsonPolygon {
  const ring = points.map((point) => [point.lng, point.lat]);
  return {
    type: "Polygon",
    coordinates: [[...ring, ring[0]]]
  };
}

function samePoint(left: ZoneMapPoint, right: ZoneMapPoint) {
  return Math.abs(left.lat - right.lat) < 0.0000001 && Math.abs(left.lng - right.lng) < 0.0000001;
}
