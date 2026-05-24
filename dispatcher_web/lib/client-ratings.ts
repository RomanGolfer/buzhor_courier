import type { Order } from "@/lib/types";

export type ClientRatingRow = {
  client_phone_normalized: string | null;
  rating: number;
};

export function normalizeClientPhone(value: string | null | undefined) {
  const phone = value?.replace(/\D/g, "") ?? "";
  if (!phone) return null;
  if (phone.length === 11 && phone.startsWith("8")) return `7${phone.slice(1)}`;
  if (phone.length === 10) return `7${phone}`;
  return phone;
}

export function attachClientRatingStats(orders: Order[], ratings: ClientRatingRow[]) {
  const totals = new Map<string, { total: number; count: number }>();

  for (const rating of ratings) {
    if (!rating.client_phone_normalized) continue;
    const current = totals.get(rating.client_phone_normalized) ?? { total: 0, count: 0 };
    current.total += rating.rating;
    current.count += 1;
    totals.set(rating.client_phone_normalized, current);
  }

  return orders.map((order) => {
    const phone = normalizeClientPhone(order.client_phone);
    const stats = phone ? totals.get(phone) : null;
    return {
      ...order,
      client_rating_stats: stats
        ? {
            average: stats.total / stats.count,
            count: stats.count
          }
        : null
    };
  });
}
