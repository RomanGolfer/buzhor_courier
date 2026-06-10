import { createClient } from "@supabase/supabase-js";

type JsonObject = Record<string, unknown>;

type OrderPushRequest = {
  orderId?: string;
  event?: "created" | "assigned" | "updated";
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
};

type OrderRow = {
  id: string;
  order_number: string;
  assigned_courier_id: string | null;
  address: string;
  client_name: string;
  delivery_date: string | null;
  time_slot: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "missing_supabase_env" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("role, is_active")
    .eq("id", user.id)
    .maybeSingle();

  if (
    profileError ||
    !profile?.is_active ||
    !["dispatcher", "admin"].includes(String(profile.role))
  ) {
    return jsonResponse({ error: "forbidden" }, 403);
  }

  const body = (await req.json().catch(() => ({}))) as OrderPushRequest;
  if (!body.orderId) {
    return jsonResponse({ error: "missing_order_id" }, 400);
  }

  const { data: order, error: orderError } = await adminClient
    .from("orders")
    .select(
      "id, order_number, assigned_courier_id, address, client_name, delivery_date, time_slot",
    )
    .eq("id", body.orderId)
    .maybeSingle<OrderRow>();

  if (orderError || !order) {
    return jsonResponse({ error: "order_not_found" }, 404);
  }

  if (!order.assigned_courier_id) {
    return jsonResponse({ ok: true, sent: 0, skipped: "order_unassigned" });
  }

  const { data: tokenRows, error: tokensError } = await adminClient
    .from("device_push_tokens")
    .select("fcm_token")
    .eq("courier_id", order.assigned_courier_id);

  if (tokensError) {
    return jsonResponse({ error: "tokens_lookup_failed" }, 500);
  }

  const tokens = [
    ...new Set(
      (tokenRows ?? [])
        .map((row: { fcm_token?: string | null }) => row.fcm_token)
        .filter((token): token is string => Boolean(token)),
    ),
  ];

  if (tokens.length === 0) {
    return jsonResponse({ ok: true, sent: 0, skipped: "no_tokens" });
  }

  let accessToken: { accessToken: string; projectId: string };
  try {
    accessToken = await getFirebaseAccessToken();
  } catch (error) {
    logInternalError("Firebase access token creation failed", error);
    return jsonResponse({ error: "firebase_credentials_failed" }, 500);
  }

  const results = await Promise.allSettled(
    tokens.map((token) => sendFcmMessage(accessToken, token, order, body.event)),
  );
  const sent = results.filter((result) => result.status === "fulfilled").length;
  const failed = results.length - sent;

  return jsonResponse({ ok: true, sent, failed });
});

function jsonResponse(body: JsonObject, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function logInternalError(message: string, error: unknown) {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(message, detail);
}

async function getFirebaseAccessToken() {
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");

  if (!serviceAccountJson) {
    throw new Error("missing_firebase_service_account_json");
  }

  const serviceAccount = JSON.parse(serviceAccountJson) as ServiceAccount;
  const firebaseProjectId = projectId || serviceAccount.project_id;
  if (!firebaseProjectId) {
    throw new Error("missing_firebase_project_id");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsignedJwt = `${base64Url(JSON.stringify(header))}.${base64Url(
    JSON.stringify(claimSet),
  )}`;
  const privateKey = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedJwt),
  );
  const jwt = `${unsignedJwt}.${base64Url(new Uint8Array(signature))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    console.error("Firebase OAuth token request failed", tokenResponse.status);
    throw new Error("firebase_token_failed");
  }

  const tokenJson = await tokenResponse.json();
  return {
    accessToken: String(tokenJson.access_token),
    projectId: firebaseProjectId,
  };
}

async function importPrivateKey(privateKeyPem: string) {
  const normalizedPem = privateKeyPem.replace(/\\n/g, "\n");
  const pemBody = normalizedPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(pemBody);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }

  return crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64Url(value: string | Uint8Array) {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function sendFcmMessage(
  credentials: { accessToken: string; projectId: string },
  token: string,
  order: OrderRow,
  event: OrderPushRequest["event"],
) {
  const body = buildMessageBody(token, order, event);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${credentials.projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${credentials.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    throw new Error(`fcm_send_failed:${await response.text()}`);
  }
}

function buildMessageBody(
  token: string,
  order: OrderRow,
  event: OrderPushRequest["event"],
) {
  const title =
    event === "assigned"
      ? `Назначен заказ ${order.order_number}`
      : `Новый заказ ${order.order_number}`;
  const details = [order.address, order.time_slot].filter(Boolean).join(" · ");

  return {
    message: {
      token,
      notification: {
        title,
        body: details || order.client_name,
      },
      data: {
        type: "new_order",
        order_id: order.id,
        order_number: order.order_number,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    },
  };
}
