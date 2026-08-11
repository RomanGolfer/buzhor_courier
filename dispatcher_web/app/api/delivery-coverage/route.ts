import { NextResponse } from "next/server";
import { checkRateLimit, rateLimitKey } from "@/lib/security/rate-limit";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { DeliveryCoverage, Profile } from "@/lib/types";

const COVERAGE_RATE_LIMIT = 120;
const COVERAGE_RATE_WINDOW_MS = 60_000;

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) return coverageResponse({ error: "unauthorized" }, { status: 401 });

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, is_active")
    .eq("id", user.id)
    .single();
  const staffProfile = profile as Pick<Profile, "role" | "is_active"> | null;
  if (!staffProfile?.is_active || !["dispatcher", "admin"].includes(staffProfile.role)) {
    return coverageResponse({ error: "forbidden" }, { status: 403 });
  }

  const rateLimit = await checkRateLimit({
    key: rateLimitKey("delivery-coverage", request.headers, user.id),
    limit: COVERAGE_RATE_LIMIT,
    windowMs: COVERAGE_RATE_WINDOW_MS
  });

  if (rateLimit.unavailable) return coverageResponse({ error: "rate_limit_unavailable" }, { status: 503 });
  if (rateLimit.limited) {
    return coverageResponse(
      { error: "rate_limited" },
      {
        headers: { "Retry-After": String(rateLimit.retryAfterSeconds) },
        status: 429
      }
    );
  }

  const { searchParams } = new URL(request.url);
  const lat = parseCoordinate(searchParams.get("lat"), -90, 90);
  const lng = parseCoordinate(searchParams.get("lng"), -180, 180);
  if (lat === null || lng === null) {
    return coverageResponse({ error: "invalid_coordinates" }, { status: 400 });
  }

  const { data, error } = await supabase.rpc("check_delivery_coverage", {
    p_lat: lat,
    p_lng: lng
  });

  if (error) {
    console.warn("Delivery coverage lookup failed", error.code);
    return coverageResponse({ error: "coverage_lookup_failed" }, { status: 500 });
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) return coverageResponse({ error: "coverage_lookup_failed" }, { status: 500 });
  return coverageResponse(row as DeliveryCoverage);
}

function parseCoordinate(value: string | null, minimum: number, maximum: number) {
  if (value === null || value.trim() === "") return null;
  const number = Number(value);
  return Number.isFinite(number) && number >= minimum && number <= maximum ? number : null;
}

function coverageResponse(body: unknown, init: ResponseInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("Cache-Control", "no-store");
  return NextResponse.json(body, { ...init, headers });
}
