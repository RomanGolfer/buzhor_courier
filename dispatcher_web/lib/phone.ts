export function normalizePhone(value: string | null | undefined) {
  const digits = value?.replace(/\D/g, "") ?? "";
  if (!digits) return null;
  if (digits.length === 11 && digits.startsWith("8")) return `7${digits.slice(1)}`;
  if (digits.length === 10) return `7${digits}`;
  if (digits.length === 11 && digits.startsWith("7")) return digits;
  return digits.length >= 6 ? digits : null;
}

export function formatPhoneForDisplay(value: string | null | undefined) {
  const phone = normalizePhone(value);
  if (!phone) return value?.trim() || "не указан";
  if (phone.length !== 11 || !phone.startsWith("7")) return `+${phone}`;
  return `+7 ${phone.slice(1, 4)} ${phone.slice(4, 7)} ${phone.slice(7, 9)} ${phone.slice(9, 11)}`;
}
