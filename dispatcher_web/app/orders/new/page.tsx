import { AppShell } from "@/components/app-shell";
import { PageHeader } from "@/components/ui";
import { requireStaff } from "@/lib/auth";
import { getCouriers } from "@/lib/data";
import { NewOrderForm } from "./new-order-form";

export const dynamic = "force-dynamic";

export default async function NewOrderPage() {
  const [profile, couriers] = await Promise.all([requireStaff(), getCouriers()]);

  return (
    <AppShell profile={profile}>
      <PageHeader title="Новый заказ" description="Создание заказа, выбор даты доставки и назначение курьера. Версия формы: delivery-date-v2." />
      <NewOrderForm couriers={couriers} />
    </AppShell>
  );
}
