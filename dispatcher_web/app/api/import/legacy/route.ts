import { createHash } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { getApiStaffContext } from "@/lib/auth";
import {
  normalizeClientRow,
  normalizeImportRow,
  normalizeOrganizationRow,
  normalizeOrderRow,
  normalizePhone,
  type LegacyImportEntity,
  type LegacyRawRow,
  type NormalizedClientRow,
  type NormalizedOrderRow,
  type NormalizedOrganizationRow
} from "@/lib/legacy-import";

export const runtime = "nodejs";

const MAX_BODY_BYTES = 2_000_000;
const MAX_BATCH_ROWS = 200;
const MAX_PREVIEW_ROWS = 25;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type BatchResult = {
  imported: number;
  updated: number;
  skipped: number;
  failed: number;
  errors: string[];
};

type ImportRecord = {
  id: string;
  entity_kind: LegacyImportEntity;
  status: string;
  imported_rows: number;
  updated_rows: number;
  skipped_rows: number;
  failed_rows: number;
  error_summary: unknown;
  source_system: string;
  filename: string;
  imported_by: string | null;
};

type SupabaseClient = NonNullable<Awaited<ReturnType<typeof getApiStaffContext>>>["supabase"];

export async function POST(request: NextRequest) {
  const context = await getApiStaffContext();
  if (!context) return NextResponse.json({ error: "Требуется авторизация сотрудника" }, { status: 401 });
  if (context.profile.role !== "admin") {
    return NextResponse.json({ error: "Импорт данных доступен только администратору" }, { status: 403 });
  }

  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > MAX_BODY_BYTES) return NextResponse.json({ error: "Слишком большой пакет данных" }, { status: 413 });

  let body: Record<string, unknown>;
  try {
    const source = await request.text();
    if (new TextEncoder().encode(source).length > MAX_BODY_BYTES) {
      return NextResponse.json({ error: "Слишком большой пакет данных" }, { status: 413 });
    }
    body = JSON.parse(source) as Record<string, unknown>;
  } catch {
    return NextResponse.json({ error: "Некорректный JSON" }, { status: 400 });
  }

  const action = typeof body.action === "string" ? body.action : "";
  if (action === "preview") return previewImport(body);
  if (action === "start") return startImport(context.supabase, context.profile.id, body);
  if (action === "batch") return importBatch(context.supabase, context.profile.id, body);
  if (action === "finish") return finishImport(context.supabase, context.profile.id, body);
  if (action === "fail") return failImport(context.supabase, context.profile.id, body);
  return NextResponse.json({ error: "Неизвестное действие импорта" }, { status: 400 });
}

function previewImport(body: Record<string, unknown>) {
  const entity = importEntity(body.entity);
  const rows = rawRows(body.rows, MAX_PREVIEW_ROWS);
  if (!entity || !rows) return NextResponse.json({ error: "Проверьте тип данных и строки файла" }, { status: 400 });
  return NextResponse.json({ previews: rows.map((row) => normalizeImportRow(entity, row)) });
}

async function startImport(supabase: SupabaseClient, profileId: string, body: Record<string, unknown>) {
  const entity = importEntity(body.entity);
  const totalRows = integer(body.totalRows);
  const sourceSystem = limitedText(body.sourceSystem, 120);
  const filename = limitedText(body.filename, 255);
  const checksum = limitedText(body.checksum, 128);

  if (!entity || totalRows === null || totalRows < 1 || totalRows > 20000 || !sourceSystem || !filename) {
    return NextResponse.json({ error: "Некорректные параметры импорта" }, { status: 400 });
  }

  const { data, error } = await supabase
    .from("data_imports")
    .insert({
      entity_kind: entity,
      source_system: sourceSystem,
      filename,
      checksum,
      total_rows: totalRows,
      imported_by: profileId
    })
    .select("id")
    .single();

  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ importId: data.id });
}

