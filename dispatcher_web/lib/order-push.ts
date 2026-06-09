import { createBrowserSupabaseClient } from "@/lib/supabase/browser";

type BrowserSupabaseClient = ReturnType<typeof createBrowserSupabaseClient>;

export async function notifyOrderPush(
  supabase: BrowserSupabaseClient,
  orderId: string,
  event: "created" | "assigned" | "updated",
) {
  try {
    const { error } = await supabase.functions.invoke("send-order-push", {
      body: { orderId, event },
    });

    if (error) {
      console.warn("Order push notification failed", error.message);
    }
  } catch (error) {
    console.warn("Order push notification failed", error);
  }
}
