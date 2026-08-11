import { createServerSupabaseClient } from "@/lib/supabase/server";
import { attachClientRatingStats, normalizeClientPhone, type ClientRatingRow } from "@/lib/client-ratings";
import type {
  AddressDirectoryRow,
  ClientDirectoryRow,
  ClientFeedbackRow,
  Courier,
  CourierStats,
  DeliveryZone,
  Order,
  OrderEventFeedRow,
  OrganizationDirectoryRow,
  Profile
} from "@/lib/types";

export function moscowDateKey(date: Date) {
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

export async function getDeliveryZones() {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_delivery_zones");

  if (error) throw error;
  return (data ?? []) as DeliveryZone[];
}

export async function getOrdersByDate(dateKey?: string) {
  const supabase = await createServerSupabaseClient();
  const selectedDate = dateKey?.match(/^\d{4}-\d{2}-\d{2}$/) ? dateKey : moscowDateKey(new Date());

  const { data, error } = await supabase
    .from("orders")
    .select(
      "id, order_number, assigned_courier_id, delivery_zone_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, marking_codes, fiscal_receipt, client_rating, time_slot, delivery_date, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name), delivery_zones(id, name, color)"
    )
    .eq("delivery_date", selectedDate)
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

export async function getDriverStats() {
  const supabase = await createServerSupabaseClient();
  const [{ data, error }, orders] = await Promise.all([
    supabase
      .from("couriers")
      .select("id, profile_id, display_name, phone, region, is_active")
      .order("display_name"),
    getOrdersByDate()
  ]);

  if (error) throw error;
  const stats = new Map<string, CourierStats>();
  for (const courier of (data ?? []) as Courier[]) {
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

type DirectoryOrder = Pick<
  Order,
  | "id"
  | "order_number"
  | "client_name"
  | "client_phone"
  | "address"
  | "district"
  | "lat"
  | "lng"
  | "payment_method"
  | "created_at"
  | "updated_at"
>;

async function getDirectorySource() {
  const supabase = await createServerSupabaseClient();
  const [ordersResult, ratingsResult] = await Promise.all([
    supabase
      .from("orders")
      .select(
        "id, order_number, client_name, client_phone, address, district, lat, lng, payment_method, created_at, updated_at"
      )
      .order("updated_at", { ascending: false })
      .limit(2000),
    supabase
      .from("client_ratings")
      .select("client_phone_normalized, rating")
      .order("created_at", { ascending: false })
      .limit(2000)
  ]);

  if (ordersResult.error) throw ordersResult.error;
  if (ratingsResult.error) throw ratingsResult.error;

  return {
    orders: (ordersResult.data ?? []) as unknown as DirectoryOrder[],
    ratings: (ratingsResult.data ?? []) as ClientRatingRow[]
  };
}

export async function getClientsDirectory() {
  const { orders, ratings } = await getDirectorySource();
  const ratingByPhone = new Map<string, { count: number; sum: number }>();

  for (const rating of ratings) {
    if (!rating.client_phone_normalized) continue;
    const current = ratingByPhone.get(rating.client_phone_normalized) ?? { count: 0, sum: 0 };
    current.count += 1;
    current.sum += rating.rating;
    ratingByPhone.set(rating.client_phone_normalized, current);
  }

  const clients = new Map<string, ClientDirectoryRow>();
  for (const order of orders) {
    const normalizedPhone = normalizeClientPhone(order.client_phone);
    const key = normalizedPhone ?? `${order.client_name.trim().toLocaleLowerCase("ru-RU")}|${order.address.trim().toLocaleLowerCase("ru-RU")}`;
    const current = clients.get(key);
    if (current) {
      current.order_count += 1;
      continue;
    }

    const rating = normalizedPhone ? ratingByPhone.get(normalizedPhone) : null;
    clients.set(key, {
      key,
      name: order.client_name,
      phone: order.client_phone,
      address: order.address,
      district: order.district,
      order_count: 1,
      last_order_number: order.order_number,
      last_order_at: order.updated_at,
      rating_average: rating ? rating.sum / rating.count : null,
      rating_count: rating?.count ?? 0
    });
  }

  return [...clients.values()];
}

export async function getAddressesDirectory() {
  const { orders } = await getDirectorySource();
  const addresses = new Map<string, AddressDirectoryRow>();

  for (const order of orders) {
    const normalizedPhone = normalizeClientPhone(order.client_phone) ?? order.client_name.trim().toLocaleLowerCase("ru-RU");
    const normalizedAddress = order.address.trim().toLocaleLowerCase("ru-RU");
    const key = `${normalizedPhone}|${normalizedAddress}`;
    const current = addresses.get(key);
    if (current) {
      current.order_count += 1;
      continue;
    }

    addresses.set(key, {
      key,
      client_name: order.client_name,
      client_phone: order.client_phone,
      address: order.address,
      district: order.district,
      lat: order.lat,
      lng: order.lng,
      order_count: 1,
      last_order_at: order.updated_at
    });
  }

  return [...addresses.values()];
}

export async function getOrganizationsDirectory() {
  const { orders } = await getDirectorySource();
  const organizations = new Map<string, OrganizationDirectoryRow>();

  for (const order of orders) {
    if (order.payment_method !== "contract") continue;
    const key = order.client_name.trim().toLocaleLowerCase("ru-RU");
    const current = organizations.get(key);
    if (current) {
      current.order_count += 1;
      continue;
    }

    organizations.set(key, {
      key,
      name: order.client_name,
      phone: order.client_phone,
      address: order.address,
      order_count: 1,
      last_order_at: order.updated_at
    });
  }

  return [...organizations.values()];
}

export async function getRecentOrderEvents(limit = 200) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("order_events")
    .select("id, event_type, payload, created_at, orders(id, order_number, client_name, address), profiles(full_name)")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data ?? []) as unknown as OrderEventFeedRow[];
}

export async function getClientFeedback(limit = 200) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("client_ratings")
    .select("id, rating, client_phone, created_at, orders(id, order_number, client_name, address), couriers(id, display_name)")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data ?? []) as unknown as ClientFeedbackRow[];
}
