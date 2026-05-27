"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { login, type LoginState } from "./actions";

const initialState: LoginState = {
  error: null
};

export function LoginForm() {
  const [state, formAction] = useActionState(login, initialState);

  return (
    <form className="space-y-4" action={formAction}>
      <label className="block">
        <span className="mb-1 block text-sm font-bold text-ink">Email</span>
        <input
          className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
          name="email"
          type="email"
          autoComplete="email"
          placeholder="dispatcher@buzhor.ru"
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-sm font-bold text-ink">Пароль</span>
        <input
          className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
          name="password"
          type="password"
          autoComplete="current-password"
          placeholder="••••••••"
          required
        />
      </label>
      {state.error ? <p className="rounded-md bg-red-50 px-3 py-2 text-sm font-semibold text-bad">{state.error}</p> : null}
      <SubmitButton />
    </form>
  );
}

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      className="w-full rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:cursor-not-allowed disabled:opacity-60"
      disabled={pending}
    >
      {pending ? "Входим..." : "Войти"}
    </button>
  );
}
