"use client";

import type { FormEvent } from "react";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Panel } from "@/components/ui";
import { notifyOrderPush } from "@/lib/order-push";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Courier, PaymentMethod } from "@/lib/types";
import { datePresets, formatShortDate, todayDateKey } from "./new-order-date-utils";
import { Field, Spinner } from "./new-order-form-fields";
import { useAddressGeocoding } from "./new-order-geocoding";

const paymentOptions: Array<{ value: PaymentMethod; label: string }> = [
  { value: "cash", label: "Наличные" },
  { value: "card", label: "Карта" },
  { value: "qr", label: "QR" },
  { value: "online", label: "Онлайн" },
  { value: "contract", label: "Договор" }
];

const timeSlots = ["10:00 - 14:00", "14:00 - 18:00", "18:00 - 21:00"];
const clientLookupDelayMs = 500;

type AutofillField =
  | "clientName"
  | "address"
  | "district"
  | "deliveryComment"
  | "assignedCourierId"
  | "paymentMethod"
  | "bottles"
  | "timeSlot"
  | "lat"
  | "lng";

type ClientLookupResponse =
  | { found: false }
  | {
      found: true;
      client: {
        client_name: string | null;
        client_phone: string | null;
        address: string | null;
        district: string | null;
        lat: string | null;
        lng: string | null;
        payment_method: PaymentMethod | null;
        bottles: number | null;
        time_slot: string | null;
        delivery_comment: string | null;
        assigned_courier_id: string | null;
        last_order_number: string;
        order_count: number;
      };
    };

