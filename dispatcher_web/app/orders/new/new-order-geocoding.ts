import { useEffect, useRef, useState } from "react";

const defaultLat = "44.8951000";
const defaultLng = "37.3168000";
const geocodeDelayMs = 800;

type GeocodeResult = {
  lat: string;
  lon: string;
  display_name: string;
  label: string;
  locality: string | null;
  distance_m: number | null;
};

type GeocodeOrigin = {
  lat: string;
  lng: string;
};

export function useAddressGeocoding() {
  const [lat, setLat] = useState(defaultLat);
  const [lng, setLng] = useState(defaultLng);
  const [geocoding, setGeocoding] = useState(false);
  const [geocodeHint, setGeocodeHint] = useState<string | null>(null);
  const [geocodeResults, setGeocodeResults] = useState<GeocodeResult[]>([]);
  const origin = useRef<GeocodeOrigin>({ lat: defaultLat, lng: defaultLng });
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

  function geocodeAddress(address: string, originOverride = origin.current) {
    if (geocodeTimer.current) {
      clearTimeout(geocodeTimer.current);
    }

    geocodeAbortController.current?.abort();
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
      const controller = new AbortController();
      geocodeAbortController.current = controller;

      try {
        const params = new URLSearchParams({
          q: trimmedAddress,
          lat: originOverride.lat,
          lng: originOverride.lng
        });
        const res = await fetch(`/api/geocode?${params.toString()}`, { signal: controller.signal });
        const data = (await res.json()) as GeocodeResult[];

        if (requestId !== geocodeRequestId.current) return;

        setGeocodeResults(data);
        if (data.length > 0) {
          applyGeocodeResult(data[0], "Координаты определены автоматически");
        } else {
          setGeocodeHint("Адрес не найден — введите координаты вручную");
        }
      } catch (fetchError) {
        if (fetchError instanceof DOMException && fetchError.name === "AbortError") return;
        if (requestId === geocodeRequestId.current) {
          setGeocodeHint("Адрес не найден — введите координаты вручную");
        }
      } finally {
        if (requestId === geocodeRequestId.current) {
          setGeocoding(false);
        }
      }
    }, geocodeDelayMs);
  }

  geocodeAddressRef.current = geocodeAddress;

  function applyGeocodeResult(result: GeocodeResult, hint = "Координаты обновлены") {
    setLat(Number(result.lat).toFixed(7));
    setLng(Number(result.lon).toFixed(7));
    setGeocodeHint(`${hint}: ${result.label}`);
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
    applyGeocodeResult
  };
}
