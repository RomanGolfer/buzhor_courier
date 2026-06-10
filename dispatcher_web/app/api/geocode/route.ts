import { NextResponse } from "next/server";
import { checkRateLimit, rateLimitKey } from "@/lib/security/rate-limit";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

type NominatimResult = {
  lat: string;
  lon: string;
  display_name: string;
  label: string;
  address_line: string;
  locality: string | null;
  distance_m: number | null;
};

const GEOCODE_RATE_LIMIT = 30;
const GEOCODE_RATE_WINDOW_MS = 60_000;
const ANAPA_CENTER = { lat: 44.8951, lng: 37.3168 };
const GEOCODE_LIMIT = 6;
const NEARBY_VIEWBOX_DEGREES = 0.45;

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
  const origin = {
    lat: parseCoordinate(searchParams.get("lat"), -90, 90) ?? ANAPA_CENTER.lat,
    lng: parseCoordinate(searchParams.get("lng"), -180, 180) ?? ANAPA_CENTER.lng
  };

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

  const coordinates = await searchNominatim(query, origin, userAgent);
  return geocodeResponse(coordinates);
}

async function searchNominatim(query: string, origin: { lat: number; lng: number }, userAgent: string) {
  const queries = buildSearchQueries(query);
  const responses = await Promise.all(
    queries.map(async (searchQuery) => {
      const nominatimUrl = new URL("https://nominatim.openstreetmap.org/search");
      nominatimUrl.searchParams.set("q", searchQuery);
      nominatimUrl.searchParams.set("format", "jsonv2");
      nominatimUrl.searchParams.set("limit", String(GEOCODE_LIMIT));
      nominatimUrl.searchParams.set("countrycodes", "ru");
      nominatimUrl.searchParams.set("addressdetails", "1");
      nominatimUrl.searchParams.set("accept-language", "ru");
      nominatimUrl.searchParams.set(
        "viewbox",
        [
          (origin.lng - NEARBY_VIEWBOX_DEGREES).toFixed(5),
          (origin.lat + NEARBY_VIEWBOX_DEGREES).toFixed(5),
          (origin.lng + NEARBY_VIEWBOX_DEGREES).toFixed(5),
          (origin.lat - NEARBY_VIEWBOX_DEGREES).toFixed(5)
        ].join(",")
      );

      const response = await fetch(nominatimUrl, {
        cache: "no-store",
        headers: {
          Accept: "application/json",
          "User-Agent": userAgent
        }
      });

      if (!response.ok) {
        console.warn(`Nominatim geocoding failed with ${response.status}`);
        return [];
      }

      return response.json();
    })
  );

  const merged = responses.flatMap((data) => normalizeNominatimResults(data, origin));
  return dedupeResults(merged)
    .sort((left, right) => (left.distance_m ?? Number.MAX_SAFE_INTEGER) - (right.distance_m ?? Number.MAX_SAFE_INTEGER))
    .slice(0, GEOCODE_LIMIT);
}

function buildSearchQueries(query: string) {
  const normalizedQuery = query.replace(/\s+/g, " ").trim();
  if (hasExplicitLocality(normalizedQuery)) return [normalizedQuery];
  return [`${normalizedQuery}, Анапа, Краснодарский край`, normalizedQuery];
}

function hasExplicitLocality(query: string) {
  return /\b(?:анапа|гостагаевская|супсех|витязево|джемете|краснодарский\s+край|город|село|поселок|посёлок|станица|район)\b/i.test(
    query
  );
}

function normalizeNominatimResults(data: unknown, origin: { lat: number; lng: number }): NominatimResult[] {
  if (!Array.isArray(data)) return [];

  return data.flatMap((item): NominatimResult[] => {
    if (!item || typeof item !== "object") return [];
    const lat = "lat" in item ? item.lat : null;
    const lon = "lon" in item ? item.lon : null;
    const displayName = "display_name" in item ? item.display_name : null;
    if (typeof lat !== "string" || typeof lon !== "string") return [];
    if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lon))) return [];

    const address = "address" in item && isRecord(item.address) ? item.address : {};
    const locality = getAddressPart(address, ["city", "town", "village", "municipality", "county"]);
    const { addressLine, label } = buildResultAddress(address, typeof displayName === "string" ? displayName : "");

    return [
      {
        lat,
        lon,
        display_name: typeof displayName === "string" ? displayName : label,
        label,
        address_line: addressLine,
        locality,
        distance_m: Math.round(distanceMeters(origin, { lat: Number(lat), lng: Number(lon) }))
      }
    ];
  });
}

function dedupeResults(results: NominatimResult[]) {
  const seen = new Set<string>();
  return results.filter((result) => {
    const key = `${Number(result.lat).toFixed(5)}:${Number(result.lon).toFixed(5)}:${result.label}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function buildResultAddress(address: Record<string, unknown>, displayName: string) {
  const road = getAddressPart(address, ["road", "pedestrian", "footway", "path"]);
  const house = getAddressPart(address, ["house_number"]);
  const locality = getAddressPart(address, ["city", "town", "village", "municipality", "county"]);
  const district = getAddressPart(address, ["suburb", "city_district", "district"]);
  const streetLine = [road, house].filter(Boolean).join(", ") || displayName;
  const placeLine = [locality, district].filter(Boolean).join(", ");
  const label = [placeLine, streetLine].filter(Boolean).join(" · ");
  return {
    addressLine: streetLine || "Найденный адрес",
    label: label || streetLine || "Найденный адрес"
  };
}

function getAddressPart(address: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = address[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object";
}

function parseCoordinate(value: string | null, min: number, max: number) {
  if (value === null) return null;
  const coordinate = Number(value);
  if (!Number.isFinite(coordinate) || coordinate < min || coordinate > max) return null;
  return coordinate;
}

function distanceMeters(from: { lat: number; lng: number }, to: { lat: number; lng: number }) {
  const earthRadiusMeters = 6_371_000;
  const fromLat = toRadians(from.lat);
  const toLat = toRadians(to.lat);
  const latDelta = toRadians(to.lat - from.lat);
  const lngDelta = toRadians(to.lng - from.lng);
  const a =
    Math.sin(latDelta / 2) * Math.sin(latDelta / 2) +
    Math.cos(fromLat) * Math.cos(toLat) * Math.sin(lngDelta / 2) * Math.sin(lngDelta / 2);
  return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRadians(degrees: number) {
  return (degrees * Math.PI) / 180;
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
