"use client";

import type { FormEvent } from "react";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Profile } from "@/lib/types";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsLoading(true);

    const supabase = createBrowserSupabaseClient();
    const { data, error: loginError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password
    });

    if (loginError || !data.user) {
      setError(loginError?.message ?? "Не удалось войти");
      setIsLoading(false);
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, role, full_name, phone, is_active")
      .eq("id", data.user.id)
      .single();

    const staffProfile = profile as Profile | null;

    if (profileError || !staffProfile || !staffProfile.is_active || !["dispatcher", "admin"].includes(staffProfile.role)) {
      await supabase.auth.signOut();
      setError("У пользователя нет доступа к диспетчерской панели");
      setIsLoading(false);
      return;
    }

    router.replace("/");
    router.refresh();
  }

  return (
    <form className="space-y-4" onSubmit={onSubmit}>
      <label className="block">
        <span className="mb-1 block text-sm font-bold text-ink">Email</span>
        <input
          className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="dispatcher@buzhor.ru"
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-sm font-bold text-ink">Пароль</span>
        <input
          className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          placeholder="••••••••"
          required
        />
      </label>
      {error ? <p className="rounded-md bg-red-50 px-3 py-2 text-sm font-semibold text-bad">{error}</p> : null}
      <button
        className="w-full rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:cursor-not-allowed disabled:opacity-60"
        disabled={isLoading}
      >
        {isLoading ? "Входим..." : "Войти"}
      </button>
    </form>
  );
}
