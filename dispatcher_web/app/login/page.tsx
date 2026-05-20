import { redirect } from "next/navigation";
import { getProfile } from "@/lib/auth";
import { LoginForm } from "./login-form";

export const dynamic = "force-dynamic";

export default async function LoginPage() {
  const profile = await getProfile();
  if (profile?.is_active && ["dispatcher", "admin"].includes(profile.role)) {
    redirect("/");
  }

  return (
    <main className="grid min-h-screen place-items-center bg-[#f4f7fb] px-5">
      <div className="w-full max-w-md rounded-lg border border-line bg-white p-8 shadow-panel">
        <div className="mb-7">
          <div className="text-sm font-black uppercase tracking-[0.22em] text-brand">Buzhor</div>
          <h1 className="mt-2 text-2xl font-black text-ink">Диспетчерская панель</h1>
          <p className="mt-2 text-sm text-muted">
            Вход доступен только пользователям с ролью dispatcher или admin.
          </p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}
