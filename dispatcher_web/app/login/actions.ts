"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

export type LoginState = {
  error: string | null;
};

export async function login(_state: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: "Введите email и пароль" };
  }

  const supabase = await createServerSupabaseClient();
  const { data, error: loginError } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (loginError || !data.user) {
    return { error: loginError?.message ?? "Не удалось войти" };
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
