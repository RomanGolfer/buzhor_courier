import { createServerSupabaseClient } from "@/lib/supabase/server";
import { attachClientRatingStats, normalizeClientPhone, type ClientRatingRow } from "@/lib/client-ratings";
import type { Courier, CourierStats, Order, Profile } from "@/lib/types";

const moscowOffsetMs = 3 * 60 * 60 * 1000;

export function dateRange(dateKey?: string) {
  const selectedDate = dateKey?.match(/^\d{4}-\d{2}-\d{2}$/)
    ? dateKey
    : moscowDateKey(new Date());
  const [year, month, day] = selectedDate.split("-").map(Number);
  const start = new Date(Date.UTC(year, month - 1, day) - moscowOffsetMs);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { start: start.toISOString(), end: end.toISOString() };
}

function moscowDateKey(date: Date) {
  const parts = new Intl.DateTimeFormat("en", {
    day: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Moscow",
    year: "numeric"
  }).formatToParts(date);
  const getPart = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  return `${getPart("year")}-${getPart("month")}-${getPart("day")}`;
}

export async function getCouriers() {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("couriers")
    .select("id, profile_id, display_name, phone, region, is_active")
    .eq("is_active", true)
    .order("display_name");

  if (error) throw error;
  return (data ?? []) as Courier[];
}

export async function getOrdersByDate(dateKey?: string) {
  const supabase = await createServerSupabaseClient();
  const { start, end } = dateRange(dateKey);

  const { data, error } = await supabase
    .from("orders")
    .select(
      "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, marking_codes, fiscal_receipt, client_rating, time_slot, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name)"
    )
    .gte("created_at", start)
    .lt("created_at", end)
    .order("created_at", { ascending: false });

  if (error) throw error;
  const orders = (data ?? []) as unknown as Order[];
  const phones = [
    ...new Set(
      orders
        .map((order) => normalizeClientPhone(order.client_phone))
        .filter((phone): phone is string => Boolean(phone))
    )
  ];
  if (phones.length === 0) return orders;

  const { data: ratings, error: ratingsError } = await supabase
    .from("client_ratings")
    .select("client_phone_normalized, rating")
    .in("client_phone_normalized", phones);

  if (ratingsError) throw ratingsError;
  return attachClientRatingStats(orders, (ratings ?? []) as ClientRatingRow[]);
}

export async function getCourierStats() {
  const [couriers, orders] = await Promise.all([getCouriers(), getOrdersByDate()]);
  const stats = new Map<string, CourierStats>();

  for (const courier of couriers) {
    stats.set(courier.id, { ...courier, ordersToday: 0, deliveredToday: 0 });
  }

  for (const order of orders) {
    if (!order.assigned_courier_id) continue;
    const row = stats.get(order.assigned_courier_id);
    if (!row) continue;
    row.ordersToday += 1;
    if (order.state === "delivered") row.deliveredToday += 1;
  }

  return [...stats.values()];
}

export async function getProfilesForManagement() {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id, role, email, full_name, phone, is_active, couriers(id, display_name, phone, region, is_active)")
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as unknown as Profile[];
}
