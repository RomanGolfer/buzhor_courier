"use client";

import { AlertTriangle, CheckCircle2, FileSpreadsheet, UploadCloud } from "lucide-react";
import { useRouter } from "next/navigation";
import { useMemo, useState, type ChangeEvent } from "react";
import { matrixToObjects, parseDelimitedText, type LegacyImportEntity, type LegacyImportPreview, type LegacyRawRow } from "@/lib/legacy-import";
import type { DataImportHistoryRow } from "@/lib/types";

const MAX_FILE_BYTES = 10 * 1024 * 1024;
const MAX_ROWS = 20000;

type ImportCounts = {
  imported: number;
  updated: number;
  skipped: number;
  failed: number;
  errors: string[];
};

const emptyCounts: ImportCounts = { imported: 0, updated: 0, skipped: 0, failed: 0, errors: [] };

export function LegacyImportManager({ history }: { history: DataImportHistoryRow[] }) {
  const router = useRouter();
  const [entity, setEntity] = useState<LegacyImportEntity>("clients");
  const [sourceSystem, setSourceSystem] = useState("Предыдущий поставщик");
  const [file, setFile] = useState<File | null>(null);
  const [rows, setRows] = useState<LegacyRawRow[]>([]);
  const [previews, setPreviews] = useState<LegacyImportPreview[]>([]);
  const [checksum, setChecksum] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [processed, setProcessed] = useState(0);
  const [counts, setCounts] = useState<ImportCounts>(emptyCounts);
  const previewErrors = useMemo(() => previews.reduce((total, row) => total + row.errors.length, 0), [previews]);

  async function chooseFile(event: ChangeEvent<HTMLInputElement>) {
    const selected = event.target.files?.[0] ?? null;
    setMessage(null);
    setRows([]);
    setPreviews([]);
    setChecksum(null);
    setCounts(emptyCounts);
    setProcessed(0);
    setFile(selected);
    if (!selected) return;
    if (selected.size > MAX_FILE_BYTES) {
      setMessage("Файл больше 10 МБ. Разделите выгрузку на несколько файлов.");
      return;
    }

    setBusy(true);
    try {
      const parsed = await parseFile(selected, entity);
      if (parsed.length === 0) throw new Error("В файле нет строк данных после заголовка");
      if (parsed.length > MAX_ROWS) throw new Error("В одном импорте допускается не более 20 000 строк");
      const [previewResponse, digest] = await Promise.all([
        api<{ previews: LegacyImportPreview[] }>({ action: "preview", entity, rows: parsed.slice(0, 10) }),
        fileChecksum(selected)
      ]);
      setRows(parsed);
      setPreviews(previewResponse.previews);
      setChecksum(digest);
      setMessage(`Файл прочитан: ${parsed.length.toLocaleString("ru-RU")} строк. Проверьте первые строки перед импортом.`);
    } catch (error) {
      setFile(null);
      setMessage(error instanceof Error ? error.message : "Не удалось прочитать файл");
    } finally {
      setBusy(false);
    }
  }

  async function changeEntity(nextEntity: LegacyImportEntity) {
    setEntity(nextEntity);
    setCounts(emptyCounts);
    setProcessed(0);
    if (rows.length === 0) return;
    setBusy(true);
    try {
      const response = await api<{ previews: LegacyImportPreview[] }>({
        action: "preview",
        entity: nextEntity,
        rows: rows.slice(0, 10)
      });
      setPreviews(response.previews);
      setMessage("Тип данных изменён. Проверьте распознанные поля ещё раз.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Не удалось обновить предварительный просмотр");
    } finally {
      setBusy(false);
    }
  }

  async function runImport() {
    if (!file || rows.length === 0 || !sourceSystem.trim()) return;
    setBusy(true);
    setProcessed(0);
    setCounts(emptyCounts);
    setMessage("Импорт начат. Не закрывайте страницу до завершения.");

    let importId: string | null = null;
    try {
      const start = await api<{ importId: string }>({
        action: "start",
        entity,
        sourceSystem: sourceSystem.trim(),
        filename: file.name,
        checksum,
        totalRows: rows.length
      });
      importId = start.importId;
      let total = { ...emptyCounts };
      let offset = 0;
      for (const batch of makeBatches(rows)) {
        const response = await api<{ counts: ImportCounts }>({
          action: "batch",
          importId,
          offset,
          rows: batch
        });
        total = addCounts(total, response.counts);
        offset += batch.length;
        setProcessed(offset);
        setCounts(total);
      }
      const finish = await api<{ status: string }>({ action: "finish", importId });
      setMessage(
        finish.status === "completed"
          ? "Импорт завершён без ошибок. Справочники уже обновлены."
          : "Импорт завершён с замечаниями. Проверьте ошибки ниже и журнал импорта."
      );
      router.refresh();
    } catch (error) {
      const reason = error instanceof Error ? error.message : "Импорт прерван из-за ошибки";
      if (importId) {
        try {
          await api({ action: "fail", importId, reason });
        } catch {
          // The original import error is more useful to the administrator.
        }
      }
      setMessage(reason);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <section className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <div className="border border-line bg-white p-6 shadow-sm">
          <div className="grid gap-5 md:grid-cols-2">
            <label className="block text-sm font-bold text-ink">
              Какие данные переносим
              <select
                className="focus-ring mt-2 w-full border border-line bg-white px-3 py-3 font-semibold"
                disabled={busy}
                onChange={(event) => void changeEntity(event.target.value as LegacyImportEntity)}
                value={entity}
              >
                <option value="clients">Клиенты и их адреса</option>
                <option value="organizations">Организации</option>
                <option value="orders">Заказы</option>
              </select>
            </label>
            <label className="block text-sm font-bold text-ink">
              Название предыдущей системы
              <input
                className="focus-ring mt-2 w-full border border-line px-3 py-3 font-semibold"
                disabled={busy}
                maxLength={120}
                onChange={(event) => setSourceSystem(event.target.value)}
                value={sourceSystem}
              />
            </label>
          </div>

          <label className="mt-6 flex min-h-44 cursor-pointer flex-col items-center justify-center border-2 border-dashed border-brand/40 bg-brand/5 px-6 py-8 text-center transition hover:border-brand">
            <UploadCloud aria-hidden className="mb-3 size-9 text-brand" />
            <span className="font-black text-ink">Выберите выгрузку предыдущего поставщика</span>
            <span className="mt-1 text-sm text-muted">CSV, XLSX или JSON · до 10 МБ и 20 000 строк</span>
            <input
              accept=".csv,.xlsx,.json,text/csv,application/json,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              className="sr-only"
              disabled={busy}
              onChange={(event) => void chooseFile(event)}
              type="file"
            />
          </label>

          {file ? (
            <div className="mt-4 flex items-center gap-3 border border-line bg-slate-50 px-4 py-3">
              <FileSpreadsheet aria-hidden className="size-5 text-brand" />
              <div className="min-w-0">
                <div className="truncate font-bold text-ink">{file.name}</div>
                <div className="text-xs text-muted">{formatBytes(file.size)} · {rows.length.toLocaleString("ru-RU")} строк</div>
              </div>
            </div>
          ) : null}

          {message ? <p aria-live="polite" className="mt-4 border-l-4 border-brand bg-brand/5 px-4 py-3 text-sm font-semibold text-ink">{message}</p> : null}

          <div className="mt-6 flex flex-wrap items-center gap-4">
            <button
              className="focus-ring bg-brand px-6 py-3 font-black text-white transition hover:bg-brand/90 disabled:cursor-not-allowed disabled:opacity-50"
              disabled={busy || rows.length === 0 || !sourceSystem.trim()}
              onClick={() => void runImport()}
              type="button"
            >
              {busy && rows.length > 0 ? "Обработка…" : `Импортировать ${rows.length ? rows.length.toLocaleString("ru-RU") : ""}`}
            </button>
            <p className="max-w-xl text-xs leading-5 text-muted">
              Клиенты и организации обновляются при совпадении. Существующие заказы с тем же номером не перезаписываются. Все исходные колонки сохраняются для последующей сверки.
            </p>
          </div>
        </div>

        <aside className="border border-line bg-slate-50 p-6">
          <h2 className="font-black text-ink">Ход импорта</h2>
          <div className="mt-4 h-2 overflow-hidden bg-slate-200">
            <div className="h-full bg-brand transition-all" style={{ width: `${rows.length ? Math.round(processed / rows.length * 100) : 0}%` }} />
          </div>
          <div className="mt-2 text-sm font-bold text-ink">{processed.toLocaleString("ru-RU")} из {rows.length.toLocaleString("ru-RU")}</div>
          <dl className="mt-6 grid grid-cols-2 gap-3 text-sm">
            <Counter label="Добавлено" value={counts.imported} tone="text-emerald-700" />
            <Counter label="Обновлено" value={counts.updated} tone="text-blue-700" />
            <Counter label="Пропущено" value={counts.skipped} tone="text-amber-700" />
            <Counter label="Ошибки" value={counts.failed} tone="text-red-700" />
          </dl>
          {counts.errors.length > 0 ? (
            <div className="mt-5 max-h-52 overflow-y-auto border border-red-200 bg-red-50 p-3 text-xs text-red-800">
              {counts.errors.slice(0, 20).map((error, index) => <div className="mb-1" key={`${error}-${index}`}>{error}</div>)}
            </div>
          ) : null}
        </aside>
      </section>

      {previews.length > 0 ? (
        <section className="border border-line bg-white shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-6 py-4">
            <div>
              <h2 className="font-black text-ink">Предварительная проверка</h2>
              <p className="mt-1 text-sm text-muted">Первые {previews.length} строк после распознавания колонок</p>
            </div>
            <div className={`flex items-center gap-2 text-sm font-bold ${previewErrors ? "text-amber-700" : "text-emerald-700"}`}>
              {previewErrors ? <AlertTriangle className="size-5" /> : <CheckCircle2 className="size-5" />}
              {previewErrors ? `${previewErrors} замечаний` : "Обязательные поля распознаны"}
            </div>
          </div>
          <PreviewTable entity={entity} rows={previews} />
        </section>
      ) : null}

      <ImportHistory rows={history} />
    </div>
  );
}

function PreviewTable({ entity, rows }: { entity: LegacyImportEntity; rows: LegacyImportPreview[] }) {
  const headers = entity === "organizations"
    ? ["Организация", "ИНН / КПП", "Телефон", "Адрес", "Проверка"]
    : entity === "orders"
      ? ["Заказ", "Клиент", "Телефон", "Адрес / организация", "Проверка"]
      : ["Клиент", "Телефон / email", "Адрес", "Организация", "Проверка"];

  return (
    <div className="overflow-x-auto">
      <table className="min-w-[1000px] text-left text-sm">
        <thead className="bg-slate-50 text-xs font-bold text-muted">
          <tr>{headers.map((header) => <th className="border-b border-line px-4 py-3" key={header}>{header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, index) => {
            const values = previewValues(entity, row);
            return (
              <tr className="align-top hover:bg-slate-50" key={index}>
                {values.map((value, valueIndex) => <td className="max-w-sm border-b border-line px-4 py-3" key={valueIndex}>{value || "—"}</td>)}
                <td className={`border-b border-line px-4 py-3 font-semibold ${row.errors.length ? "text-red-700" : "text-emerald-700"}`}>
                  {row.errors.length ? row.errors.join("; ") : "Готово"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function previewValues(entity: LegacyImportEntity, preview: LegacyImportPreview) {
  if (entity === "organizations" && "name" in preview) {
    return [preview.name, [preview.inn, preview.kpp].filter(Boolean).join(" / "), preview.phone, preview.address];
  }
  if (entity === "orders" && "orderNumber" in preview) {
    return [preview.orderNumber ?? `Без номера · ${preview.deliveryDate}`, preview.clientName, preview.phone, [preview.address, preview.organization].filter(Boolean).join(" · ")];
  }
  if ("fullName" in preview) return [preview.fullName, [preview.phone, preview.email].filter(Boolean).join(" · "), preview.address, preview.organization];
  return ["", "", "", ""];
}

function ImportHistory({ rows }: { rows: DataImportHistoryRow[] }) {
  return (
    <section className="border border-line bg-white shadow-sm">
      <div className="border-b border-line px-6 py-4">
        <h2 className="font-black text-ink">Журнал импорта</h2>
        <p className="mt-1 text-sm text-muted">Последние запуски администраторов</p>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-[1100px] text-left text-sm">
          <thead className="bg-slate-50 text-xs font-bold text-muted">
            <tr>
              <th className="border-b border-line px-4 py-3">Дата</th>
              <th className="border-b border-line px-4 py-3">Источник</th>
              <th className="border-b border-line px-4 py-3">Файл / тип</th>
              <th className="border-b border-line px-4 py-3">Всего</th>
              <th className="border-b border-line px-4 py-3">Добавлено</th>
              <th className="border-b border-line px-4 py-3">Обновлено</th>
              <th className="border-b border-line px-4 py-3">Пропущено</th>
              <th className="border-b border-line px-4 py-3">Ошибки</th>
              <th className="border-b border-line px-4 py-3">Статус</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr className="hover:bg-slate-50" key={row.id}>
                <td className="border-b border-line px-4 py-3">{formatDateTime(row.created_at)}</td>
                <td className="border-b border-line px-4 py-3 font-semibold">{row.source_system}</td>
                <td className="border-b border-line px-4 py-3"><div className="font-bold">{row.filename}</div><div className="text-xs text-muted">{entityLabel(row.entity_kind)}</div></td>
                <td className="border-b border-line px-4 py-3 font-black">{row.total_rows}</td>
                <td className="border-b border-line px-4 py-3 text-emerald-700">{row.imported_rows}</td>
                <td className="border-b border-line px-4 py-3 text-blue-700">{row.updated_rows}</td>
                <td className="border-b border-line px-4 py-3 text-amber-700">{row.skipped_rows}</td>
                <td className="border-b border-line px-4 py-3 text-red-700">{row.failed_rows}</td>
                <td className="border-b border-line px-4 py-3 font-bold">{statusLabel(row.status)}</td>
              </tr>
            ))}
            {rows.length === 0 ? <tr><td className="px-4 py-10 text-center font-semibold text-muted" colSpan={9}>Импортов пока не было</td></tr> : null}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function Counter({ label, value, tone }: { label: string; value: number; tone: string }) {
  return <div className="border border-line bg-white p-3"><dt className="text-xs font-bold text-muted">{label}</dt><dd className={`mt-1 text-2xl font-black ${tone}`}>{value}</dd></div>;
}

async function parseFile(file: File, entity: LegacyImportEntity) {
  const extension = file.name.split(".").pop()?.toLocaleLowerCase("ru-RU");
  if (extension === "xlsx") {
    const { readSheet } = await import("read-excel-file/browser");
    return matrixToObjects(await readSheet(file));
  }

  const buffer = await file.arrayBuffer();
  const text = decodeText(buffer);
  if (extension === "json") {
    const parsed = JSON.parse(text) as unknown;
    const candidate = jsonRows(parsed, entity);
    if (!candidate) throw new Error("JSON должен содержать массив объектов или поле data/rows");
    return candidate;
  }
  if (extension === "csv") return parseDelimitedText(text);
  throw new Error("Поддерживаются только файлы CSV, XLSX и JSON");
}

function jsonRows(value: unknown, entity: LegacyImportEntity): LegacyRawRow[] | null {
  let candidate = value;
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const object = value as Record<string, unknown>;
    candidate = object.data ?? object.rows ?? object[entity];
  }
  if (!Array.isArray(candidate)) return null;
  const rows = candidate.filter((row): row is LegacyRawRow => Boolean(row) && typeof row === "object" && !Array.isArray(row));
  return rows.length === candidate.length ? rows : null;
}

function decodeText(buffer: ArrayBuffer) {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(buffer);
  } catch {
    return new TextDecoder("windows-1251").decode(buffer);
  }
}

async function fileChecksum(file: File) {
  const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer());
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function makeBatches(rows: LegacyRawRow[]) {
  const batches: LegacyRawRow[][] = [];
  let current: LegacyRawRow[] = [];
  let currentBytes = 0;
  for (const row of rows) {
    const rowBytes = new TextEncoder().encode(JSON.stringify(row)).length;
    if (current.length > 0 && (current.length >= 100 || currentBytes + rowBytes > 1_400_000)) {
      batches.push(current);
      current = [];
      currentBytes = 0;
    }
    current.push(row);
    currentBytes += rowBytes;
  }
  if (current.length > 0) batches.push(current);
  return batches;
}

async function api<T>(body: Record<string, unknown>): Promise<T> {
  const response = await fetch("/api/import/legacy", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  const data = await response.json() as T & { error?: string };
  if (!response.ok) throw new Error(data.error ?? "Ошибка импорта");
  return data;
}

function addCounts(current: ImportCounts, next: ImportCounts): ImportCounts {
  return {
    imported: current.imported + next.imported,
    updated: current.updated + next.updated,
    skipped: current.skipped + next.skipped,
    failed: current.failed + next.failed,
    errors: [...current.errors, ...next.errors].slice(0, 100)
  };
}

function entityLabel(entity: LegacyImportEntity) {
  return entity === "clients" ? "Клиенты" : entity === "organizations" ? "Организации" : "Заказы";
}

function statusLabel(status: DataImportHistoryRow["status"]) {
  if (status === "completed") return "Завершён";
  if (status === "completed_with_errors") return "Есть ошибки";
  if (status === "failed") return "Ошибка";
  return "В процессе";
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("ru-RU", { dateStyle: "short", timeStyle: "short" }).format(new Date(value));
}

function formatBytes(value: number) {
  return value < 1024 * 1024 ? `${Math.ceil(value / 1024)} КБ` : `${(value / 1024 / 1024).toFixed(1)} МБ`;
}
