import { useEffect, useRef, useState } from "react";

const defaultLat = "44.8951000";
const defaultLng = "37.3168000";
const geocodeDelayMs = 800;

type GeocodeResult = {
  lat: string;
  lon: string;
};

export function useAddressGeocoding() {
  const [lat, setLat] = useState(defaultLat);
  const [lng, setLng] = useState(defaultLng);
  const [geocoding, setGeocoding] = useState(false);
  const [geocodeHint, setGeocodeHint] = useState<string | null>(null);
  const geocodeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const geocodeAbortController = useRef<AbortController | null>(null);
  const geocodeRequestId = useRef(0);

  useEffect(() => {
    return () => {
      if (geocodeTimer.current) {
        clearTimeout(geocodeTimer.current);
      }
      geocodeAbortController.current?.abort();
    };
  }, []);

  function geocodeAddress(address: string) {
    if (geocodeTimer.current) {
      clearTimeout(geocodeTimer.current);
    }

    geocodeAbortController.current?.abort();
    const trimmedAddress = address.trim();

    if (!trimmedAddress) {
      setGeocoding(false);
      setGeocodeHint(null);
      return;
    }

    setGeocoding(true);
    const requestId = geocodeRequestId.current + 1;
    geocodeRequestId.current = requestId;

    geocodeTimer.current = setTimeout(async () => {
      const controller = new AbortController();
      geocodeAbortController.current = controller;

      try {
        const res = await fetch(`/api/geocode?q=${encodeURIComponent(trimmedAddress)}`, {
          signal: controller.signal
        });
        const data = (await res.json()) as GeocodeResult[];

        if (requestId !== geocodeRequestId.current) return;

        if (data.length > 0) {
          setLat(Number(data[0].lat).toFixed(7));
          setLng(Number(data[0].lon).toFixed(7));
          setGeocodeHint("Координаты определены автоматически");
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

  return { lat, setLat, lng, setLng, geocoding, geocodeHint, geocodeAddress };
}
