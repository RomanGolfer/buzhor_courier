import { useEffect, useRef, useState } from "react";

const defaultOrigin = {
  lat: "44.8951000",
  lng: "37.3168000"
};
const geocodeDelayMs = 800;

type GeocodeResult = {
  lat: string;
  lon: string;
  display_name: string;
  label: string;
  address_line: string;
  locality: string | null;
  distance_m: number | null;
  match_type: "exact" | "nearby";
};

type GeocodeOrigin = {
  lat: string;
  lng: string;
};

export function useAddressGeocoding() {
  const [lat, setLat] = useState("");
  const [lng, setLng] = useState("");
  const [geocoding, setGeocoding] = useState(false);
  const [geocodeHint, setGeocodeHint] = useState<string | null>(null);
  const [geocodeResults, setGeocodeResults] = useState<GeocodeResult[]>([]);
  const origin = useRef<GeocodeOrigin>(defaultOrigin);
  const geocodeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const geocodeAbortController = useRef<AbortController | null>(null);
  const geocodeRequestId = useRef(0);
  const latestAddress = useRef("");
  const geocodeAddressRef = useRef<(address: string, originOverride?: GeocodeOrigin) => void>(() => undefined);

  useEffect(() => {
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const nextOrigin = {
            lat: position.coords.latitude.toFixed(7),
            lng: position.coords.longitude.toFixed(7)
          };
          origin.current = nextOrigin;
          if (latestAddress.current) {
            geocodeAddressRef.current(latestAddress.current, nextOrigin);
          }
        },
        () => undefined,
        { enableHighAccuracy: false, maximumAge: 300_000, timeout: 7_000 }
      );
    }

    return () => {
      if (geocodeTimer.current) {
        clearTimeout(geocodeTimer.current);
      }
      geocodeAbortController.current?.abort();
    };
  }, []);

  function clearPendingGeocode() {
    if (geocodeTimer.current) {
      clearTimeout(geocodeTimer.current);
      geocodeTimer.current = null;
    }

    geocodeAbortController.current?.abort();
  }

  function geocodeAddress(address: string, originOverride = origin.current) {
    clearPendingGeocode();
    const trimmedAddress = address.trim();
    latestAddress.current = trimmedAddress;

    if (!trimmedAddress) {
      setGeocoding(false);
      setGeocodeHint(null);
      setGeocodeResults([]);
      return;
    }

    setGeocoding(true);
    setGeocodeResults([]);
    const requestId = geocodeRequestId.current + 1;
    geocodeRequestId.current = requestId;

    geocodeTimer.current = setTimeout(async () => {
      await runGeocode(trimmedAddress, originOverride, requestId);
    }, geocodeDelayMs);
  }

  async function geocodeAddressNow(address: string, originOverride = origin.current) {
    clearPendingGeocode();
    const trimmedAddress = address.trim();
    latestAddress.current = trimmedAddress;

    if (!trimmedAddress) {
      setGeocoding(false);
      setGeocodeHint(null);
      setGeocodeResults([]);
      return null;
    }

    setGeocoding(true);
    setGeocodeResults([]);
    const requestId = geocodeRequestId.current + 1;
    geocodeRequestId.current = requestId;

    return runGeocode(trimmedAddress, originOverride, requestId);
  }

  geocodeAddressRef.current = geocodeAddress;

  async function runGeocode(address: string, originOverride: GeocodeOrigin, requestId: number) {
    const controller = new AbortController();
    geocodeAbortController.current = controller;

    try {
      const params = new URLSearchParams({
        q: address,
        lat: originOverride.lat,
        lng: originOverride.lng
      });
      const res = await fetch(`/api/geocode?${params.toString()}`, { signal: controller.signal });
      const data = (await res.json()) as GeocodeResult[];

      if (requestId !== geocodeRequestId.current) return null;

      setGeocodeResults(data);
      if (data.length > 0) {
        applyGeocodeResult(data[0], "Координаты определены автоматически");
        return data[0];
      }

      setGeocodeHint("Адрес не найден — введите координаты вручную");
      return null;
    } catch (fetchError) {
      if (fetchError instanceof DOMException && fetchError.name === "AbortError") return null;
      if (requestId === geocodeRequestId.current) {
        setGeocodeHint("Адрес не найден — введите координаты вручную");
      }
      return null;
    } finally {
      if (requestId === geocodeRequestId.current) {
        setGeocoding(false);
      }
    }
  }

  function applyGeocodeResult(result: GeocodeResult, hint = "Координаты обновлены") {
    setLat(Number(result.lat).toFixed(7));
    setLng(Number(result.lon).toFixed(7));
    const hintPrefix =
      result.match_type === "nearby" ? "Координаты привязаны к ближайшему дому на карте" : hint;
    setGeocodeHint(`${hintPrefix}: ${result.label}`);
  }

  return {
    lat,
    setLat,
    lng,
    setLng,
    geocoding,
    geocodeHint,
    geocodeResults,
    geocodeAddress,
    geocodeAddressNow,
    applyGeocodeResult
  };
}
