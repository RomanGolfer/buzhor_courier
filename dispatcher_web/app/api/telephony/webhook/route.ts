import { NextResponse } from "next/server";
import { createServiceSupabaseClient } from "@/lib/supabase/service";
import {
  getTelephonyProviderName,
  normalizePhoneForTelephony
} from "@/lib/telephony";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  if (!isAuthorizedWebhook(request)) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  let supabase: ReturnType<typeof createServiceSupabaseClient>;
  try {
    supabase = createServiceSupabaseClient();
  } catch (error) {
    console.warn("Telephony webhook service client unavailable", error);
    return NextResponse.json({ error: "service_client_unavailable" }, { status: 503 });
  }

  const body = await readRequestBody(request);
  const provider = limitText(getString(body, ["provider"]) ?? getTelephonyProviderName(), 64);
  const providerCallId = limitText(getString(body, ["provider_call_id", "call_id", "id"]), 160);
  const eventType = limitText(getString(body, ["event_type", "status", "state"]) ?? "ringing", 80);
  const direction = getDirection(body);
  const phone = normalizePhoneForTelephony(getString(body, ["client_phone", "phone", "from", "caller"]));
  const providedOrderId = getString(body, ["order_id"]);
  const linkedOrder = providedOrderId
    ? await loadOrderById(supabase, providedOrderId)
    : phone
      ? await loadLatestOrderByPhone(supabase, phone)
      : null;

  const event = {
    answered_at: getTimestamp(body, ["answered_at", "answeredAt"]),
    client_phone: phone,
    courier_id: linkedOrder?.assigned_courier_id ?? null,
    direction,
    duration_seconds: getInteger(body, ["duration_seconds", "duration", "billsec"]),
    ended_at: getTimestamp(body, ["ended_at", "endedAt"]),
    event_type: eventType,
    order_id: linkedOrder?.id ?? (providedOrderId && isUuid(providedOrderId) ? providedOrderId : null),
    payload: sanitizePayload(body),
    provider,
    provider_call_id: providerCallId,
    recording_url: limitText(getString(body, ["recording_url", "recordingUrl", "record_url"]), 2048),
    started_at: getTimestamp(body, ["started_at", "startedAt", "timestamp"])
  };

  const query =
    providerCallId === null
      ? supabase.from("call_events").insert(event).select("id").single()
      : supabase
          .from("call_events")
          .upsert(event, { onConflict: "provider,provider_call_id" })
          .select("id")
          .single();

  const { data, error } = await query;
  if (error) {
    console.warn("Telephony webhook insert failed", error);
    return NextResponse.json({ error: "call_event_write_failed" }, { status: 500 });
  }

  return NextResponse.json({
    call_event_id: data.id,
    linked_order_id: event.order_id,
    ok: true
  });
}

function isAuthorizedWebhook(request: Request) {
  const expectedSecret = process.env.TELEPHONY_WEBHOOK_SECRET?.trim();
  if (!expectedSecret) return false;

  const headerSecret = request.headers.get("x-telephony-secret")?.trim();
  const bearerSecret = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
  return headerSecret === expectedSecret || bearerSecret === expectedSecret;
}

async function loadOrderById(supabase: ReturnType<typeof createServiceSupabaseClient>, orderId: string) {
  if (!isUuid(orderId)) return null;

  const { data } = await supabase
    .from("orders")
    .select("id, assigned_courier_id")
    .eq("id", orderId)
    .maybeSingle();

  return data as { id: string; assigned_courier_id: string | null } | null;
}

async function loadLatestOrderByPhone(supabase: ReturnType<typeof createServiceSupabaseClient>, phone: string) {
  const { data } = await supabase
    .from("orders")
    .select("id, assigned_courier_id")
    .eq("client_phone_normalized", phone)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  return data as { id: string; assigned_courier_id: string | null } | null;
}

async function readRequestBody(request: Request) {
  try {
    const body = await request.json();
    return body && typeof body === "object" && !Array.isArray(body) ? (body as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function getDirection(body: Record<string, unknown>) {
  const direction = getString(body, ["direction"]);
  return direction === "outbound" ? "outbound" : "inbound";
}

function getString(body: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = body[key];
    if (typeof value === "string" && value.trim()) return value.trim();
    if (typeof value === "number" && Number.isFinite(value)) return String(value);
  }
  return null;
}

function getInteger(body: Record<string, unknown>, keys: string[]) {
  const value = getString(body, keys);
  if (value === null) return null;
  const number = Number(value);
  return Number.isInteger(number) && number >= 0 ? number : null;
}

function limitText(value: string | null, maxLength: number) {
  if (!value) return null;
  return value.slice(0, maxLength);
}

function getTimestamp(body: Record<string, unknown>, keys: string[]) {
  const value = getString(body, keys);
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function sanitizePayload(body: Record<string, unknown>) {
  const payload = { ...body };
  delete payload.secret;
  delete payload.token;
  delete payload.password;
  return payload;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
