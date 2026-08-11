import { Store, Truck, Timer, UserRoundPlus } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { PageHeader, Panel } from "@/components/ui";
import { requireStaff } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function MicroMarketsPage() {
  const profile = await requireStaff();

  return (
    <AppShell profile={profile}>
      <PageHeader
        title="Микромаркеты 0"
        description="Контроль точек самообслуживания и вендинговых аппаратов для продажи воды."
      />
      <Panel className="max-w-4xl p-6">
        <div className="bg-slate-100 p-7">
          <Store className="mb-4 size-10 text-brand" />
          <h2 className="max-w-xl text-3xl font-black leading-tight text-ink">Вендинговые аппараты для продажи воды</h2>
          <p className="mt-3 text-sm font-semibold text-muted">Раздел готов к подключению реестра аппаратов. Сейчас источника данных о микромаркетах в Supabase нет.</p>
        </div>
        <div className="mt-4 grid gap-3 md:grid-cols-3">
          <Feature icon={Truck} title="Разгружают логистику">Одна загрузка точки вместо нескольких доставок на один адрес.</Feature>
          <Feature icon={Timer} title="Доступность 24/7">Клиенты получают воду без ожидания курьера.</Feature>
          <Feature icon={UserRoundPlus} title="Новые клиенты">Точки самообслуживания расширяют охват доставки.</Feature>
        </div>
      </Panel>
    </AppShell>
  );
}

function Feature({ icon: Icon, title, children }: { icon: typeof Truck; title: string; children: React.ReactNode }) {
  return (
    <div className="border border-line p-5">
      <Icon className="size-6 text-brand" />
      <h3 className="mt-3 font-black text-ink">{title}</h3>
      <p className="mt-2 text-sm text-muted">{children}</p>
    </div>
  );
}
