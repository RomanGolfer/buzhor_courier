"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, requireStaff } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export type CloseShiftInput = {
  courierId: string;
  workDate: string;
  actualCash: number;
  actualCard: number;
  actualQr: number;
  actualOnline: number;
  actualContract: number;
  actualFullBottles: number;
  actualEmptyBottles: number;
  startMileage: number | null;
  endMileage: number | null;
  discrepancyReason: string;
  notes: string;
};

export async function closeCourierShift(input: CloseShiftInput) {
  await requireStaff();
  const moneyValues = [input.actualCash, input.actualCard, input.actualQr, input.actualOnline, input.actualContract];
  const bottleValues = [input.actualFullBottles, input.actualEmptyBottles];
  const mileageValues = [input.startMileage, input.endMileage].filter((value): value is number => value !== null);
  if (
    !input.courierId || !/^\d{4}-\d{2}-\d{2}$/.test(input.workDate)
    || moneyValues.some((value) => !Number.isFinite(value) || value < 0 || value > 100000000)
    || bottleValues.some((value) => !Number.isInteger(value) || value < 0 || value > 100000)
    || mileageValues.some((value) => !Number.isFinite(value) || value < 0 || value > 10000000)
    || (input.startMileage !== null && input.endMileage !== null && input.endMileage < input.startMileage)
    || input.discrepancyReason.length > 1000 || input.notes.length > 2000
  ) {
    return { ok: false as const, error: "Проверьте суммы, остатки и пробег." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("close_courier_shift", {
    p_actual_card: input.actualCard,
    p_actual_cash: input.actualCash,
    p_actual_contract: input.actualContract,
    p_actual_empty_bottles: input.actualEmptyBottles,
    p_actual_full_bottles: input.actualFullBottles,
    p_actual_online: input.actualOnline,
    p_actual_qr: input.actualQr,
    p_courier_id: input.courierId,
    p_discrepancy_reason: input.discrepancyReason,
    p_end_mileage: input.endMileage,
    p_notes: input.notes,
    p_start_mileage: input.startMileage,
    p_work_date: input.workDate
  });
  if (error) {
    console.warn("Shift close failed", error);
    if (error.message.includes("active_orders_remain")) return { ok: false as const, error: "У водителя остались активные заказы." };
    if (error.message.includes("inventory_not_configured")) return { ok: false as const, error: "Сначала заполните загрузку и выгрузку машины." };
    if (error.message.includes("discrepancy_reason_required")) return { ok: false as const, error: "Для расхождения укажите причину не короче пяти символов." };
    if (error.message.includes("shift_already_closed")) return { ok: false as const, error: "Смена уже закрыта." };
    return { ok: false as const, error: "Не удалось закрыть смену." };
  }
  revalidatePath("/shifts");
  revalidatePath("/operations");
  revalidatePath("/couriers");
  return { ok: true as const };
}

export async function reopenCourierShift(input: { courierId: string; workDate: string; reason: string }) {
  await requireAdmin();
  if (!input.courierId || !/^\d{4}-\d{2}-\d{2}$/.test(input.workDate) || input.reason.trim().length < 5 || input.reason.length > 1000) {
    return { ok: false as const, error: "Укажите причину повторного открытия смены." };
  }
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("reopen_courier_shift", {
    p_courier_id: input.courierId,
    p_reason: input.reason,
    p_work_date: input.workDate
  });
  if (error) {
    console.warn("Shift reopen failed", error);
    return { ok: false as const, error: "Не удалось открыть смену повторно." };
  }
  revalidatePath("/shifts");
  revalidatePath("/operations");
  revalidatePath("/couriers");
  return { ok: true as const };
}
