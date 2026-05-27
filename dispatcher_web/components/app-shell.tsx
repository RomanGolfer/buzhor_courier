import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";
import { ShellNav } from "./shell-nav";

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
    <div className="min-h-screen bg-white">
      <aside className="fixed inset-y-0 left-0 z-30 flex w-24 flex-col border-r border-line bg-white">
        <div className="flex h-20 items-center justify-center border-b border-line">
          <div className="flex size-9 items-center justify-center rounded-full bg-brand text-sm font-black text-white">
            {profile.full_name?.slice(0, 1).toUpperCase() || "A"}
          </div>
        </div>
        <ShellNav />
        <form action={signOut} className="border-t border-line p-2">
          <button className="w-full px-2 py-3 text-xs font-semibold text-ink hover:text-brand">
            Выйти
          </button>
        </form>
      </aside>
      <main className="min-h-screen pl-24">
        <div className="max-w-[1800px] px-8 py-8">{children}</div>
      </main>
    </div>
  );
}