export function NewOrderForm({ couriers }: { couriers: Courier[] }) {
  const router = useRouter();
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [clientName, setClientName] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("cash");
  const [bottles, setBottles] = useState(2);
  const [deliveryDate, setDeliveryDate] = useState(todayDateKey);
  const [clientPhone, setClientPhone] = useState("");
  const [address, setAddress] = useState("");
  const [district, setDistrict] = useState("");
  const [deliveryComment, setDeliveryComment] = useState("");
  const [assignedCourierId, setAssignedCourierId] = useState("");
  const [timeSlot, setTimeSlot] = useState(timeSlots[0]);
  const [clientLookupHint, setClientLookupHint] = useState<string | null>(null);
  const [clientLookupLoading, setClientLookupLoading] = useState(false);
  const touchedFields = useRef(new Set<AutofillField>());
  const clientLookupTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const clientLookupAbortController = useRef<AbortController | null>(null);
  const clientLookupRequestId = useRef(0);
  const applyClientLookupRef = useRef<(client: Extract<ClientLookupResponse, { found: true }>["client"]) => void>(
    () => undefined
  );
  const { lat, setLat, lng, setLng, geocoding, geocodeHint, geocodeResults, geocodeAddress, applyGeocodeResult } =
    useAddressGeocoding();

  useEffect(() => {
    return () => {
      if (clientLookupTimer.current) {
        clearTimeout(clientLookupTimer.current);
      }
      clientLookupAbortController.current?.abort();
    };
  }, []);

  function markTouched(field: AutofillField) {
    touchedFields.current.add(field);
  }

  function fillTextField(
    field: AutofillField,
    currentValue: string,
    nextValue: string | null,
    setter: (value: string) => void
  ) {
    if (!nextValue) return;
    if (!touchedFields.current.has(field) || !currentValue.trim()) {
      setter(nextValue);
    }
  }

  function applyClientLookup(client: Extract<ClientLookupResponse, { found: true }>["client"]) {
    fillTextField("clientName", clientName, client.client_name, setClientName);
    fillTextField("address", address, client.address ? normalizeAddressShortcuts(client.address) : null, (value) => {
      setAddress(value);
      if (!client.lat || !client.lng) {
        geocodeAddress(value);
      }
    });
    fillTextField("district", district, client.district, setDistrict);
    fillTextField("deliveryComment", deliveryComment, client.delivery_comment, setDeliveryComment);
    fillTextField("assignedCourierId", assignedCourierId, client.assigned_courier_id, setAssignedCourierId);
    fillTextField("timeSlot", timeSlot, client.time_slot, setTimeSlot);

    if (client.payment_method && !touchedFields.current.has("paymentMethod")) {
      setPaymentMethod(client.payment_method);
    }
    if (client.bottles !== null && Number.isFinite(client.bottles) && !touchedFields.current.has("bottles")) {
      setBottles(client.bottles);
    }
    if (client.lat && !touchedFields.current.has("lat")) {
      setLat(client.lat);
    }
    if (client.lng && !touchedFields.current.has("lng")) {
      setLng(client.lng);
    }
  }

  useEffect(() => {
    applyClientLookupRef.current = applyClientLookup;
  });

  useEffect(() => {
    if (clientLookupTimer.current) {
      clearTimeout(clientLookupTimer.current);
    }
    clientLookupAbortController.current?.abort();

    const normalizedPhone = normalizeRussianPhone(clientPhone);
    const phoneDigits = toRussianPhoneDigits(normalizedPhone);
    if (phoneDigits.length !== 11) return;

    const requestId = clientLookupRequestId.current + 1;
    clientLookupRequestId.current = requestId;

    clientLookupTimer.current = setTimeout(async () => {
      const controller = new AbortController();
      clientLookupAbortController.current = controller;

      try {
        const params = new URLSearchParams({ phone: normalizedPhone });
        const response = await fetch(`/api/client-lookup?${params.toString()}`, {
          signal: controller.signal
        });
        const data = (await response.json()) as ClientLookupResponse;

        if (requestId !== clientLookupRequestId.current) return;

        if (response.ok && data.found) {
          applyClientLookupRef.current(data.client);
          setClientLookupHint(
            `Найден прошлый заказ ${data.client.last_order_number}. Данные клиента подставлены, их можно изменить.`
          );
        } else {
          setClientLookupHint("Клиент с таким телефоном еще не найден");
        }
      } catch (fetchError) {
        if (fetchError instanceof DOMException && fetchError.name === "AbortError") return;
        if (requestId === clientLookupRequestId.current) {
          setClientLookupHint("Не удалось проверить клиента по телефону");
        }
      } finally {
        if (requestId === clientLookupRequestId.current) {
          setClientLookupLoading(false);
        }
      }
    }, clientLookupDelayMs);
  }, [clientPhone]);

  function updateClientPhone(value: string, finalize = false) {
    const nextPhone = finalize ? normalizeRussianPhone(value) : formatRussianPhoneInput(value);
    setClientPhone(nextPhone);

    if (toRussianPhoneDigits(nextPhone).length === 11) {
      setClientLookupLoading(true);
      setClientLookupHint(null);
    } else {
      setClientLookupLoading(false);
      setClientLookupHint(null);
    }
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

    const selectedDeliveryDate = String(form.get("delivery_date") ?? "") || deliveryDate || todayDateKey();
    const payload = {
      order_number: orderNumber,
      state: "assigned",
      client_name: clientName.trim(),
      client_phone: normalizeRussianPhone(String(form.get("client_phone") ?? "")) || null,
      address: normalizeAddressShortcuts(address),
      district: district.trim() || null,
      lat: nullableNumber(form.get("lat")),
      lng: nullableNumber(form.get("lng")),
      bottles: bottleCount,
      price,
      payment_method: paymentMethod,
      time_slot: timeSlot || null,
      delivery_date: selectedDeliveryDate,
      delivery_comment: deliveryComment.trim() || null,
      assigned_courier_id: assignedCourierId || null,
      created_by: user?.id ?? null,
      updated_by: user?.id ?? null
    };

    if (!payload.client_name || !payload.address) {
      setError("Заполните клиента и адрес");
      setIsSaving(false);
      return;
    }

    const { data: createdOrder, error: insertError } = await supabase.from("orders").insert(payload).select("id").single();

    if (insertError) {
      console.warn("Order creation failed", insertError);
      setError("Не удалось создать заказ. Попробуйте еще раз.");
      setIsSaving(false);
      return;
    }

    if (createdOrder?.id) {
      await notifyOrderPush(supabase, createdOrder.id, "created");
    }

    router.push(`/?date=${encodeURIComponent(selectedDeliveryDate)}`);
    router.refresh();
  }

  return (
    <Panel className="p-5">
      <form className="grid gap-5 md:grid-cols-2" onSubmit={onSubmit}>
        <Field
          label="Клиент"
          name="client_name"
          onChange={(event) => {
            markTouched("clientName");
            setClientName(event.target.value);
          }}
          placeholder="Иванова Марина"
          required
          value={clientName}
        />
        <Field
          inputMode="tel"
          label="Телефон"
          name="client_phone"
          onBlur={(event) => updateClientPhone(event.currentTarget.value, true)}
          onChange={(event) => updateClientPhone(event.target.value)}
          placeholder="+7 900 000 00 00"
          value={clientPhone}
        />
        <div className="md:col-span-2">
          <Field
            label="Адрес"
            name="address"
            onBlur={(event) => {
              const normalized = normalizeAddressShortcuts(event.target.value);
              if (normalized !== address) {
                setAddress(normalized);
                geocodeAddress(normalized);
              }
            }}
            onChange={(event) => {
              markTouched("address");
              const formattedAddress = normalizeAddressShortcuts(event.target.value, false);
              setAddress(formattedAddress);
              geocodeAddress(formattedAddress);
            }}
            placeholder="ул. Крымская, 45, кв. 12"
            required
            value={address}
          />
        </div>
        {geocodeResults.length > 0 && (
          <div className="grid gap-2 md:col-span-2">
            {geocodeResults.map((result) => (
              <button
                className="rounded-md border border-line bg-white px-3 py-2 text-left text-sm hover:border-brand hover:text-brand"
                key={`${result.lat}-${result.lon}-${result.label}`}
                onClick={() => {
                  markTouched("address");
                  setAddress(
                    mergeSelectedAddressWithDetails(
                      result.address_line || stripLocalityFromAddress(result.label, result.locality),
                      address
                    )
                  );
                  applyGeocodeResult(result);
                }}
                type="button"
              >
                <span className="block font-bold">{result.label}</span>
                {result.distance_m !== null && (
                  <span className="block text-xs font-semibold text-muted">{formatDistance(result.distance_m)}</span>
                )}
              </button>
            ))}
          </div>
        )}
        {(clientLookupLoading || clientLookupHint) && (
          <p className="text-xs font-semibold text-muted md:col-span-2">
            {clientLookupLoading ? "Проверяем клиента по телефону..." : clientLookupHint}
          </p>
        )}
        <section className="rounded-md border border-brand/30 bg-brand/5 p-4 md:col-span-2">
          <div className="mb-3 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h2 className="text-base font-black text-ink">Дата и время доставки</h2>
              <p className="text-xs font-semibold text-muted">Выберите день доставки до назначения курьера</p>
            </div>
            <div className="text-sm font-black text-brand">{formatShortDate(deliveryDate)}</div>
          </div>
          <div className="grid gap-3 md:grid-cols-[1fr_220px]">
            <div className="grid gap-2 sm:grid-cols-3">
              {datePresets().map((preset) => (
                <button
                  className={`rounded-md border px-3 py-2 text-sm font-black ${
                    deliveryDate === preset.value
                      ? "border-brand bg-brand text-white"
                      : "border-line bg-white text-ink hover:border-brand hover:text-brand"
                  }`}
                  key={preset.value}
                  onClick={() => setDeliveryDate(preset.value)}
                  type="button"
                >
                  <span className="block">{preset.label}</span>
                  <span className="block text-xs font-semibold opacity-80">{formatShortDate(preset.value)}</span>
                </button>
              ))}
            </div>
            <label className="block">
              <span className="mb-1 block text-sm font-bold text-ink">Другая дата</span>
              <input
                className="focus-ring w-full rounded-md border border-line bg-white px-3 py-3 text-sm font-bold"
                min={todayDateKey()}
                name="delivery_date"
                onChange={(event) => setDeliveryDate(event.target.value)}
                required
                type="date"
                value={deliveryDate}
              />
            </label>
          </div>
        </section>
        <label className="block md:col-span-2">
          <span className="mb-1 block text-sm font-bold text-ink">Комментарий диспетчера</span>
          <textarea
            className="focus-ring min-h-24 w-full resize-y rounded-md border border-line px-3 py-3 text-sm"
            name="delivery_comment"
            onChange={(event) => {
              markTouched("deliveryComment");
              setDeliveryComment(event.target.value);
            }}
            placeholder="Код домофона, подъезд, уточнения по клиенту или доставке"
            value={deliveryComment}
          />
        </label>
        <Field
          label="Район"
          name="district"
          onChange={(event) => {
            markTouched("district");
            setDistrict(event.target.value);
          }}
          placeholder="Анапа"
          value={district}
        />
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Курьер</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            name="assigned_courier_id"
            onChange={(event) => {
              markTouched("assignedCourierId");
              setAssignedCourierId(event.target.value);
            }}
            required
            value={assignedCourierId}
          >
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
            onChange={(e) => {
              markTouched("lat");
              setLat(e.target.value);
            }}
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
            onChange={(e) => {
              markTouched("lng");
              setLng(e.target.value);
            }}
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
            onChange={(event) => {
              markTouched("bottles");
              setBottles(Number(event.target.value));
            }}
            required
            type="number"
            value={bottles}
          />
        </label>
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Тип оплаты</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            value={paymentMethod}
            onChange={(event) => {
              markTouched("paymentMethod");
              setPaymentMethod(event.target.value as PaymentMethod);
            }}
          >
            {paymentOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Временной слот</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            name="time_slot"
            onChange={(event) => {
              markTouched("timeSlot");
              setTimeSlot(event.target.value);
            }}
            value={timeSlot}
          >
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

function nullableNumber(value: FormDataEntryValue | null) {
  if (value === null || String(value).trim() === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeRussianPhone(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return "";

  const digits = toRussianPhoneDigits(trimmed);
  if (digits.length === 11) return formatRussianPhone(digits);
  return trimmed;
}

function formatRussianPhoneInput(value: string) {
  if (!value.trim()) return "";
  if (value === "+") return "+";

  const digits = toRussianPhoneDigits(value);
  if (!digits) return value.startsWith("+") ? "+" : "";
  return formatPartialRussianPhone(digits);
}

function toRussianPhoneDigits(value: string) {
  const digits = value.replace(/\D/g, "");
  if (!digits) return "";
  if (digits.startsWith("8")) return `7${digits.slice(1, 11)}`;
  if (digits.startsWith("7")) return digits.slice(0, 11);
  return `7${digits.slice(0, 10)}`;
}

function formatRussianPhone(digits: string) {
  return `+${digits.slice(0, 1)} ${digits.slice(1, 4)} ${digits.slice(4, 7)} ${digits.slice(7, 9)} ${digits.slice(9, 11)}`;
}

function formatPartialRussianPhone(digits: string) {
  const limitedDigits = digits.slice(0, 11);
  const parts = [
    `+${limitedDigits.slice(0, 1)}`,
    limitedDigits.slice(1, 4),
    limitedDigits.slice(4, 7),
    limitedDigits.slice(7, 9),
    limitedDigits.slice(9, 11)
  ].filter(Boolean);
  return parts.join(" ");
}

function normalizeAddressShortcuts(value: string, finalize = true) {
  const normalized = value
    .replace(/(^|[^\p{L}\p{N}_])улица(?=$|[^\p{L}\p{N}_])/giu, "$1ул.")
    .replace(/(^|[^\p{L}\p{N}_])ул\.?(?=$|[^\p{L}\p{N}_])/giu, "$1ул.")
    .replace(/(^|[^\p{L}\p{N}_])подъезд\.?\s*(?=\d)/giu, "$1п. ")
    .replace(/(^|[^\p{L}\p{N}_])п\.?\s*(?=\d)/giu, "$1п. ")
    .replace(/(^|[^\p{L}\p{N}_])э(?:т|таж)?\.?\s*(?=\d)/giu, "$1эт. ")
    .replace(/(^|[^\p{L}\p{N}_])кв(?:артира)?\.?\s*(?=\d)/giu, "$1кв. ")
    .replace(/(^|[^\p{L}\p{N}_])к\.?\s*(?=\d{2,})/giu, "$1кв. ");

  if (!finalize) return normalized;

  return normalized
    .trim()
    .replace(/(^|[^\p{L}\p{N}_])улица(?=$|[^\p{L}\p{N}_])/giu, "$1ул.")
    .replace(/(^|[^\p{L}\p{N}_])ул\.?(?=$|[^\p{L}\p{N}_])/giu, "$1ул.")
    .replace(/(^|[^\p{L}\p{N}_])подъезд(?=$|[^\p{L}\p{N}_])/giu, "$1п.")
    .replace(/(^|[^\p{L}\p{N}_])п\.?(?=$|[^\p{L}\p{N}_])/giu, "$1п.")
    .replace(/(^|[^\p{L}\p{N}_])э(?:т|таж)?\.?(?=$|[^\p{L}\p{N}_])/giu, "$1эт.")
    .replace(/(^|[^\p{L}\p{N}_])кв(?:артира)?\.?(?=$|[^\p{L}\p{N}_])/giu, "$1кв.")
    .replace(/\s+/g, " ");
}

function stripLocalityFromAddress(label: string, locality: string | null) {
  if (!locality) return label;
  return label
    .split("·")
    .map((part) => part.trim())
    .filter((part) => part && part.toLocaleLowerCase("ru-RU") !== locality.toLocaleLowerCase("ru-RU"))
    .join(" ");
}

function mergeSelectedAddressWithDetails(selectedAddress: string, currentAddress: string) {
  const baseAddress = normalizeAddressShortcuts(selectedAddress);
  const lowerBase = baseAddress.toLocaleLowerCase("ru-RU");
  const details = extractAddressDetails(currentAddress).filter(
    (detail) => !lowerBase.includes(detail.toLocaleLowerCase("ru-RU"))
  );
  return normalizeAddressShortcuts([baseAddress, ...details].join(" "));
}

function extractAddressDetails(value: string) {
  const normalized = normalizeAddressShortcuts(value);
  const details = new Set<string>();
  const patterns = [
    /(^|[^\p{L}\p{N}_])(к\.?\s*\d+\p{L}?)(?=$|[^\p{L}\p{N}_])/giu,
    /(^|[^\p{L}\p{N}_])(п\.\s*\d+\p{L}?)(?=$|[^\p{L}\p{N}_])/giu,
    /(^|[^\p{L}\p{N}_])(эт\.\s*\d+\p{L}?)(?=$|[^\p{L}\p{N}_])/giu,
    /(^|[^\p{L}\p{N}_])(кв\.\s*\d+\p{L}?)(?=$|[^\p{L}\p{N}_])/giu
  ];

  for (const pattern of patterns) {
    for (const match of normalized.matchAll(pattern)) {
      const detail = match[2]?.replace(/\s+/g, " ").trim();
      if (detail) details.add(detail);
    }
  }

  return [...details];
}

function formatDistance(distanceMeters: number) {
  if (distanceMeters < 1000) return `${distanceMeters} м от точки диспетчера`;
  return `${(distanceMeters / 1000).toFixed(distanceMeters < 10_000 ? 1 : 0)} км от точки диспетчера`;
}
