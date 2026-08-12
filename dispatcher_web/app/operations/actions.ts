"use server";

import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

type IssueStatus = "open" | "acknowledged" | "resolved" | "dismissed";

export async function updateOperationalIssue(input: {
  issueKey: string;
  issueType: string;
  status: IssueStatus;
  note: string;
  orderId: string | null;
  courierId: string | null;
}) {
  await requireStaff();
  if (
    input.issueKey.length < 3 || input.issueKey.length > 240
    || input.issueType.length < 2 || input.issueType.length > 80
    || !["open", "acknowledged", "resolved", "dismissed"].includes(input.status)
    || input.note.length > 1000
  ) {
    return { ok: false as const, error: "Некорректное действие по проблеме." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_operational_issue_status", {
    p_courier_id: input.courierId,
    p_issue_key: input.issueKey,
    p_issue_type: input.issueType,
    p_note: input.note,
    p_order_id: input.orderId,
    p_status: input.status
  });
  if (error) {
    console.warn("Operational issue update failed", error);
    return { ok: false as const, error: "Не удалось обновить проблему." };
  }
  revalidatePath("/operations");
  return { ok: true as const };
}
