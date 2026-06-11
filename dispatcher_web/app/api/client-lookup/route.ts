import { NextResponse } from "next/server";
import { checkRateLimit, rateLimitKey } from "@/lib/security/rate-limit";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { PaymentMethod, Profile } from "@/lib/types";

type ClientLookupOrder = {
  id: string;
  order_number: string;
  assigned_courier_id: string | null;
  client_name: string;
  client_phone: string | null;
  address: string;
  district: string | null;
  lat: number | string | null;
  lng: number | string | null;
  payment_method: PaymentMethod;
  bottles: number | null;
  time_slot: string | null;
  delivery_comment: string | null;
  updated_at: string;
};

const CLIENT_LOOKUP_RATE_LIMIT = 60;
const CLIENT_LOOKUP_RATE_WINDOW_MS = 60_000;
const CLIENT_LOOKUP_SCAN_LIMIT = 1000;
const DEFAULT_COORDINATE_PAIR = {
  lat: 44.8951,
  lng: 37.3168
};

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return clientLookupResponse({ found: false }, { status: 401 });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, is_active")
    .eq("id", user.id)
    .single();

  const staffProfile = profile as Pick<Profile, "role" | "is_active"> | null;
  if (!staffProfile?.is_active || !["dispatcher", "admin"].includes(staffProfile.role)) {
    return clientLookupResponse({ found: false }, { status: 403 });
  }

  const rateLimit = await checkRateLimit({
    key: rateLimitKey("client-lookup", request.headers, user.id),
    limit: CLIENT_LOOKUP_RATE_LIMIT,
    windowMs: CLIENT_LOOKUP_RATE_WINDOW_MS
  });

  if (rateLimit.unavailable) {
    return clientLookupResponse({ found: false }, { status: 503 });
  }

  if (rateLimit.limited) {
    return clientLookupResponse(
      { found: false },
      {
        headers: {
          "Retry-After": String(rateLimit.retryAfterSeconds)
        },
        status: 429
      }
    );
  }

  const { searchParams } = new URL(request.url);
  const phone = normalizeClientPhone(searchParams.get("phone"));
  if (!phone || phone.length < 11) {
    return clientLookupResponse({ found: false });
  }

  const { data, error } = await supabase
    .from("orders")
    .select(
      "id, order_number, assigned_courier_id, client_name, client_phone, address, district, lat, lng, payment_method, bottles, time_slot, delivery_comment, updated_at"
    )
    .not("client_phone", "is", null)
    .order("updated_at", { ascending: false })
    .limit(CLIENT_LOOKUP_SCAN_LIMIT);

  if (error) {
    console.warn("Client lookup failed", error);
    return clientLookupResponse({ found: false }, { status: 500 });
  }

  const matches = ((data ?? []) as ClientLookupOrder[]).filter((order) => normalizeClientPhone(order.client_phone) === phone);
  if (matches.length === 0) {
    return clientLookupResponse({ found: false });
  }

  return clientLookupResponse({
    found: true,
    client: mergeClientOrders(matches)
  });
}

function mergeClientOrders(orders: ClientLookupOrder[]) {
  const latest = orders[0];
  const coordinates = firstCoordinatePair(orders);

  return {
    client_name: firstText(orders, "client_name") ?? latest.client_name,
    client_phone: latest.client_phone,
    address: firstText(orders, "address") ?? latest.address,
    district: firstText(orders, "district"),
    lat: coordinates?.lat ?? null,
    lng: coordinates?.lng ?? null,
    payment_method: latest.payment_method,
    bottles: Number.isFinite(Number(latest.bottles)) ? Number(latest.bottles) : null,
    time_slot: firstText(orders, "time_slot"),
    delivery_comment: firstText(orders, "delivery_comment"),
    assigned_courier_id: firstText(orders, "assigned_courier_id"),
    last_order_number: latest.order_number,
    last_order_updated_at: latest.updated_at,
    order_count: orders.length
  };
}

function firstText<K extends keyof ClientLookupOrder>(orders: ClientLookupOrder[], key: K) {
  for (const order of orders) {
    const value = order[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function firstCoordinatePair(orders: ClientLookupOrder[]) {
  for (const order of orders) {
    if (order.lat === null || order.lat === "" || order.lng === null || order.lng === "") continue;
    const lat = Number(order.lat);
    const lng = Number(order.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    if (isDefaultCoordinatePair(lat, lng)) continue;

    return {
      lat: lat.toFixed(7),
      lng: lng.toFixed(7)
    };
  }
  return null;
}

function isDefaultCoordinatePair(lat: number, lng: number) {
  return (
    Math.abs(lat - DEFAULT_COORDINATE_PAIR.lat) < 0.0000001 &&
    Math.abs(lng - DEFAULT_COORDINATE_PAIR.lng) < 0.0000001
  );
}

function normalizeClientPhone(value: string | null | undefined) {
  const digits = value?.replace(/\D/g, "") ?? "";
  if (!digits) return null;
  if (digits.length === 11 && digits.startsWith("8")) return `7${digits.slice(1)}`;
  if (digits.length === 10) return `7${digits}`;
  return digits;
}

function clientLookupResponse(body: unknown, init: ResponseInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("Cache-Control", "no-store");
  return NextResponse.json(body, { ...init, headers });
}