async function importBatch(supabase: SupabaseClient, profileId: string, body: Record<string, unknown>) {
  const importId = typeof body.importId === "string" && UUID_PATTERN.test(body.importId) ? body.importId : null;
  const rows = rawRows(body.rows, MAX_BATCH_ROWS);
  const offset = integer(body.offset) ?? 0;
  if (!importId || !rows || rows.length === 0 || offset < 0) {
    return NextResponse.json({ error: "Некорректный пакет импорта" }, { status: 400 });
  }

  const { data, error } = await supabase
    .from("data_imports")
    .select("id, entity_kind, status, imported_rows, updated_rows, skipped_rows, failed_rows, error_summary, source_system, filename, imported_by")
    .eq("id", importId)
    .single();
  if (error || !data) return NextResponse.json({ error: "Импорт не найден" }, { status: 404 });

  const record = data as ImportRecord;
  if (record.imported_by !== profileId) {
    return NextResponse.json({ error: "Этот импорт запущен другим администратором" }, { status: 403 });
  }
  if (record.status !== "processing") return NextResponse.json({ error: "Импорт уже завершён" }, { status: 409 });

  let result: BatchResult;
  if (record.entity_kind === "clients") {
    result = await processClients(supabase, rows, record.source_system, offset);
  } else if (record.entity_kind === "organizations") {
    result = await processOrganizations(supabase, rows, record.source_system, offset);
  } else {
    result = await processOrders(supabase, rows, record.source_system, record.filename, importId, profileId, offset);
  }

  const previousErrors = Array.isArray(record.error_summary) ? record.error_summary.filter((item): item is string => typeof item === "string") : [];
  const { error: updateError } = await supabase
    .from("data_imports")
    .update({
      imported_rows: record.imported_rows + result.imported,
      updated_rows: record.updated_rows + result.updated,
      skipped_rows: record.skipped_rows + result.skipped,
      failed_rows: record.failed_rows + result.failed,
      error_summary: [...previousErrors, ...result.errors].slice(0, 100)
    })
    .eq("id", importId);
  if (updateError) return NextResponse.json({ error: updateError.message }, { status: 400 });

  return NextResponse.json({ counts: result });
}

async function finishImport(supabase: SupabaseClient, profileId: string, body: Record<string, unknown>) {
  const importId = typeof body.importId === "string" && UUID_PATTERN.test(body.importId) ? body.importId : null;
  if (!importId) return NextResponse.json({ error: "Некорректный идентификатор импорта" }, { status: 400 });

  const { data, error } = await supabase
    .from("data_imports")
    .select("failed_rows, error_summary")
    .eq("id", importId)
    .eq("imported_by", profileId)
    .single();
  if (error || !data) return NextResponse.json({ error: "Импорт не найден" }, { status: 404 });

  const status = data.failed_rows > 0 || (Array.isArray(data.error_summary) && data.error_summary.length > 0)
    ? "completed_with_errors"
    : "completed";
  const { error: updateError } = await supabase
    .from("data_imports")
    .update({ status, completed_at: new Date().toISOString() })
    .eq("id", importId);
  if (updateError) return NextResponse.json({ error: updateError.message }, { status: 400 });
  return NextResponse.json({ status });
}

async function failImport(supabase: SupabaseClient, profileId: string, body: Record<string, unknown>) {
  const importId = typeof body.importId === "string" && UUID_PATTERN.test(body.importId) ? body.importId : null;
  const reason = limitedText(body.reason, 500) ?? "Импорт был прерван";
  if (!importId) return NextResponse.json({ error: "Некорректный идентификатор импорта" }, { status: 400 });

  const { data, error } = await supabase
    .from("data_imports")
    .select("error_summary")
    .eq("id", importId)
    .eq("imported_by", profileId)
    .single();
  if (error || !data) return NextResponse.json({ error: "Импорт не найден" }, { status: 404 });
  const previous = Array.isArray(data.error_summary)
    ? data.error_summary.filter((item): item is string => typeof item === "string")
    : [];
  const { error: updateError } = await supabase
    .from("data_imports")
    .update({
      status: "failed",
      completed_at: new Date().toISOString(),
      error_summary: [...previous, reason].slice(0, 100)
    })
    .eq("id", importId);
  if (updateError) return NextResponse.json({ error: updateError.message }, { status: 400 });
  return NextResponse.json({ status: "failed" });
}

