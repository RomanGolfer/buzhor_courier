import { createBrowserSupabaseClient } from "@/lib/supabase/browser";

type BrowserSupabaseClient = ReturnType<typeof createBrowserSupabaseClient>;
const PUSH_WAIT_TIMEOUT_MS = 2_500;

export async function notifyOrderPush(
  supabase: BrowserSupabaseClient,
  orderId: string,
  event: "created" | "assigned" | "updated",
) {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    const result = await Promise.race([
      supabase.functions.invoke("send-order-push", {
        body: { orderId, event },
      }),
      new Promise<null>((resolve) => {
        timeoutId = setTimeout(() => resolve(null), PUSH_WAIT_TIMEOUT_MS);
      }),
    ]);

    if (result === null) {
      console.warn("Order push notification timed out");
    } else if (result.error) {
      console.warn("Order push notification failed", result.error.message);
    }
  } catch (error) {
    console.warn("Order push notification failed", error);
  } finally {
    if (timeoutId) clearTimeout(timeoutId);
  }
}
