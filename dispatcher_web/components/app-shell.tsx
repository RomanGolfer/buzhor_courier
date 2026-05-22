import Link from "next/link";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

type AppShellProps = {
  profile: Profile;
  children: React.ReactNode;
};

export function AppShell({ profile, children }: AppShellProps) {
  async function signOut() {
    "use server";
    const supabase = await createServerSupabaseClient();
    await supabase.auth.signOut();
    redirect("/login");
  }

  return (
    <div className="min-h-screen bg-[#f4f7fb]">
      <header className="border-b border-line bg-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4">
          <div>
            <div className="text-lg font-black text-ink">Buzhor Dispatcher</div>
            <div className="text-xs font-medium uppercase tracking-[0.18em] text-muted">
              {profile.role}
            </div>
          </div>
          <nav className="flex items-center gap-2 text-sm font-semibold text-muted">
            <Link className="rounded-md px-3 py-2 hover:bg-slate-100 hover:text-ink" href="/">
              Заказы
            </Link>
            <Link className="rounded-md px-3 py-2 hover:bg-slate-100 hover:text-ink" href="/orders/new">
              Новый заказ
            </Link>
            <Link className="rounded-md px-3 py-2 hover:bg-slate-100 hover:text-ink" href="/couriers">
              Курьеры
            </Link>
            <Link className="rounded-md px-3 py-2 hover:bg-slate-100 hover:text-ink" href="/users">
              Пользователи
            </Link>
            <form action={signOut}>
              <button className="ml-2 rounded-md border border-line px-3 py-2 hover:border-brand hover:text-brand">
                Выйти
              </button>
            </form>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-5 py-6">{children}</main>
    </div>
  );
}
