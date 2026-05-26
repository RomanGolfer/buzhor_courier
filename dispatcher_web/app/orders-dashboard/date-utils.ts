import type { Order, OrderState } from "@/lib/types";

export const moscowOffsetMs = 3 * 60 * 60 * 1000;
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
  const delivery = order.delivery_date
    ? new Date(`${order.delivery_date}T00:00:00Z`)
    : new Date(order.created_at);
  const deliveryParts = order.delivery_date
    ? {
        day: delivery.getUTCDate(),
        month: delivery.getUTCMonth(),
        year: delivery.getUTCFullYear()
      }
    : moscowDateParts(delivery);
  const endUtc = new Date(Date.UTC(deliveryParts.year, deliveryParts.month, deliveryParts.day, slotEnd.hour, slotEnd.minute) - moscowOffsetMs);
  return Date.now() >= endUtc.getTime();
}
