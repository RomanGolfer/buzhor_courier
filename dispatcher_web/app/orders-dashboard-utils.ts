import type { Order, OrderState } from "@/lib/types";

export const orderSelect =
  "id, order_number, assigned_courier_id, state, client_name, client_phone, address, district, lat, lng, payment_method, price, bottles, marking_codes, fiscal_receipt, client_rating, time_slot, delivery_comment, failure_reason, created_at, updated_at, couriers(id, display_name)";

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

const moscowOffsetMs = 3 * 60 * 60 * 1000;
const defaultTimeSlot = "10:00 - 14:00";
const activeStates: OrderState[] = ["draft", "assigned", "accepted", "in_progress"];

export function todayDateKey() {
  const parts = new Intl.DateTimeFormat("en", {
    day: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Moscow",
    year: "numeric"
  }).formatToParts(new Date());
  const getPart = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  return `${getPart("year")}-${getPart("month")}-${getPart("day")}`;
}

export function dateRangeForKey(dateKey: string) {
  const selectedDate = dateKey.match(/^\d{4}-\d{2}-\d{2}$/) ? dateKey : todayDateKey();
  const [year, month, day] = selectedDate.split("-").map(Number);
  const start = new Date(Date.UTC(year, month - 1, day) - moscowOffsetMs);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { start: start.toISOString(), end: end.toISOString() };
}

export function formatDateLabel(dateKey: string) {
  const date = new Date(`${dateKey}T00:00:00`);
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    month: "long",
    year: "numeric"
  }).format(date);
}

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

function parseTimeSlotEnd(slot: string | null) {
  const match = (slot?.trim() || defaultTimeSlot).match(/^\s*\d{1,2}:\d{2}\s*[-–—]\s*(\d{1,2}):(\d{2})\s*$/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return { hour, minute };
}

function moscowDateParts(date: Date) {
  const moscow = new Date(date.getTime() + moscowOffsetMs);
  return {
    day: moscow.getUTCDate(),
    month: moscow.getUTCMonth(),
    year: moscow.getUTCFullYear()
  };
}

export function isOrderOverdue(order: Order) {
  if (!activeStates.includes(order.state)) return false;
  const slotEnd = parseTimeSlotEnd(order.time_slot);
  if (!slotEnd) return false;
  const created = moscowDateParts(new Date(order.created_at));
  const endUtc = new Date(Date.UTC(created.year, created.month, created.day, slotEnd.hour, slotEnd.minute) - moscowOffsetMs);
  return Date.now() >= endUtc.getTime();
}

export function orderRowClassName(order: Order, isSelected: boolean) {
  if (isOrderOverdue(order)) {
    return isSelected ? "bg-red-50/90 ring-1 ring-inset ring-red-200" : "bg-red-50/80 hover:bg-red-100/80";
  }
  return isSelected ? "bg-blue-50/70" : "hover:bg-slate-50";
}
