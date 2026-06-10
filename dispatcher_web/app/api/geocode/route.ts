import { NextResponse } from "next/server";
import { checkRateLimit, rateLimitKey } from "@/lib/security/rate-limit";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

type NominatimResult = {
  lat: string;
  lon: string;
};

const GEOCODE_RATE_LIMIT = 30;
const GEOCODE_RATE_WINDOW_MS = 60_000;

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return geocodeResponse([], { status: 401 });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, is_active")
    .eq("id", user.id)
    .single();

  const staffProfile = profile as Pick<Profile, "role" | "is_active"> | null;
  if (
    !staffProfile?.is_active ||
    !["dispatcher", "admin"].includes(staffProfile.role)
  ) {
    return geocodeResponse([], { status: 403 });
  }

  const rateLimit = await checkRateLimit({
    key: rateLimitKey("geocode", request.headers, user.id),
    limit: GEOCODE_RATE_LIMIT,
    windowMs: GEOCODE_RATE_WINDOW_MS
  });

  if (rateLimit.unavailable) {
    return geocodeResponse([], { status: 503 });
  }

  if (rateLimit.limited) {
    return geocodeResponse([], {
      headers: {
        "Retry-After": String(rateLimit.retryAfterSeconds)
      },
      status: 429
    });
  }

  const { searchParams } = new URL(request.url);
  const query = searchParams.get("q")?.trim();

  if (!query) {
    return geocodeResponse([]);
  }
  if (query.length < 3 || query.length > 120) {
    return geocodeResponse([], { status: 400 });
  }

  const userAgent = getNominatimUserAgent();
  if (!userAgent) {
    return geocodeResponse([], { status: 503 });
  }

  const nominatimUrl = new URL("https://nominatim.openstreetmap.org/search");
  nominatimUrl.searchParams.set("q", query);
  nominatimUrl.searchParams.set("format", "json");
  nominatimUrl.searchParams.set("limit", "1");
  nominatimUrl.searchParams.set("countrycodes", "ru");

  const response = await fetch(nominatimUrl, {
    cache: "no-store",
    headers: {
      Accept: "application/json",
      "User-Agent": userAgent
    }
  });

  if (!response.ok) {
    return geocodeResponse([], { status: response.status });
  }

  const data = await response.json();
  const coordinates = normalizeNominatimResults(data);
  return geocodeResponse(coordinates);
}

function normalizeNominatimResults(data: unknown): NominatimResult[] {
  if (!Array.isArray(data)) return [];

  return data
    .flatMap((item): NominatimResult[] => {
      if (!item || typeof item !== "object") return [];
      const lat = "lat" in item ? item.lat : null;
      const lon = "lon" in item ? item.lon : null;
      if (typeof lat !== "string" || typeof lon !== "string") return [];
      if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lon))) return [];
      return [{ lat, lon }];
    })
    .slice(0, 1);
}

function getNominatimUserAgent(): string | null {
  const configured = process.env.NOMINATIM_USER_AGENT?.trim();
  if (configured) return configured;

  if (process.env.NODE_ENV !== "production") {
    return "buzhor-dispatcher-dev/1.0";
  }

  console.error("NOMINATIM_USER_AGENT must be configured for production geocoding.");
  return null;
}

function geocodeResponse(body: NominatimResult[], init: ResponseInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("Cache-Control", "no-store");
  return NextResponse.json(body, { ...init, headers });
}
