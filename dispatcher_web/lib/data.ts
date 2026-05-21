import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Courier, CourierStats, Order } from "@/lib/types";

export function todayRange() {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start: start.toISOString(), end: end.toISOString() };
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

export async function getTodayOrders() {
  const supabase = await createServerSupabaseClient();
  const { start, end } = todayRange();

  const { data, error } = await supabase
    .from("orders")
    .select(
      "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, time_slot, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name)"
    )
    .gte("created_at", start)
    .lt("created_at", end)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as unknown as Order[];
}

export async function getCourierStats() {
  const [couriers, orders] = await Promise.all([getCouriers(), getTodayOrders()]);
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
