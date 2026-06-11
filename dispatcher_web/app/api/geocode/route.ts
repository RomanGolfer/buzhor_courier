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
  match_type: GeocodeMatchType;
};

type GeocodeMatchType = "exact" | "nearby";

type InternalNominatimResult = NominatimResult & {
  house_number: string | null;
  house_distance: number | null;
  road: string | null;
};

type ParsedAddressQuery = {
  houseBase: number | null;
  houseNumber: string;
  houseNumberKey: string;
  localityParts: string[];
  roadKey: string | null;
  roadPart: string;
};

const GEOCODE_RATE_LIMIT = 30;
const GEOCODE_RATE_WINDOW_MS = 60_000;
const ANAPA_CENTER = { lat: 44.8951, lng: 37.3168 };
const GEOCODE_LIMIT = 6;
const NEARBY_VIEWBOX_DEGREES = 0.45;
const NEARBY_HOUSE_QUERY_LIMIT = 6;

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
  const parsedAddress = parseAddressQuery(query);
  const merged = await fetchAndNormalizeNominatim(buildSearchQueries(query), origin, userAgent, parsedAddress);
  const ranked = rankResults(merged, parsedAddress);

  if (ranked.length > 0) {
    return ranked.slice(0, GEOCODE_LIMIT).map(toPublicResult);
  }

  if (!parsedAddress) return [];

  const fallbackQueries = buildNearbyHouseQueries(parsedAddress);
  if (fallbackQueries.length === 0) return [];

  const fallbackResults = await fetchAndNormalizeNominatim(fallbackQueries, origin, userAgent, parsedAddress);
  return rankResults(fallbackResults, parsedAddress)
    .slice(0, GEOCODE_LIMIT)
    .map((result) => toPublicResult({ ...result, match_type: "nearby" }));
}

async function fetchAndNormalizeNominatim(
  queries: string[],
  origin: { lat: number; lng: number },
  userAgent: string,
  parsedAddress: ParsedAddressQuery | null
) {
  const responses = await Promise.all(
    queries.map(async (searchQuery) => {
      return fetchNominatim(searchQuery, origin, userAgent);
    })
  );

  return dedupeResults(responses.flatMap((data) => normalizeNominatimResults(data, origin, parsedAddress)));
}

async function fetchNominatim(searchQuery: string, origin: { lat: number; lng: number }, userAgent: string) {
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
}

function buildSearchQueries(query: string) {
  const normalizedQuery = query.replace(/\s+/g, " ").trim();
  if (hasExplicitLocality(normalizedQuery)) return [normalizedQuery];
  return [`${normalizedQuery}, Анапа, Краснодарский край`, normalizedQuery];
}

function buildNearbyHouseQueries(parsedAddress: ParsedAddressQuery) {
  if (parsedAddress.houseBase === null || !parsedAddress.roadPart) return [];

  const candidateNumbers = nearbyHouseNumbers(parsedAddress.houseBase);
  const queries = candidateNumbers.map((houseNumber) => {
    const address = [parsedAddress.roadPart, String(houseNumber), ...parsedAddress.localityParts].filter(Boolean).join(", ");
    return hasExplicitLocality(address) ? address : `${address}, Анапа, Краснодарский край`;
  });

  return [...new Set(queries)].slice(0, NEARBY_HOUSE_QUERY_LIMIT);
}

function nearbyHouseNumbers(base: number) {
  const numbers = [base];
  for (let offset = 1; numbers.length < NEARBY_HOUSE_QUERY_LIMIT; offset += 1) {
    if (base - offset > 0) numbers.push(base - offset);
    if (numbers.length < NEARBY_HOUSE_QUERY_LIMIT) numbers.push(base + offset);
  }
  return numbers;
}

function hasExplicitLocality(query: string) {
  return /\b(?:анапа|гостагаевская|супсех|витязево|джемете|краснодарский\s+край|город|село|поселок|посёлок|станица|район)\b/i.test(
    query
  );
}

