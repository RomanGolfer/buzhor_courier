import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers } from "@/lib/data";
import { NewOrderForm } from "./new-order-form";

export const dynamic = "force-dynamic";

export default async function NewOrderPage({
  searchParams
}: {
  searchParams?: Promise<{ phone?: string | string[] }>;
}) {
  const [profile, couriers] = await Promise.all([requireStaff(), getCouriers()]);
  const params = await searchParams;
  const initialPhone = typeof params?.phone === "string" ? params.phone : "";

  return (
    <AppShell profile={profile}>
      <PageHeader title="Новый заказ" description="Создание заказа, выбор даты доставки и назначение курьера." />
      <NewOrderForm couriers={couriers} initialPhone={initialPhone} />
    </AppShell>
  );
}
