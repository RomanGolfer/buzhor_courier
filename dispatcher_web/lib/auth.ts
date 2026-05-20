import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

export async function getProfile() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data } = await supabase
    .from("profiles")
    .select("id, role, full_name, phone, is_active")
    .eq("id", user.id)
    .single();

  return data as Profile | null;
}

export async function requireStaff() {
  const profile = await getProfile();
  if (!profile || !profile.is_active || !["dispatcher", "admin"].includes(profile.role)) {
    redirect("/login");
  }
  return profile;
}