function parseAddressQuery(query: string): ParsedAddressQuery | null {
  const normalizedQuery = query.replace(/\s+/g, " ").trim();
  if (!normalizedQuery) return null;

  const parts = normalizedQuery
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);

  for (let index = 1; index < parts.length; index += 1) {
    if (isAddressDetailPart(parts[index])) continue;
    const houseNumber = extractHouseNumber(parts[index]);
    if (!houseNumber) continue;

    const roadPart = parts.slice(0, index).join(", ").trim();
    const localityParts = parts.slice(index + 1).filter((part) => !isAddressDetailPart(part));
    return buildParsedAddress(roadPart, houseNumber, localityParts);
  }

  const inlineHouse = extractInlineHouseNumber(stripInlineAddressDetails(normalizedQuery));
  if (!inlineHouse) return null;

  return buildParsedAddress(inlineHouse.roadPart, inlineHouse.houseNumber, []);
}

function buildParsedAddress(roadPart: string, houseNumber: string, localityParts: string[]): ParsedAddressQuery | null {
  const houseNumberKey = normalizeHouseNumber(houseNumber);
  if (!roadPart || !houseNumberKey) return null;

  return {
    houseBase: houseBaseNumber(houseNumber),
    houseNumber,
    houseNumberKey,
    localityParts,
    roadKey: normalizeRoadName(roadPart),
    roadPart
  };
}

function extractHouseNumber(value: string) {
  const match = value.match(/(?:^|[^\p{L}\p{N}_])(?:д(?:ом)?\.?\s*)?(\d+(?:[-/]\d+)?\s*[a-zа-яё]?)(?=$|[^\p{L}\p{N}_])/iu);
  return match?.[1]?.replace(/\s+/g, "").trim() || null;
}

function extractInlineHouseNumber(value: string) {
  const matches = [
    ...value.matchAll(/(?:^|[^\p{L}\p{N}_])(?:д(?:ом)?\.?\s*)?(\d+(?:[-/]\d+)?\s*[a-zа-яё]?)(?=$|[^\p{L}\p{N}_])/giu)
  ];
  const match = matches.at(-1);
  if (!match?.[1]) return null;

  const houseStart = (match.index ?? 0) + (match[0].indexOf(match[1]) ?? 0);
  const roadPart = value.slice(0, houseStart).replace(/[,\s]+$/g, "").trim();
  const houseNumber = match[1].replace(/\s+/g, "").trim();
  if (!roadPart || !houseNumber || isAddressDetailPart(roadPart)) return null;

  return { houseNumber, roadPart };
}

function isAddressDetailPart(value: string) {
  return /^(?:кв\.?|квартира|п\.?|подъезд|эт\.?|этаж|офис)\b/i.test(value.trim());
}

function stripInlineAddressDetails(value: string) {
  return value
    .replace(/(?:^|[,\s]+)(?:кв\.?|квартира|п\.?|подъезд|эт\.?|этаж|офис)\s*\d+.*$/iu, "")
    .trim();
}

function normalizeNominatimResults(
  data: unknown,
  origin: { lat: number; lng: number },
  parsedAddress: ParsedAddressQuery | null
): InternalNominatimResult[] {
  if (!Array.isArray(data)) return [];

  return data.flatMap((item): InternalNominatimResult[] => {
    if (!item || typeof item !== "object") return [];
    const lat = "lat" in item ? item.lat : null;
    const lon = "lon" in item ? item.lon : null;
    const displayName = "display_name" in item ? item.display_name : null;
    if (typeof lat !== "string" || typeof lon !== "string") return [];
    if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lon))) return [];

    const address = "address" in item && isRecord(item.address) ? item.address : {};
    const locality = getAddressPart(address, ["city", "town", "village", "municipality", "county"]);
    const houseNumber = getAddressPart(address, ["house_number"]);
    const road = getAddressPart(address, ["road", "pedestrian", "footway", "path"]);
    const { addressLine, label } = buildResultAddress(address, typeof displayName === "string" ? displayName : "");
    const matchType = parsedAddress && !isExactHouseMatch(houseNumber, road, parsedAddress) ? "nearby" : "exact";

    return [
      {
        lat,
        lon,
        display_name: typeof displayName === "string" ? displayName : label,
        label,
        address_line: addressLine,
        locality,
        distance_m: Math.round(distanceMeters(origin, { lat: Number(lat), lng: Number(lon) })),
        match_type: matchType,
        house_number: houseNumber,
        house_distance: houseDistance(houseNumber, parsedAddress),
        road
      }
    ];
  });
}

