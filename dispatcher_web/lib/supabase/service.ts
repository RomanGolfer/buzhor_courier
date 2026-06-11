import { createClient } from "@supabase/supabase-js";
import { getSupabaseServiceConfig } from "./config";

export function createServiceSupabaseClient() {
  const { url, serviceRoleKey } = getSupabaseServiceConfig();

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false
    }
  });
}