async function processClients(
  supabase: SupabaseClient,
  rows: LegacyRawRow[],
  sourceSystem: string,
  offset: number
): Promise<BatchResult> {
  const normalized = rows.map(normalizeClientRow);
  const errors = validationErrors(normalized, offset);
  const valid = normalized.filter((row) => row.errors.length === 0 && row.fullName);
  const unique = new Map(valid.map((row) => [clientKey(row, sourceSystem), row]));
  const duplicateCount = valid.length - unique.size;
  if (unique.size === 0) return counts(0, 0, duplicateCount, normalized.length - valid.length, errors);

  const keys = [...unique.keys()];
  const { data: existingData, error: existingError } = await supabase
    .from("clients")
    .select("id, dedupe_key, legacy_id, full_name, phone, email, status, loyalty_points, tare_debt, notes, legacy_data")
    .in("dedupe_key", keys);
  if (existingError) return databaseFailure(rows.length, existingError.message, offset);

  const existingByKey = new Map((existingData ?? []).map((row) => [row.dedupe_key, row]));
  const payloads = [...unique].map(([key, row]) => {
    const existing = existingByKey.get(key);
    return {
      legacy_id: limitedText(row.legacyId, 160) ?? existing?.legacy_id ?? null,
      full_name: limitedText(row.fullName, 160)!,
      phone: limitedText(row.phone, 64) ?? existing?.phone ?? null,
      email: limitedText(row.email, 320) ?? existing?.email ?? null,
      status: limitedText(row.status, 80) ?? existing?.status ?? null,
      loyalty_points: row.loyaltyPoints ?? existing?.loyalty_points ?? 0,
      tare_debt: row.tareDebt ?? existing?.tare_debt ?? 0,
      notes: limitedText(row.notes, 2000) ?? existing?.notes ?? null,
      dedupe_key: key,
      source_system: sourceSystem,
      legacy_data: mergeLegacyData(existing?.legacy_data, row.original, sourceSystem)
    };
  });

  const { data: saved, error: saveError } = await supabase
    .from("clients")
    .upsert(payloads, { onConflict: "dedupe_key" })
    .select("id, dedupe_key");
  if (saveError) return databaseFailure(rows.length, saveError.message, offset);

  const idByKey = new Map((saved ?? []).map((row) => [row.dedupe_key, row.id]));
  const addressPayloads = [...unique].flatMap(([key, row]) => {
    const clientId = idByKey.get(key);
    if (!clientId || !row.address) return [];
    return [addressPayload(clientId, row, sourceSystem)];
  });
  if (addressPayloads.length > 0) {
    const { error: addressError } = await supabase
      .from("client_addresses")
      .upsert(addressPayloads, { onConflict: "client_id,dedupe_key" });
    if (addressError) errors.push(`Адреса: ${addressError.message}`);
  }

  return counts(unique.size - existingByKey.size, existingByKey.size, duplicateCount, normalized.length - valid.length, errors);
}

