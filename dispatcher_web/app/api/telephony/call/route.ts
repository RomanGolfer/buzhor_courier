import { NextResponse } from "next/server";
import { getApiStaffContext } from "@/lib/auth";
import { checkRateLimit, rateLimitKey } from "@/lib/security/rate-limit";
import {
  getTelephonyProviderName,
  normalizePhoneForTelephony,
  placeTelephonyCall
} from "@/lib/telephony";

const TELEPHONY_CALL_RATE_LIMIT = 20;
const TELEPHONY_CALL_RATE_WINDOW_MS = 60_000;

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const context = await getApiStaffContext();
  if (!context) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const rateLimit = await checkRateLimit({
    key: rateLimitKey("telephony-call", request.headers, context.user.id),
    limit: TELEPHONY_CALL_RATE_LIMIT,
    windowMs: TELEPHONY_CALL_RATE_WINDOW_MS
  });

  if (rateLimit.unavailable) {
    return NextResponse.json({ error: "rate_limit_unavailable" }, { status: 503 });
  }
  if (rateLimit.limited) {
    return NextResponse.json(
      { error: "rate_limited" },
      {
        headers: {
          "Retry-After": String(rateLimit.retryAfterSeconds)
        },
        status: 429
      }
    );
  }

  const body = await readRequestBody(request);
  const rawOrderId = getString(body, "order_id");
  if (rawOrderId && !isUuid(rawOrderId)) {
    return NextResponse.json({ error: "invalid_order_id" }, { status: 400 });
  }

  const orderId = rawOrderId;
  const requestedPhone = getString(body, "phone");
  let orderPhone: string | null = null;

  if (orderId) {
    const { data: order, error } = await context.supabase
      .from("orders")
      .select("id, client_phone")
      .eq("id", orderId)
      .maybeSingle();

    if (error) {
      console.warn("Telephony order lookup failed", error);
      return NextResponse.json({ error: "order_lookup_failed" }, { status: 500 });
    }
    if (!order) {
      return NextResponse.json({ error: "order_not_found" }, { status: 404 });
    }
    orderPhone = typeof order.client_phone === "string" ? order.client_phone : null;
  }

  const phone = normalizePhoneForTelephony(requestedPhone ?? orderPhone);
  if (!phone) {
    return NextResponse.json({ error: "invalid_phone" }, { status: 400 });
  }

  const provider = getTelephonyProviderName();
  const { data: callEvent, error: insertError } = await context.supabase
    .from("call_events")
    .insert({
      client_phone: phone,
      direction: "outbound",
      dispatcher_profile_id: context.user.id,
      event_type: "outbound_requested",
      order_id: orderId,
      payload: {
        source: "dispatcher_panel"
      },
      provider
    })
    .select("id")
    .single();

  if (insertError) {
    console.warn("Telephony call event insert failed", insertError);
    return NextResponse.json({ error: "call_event_insert_failed" }, { status: 500 });
  }

  const result = await placeTelephonyCall({
    dispatcherProfileId: context.user.id,
    orderId,
    phone
  });

  const updatePayload = result.ok
    ? {
        event_type: "outbound_requested",
        payload: {
          provider_call_id: result.providerCallId,
          source: "dispatcher_panel"
        },
        provider_call_id: result.providerCallId
      }
    : {
        event_type: "failed",
        payload: {
          error: result.error,
          source: "dispatcher_panel",
          status: result.status
        }
      };

  await context.supabase
    .from("call_events")
    .update(updatePayload)
    .eq("id", callEvent.id);

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  return NextResponse.json({
    call_event_id: callEvent.id,
    provider: result.provider,
    provider_call_id: result.providerCallId,
    status: "queued"
  });
}

async function readRequestBody(request: Request) {
  try {
    const body = await request.json();
    return body && typeof body === "object" && !Array.isArray(body) ? (body as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function getString(body: Record<string, unknown>, key: string) {
  const value = body[key];
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
