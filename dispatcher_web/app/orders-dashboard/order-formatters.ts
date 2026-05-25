import type { Order, OrderState } from "@/lib/types";
import { isOrderOverdue } from "./date-utils";

export const stateLabels: Record<OrderState, string> = {
  draft: "Черновик",
  assigned: "Назначен",
  accepted: "Принят",
  in_progress: "В пути",
  delivered: "Выполнен",
  failed: "Проблема",
  cancelled: "Отменен"
};

export const paymentLabels: Record<string, string> = {
  card: "Карта",
  cash: "Наличные",
  qr: "QR",
  online: "Онлайн",
  contract: "Договор"
};

const fiscalReceiptLabels: Record<string, string> = {
  not_required: "чек не требуется",
  pending: "чек ожидает",
  issued: "чек выдан",
  failed: "ошибка чека",
  needs_review: "проверить чек"
};

export const editableStates: OrderState[] = [
  "draft",
  "assigned",
  "accepted",
  "in_progress",
  "delivered",
  "failed",
  "cancelled"
];

export function stateTone(state: OrderState): "good" | "warn" | "bad" | "muted" {
  if (state === "delivered") return "good";
  if (state === "failed" || state === "cancelled") return "bad";
  if (state === "in_progress" || state === "accepted") return "warn";
  return "muted";
}

export function formatMoney(value: number) {
  return new Intl.NumberFormat("ru-RU", {
    maximumFractionDigits: 0,
    style: "currency",
    currency: "RUB"
  }).format(value);
}

export function clientRatingLabel(order: Order) {
  const stats = order.client_rating_stats;
  if (!stats || stats.count === 0) return "нет оценок";
  return `${stats.average.toFixed(1)} / 5 · ${stats.count} оценок`;
}

export function clientRatingShortLabel(order: Order) {
  const stats = order.client_rating_stats;
  if (!stats || stats.count === 0) return null;
  return `★ ${stats.average.toFixed(1)} (${stats.count})`;
}

export function fiscalReceiptLabel(order: Order) {
  return fiscalReceiptLabels[order.fiscal_receipt?.status ?? "not_required"] ?? "чек не требуется";
}

export function markingCount(order: Order) {
  return order.marking_codes?.water?.length ?? 0;
}

export function orderRowClassName(order: Order, isSelected: boolean) {
  if (isOrderOverdue(order)) {
    return isSelected ? "bg-red-50/90 ring-1 ring-inset ring-red-200" : "bg-red-50/80 hover:bg-red-100/80";
  }
  return isSelected ? "bg-blue-50/70" : "hover:bg-slate-50";
}