async function processOrganizations(
  supabase: SupabaseClient,
  rows: LegacyRawRow[],
  sourceSystem: string,
  offset: number
): Promise<BatchResult> {
  const normalized = rows.map(normalizeOrganizationRow);
  const errors = validationErrors(normalized, offset);
  const valid = normalized.filter((row) => row.errors.length === 0 && row.name);
  const unique = new Map(valid.map((row) => [organizationKey(row, sourceSystem), row]));
  const duplicateCount = valid.length - unique.size;
  if (unique.size === 0) return counts(0, 0, duplicateCount, normalized.length - valid.length, errors);

  const keys = [...unique.keys()];
  const { data: existingData, error: existingError } = await supabase
    .from("organizations")
    .select("dedupe_key, legacy_id, name, inn, kpp, phone, email, address_text, tare_debt, legacy_data")
    .in("dedupe_key", keys);
  if (existingError) return databaseFailure(rows.length, existingError.message, offset);

  const existingByKey = new Map((existingData ?? []).map((row) => [row.dedupe_key, row]));
  const payloads = [...unique].map(([key, row]) => {
    const existing = existingByKey.get(key);
    return {
      legacy_id: limitedText(row.legacyId, 160) ?? existing?.legacy_id ?? null,
      name: limitedText(row.name, 240)!,
      inn: limitedText(row.inn, 32) ?? existing?.inn ?? null,
      kpp: limitedText(row.kpp, 32) ?? existing?.kpp ?? null,
      phone: limitedText(row.phone, 64) ?? existing?.phone ?? null,
      email: limitedText(row.email, 320) ?? existing?.email ?? null,
      address_text: limitedText(row.address, 500) ?? existing?.address_text ?? null,
      tare_debt: row.tareDebt ?? existing?.tare_debt ?? 0,
      dedupe_key: key,
      source_system: sourceSystem,
      legacy_data: mergeLegacyData(existing?.legacy_data, row.original, sourceSystem)
    };
  });

  const { error: saveError } = await supabase.from("organizations").upsert(payloads, { onConflict: "dedupe_key" });
  if (saveError) return databaseFailure(rows.length, saveError.message, offset);
  return counts(unique.size - existingByKey.size, existingByKey.size, duplicateCount, normalized.length - valid.length, errors);
}

