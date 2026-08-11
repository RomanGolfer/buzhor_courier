import { createServerSupabaseClient } from "@/lib/supabase/server";
import { attachClientRatingStats, normalizeClientPhone, type ClientRatingRow } from "@/lib/client-ratings";
import type {
  AddressDirectoryRow,
  ClientDirectoryRow,
  ClientFeedbackRow,
  Courier,
  CourierStats,
  DeliveryZone,
  DeliveryZoneLearningCandidate,
  DeliveryZoneLearningCandidateRow,
  DataImportHistoryRow,
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

export async function getDeliveryZoneLearningCandidates() {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_delivery_zone_learning_candidates");

  if (error) throw error;
  return ((data ?? []) as DeliveryZoneLearningCandidateRow[]).map((candidate): DeliveryZoneLearningCandidate => ({
    ...candidate,
    lat: Number(candidate.lat),
    lng: Number(candidate.lng),
    distance_m: Number(candidate.distance_m)
  }));
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

export async function getClientsDirectory() {
  const supabase = await createServerSupabaseClient();
  const [clientsResult, addressesResult, ordersResult, ratingsResult] = await Promise.all([
    supabase
      .from("clients")
      .select("id, legacy_id, full_name, phone, email, status, loyalty_points, tare_debt, updated_at")
      .order("updated_at", { ascending: false })
      .limit(5000),
    supabase
      .from("client_addresses")
      .select("client_id, address_text, district, updated_at")
      .order("updated_at", { ascending: false })
      .limit(10000),
    supabase
      .from("orders")
      .select("client_id, order_number, updated_at")
      .not("client_id", "is", null)
      .order("updated_at", { ascending: false })
      .limit(10000),
    supabase
      .from("client_ratings")
      .select("client_phone_normalized, rating")
      .order("created_at", { ascending: false })
      .limit(5000)
  ]);
  if (clientsResult.error) throw clientsResult.error;
  if (addressesResult.error) throw addressesResult.error;
  if (ordersResult.error) throw ordersResult.error;
  if (ratingsResult.error) throw ratingsResult.error;

  const ratings = (ratingsResult.data ?? []) as ClientRatingRow[];
  const ratingByPhone = new Map<string, { count: number; sum: number }>();
  for (const rating of ratings) {
    if (!rating.client_phone_normalized) continue;
    const current = ratingByPhone.get(rating.client_phone_normalized) ?? { count: 0, sum: 0 };
    current.count += 1;
    current.sum += rating.rating;
    ratingByPhone.set(rating.client_phone_normalized, current);
  }

  const latestAddressByClient = new Map<string, { address_text: string; district: string | null }>();
  for (const address of addressesResult.data ?? []) {
    if (!latestAddressByClient.has(address.client_id)) latestAddressByClient.set(address.client_id, address);
  }
  const orderStats = new Map<string, { count: number; number: string; updated_at: string }>();
  for (const order of ordersResult.data ?? []) {
    if (!order.client_id) continue;
    const current = orderStats.get(order.client_id);
    if (current) current.count += 1;
    else orderStats.set(order.client_id, { count: 1, number: order.order_number, updated_at: order.updated_at });
  }

  return (clientsResult.data ?? []).map((client): ClientDirectoryRow => {
    const address = latestAddressByClient.get(client.id);
    const orders = orderStats.get(client.id);
    const normalizedPhone = normalizeClientPhone(client.phone);
    const rating = normalizedPhone ? ratingByPhone.get(normalizedPhone) : null;
    return {
      key: client.id,
      legacy_id: client.legacy_id,
      name: client.full_name,
      phone: client.phone,
      email: client.email,
      status: client.status,
      loyalty_points: Number(client.loyalty_points ?? 0),
      tare_debt: client.tare_debt ?? 0,
      address: address?.address_text ?? "Адрес не указан",
      district: address?.district ?? null,
      order_count: orders?.count ?? 0,
      last_order_number: orders?.number ?? null,
      last_order_at: orders?.updated_at ?? client.updated_at,
      rating_average: rating ? rating.sum / rating.count : null,
      rating_count: rating?.count ?? 0
    };
  });
}

export async function getAddressesDirectory() {
  const supabase = await createServerSupabaseClient();
  const [addressesResult, ordersResult] = await Promise.all([
    supabase
      .from("client_addresses")
      .select("id, client_id, address_text, zone_name, district, lat, lng, updated_at, clients(full_name, phone)")
      .order("updated_at", { ascending: false })
      .limit(10000),
    supabase
      .from("orders")
      .select("client_id, address, updated_at")
      .not("client_id", "is", null)
      .order("updated_at", { ascending: false })
      .limit(10000)
  ]);
  if (addressesResult.error) throw addressesResult.error;
  if (ordersResult.error) throw ordersResult.error;

  const orderStats = new Map<string, { count: number; updated_at: string }>();
  for (const order of ordersResult.data ?? []) {
    if (!order.client_id) continue;
    const key = `${order.client_id}|${order.address.trim().toLocaleLowerCase("ru-RU")}`;
    const current = orderStats.get(key);
    if (current) current.count += 1;
    else orderStats.set(key, { count: 1, updated_at: order.updated_at });
  }

  return (addressesResult.data ?? []).map((address): AddressDirectoryRow => {
    const stats = orderStats.get(`${address.client_id}|${address.address_text.trim().toLocaleLowerCase("ru-RU")}`);
    const relatedClients = address.clients as unknown;
    const client = (Array.isArray(relatedClients) ? relatedClients[0] : relatedClients) as {
      full_name: string;
      phone: string | null;
    } | null;
    return {
      key: address.id,
      client_name: client?.full_name ?? "Клиент не указан",
      client_phone: client?.phone ?? null,
      address: address.address_text,
      zone_name: address.zone_name,
      district: address.district,
      lat: address.lat === null ? null : Number(address.lat),
      lng: address.lng === null ? null : Number(address.lng),
      order_count: stats?.count ?? 0,
      last_order_at: stats?.updated_at ?? address.updated_at
    };
  });
}

export async function getOrganizationsDirectory() {
  const supabase = await createServerSupabaseClient();
  const [organizationsResult, ordersResult] = await Promise.all([
    supabase
      .from("organizations")
      .select("id, legacy_id, name, inn, kpp, phone, email, address_text, tare_debt, updated_at")
      .order("updated_at", { ascending: false })
      .limit(5000),
    supabase
      .from("orders")
      .select("organization_id, updated_at")
      .not("organization_id", "is", null)
      .order("updated_at", { ascending: false })
      .limit(10000)
  ]);
  if (organizationsResult.error) throw organizationsResult.error;
  if (ordersResult.error) throw ordersResult.error;

  const orderStats = new Map<string, { count: number; updated_at: string }>();
  for (const order of ordersResult.data ?? []) {
    if (!order.organization_id) continue;
    const current = orderStats.get(order.organization_id);
    if (current) current.count += 1;
    else orderStats.set(order.organization_id, { count: 1, updated_at: order.updated_at });
  }

  return (organizationsResult.data ?? []).map((organization): OrganizationDirectoryRow => {
    const stats = orderStats.get(organization.id);
    return {
      key: organization.id,
      legacy_id: organization.legacy_id,
      name: organization.name,
      inn: organization.inn,
      kpp: organization.kpp,
      phone: organization.phone,
      email: organization.email,
      address: organization.address_text ?? "Адрес не указан",
      tare_debt: organization.tare_debt ?? 0,
      order_count: stats?.count ?? 0,
      last_order_at: stats?.updated_at ?? organization.updated_at
    };
  });
}

export async function getDataImportHistory(limit = 20) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("data_imports")
    .select("id, entity_kind, status, source_system, filename, total_rows, imported_rows, updated_rows, skipped_rows, failed_rows, error_summary, created_at, completed_at")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data ?? []) as DataImportHistoryRow[];
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
