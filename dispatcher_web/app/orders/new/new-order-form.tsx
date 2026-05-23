"use client";

import type { FormEvent, InputHTMLAttributes } from "react";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Panel } from "@/components/ui";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Courier, PaymentMethod } from "@/lib/types";

const paymentOptions: Array<{ value: PaymentMethod; label: string }> = [
  { value: "cash", label: "Наличные" },
  { value: "card", label: "Карта" },
  { value: "qr", label: "QR" },
  { value: "online", label: "Онлайн" },
  { value: "contract", label: "Договор" }
];

const timeSlots = ["10:00 - 14:00", "14:00 - 18:00", "18:00 - 21:00"];
const defaultLat = "44.8951000";
const defaultLng = "37.3168000";

export function NewOrderForm({ couriers }: { couriers: Courier[] }) {
  const router = useRouter();
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("cash");
  const [bottles, setBottles] = useState(2);
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
        const data: Array<{ lat: string; lon: string }> = await res.json();

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
    }, 800);
  }

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsSaving(true);

    const form = new FormData(event.currentTarget);
    const bottleCount = Number(form.get("bottles") ?? bottles);
    const price = bottleCount <= 1 ? bottleCount * 400 : bottleCount * 300;
    const now = new Date();
    const orderNumber = `#${now.getFullYear().toString().slice(2)}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}${String(now.getTime()).slice(-4)}`;

    const supabase = createBrowserSupabaseClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();

    const payload = {
      order_number: orderNumber,
      state: "assigned",
      client_name: String(form.get("client_name") ?? "").trim(),
      client_phone: String(form.get("client_phone") ?? "").trim() || null,
      address: String(form.get("address") ?? "").trim(),
      district: String(form.get("district") ?? "").trim() || null,
      lat: nullableNumber(form.get("lat")),
      lng: nullableNumber(form.get("lng")),
      bottles: bottleCount,
      price,
      payment_method: paymentMethod,
      time_slot: String(form.get("time_slot") ?? "") || null,
      delivery_comment: String(form.get("delivery_comment") ?? "").trim() || null,
      assigned_courier_id: String(form.get("assigned_courier_id") ?? "") || null,
      created_by: user?.id ?? null,
      updated_by: user?.id ?? null
    };

    if (!payload.client_name || !payload.address) {
      setError("Заполните клиента и адрес");
      setIsSaving(false);
      return;
    }

    const { error: insertError } = await supabase.from("orders").insert(payload);

    if (insertError) {
      setError(insertError.message);
      setIsSaving(false);
      return;
    }

    router.push("/");
    router.refresh();
  }

  return (
    <Panel className="p-5">
      <form className="grid gap-5 md:grid-cols-2" onSubmit={onSubmit}>
        <Field label="Клиент" name="client_name" placeholder="Иванова Марина" required />
        <Field label="Телефон" name="client_phone" placeholder="+7 900 000 00 00" />
        <div className="md:col-span-2">
          <Field label="Адрес" name="address" placeholder="ул. Крымская, 45, кв. 12" required onChange={(e) => geocodeAddress(e.target.value)} />
        </div>
        <label className="block md:col-span-2">
          <span className="mb-1 block text-sm font-bold text-ink">Комментарий диспетчера</span>
          <textarea
            className="focus-ring min-h-24 w-full resize-y rounded-md border border-line px-3 py-3 text-sm"
            name="delivery_comment"
            placeholder="Код домофона, подъезд, уточнения по клиенту или доставке"
          />
        </label>
        <Field label="Район" name="district" placeholder="Анапа" />
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Курьер</span>
          <select className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm" name="assigned_courier_id" required>
            <option value="">Выберите курьера</option>
            {couriers.map((courier) => (
              <option key={courier.id} value={courier.id}>
                {courier.display_name}
              </option>
            ))}
          </select>
        </label>
        <label className="block">
          <span className="mb-1 flex items-center gap-1.5">
            <span className="text-sm font-bold text-ink">Lat</span>
            {geocoding && <Spinner />}
          </span>
          <input
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            inputMode="decimal"
            name="lat"
            value={lat}
            onChange={(e) => setLat(e.target.value)}
          />
        </label>
        <label className="block">
          <span className="mb-1 flex items-center gap-1.5">
            <span className="text-sm font-bold text-ink">Lng</span>
            {geocoding && <Spinner />}
          </span>
          <input
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            inputMode="decimal"
            name="lng"
            value={lng}
            onChange={(e) => setLng(e.target.value)}
          />
        </label>
        {geocodeHint && (
          <p className="text-xs text-gray-400 md:col-span-2">{geocodeHint}</p>
        )}
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Бутыли</span>
          <input
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            min={0}
            name="bottles"
            onChange={(event) => setBottles(Number(event.target.value))}
            required
            type="number"
            value={bottles}
          />
        </label>
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Тип оплаты</span>
          <select className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm" value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value as PaymentMethod)}>
            {paymentOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Временной слот</span>
          <select className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm" name="time_slot">
            {timeSlots.map((slot) => (
              <option key={slot} value={slot}>
                {slot}
              </option>
            ))}
          </select>
        </label>
        <div className="flex items-end justify-between gap-4 md:col-span-2">
          {error ? <p className="rounded-md bg-red-50 px-3 py-2 text-sm font-semibold text-bad">{error}</p> : <span />}
          <button className="rounded-md bg-brand px-5 py-3 text-sm font-black text-white hover:bg-brandDark disabled:opacity-60" disabled={isSaving}>
            {isSaving ? "Сохраняем..." : "Создать заказ"}
          </button>
        </div>
      </form>
    </Panel>
  );
}

function Field({
  label,
  name,
  placeholder,
  required,
  inputMode,
  defaultValue,
  onChange
}: {
  label: string;
  name: string;
  placeholder: string;
  required?: boolean;
  inputMode?: InputHTMLAttributes<HTMLInputElement>["inputMode"];
  defaultValue?: string;
  onChange?: InputHTMLAttributes<HTMLInputElement>["onChange"];
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-bold text-ink">{label}</span>
      <input
        className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
        inputMode={inputMode}
        name={name}
        placeholder={placeholder}
        required={required}
        defaultValue={defaultValue}
        onChange={onChange}
      />
    </label>
  );
}

function Spinner() {
  return (
    <svg className="size-3.5 animate-spin text-gray-400" viewBox="0 0 24 24" fill="none">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
    </svg>
  );
}

function nullableNumber(value: FormDataEntryValue | null) {
  if (value === null || String(value).trim() === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
