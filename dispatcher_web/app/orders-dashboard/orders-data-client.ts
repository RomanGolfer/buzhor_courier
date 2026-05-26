import { attachClientRatingStats, normalizeClientPhone, type ClientRatingRow } from "@/lib/client-ratings";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Order, OrderState } from "@/lib/types";

export const orderSelect =
  "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, marking_codes, fiscal_receipt, client_rating, time_slot, delivery_date, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name)";

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

  if (error) return { error: error.message };

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