async function processOrders(
  supabase: SupabaseClient,
  rows: LegacyRawRow[],
  sourceSystem: string,
  filename: string,
  importId: string,
  profileId: string,
  offset: number
): Promise<BatchResult> {
  const normalized = rows.map(normalizeOrderRow);
  const errors = validationErrors(normalized, offset);
  const valid = normalized.filter((row) => row.errors.length === 0 && row.clientName && row.address);
  const withNumbers = valid.map((row) => ({ row, orderNumber: orderNumber(row, sourceSystem) }));
  const unique = new Map(withNumbers.map((item) => [item.orderNumber, item]));
  const duplicateCount = withNumbers.length - unique.size;
  if (unique.size === 0) return counts(0, 0, duplicateCount, normalized.length - valid.length, errors);

  const orderNumbers = [...unique.keys()];
  const sourceIds = [...new Set([...unique.values()].map(({ row }) => limitedText(row.legacyId, 160)).filter((value): value is string => Boolean(value)))];
  const [numberResult, sourceResult] = await Promise.all([
    supabase.from("orders").select("order_number").in("order_number", orderNumbers),
    sourceIds.length > 0
      ? supabase.from("orders").select("source_record_id").eq("source_system", sourceSystem).in("source_record_id", sourceIds)
      : Promise.resolve({ data: [], error: null })
  ]);
  if (numberResult.error || sourceResult.error) {
    return databaseFailure(rows.length, numberResult.error?.message ?? sourceResult.error?.message ?? "Ошибка поиска заказов", offset);
  }

  const existingNumbers = new Set((numberResult.data ?? []).map((row) => row.order_number));
  const existingSourceIds = new Set((sourceResult.data ?? []).map((row) => row.source_record_id));
  const newItems = [...unique.values()].filter(({ row, orderNumber: number }) => {
    const sourceId = limitedText(row.legacyId, 160);
    return !existingNumbers.has(number) && (!sourceId || !existingSourceIds.has(sourceId));
  });
  const existingCount = unique.size - newItems.length;
  if (newItems.length === 0) {
    return counts(0, 0, duplicateCount + existingCount, normalized.length - valid.length, errors);
  }

  const clientIds = await upsertOrderClients(supabase, newItems.map((item) => item.row), sourceSystem);
  if (clientIds.error) return databaseFailure(rows.length, clientIds.error, offset);
  const organizationIds = await upsertOrderOrganizations(supabase, newItems.map((item) => item.row), sourceSystem);
  if (organizationIds.error) return databaseFailure(rows.length, organizationIds.error, offset);
  const couriers = await loadCouriers(supabase);
  if (couriers.error) return databaseFailure(rows.length, couriers.error, offset);

  const payloads = newItems.map(({ row, orderNumber: number }) => {
    const clientDedupeKey = orderClientKey(row, sourceSystem);
    const organizationDedupeKey = row.organization ? orderOrganizationKey(row, sourceSystem) : null;
    const createdAt = row.createdAt ?? undefined;
    return {
      order_number: number,
      assigned_courier_id: courierId(row, couriers.byName, couriers.byPhone),
      state: row.state,
      client_id: clientIds.byKey.get(clientDedupeKey) ?? null,
      organization_id: organizationDedupeKey ? organizationIds.byKey.get(organizationDedupeKey) ?? null : null,
      client_name: limitedText(row.clientName, 160)!,
      client_phone: limitedText(row.phone, 64),
      address: limitedText(row.address, 500)!,
      district: limitedText(row.district, 120),
      lat: row.lat,
      lng: row.lng,
      payment_method: row.paymentMethod,
      price: row.price,
      bottles: row.bottles,
      time_slot: limitedText(row.timeSlot, 80),
      delivery_date: row.deliveryDate,
      delivery_comment: limitedText(row.comment, 1200),
      created_by: profileId,
      updated_by: profileId,
      source_system: sourceSystem,
      source_record_id: limitedText(row.legacyId, 160),
      legacy_data: mergeLegacyData(null, row.original, sourceSystem),
      ...(createdAt ? { created_at: createdAt, updated_at: createdAt } : {})
    };
  });

  let inserted: { id: string; order_number: string }[] = [];
  const bulkResult = await supabase.from("orders").insert(payloads).select("id, order_number");
  if (!bulkResult.error) {
    inserted = bulkResult.data ?? [];
  } else {
    for (let index = 0; index < payloads.length; index += 1) {
      const result = await supabase.from("orders").insert(payloads[index]).select("id, order_number").single();
      if (result.error) errors.push(`Строка ${offset + index + 1}: ${result.error.message}`);
      else inserted.push(result.data);
    }
  }

  if (inserted.length > 0) {
    const { error: eventError } = await supabase.from("order_events").insert(
      inserted.map((order) => ({
        order_id: order.id,
        actor_profile_id: profileId,
        event_type: "legacy_imported",
        payload: { import_id: importId, source_system: sourceSystem, filename }
      }))
    );
    if (eventError) errors.push(`История заказов: ${eventError.message}`);
  }

  const failedInserts = payloads.length - inserted.length;
  return counts(
    inserted.length,
    0,
    duplicateCount + existingCount,
    normalized.length - valid.length + failedInserts,
    errors
  );
}

async function upsertOrderClients(supabase: SupabaseClient, rows: NormalizedOrderRow[], sourceSystem: string) {
  const unique = new Map(rows.map((row) => [orderClientKey(row, sourceSystem), row]));
  const keys = [...unique.keys()];
  const existingResult = await supabase.from("clients").select("dedupe_key, legacy_data").in("dedupe_key", keys);
  if (existingResult.error) return { byKey: new Map<string, string>(), error: existingResult.error.message };
  const legacyByKey = new Map((existingResult.data ?? []).map((row) => [row.dedupe_key, row.legacy_data]));
  const payloads = [...unique].map(([key, row]) => ({
    legacy_id: limitedText(row.legacyId, 160),
    full_name: limitedText(row.clientName, 160)!,
    phone: limitedText(row.phone, 64),
    dedupe_key: key,
    source_system: sourceSystem,
    legacy_data: mergeLegacyData(legacyByKey.get(key), row.original, sourceSystem)
  }));
  const saved = await supabase.from("clients").upsert(payloads, { onConflict: "dedupe_key" }).select("id, dedupe_key");
  if (saved.error) return { byKey: new Map<string, string>(), error: saved.error.message };
  const byKey = new Map((saved.data ?? []).map((row) => [row.dedupe_key, row.id]));

  const addressPayloads = rows.flatMap((row) => {
    const id = byKey.get(orderClientKey(row, sourceSystem));
    if (!id || !row.address) return [];
    return [{
      client_id: id,
      address_text: limitedText(row.address, 500)!,
      district: limitedText(row.district, 160),
      lat: row.lat,
      lng: row.lng,
      dedupe_key: `address:${hash(normalizeText(row.address))}`,
      source_system: sourceSystem,
      legacy_data: mergeLegacyData(null, row.original, sourceSystem)
    }];
  });
  if (addressPayloads.length > 0) {
    const addressResult = await supabase.from("client_addresses").upsert(addressPayloads, { onConflict: "client_id,dedupe_key" });
    if (addressResult.error) return { byKey, error: addressResult.error.message };
  }
  return { byKey, error: null };
}

