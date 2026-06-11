import { attachClientRatingStats, normalizeClientPhone, type ClientRatingRow } from "@/lib/client-ratings";
import { notifyOrderPush } from "@/lib/order-push";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { CallEvent, Order, OrderState } from "@/lib/types";

export const orderSelect =
  "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, marking_codes, fiscal_receipt, client_rating, time_slot, delivery_date, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name)";
const callEventSelect =
  "id, provider, provider_call_id, direction, event_type, order_id, client_phone, client_phone_normalized, dispatcher_profile_id, courier_id, started_at, answered_at, ended_at, duration_seconds, recording_url, payload, created_at, updated_at";

type BrowserSupabaseClient = ReturnType<typeof createBrowserSupabaseClient>;

async function loadClientRatingStats(supabase: BrowserSupabaseClient, orders: Order[]) {
  const phones = [
    ...new Set(
      orders
        .map((order) => normalizeClientPhone(order.client_phone))
        .filter((phone): phone is string => Boolean(phone))
    )
  ];
  if (phones.length === 0) return orders;

  const { data, error } = await supabase
    .from("client_ratings")
    .select("client_phone_normalized, rating")
    .in("client_phone_normalized", phones);

  if (error) return orders;
  return attachClientRatingStats(orders, (data ?? []) as ClientRatingRow[]);
}

export async function loadOrdersForDate(supabase: BrowserSupabaseClient, dateKey: string) {
  const { data } = await supabase
    .from("orders")
    .select(orderSelect)
    .eq("delivery_date", dateKey)
    .order("created_at", { ascending: false });

  if (!data) return null;
  return loadClientRatingStats(supabase, data as unknown as Order[]);
}

export async function loadCallEventsForOrder(supabase: BrowserSupabaseClient, order: Order | null) {
  if (!order) return [];

  const normalizedPhone = normalizeClientPhone(order.client_phone);
  let query = supabase
    .from("call_events")
    .select(callEventSelect)
    .order("created_at", { ascending: false })
    .limit(30);

  query = normalizedPhone
    ? query.or(`order_id.eq.${order.id},client_phone_normalized.eq.${normalizedPhone}`)
    : query.eq("order_id", order.id);

  const { data, error } = await query;
  if (error) {
    console.warn("Call events load failed", error);
    return [];
  }

  return (data ?? []) as unknown as CallEvent[];
}

export async function requestTelephonyCall({ order }: { order: Order }) {
  const response = await fetch("/api/telephony/call", {
    body: JSON.stringify({
      order_id: order.id,
      phone: order.client_phone
    }),
    headers: {
      "Content-Type": "application/json"
    },
    method: "POST"
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = typeof data.error === "string" ? data.error : "Не удалось поставить звонок в очередь АТС";
    return { error };
  }

  return { error: null };
}

export async function saveDispatcherOrderUpdate({
  draftComment,
  draftCourierId,
  draftFailureReason,
  draftState,
  order,
  supabase
}: {
  draftComment: string;
  draftCourierId: string;
  draftFailureReason: string;
  draftState: OrderState;
  order: Order;
  supabase: BrowserSupabaseClient;
}) {
  const {
    data: { user }
  } = await supabase.auth.getUser();
  const needsFailureReason = draftState === "failed" || draftState === "cancelled";
  const failureReason = needsFailureReason ? draftFailureReason.trim() || null : null;
  const deliveryComment = draftComment.trim() || null;
  const nextCourierId = draftCourierId || null;

  const { error } = await supabase
    .from("orders")
    .update({
      assigned_courier_id: nextCourierId,
      state: draftState,
      delivery_comment: deliveryComment,
      failure_reason: failureReason,
      updated_by: user?.id ?? null
    })
    .eq("id", order.id);

  if (error) {
    console.warn("Order update failed", error);
    return { error: "Не удалось сохранить заказ. Попробуйте еще раз." };
  }

  if (nextCourierId && nextCourierId !== order.assigned_courier_id) {
    await notifyOrderPush(supabase, order.id, "assigned");
  }

  await supabase.from("order_events").insert({
    order_id: order.id,
    actor_profile_id: user?.id ?? null,
    event_type: "dispatcher_update",
    payload: {
      state: draftState,
      assigned_courier_id: nextCourierId,
      delivery_comment: deliveryComment,
      failure_reason: failureReason
    }
  });

  return { error: null };
}
