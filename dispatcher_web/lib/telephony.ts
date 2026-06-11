import { normalizePhone } from "./phone";

export type TelephonyCallResult =
  | {
      ok: true;
      provider: string;
      providerCallId: string | null;
    }
  | {
      ok: false;
      provider: string;
      status: number;
      error: string;
    };

type PlaceTelephonyCallOptions = {
  dispatcherProfileId: string;
  orderId: string | null;
  phone: string;
};

export const normalizePhoneForTelephony = normalizePhone;

export function getTelephonyProviderName() {
  return process.env.TELEPHONY_PROVIDER?.trim() || "generic";
}

export async function placeTelephonyCall({
  dispatcherProfileId,
  orderId,
  phone
}: PlaceTelephonyCallOptions): Promise<TelephonyCallResult> {
  const provider = getTelephonyProviderName();
  const originateUrl = process.env.TELEPHONY_ORIGINATE_URL?.trim();
  const normalizedPhone = normalizePhoneForTelephony(phone);

  if (!normalizedPhone) {
    return {
      ok: false,
      provider,
      status: 400,
      error: "Некорректный номер телефона"
    };
  }

  if (!originateUrl) {
    return {
      ok: false,
      provider,
      status: 501,
      error: "АТС не настроена: задайте TELEPHONY_ORIGINATE_URL"
    };
  }

  const headers = new Headers({
    Accept: "application/json",
    "Content-Type": "application/json"
  });
  const token = process.env.TELEPHONY_API_TOKEN?.trim();
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const response = await fetch(originateUrl, {
    body: JSON.stringify({
      dispatcher_profile_id: dispatcherProfileId,
      from_extension: process.env.TELEPHONY_FROM_EXTENSION?.trim() || null,
      order_id: orderId,
      to: normalizedPhone
    }),
    cache: "no-store",
    headers,
    method: "POST"
  });

  const body = await readJsonObject(response);
  if (!response.ok) {
    return {
      ok: false,
      provider,
      status: response.status,
      error: getString(body, ["error", "message"]) ?? `АТС вернула ошибку ${response.status}`
    };
  }

  return {
    ok: true,
    provider,
    providerCallId: getString(body, ["provider_call_id", "call_id", "id"])
  };
}

async function readJsonObject(response: Response) {
  try {
    const data = await response.json();
    return data && typeof data === "object" && !Array.isArray(data) ? (data as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function getString(data: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = data[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}