async function upsertOrderOrganizations(supabase: SupabaseClient, rows: NormalizedOrderRow[], sourceSystem: string) {
  const relevant = rows.filter((row) => row.organization);
  const unique = new Map(relevant.map((row) => [orderOrganizationKey(row, sourceSystem), row]));
  if (unique.size === 0) return { byKey: new Map<string, string>(), error: null };
  const payloads = [...unique].map(([key, row]) => ({
    legacy_id: limitedText(row.legacyId, 160),
    name: limitedText(row.organization, 240)!,
    inn: limitedText(row.organizationInn, 32),
    phone: limitedText(row.phone, 64),
    address_text: limitedText(row.address, 500),
    dedupe_key: key,
    source_system: sourceSystem,
    legacy_data: mergeLegacyData(null, row.original, sourceSystem)
  }));
  const saved = await supabase.from("organizations").upsert(payloads, { onConflict: "dedupe_key" }).select("id, dedupe_key");
  if (saved.error) return { byKey: new Map<string, string>(), error: saved.error.message };
  return { byKey: new Map((saved.data ?? []).map((row) => [row.dedupe_key, row.id])), error: null };
}

async function loadCouriers(supabase: SupabaseClient) {
  const result = await supabase.from("couriers").select("id, display_name, phone").eq("is_active", true);
  if (result.error) return { byName: new Map<string, string>(), byPhone: new Map<string, string>(), error: result.error.message };
  return {
    byName: new Map((result.data ?? []).map((row) => [normalizeText(row.display_name), row.id])),
    byPhone: new Map((result.data ?? []).flatMap((row) => {
      const phone = normalizePhone(row.phone);
      return phone ? [[phone, row.id] as const] : [];
    })),
    error: null
  };
}

function courierId(row: NormalizedOrderRow, byName: Map<string, string>, byPhone: Map<string, string>) {
  const phone = normalizePhone(row.courierPhone);
  if (phone && byPhone.has(phone)) return byPhone.get(phone) ?? null;
  return row.courierName ? byName.get(normalizeText(row.courierName)) ?? null : null;
}

function addressPayload(clientId: string, row: NormalizedClientRow, sourceSystem: string) {
  return {
    client_id: clientId,
    legacy_id: limitedText(row.legacyId, 160),
    address_text: limitedText(row.address, 500)!,
    zone_name: limitedText(row.zoneName, 160),
    district: limitedText(row.district, 160),
    locality: limitedText(row.locality, 160),
    street: limitedText(row.street, 200),
    house: limitedText(row.house, 40),
    building: limitedText(row.building, 40),
    structure: limitedText(row.structure, 40),
    entrance: limitedText(row.entrance, 40),
    floor: limitedText(row.floor, 40),
    apartment: limitedText(row.apartment, 40),
    lat: row.lat,
    lng: row.lng,
    dedupe_key: `address:${hash(normalizeText(row.address))}`,
    source_system: sourceSystem,
    legacy_data: mergeLegacyData(null, row.original, sourceSystem)
  };
}

