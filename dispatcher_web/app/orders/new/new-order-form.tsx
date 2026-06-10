"use client";

import type { FormEvent } from "react";
import { useState } from "react";
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

export function NewOrderForm({ couriers }: { couriers: Courier[] }) {
  const router = useRouter();
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("cash");
  const [bottles, setBottles] = useState(2);
  const [deliveryDate, setDeliveryDate] = useState(todayDateKey);
  const { lat, setLat, lng, setLng, geocoding, geocodeHint, geocodeAddress } = useAddressGeocoding();

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
      delivery_date: selectedDeliveryDate,
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
        <Field label="Клиент" name="client_name" placeholder="Иванова Марина" required />
        <Field label="Телефон" name="client_phone" placeholder="+7 900 000 00 00" />
        <div className="md:col-span-2">
          <Field label="Адрес" name="address" placeholder="ул. Крымская, 45, кв. 12" required onChange={(e) => geocodeAddress(e.target.value)} />
        </div>
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

function nullableNumber(value: FormDataEntryValue | null) {
  if (value === null || String(value).trim() === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
