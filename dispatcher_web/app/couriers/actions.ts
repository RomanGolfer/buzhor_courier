"use server";

import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export type SaveCourierInventoryInput = {
  courierId: string;
  workDate: string;
  loadedFullBottles: number;
  openingEmptyBottles: number;
  unloadedFullBottles: number;
  unloadedEmptyBottles: number;
  notes: string;
};

export async function saveCourierInventory(input: SaveCourierInventoryInput) {
  await requireStaff();
  if (!input.courierId || !/^\d{4}-\d{2}-\d{2}$/.test(input.workDate)) {
    return { ok: false as const, error: "Некорректный водитель или дата." };
  }

  const quantities = [
    input.loadedFullBottles,
    input.openingEmptyBottles,
    input.unloadedFullBottles,
    input.unloadedEmptyBottles
  ];
  if (quantities.some((value) => !Number.isInteger(value) || value < 0 || value > 100000)) {
    return { ok: false as const, error: "Количество должно быть целым числом от 0 до 100000." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("save_courier_daily_inventory", {
    p_courier_id: input.courierId,
    p_loaded_full_bottles: input.loadedFullBottles,
    p_notes: input.notes,
    p_opening_empty_bottles: input.openingEmptyBottles,
    p_unloaded_empty_bottles: input.unloadedEmptyBottles,
    p_unloaded_full_bottles: input.unloadedFullBottles,
    p_work_date: input.workDate
  });

  if (error) {
    console.warn("Courier daily inventory save failed", error);
    return { ok: false as const, error: "Не удалось сохранить загрузку и остатки." };
  }

  revalidatePath("/couriers");
  return { ok: true as const };
}
