const moscowTimeZone = "Europe/Moscow";

export function todayDateKey() {
  return dateKeyFromDate(new Date());
}

function dateKeyFromNow(days: number) {
  return dateKeyFromDate(new Date(Date.now() + days * 24 * 60 * 60 * 1000));
}

function dateKeyFromDate(date: Date) {
  const parts = new Intl.DateTimeFormat("en", {
    day: "2-digit",
    month: "2-digit",
    timeZone: moscowTimeZone,
    year: "numeric"
  }).formatToParts(date);
  const getPart = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  return `${getPart("year")}-${getPart("month")}-${getPart("day")}`;
}

export function datePresets() {
  return [
    { label: "Сегодня", value: dateKeyFromNow(0) },
    { label: "Завтра", value: dateKeyFromNow(1) },
    { label: "Послезавтра", value: dateKeyFromNow(2) }
  ];
}

export function formatShortDate(dateKey: string) {
  const [year, month, day] = dateKey.split("-").map(Number);
  if (!year || !month || !day) return "";
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    month: "long",
    timeZone: moscowTimeZone,
    weekday: "short"
  }).format(new Date(Date.UTC(year, month - 1, day)));
}
