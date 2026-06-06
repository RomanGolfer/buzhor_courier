"use server";

import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { checkRateLimit, rateLimitKey } from "@/lib/security/rate-limit";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

export type LoginState = {
  error: string | null;
};

const LOGIN_RATE_LIMIT = 8;
const LOGIN_RATE_WINDOW_MS = 10 * 60 * 1000;

export async function login(_state: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: "Введите email и пароль" };
  }

  const requestHeaders = await headers();
  const rateLimit = checkRateLimit({
    key: rateLimitKey("dispatcher-login", requestHeaders, email),
    limit: LOGIN_RATE_LIMIT,
    windowMs: LOGIN_RATE_WINDOW_MS
  });

  if (rateLimit.limited) {
    return { error: `Слишком много попыток входа. Попробуйте через ${rateLimit.retryAfterSeconds} сек.` };
  }

  const supabase = await createServerSupabaseClient();
  const { data, error: loginError } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (loginError || !data.user) {
    return { error: "Неверный email или пароль" };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, role, email, full_name, phone, is_active")
    .eq("id", data.user.id)
    .single();

  const staffProfile = profile as Profile | null;

  if (profileError || !staffProfile || !staffProfile.is_active || !["dispatcher", "admin"].includes(staffProfile.role)) {
    await supabase.auth.signOut();
    return { error: "У пользователя нет доступа к диспетчерской панели" };
  }

  revalidatePath("/", "layout");
  redirect("/");
}