function clientKey(row: NormalizedClientRow, sourceSystem: string) {
  const phone = normalizePhone(row.phone);
  if (phone) return `phone:${phone}`;
  if (row.legacyId) return `legacy:${hash(`${sourceSystem}|${row.legacyId}`)}`;
  if (row.email) return `email:${normalizeText(row.email)}`;
  return `person:${hash(`${normalizeText(row.fullName)}|${normalizeText(row.address)}`)}`;
}

function orderClientKey(row: NormalizedOrderRow, sourceSystem: string) {
  const phone = normalizePhone(row.phone);
  if (phone) return `phone:${phone}`;
  if (row.legacyId) return `legacy-order-client:${hash(`${sourceSystem}|${row.legacyId}`)}`;
  return `person:${hash(`${normalizeText(row.clientName)}|${normalizeText(row.address)}`)}`;
}

function organizationKey(row: NormalizedOrganizationRow, sourceSystem: string) {
  if (row.inn) return `inn:${row.inn.replace(/\D/g, "") || normalizeText(row.inn)}`;
  if (row.legacyId) return `legacy:${hash(`${sourceSystem}|${row.legacyId}`)}`;
  if (row.phone) return `org-phone:${normalizePhone(row.phone)}`;
  return `name:${hash(normalizeText(row.name))}`;
}

function orderOrganizationKey(row: NormalizedOrderRow, sourceSystem: string) {
  if (row.organizationInn) return `inn:${row.organizationInn.replace(/\D/g, "") || normalizeText(row.organizationInn)}`;
  if (row.legacyId) return `legacy-order-org:${hash(`${sourceSystem}|${row.legacyId}`)}`;
  return `name:${hash(normalizeText(row.organization))}`;
}

function orderNumber(row: NormalizedOrderRow, sourceSystem: string) {
  const supplied = limitedText(row.orderNumber, 64);
  if (supplied && supplied.length <= 64) return supplied;
  const seed = `${sourceSystem}|${row.legacyId ?? ""}|${JSON.stringify(row.original)}`;
  return `#IMP-${hash(seed).slice(0, 20).toUpperCase()}`;
}

function validationErrors(rows: { errors: string[] }[], offset: number) {
  return rows.flatMap((row, index) => row.errors.map((error) => `Строка ${offset + index + 1}: ${error}`));
}

function databaseFailure(rowCount: number, message: string, offset: number): BatchResult {
  return counts(0, 0, 0, rowCount, [`Строки ${offset + 1}–${offset + rowCount}: ${message}`]);
}

function counts(imported: number, updated: number, skipped: number, failed: number, errors: string[]): BatchResult {
  return { imported, updated, skipped, failed, errors };
}

function mergeLegacyData(existing: unknown, original: LegacyRawRow, sourceSystem: string) {
  const base = existing && typeof existing === "object" && !Array.isArray(existing) ? existing as Record<string, unknown> : {};
  return { ...base, ...original, _import_source: sourceSystem };
}

function rawRows(value: unknown, limit: number): LegacyRawRow[] | null {
  if (!Array.isArray(value) || value.length > limit) return null;
  const valid = value.filter((row): row is LegacyRawRow => Boolean(row) && typeof row === "object" && !Array.isArray(row));
  return valid.length === value.length ? valid : null;
}

function importEntity(value: unknown): LegacyImportEntity | null {
  return value === "clients" || value === "organizations" || value === "orders" ? value : null;
}

function integer(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) ? value : null;
}

function limitedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (!text) return null;
  if (text.length <= maxLength) return text;
  const suffix = hash(text).slice(0, 12);
  return `${text.slice(0, Math.max(1, maxLength - suffix.length - 1))}-${suffix}`;
}

function normalizeText(value: unknown) {
  return String(value ?? "").trim().toLocaleLowerCase("ru-RU").replace(/\s+/g, " ");
}

function hash(value: string) {
  return createHash("sha256").update(value).digest("hex").slice(0, 40);
}