function dedupeResults(results: InternalNominatimResult[]) {
  const seen = new Set<string>();
  return results.filter((result) => {
    const key = `${Number(result.lat).toFixed(5)}:${Number(result.lon).toFixed(5)}:${result.label}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function rankResults(results: InternalNominatimResult[], parsedAddress: ParsedAddressQuery | null) {
  const candidates = parsedAddress
    ? results.filter((result) => isHouseLevelResult(result) && isSameRoad(result.road, parsedAddress))
    : results;

  return candidates.sort((left, right) => {
    if (left.match_type !== right.match_type) return left.match_type === "exact" ? -1 : 1;
    return (
      (left.house_distance ?? Number.MAX_SAFE_INTEGER) - (right.house_distance ?? Number.MAX_SAFE_INTEGER) ||
      (left.distance_m ?? Number.MAX_SAFE_INTEGER) - (right.distance_m ?? Number.MAX_SAFE_INTEGER)
    );
  });
}

function toPublicResult(result: InternalNominatimResult): NominatimResult {
  return {
    lat: result.lat,
    lon: result.lon,
    display_name: result.display_name,
    label: result.label,
    address_line: result.address_line,
    locality: result.locality,
    distance_m: result.distance_m,
    match_type: result.match_type
  };
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

function isHouseLevelResult(result: InternalNominatimResult) {
  return Boolean(result.house_number);
}

function isExactHouseMatch(houseNumber: string | null, road: string | null, parsedAddress: ParsedAddressQuery) {
  return isSameRoad(road, parsedAddress) && normalizeHouseNumber(houseNumber) === parsedAddress.houseNumberKey;
}

function isSameRoad(road: string | null, parsedAddress: ParsedAddressQuery) {
  if (!parsedAddress.roadKey) return true;
  const roadKey = normalizeRoadName(road);
  if (!roadKey) return false;
  return roadKey === parsedAddress.roadKey || roadKey.includes(parsedAddress.roadKey) || parsedAddress.roadKey.includes(roadKey);
}

function houseDistance(houseNumber: string | null, parsedAddress: ParsedAddressQuery | null) {
  if (!parsedAddress?.houseBase) return null;
  const resultBase = houseBaseNumber(houseNumber);
  return resultBase === null ? null : Math.abs(resultBase - parsedAddress.houseBase);
}

function houseBaseNumber(value: string | null) {
  const match = normalizeHouseNumber(value).match(/^(\d+)/);
  if (!match?.[1]) return null;
  const number = Number(match[1]);
  return Number.isFinite(number) ? number : null;
}

function normalizeHouseNumber(value: string | null) {
  return (value ?? "")
    .toLocaleLowerCase("ru-RU")
    .replace(/ё/g, "е")
    .replace(/[acekopx]/g, (letter) => {
      const replacements: Record<string, string> = {
        a: "а",
        c: "с",
        e: "е",
        k: "к",
        o: "о",
        p: "р",
        x: "х"
      };
      return replacements[letter] ?? letter;
    })
    .replace(/\s+/g, "")
    .trim();
}

function normalizeRoadName(value: string | null) {
  const normalized = (value ?? "")
    .toLocaleLowerCase("ru-RU")
    .replace(/ё/g, "е")
    .replace(
      /\b(?:ул\.?|улица|пер\.?|переулок|просп\.?|проспект|пр-т|проезд|шоссе|бульвар|бул\.?|набережная|наб\.?|тупик|аллея)\b/giu,
      " "
    )
    .replace(/[^\p{L}\p{N}]+/gu, "");

  return normalized || null;
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
