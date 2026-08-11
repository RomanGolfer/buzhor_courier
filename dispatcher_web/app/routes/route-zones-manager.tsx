"use client";

import dynamic from "next/dynamic";
import { useState } from "react";
import { Panel } from "@/components/ui";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type {
  DeliveryZone,
  DeliveryZoneLearningCandidate,
  DeliveryZoneLearningCandidateRow,
  GeoJsonPolygon
} from "@/lib/types";
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
  autoExpandEnabled: boolean;
  learningMinDeliveries: number;
  learningLookbackDays: number;
  learningMaxDistanceM: number;
  learningRadiusM: number;
  points: ZoneMapPoint[];
};

export function RouteZonesManager({
  initialZones,
  initialLearningCandidates,
  canManage
}: {
  initialZones: DeliveryZone[];
  initialLearningCandidates: DeliveryZoneLearningCandidate[];
  canManage: boolean;
}) {
  const [zones, setZones] = useState(initialZones);
  const [learningCandidates, setLearningCandidates] = useState(initialLearningCandidates);
  const [editor, setEditor] = useState<EditorState | null>(() => initialZones[0] ? editorFromZone(initialZones[0]) : null);
  const [drawingEnabled, setDrawingEnabled] = useState(canManage && initialZones.length === 0);
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
    if (!canManage) return;
    setEditor({
      id: null,
      name: `Маршрут ${zones.length + 1}`,
      color: zoneColors[zones.length % zoneColors.length],
      priority: Math.min(999, (zones.at(-1)?.priority ?? 90) + 10),
      isActive: true,
      customerOrderEnabled: true,
      autoExpandEnabled: true,
      learningMinDeliveries: 3,
      learningLookbackDays: 90,
      learningMaxDistanceM: 1000,
      learningRadiusM: 100,
      points: []
    });
    setDrawingEnabled(true);
    setError(null);
    setNotice(null);
  }

  async function saveZone() {
    if (!canManage || !editor) return;
    const name = editor.name.trim();
    if (!name) {
      setError("Введите название маршрута");
      return;
    }
    if (editor.points.length < 3) {
      setError("Поставьте на карте минимум три точки границы");
      return;
    }
    if (!learningSettingsAreValid(editor)) {
      setError("Проверьте настройки автокоррекции: доставки 2–20, период 7–365 дней, расстояние 100–5000 м, радиус 30–300 м.");
      return;
    }

    setIsSaving(true);
    setError(null);
    setNotice(null);

    const supabase = createBrowserSupabaseClient();
    const { data, error: saveError } = await supabase.rpc("save_delivery_zone", {
      p_boundary: pointsToBoundary(editor.points),
      p_auto_expand_enabled: editor.autoExpandEnabled,
      p_color: editor.color,
      p_customer_order_enabled: editor.customerOrderEnabled,
      p_id: editor.id,
      p_is_active: editor.isActive,
      p_learning_lookback_days: editor.learningLookbackDays,
      p_learning_max_distance_m: editor.learningMaxDistanceM,
      p_learning_min_deliveries: editor.learningMinDeliveries,
      p_learning_radius_m: editor.learningRadiusM,
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
    const refreshedCandidates = await loadLearningCandidates();
    if (refreshedCandidates) setLearningCandidates(refreshedCandidates);
    const savedZone = refreshedZones.find((zone) => zone.id === data);
    if (savedZone) setEditor(editorFromZone(savedZone));
    setDrawingEnabled(false);
    setNotice("Границы маршрута сохранены");
    setIsSaving(false);
  }

  async function deleteZone() {
    if (!canManage || !editor?.id) return;
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

    const [loadedZones, refreshedCandidates] = await Promise.all([loadZones(), loadLearningCandidates()]);
    const refreshedZones = loadedZones ?? zones.filter((zone) => zone.id !== editor.id);
    setZones(refreshedZones);
    if (refreshedCandidates) setLearningCandidates(refreshedCandidates);
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

  async function loadLearningCandidates() {
    const supabase = createBrowserSupabaseClient();
    const { data, error: loadError } = await supabase.rpc("list_delivery_zone_learning_candidates");
    if (loadError) {
      console.warn("Delivery zone learning candidates reload failed", loadError);
      return null;
    }
    return ((data ?? []) as DeliveryZoneLearningCandidateRow[]).map((candidate): DeliveryZoneLearningCandidate => ({
      ...candidate,
      lat: Number(candidate.lat),
      lng: Number(candidate.lng),
      distance_m: Number(candidate.distance_m)
    }));
  }

  async function runLearning() {
    if (!canManage) return;
    setIsSaving(true);
    setError(null);
    setNotice(null);
    const supabase = createBrowserSupabaseClient();
    const { data, error: learningError } = await supabase.rpc("run_delivery_zone_learning");
    if (learningError) {
      console.warn("Delivery zone learning refresh failed", learningError);
      setError("Не удалось пересчитать статистику маршрутов");
      setIsSaving(false);
      return;
    }
    const [refreshedZones, refreshedCandidates] = await Promise.all([loadZones(), loadLearningCandidates()]);
    if (refreshedZones) {
      setZones(refreshedZones);
      const refreshedEditor = editor?.id ? refreshedZones.find((zone) => zone.id === editor.id) : null;
      if (refreshedEditor) setEditor(editorFromZone(refreshedEditor));
    }
    if (refreshedCandidates) setLearningCandidates(refreshedCandidates);
    setNotice(`Статистика пересчитана. Проверено заказов: ${Number(data ?? 0)}.`);
    setIsSaving(false);
  }

  async function manageLearningCandidate(candidateId: string, action: "ignore" | "observe" | "revert") {
    if (!canManage) return;
    if (action === "revert" && !window.confirm("Откатить последнее автоматическое расширение этой зоны?")) return;
    setIsSaving(true);
    setError(null);
    setNotice(null);
    const supabase = createBrowserSupabaseClient();
    const { error: actionError } = await supabase.rpc("manage_delivery_zone_learning_candidate", {
      p_action: action,
      p_candidate_id: candidateId
    });
    if (actionError) {
      console.warn("Delivery zone learning action failed", actionError);
      setError(
        actionError.message.includes("only_latest") || actionError.message.includes("boundary_changed")
          ? "Откат возможен только для последнего автоизменения, если границу после него не редактировали вручную."
          : "Не удалось изменить решение автоматики"
      );
      setIsSaving(false);
      return;
    }
    const [refreshedZones, refreshedCandidates] = await Promise.all([loadZones(), loadLearningCandidates()]);
    if (refreshedZones) {
      setZones(refreshedZones);
      const refreshedEditor = editor?.id ? refreshedZones.find((zone) => zone.id === editor.id) : null;
      if (refreshedEditor) setEditor(editorFromZone(refreshedEditor));
    }
    if (refreshedCandidates) setLearningCandidates(refreshedCandidates);
    setNotice(action === "revert" ? "Автоматическое расширение отменено" : "Решение по адресу сохранено");
    setIsSaving(false);
  }

  const selectedLearningCandidates = editor?.id
    ? learningCandidates.filter((candidate) => candidate.zone_id === editor.id)
    : [];

  return (
    <div className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
      <div className="grid content-start gap-4">
        <Panel className="p-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="font-black text-ink">Зоны обслуживания</h2>
              <p className="mt-1 text-xs font-semibold text-muted">Приоритет определяет выбор, если зоны пересекаются.</p>
            </div>
            {canManage ? (
              <button className="rounded-md bg-brand px-3 py-2 text-xs font-black text-white hover:bg-brandDark" onClick={createZone} type="button">
                Новая
              </button>
            ) : null}
          </div>

          <div className="mt-4 grid max-h-64 gap-2 overflow-y-auto pr-1 app-scrollbar">
            {zones.length === 0 ? (
              canManage ? (
                <button className="rounded-md border border-dashed border-brand/50 bg-brand/5 px-4 py-5 text-left text-sm font-bold text-brand" onClick={createZone} type="button">
                  Создайте первую зону и отметьте её границы на карте
                </button>
              ) : (
                <div className="rounded-md border border-dashed border-line bg-slate-50 px-4 py-5 text-sm font-semibold text-muted">
                  Зоны ещё не настроены. Создать первую зону может администратор.
                </div>
              )
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
          canManage ? (
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

            <div className="rounded-md border border-line p-3">
              <label className="flex items-start gap-3">
                <input
                  checked={editor.autoExpandEnabled}
                  className="mt-0.5 size-4 accent-brand"
                  onChange={(event) => setEditor({ ...editor, autoExpandEnabled: event.target.checked })}
                  type="checkbox"
                />
                <span>
                  <span className="block text-sm font-black text-ink">Автокоррекция по статистике</span>
                  <span className="block text-xs font-semibold text-muted">
                    Расширять границу, если рядом несколько раз успешно доставили на новый адрес
                  </span>
                </span>
              </label>

              {editor.autoExpandEnabled ? (
                <div className="mt-4 grid grid-cols-2 gap-3">
                  <LearningNumberInput
                    label="Доставок для включения"
                    max={20}
                    min={2}
                    onChange={(value) => setEditor({ ...editor, learningMinDeliveries: value })}
                    value={editor.learningMinDeliveries}
                  />
                  <LearningNumberInput
                    label="Период, дней"
                    max={365}
                    min={7}
                    onChange={(value) => setEditor({ ...editor, learningLookbackDays: value })}
                    value={editor.learningLookbackDays}
                  />
                  <LearningNumberInput
                    label="Не дальше, м"
                    max={5000}
                    min={100}
                    onChange={(value) => setEditor({ ...editor, learningMaxDistanceM: value })}
                    step={100}
                    value={editor.learningMaxDistanceM}
                  />
                  <LearningNumberInput
                    label="Радиус включения, м"
                    max={300}
                    min={30}
                    onChange={(value) => setEditor({ ...editor, learningRadiusM: value })}
                    step={10}
                    value={editor.learningRadiusM}
                  />
                </div>
              ) : null}
            </div>

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

            {editor.id ? (
              <button
                className="rounded-md border border-brand px-4 py-2.5 text-sm font-black text-brand hover:bg-brand/5 disabled:opacity-50"
                disabled={isSaving}
                onClick={() => void runLearning()}
                type="button"
              >
                Пересчитать историю доставок
              </button>
            ) : null}
            </Panel>
          ) : (
            <ReadOnlyZoneDetails zone={editor} />
          )
        ) : null}

        {editor?.id ? (
          <LearningCandidatesPanel
            canManage={canManage}
            candidates={selectedLearningCandidates}
            isSaving={isSaving}
            minDeliveries={editor.learningMinDeliveries}
            onAction={(candidateId, action) => void manageLearningCandidate(candidateId, action)}
          />
        ) : null}
      </div>

      <Panel className="relative overflow-hidden">
        <RouteZoneMap
          drawingEnabled={canManage && drawingEnabled && Boolean(editor)}
          editable={canManage}
          editingZoneId={canManage ? editor?.id ?? null : null}
          onAddPoint={(point) => canManage && editor && setEditor({ ...editor, points: [...editor.points, point] })}
          onMovePoint={(index, point) => {
            if (!canManage || !editor) return;
            const points = editor.points.map((candidate, candidateIndex) => candidateIndex === index ? point : candidate);
            setEditor({ ...editor, points });
          }}
          onSelectZone={selectZone}
          learningCandidates={learningCandidates}
          points={canManage ? editor?.points ?? [] : []}
          zones={zones}
        />
        {canManage && drawingEnabled ? (
          <div className="pointer-events-none absolute left-1/2 top-4 z-[500] -translate-x-1/2 rounded-full bg-ink/90 px-4 py-2 text-xs font-black text-white shadow-panel">
            Кликайте по карте, чтобы поставить точки границы
          </div>
        ) : null}
      </Panel>
    </div>
  );
}

function LearningNumberInput({
  label,
  value,
  min,
  max,
  step = 1,
  onChange
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-[11px] font-bold text-muted">{label}</span>
      <input
        className="focus-ring w-full rounded-md border border-line px-2.5 py-2 text-sm font-bold"
        max={max}
        min={min}
        onChange={(event) => onChange(Number(event.target.value))}
        step={step}
        type="number"
        value={value}
      />
    </label>
  );
}

function LearningCandidatesPanel({
  candidates,
  minDeliveries,
  canManage,
  isSaving,
  onAction
}: {
  candidates: DeliveryZoneLearningCandidate[];
  minDeliveries: number;
  canManage: boolean;
  isSaving: boolean;
  onAction: (candidateId: string, action: "ignore" | "observe" | "revert") => void;
}) {
  return (
    <Panel className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="font-black text-ink">Обучение маршрута</h2>
          <p className="mt-1 text-xs font-semibold text-muted">Повторные доставки рядом с границей</p>
        </div>
        <span className="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-black text-ink">{candidates.length}</span>
      </div>

      <div className="mt-4 grid max-h-96 gap-3 overflow-y-auto pr-1 app-scrollbar">
        {candidates.map((candidate) => (
          <article className="rounded-md border border-line p-3" key={candidate.id}>
            <div className="flex items-center justify-between gap-3">
              <span className={`rounded-full px-2 py-1 text-[10px] font-black ${candidateStatusClass(candidate.status)}`}>
                {candidateStatusLabel(candidate.status)}
              </span>
              <span className="text-xs font-black text-ink">
                {candidate.delivery_count} / {minDeliveries} доставок
              </span>
            </div>
            <p className="mt-2 text-sm font-bold leading-5 text-ink">{candidate.address_text}</p>
            <p className="mt-1 text-xs font-semibold text-muted">
              {Math.round(candidate.distance_m)} м от прежней границы
              {candidate.last_seen_at ? ` · ${formatLearningDate(candidate.last_seen_at)}` : ""}
            </p>
            {candidate.last_error ? <p className="mt-2 text-xs font-semibold text-bad">{candidate.last_error}</p> : null}
            {canManage ? (
              <div className="mt-3 flex flex-wrap gap-2">
                {candidate.status === "observing" || candidate.status === "needs_review" ? (
                  <button
                    className="rounded border border-line px-2.5 py-1.5 text-xs font-black text-muted hover:border-bad hover:text-bad"
                    disabled={isSaving}
                    onClick={() => onAction(candidate.id, "ignore")}
                    type="button"
                  >
                    Не учитывать
                  </button>
                ) : null}
                {candidate.status === "ignored" || candidate.status === "reverted" || candidate.status === "needs_review" ? (
                  <button
                    className="rounded border border-brand px-2.5 py-1.5 text-xs font-black text-brand hover:bg-brand/5"
                    disabled={isSaving}
                    onClick={() => onAction(candidate.id, "observe")}
                    type="button"
                  >
                    Наблюдать снова
                  </button>
                ) : null}
                {candidate.status === "applied" ? (
                  <button
                    className="rounded border border-red-200 px-2.5 py-1.5 text-xs font-black text-bad hover:bg-red-50"
                    disabled={isSaving}
                    onClick={() => onAction(candidate.id, "revert")}
                    type="button"
                  >
                    Откатить расширение
                  </button>
                ) : null}
              </div>
            ) : null}
          </article>
        ))}
        {candidates.length === 0 ? (
          <div className="rounded-md border border-dashed border-line bg-slate-50 px-4 py-5 text-sm font-semibold text-muted">
            Новых повторяющихся адресов рядом с этой зоной пока нет.
          </div>
        ) : null}
      </div>
    </Panel>
  );
}

function ReadOnlyZoneDetails({ zone }: { zone: EditorState }) {
  return (
    <Panel className="grid gap-4 p-4">
      <div className="flex items-center gap-3">
        <span className="size-4 shrink-0 rounded-full" style={{ backgroundColor: zone.color }} />
        <div>
          <h2 className="font-black text-ink">{zone.name}</h2>
          <p className="text-xs font-semibold text-muted">Просмотр без права изменения</p>
        </div>
      </div>
      <dl className="grid gap-3 text-sm">
        <div className="flex items-center justify-between gap-3 border-b border-line pb-3">
          <dt className="font-semibold text-muted">Приоритет</dt>
          <dd className="font-black text-ink">{zone.priority}</dd>
        </div>
        <div className="flex items-center justify-between gap-3 border-b border-line pb-3">
          <dt className="font-semibold text-muted">Зона</dt>
          <dd className={`font-black ${zone.isActive ? "text-good" : "text-muted"}`}>
            {zone.isActive ? "Активна" : "Выключена"}
          </dd>
        </div>
        <div className="flex items-center justify-between gap-3 border-b border-line pb-3">
          <dt className="font-semibold text-muted">Заказы клиентов</dt>
          <dd className={`font-black ${zone.customerOrderEnabled ? "text-good" : "text-muted"}`}>
            {zone.customerOrderEnabled ? "Разрешены" : "Запрещены"}
          </dd>
        </div>
        <div className="flex items-center justify-between gap-3">
          <dt className="font-semibold text-muted">Точек границы</dt>
          <dd className="font-black text-ink">{zone.points.length}</dd>
        </div>
        <div className="flex items-center justify-between gap-3 border-t border-line pt-3">
          <dt className="font-semibold text-muted">Автокоррекция</dt>
          <dd className={`font-black ${zone.autoExpandEnabled ? "text-good" : "text-muted"}`}>
            {zone.autoExpandEnabled ? `После ${zone.learningMinDeliveries} доставок` : "Выключена"}
          </dd>
        </div>
      </dl>
      <p className="rounded-md bg-slate-50 px-3 py-2 text-xs font-semibold text-muted">
        Изменять границы, активность и доступность клиентских заказов может только администратор.
      </p>
    </Panel>
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
    autoExpandEnabled: zone.auto_expand_enabled,
    learningMinDeliveries: zone.learning_min_deliveries,
    learningLookbackDays: zone.learning_lookback_days,
    learningMaxDistanceM: zone.learning_max_distance_m,
    learningRadiusM: zone.learning_radius_m,
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

function learningSettingsAreValid(editor: EditorState) {
  return Number.isInteger(editor.learningMinDeliveries)
    && editor.learningMinDeliveries >= 2
    && editor.learningMinDeliveries <= 20
    && Number.isInteger(editor.learningLookbackDays)
    && editor.learningLookbackDays >= 7
    && editor.learningLookbackDays <= 365
    && Number.isInteger(editor.learningMaxDistanceM)
    && editor.learningMaxDistanceM >= 100
    && editor.learningMaxDistanceM <= 5000
    && Number.isInteger(editor.learningRadiusM)
    && editor.learningRadiusM >= 30
    && editor.learningRadiusM <= 300;
}

function samePoint(left: ZoneMapPoint, right: ZoneMapPoint) {
  return Math.abs(left.lat - right.lat) < 0.0000001 && Math.abs(left.lng - right.lng) < 0.0000001;
}

function candidateStatusLabel(status: DeliveryZoneLearningCandidate["status"]) {
  if (status === "applied") return "Включён автоматически";
  if (status === "ignored") return "Не учитывать";
  if (status === "reverted") return "Расширение отменено";
  if (status === "needs_review") return "Нужна проверка";
  return "Наблюдение";
}

function candidateStatusClass(status: DeliveryZoneLearningCandidate["status"]) {
  if (status === "applied") return "bg-emerald-50 text-good";
  if (status === "needs_review") return "bg-red-50 text-bad";
  if (status === "ignored" || status === "reverted") return "bg-slate-100 text-muted";
  return "bg-amber-50 text-amber-700";
}

function formatLearningDate(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { day: "2-digit", month: "2-digit", year: "numeric" }).format(new Date(value));
}
