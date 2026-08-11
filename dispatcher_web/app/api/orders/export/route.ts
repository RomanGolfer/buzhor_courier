import { getApiStaffContext } from "@/lib/auth";

export async function GET(request: Request) {
  const context = await getApiStaffContext();
  if (!context) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const requestedDate = new URL(request.url).searchParams.get("date") ?? "";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(requestedDate)) {
    return Response.json({ error: "invalid_date" }, { status: 400 });
  }

  const { data, error } = await context.supabase
    .from("orders")
    .select(
      "order_number, client_name, client_phone, address, district, delivery_date, time_slot, bottles, state, payment_method, created_at, couriers(display_name), delivery_zones(name)"
    )
    .eq("delivery_date", requestedDate)
    .order("created_at", { ascending: false });

  if (error) {
    console.warn("Orders export failed", error);
    return Response.json({ error: "export_failed" }, { status: 500 });
  }

  const header = [
    "Номер",
    "Клиент",
    "Телефон",
    "Адрес",
    "Район",
    "Зона доставки",
    "Дата доставки",
    "Интервал",
    "Бутыли",
    "Водитель",
    "Статус",
    "Оплата",
    "Создан"
  ];
  const rows = (data ?? []).map((order) => [
    order.order_number,
    order.client_name,
    order.client_phone,
    order.address,
    order.district,
    relationName(order.delivery_zones),
    order.delivery_date,
    order.time_slot,
    order.bottles,
    relationName(order.couriers),
    order.state,
    order.payment_method,
    order.created_at
  ]);
  const csv = `\uFEFF${[header, ...rows].map((row) => row.map(csvCell).join(";")).join("\r\n")}`;

  return new Response(csv, {
    headers: {
      "Content-Disposition": `attachment; filename="buzhor-orders-${requestedDate}.csv"`,
      "Content-Type": "text/csv; charset=utf-8"
    }
  });
}

function relationName(value: { name?: string | null; display_name?: string | null } | Array<{ name?: string | null; display_name?: string | null }> | null) {
  const relation = Array.isArray(value) ? value[0] : value;
  return relation?.name ?? relation?.display_name ?? "";
}

function csvCell(value: unknown) {
  let text = value === null || value === undefined ? "" : String(value);
  if (/^[=+\-@]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}
