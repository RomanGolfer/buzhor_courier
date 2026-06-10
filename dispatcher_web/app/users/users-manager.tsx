"use client";

import { useMemo, useState } from "react";
import { Panel, StatusPill } from "@/components/ui";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { Profile, Role } from "@/lib/types";

const roleLabels: Record<Role, string> = {
  admin: "Админ",
  dispatcher: "Диспетчер",
  courier: "Курьер"
};

const roles: Role[] = ["courier", "dispatcher", "admin"];

export function UsersManager({
  currentProfile,
  profiles
}: {
  currentProfile: Profile;
  profiles: Profile[];
}) {
  const [rows, setRows] = useState(profiles);
  const [selectedProfileId, setSelectedProfileId] = useState(profiles[0]?.id ?? "");
  const [role, setRole] = useState<Role>(profiles[0]?.role ?? "courier");
  const [fullName, setFullName] = useState(profiles[0]?.full_name ?? "");
  const [phone, setPhone] = useState(profiles[0]?.phone ?? "");
  const [isActive, setIsActive] = useState(profiles[0]?.is_active ?? true);
  const [courierName, setCourierName] = useState(profiles[0]?.couriers?.[0]?.display_name ?? "");
  const [courierPhone, setCourierPhone] = useState(profiles[0]?.couriers?.[0]?.phone ?? "");
  const [courierRegion, setCourierRegion] = useState(profiles[0]?.couriers?.[0]?.region ?? "Анапа");
  const [courierActive, setCourierActive] = useState(profiles[0]?.couriers?.[0]?.is_active ?? true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const isAdmin = currentProfile.role === "admin";

  const selectedProfile = useMemo(() => {
    return rows.find((profile) => profile.id === selectedProfileId) ?? rows[0] ?? null;
  }, [rows, selectedProfileId]);

  function selectProfile(profile: Profile) {
    const courier = profile.couriers?.[0] ?? null;
    setSelectedProfileId(profile.id);
    setRole(profile.role);
    setFullName(profile.full_name ?? "");
    setPhone(profile.phone ?? "");
    setIsActive(profile.is_active);
    setCourierName(courier?.display_name ?? profile.full_name ?? "");
    setCourierPhone(courier?.phone ?? profile.phone ?? "");
    setCourierRegion(courier?.region ?? "Анапа");
    setCourierActive(courier?.is_active ?? true);
    setMessage(null);
    setError(null);
  }

  async function refreshProfiles() {
    const { data } = await supabase
      .from("profiles")
      .select("id, role, email, full_name, phone, is_active, couriers(id, display_name, phone, region, is_active)")
      .order("created_at", { ascending: false });

    if (data) setRows(data as unknown as Profile[]);
  }

  async function saveProfile() {
    if (!selectedProfile || !isAdmin) return;

    setIsSaving(true);
    setMessage(null);
    setError(null);

    const normalizedFullName = fullName.trim() || null;
    const normalizedPhone = phone.trim() || null;
    const { error: profileError } = await supabase
      .from("profiles")
      .update({
        role,
        full_name: normalizedFullName,
        phone: normalizedPhone,
        is_active: isActive
      })
      .eq("id", selectedProfile.id);

    if (profileError) {
      console.warn("Profile update failed", profileError);
      setError("Не удалось сохранить профиль. Попробуйте еще раз.");
      setIsSaving(false);
      return;
    }

    if (role === "courier") {
      const existingCourier = selectedProfile.couriers?.[0] ?? null;
      const payload = {
        profile_id: selectedProfile.id,
        display_name: courierName.trim() || normalizedFullName || selectedProfile.email || "Курьер",
        phone: courierPhone.trim() || normalizedPhone,
        region: courierRegion.trim() || null,
        is_active: courierActive
      };

      const { error: courierError } = existingCourier
        ? await supabase.from("couriers").update(payload).eq("id", existingCourier.id)
        : await supabase.from("couriers").insert(payload);

      if (courierError) {
        console.warn("Courier profile save failed", courierError);
        setError("Не удалось сохранить карточку курьера. Попробуйте еще раз.");
        setIsSaving(false);
        return;
      }
    }

    await refreshProfiles();
    setMessage("Профиль сохранен");
    setIsSaving(false);
  }

  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
      <Panel>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-[0.12em] text-muted">
              <tr>
                <th className="border-b border-line px-4 py-3">Email</th>
                <th className="border-b border-line px-4 py-3">Имя</th>
                <th className="border-b border-line px-4 py-3">Роль</th>
                <th className="border-b border-line px-4 py-3">Курьер</th>
                <th className="border-b border-line px-4 py-3">Статус</th>
                <th className="border-b border-line px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {rows.map((profile) => {
                const courier = profile.couriers?.[0] ?? null;
                return (
                  <tr
                    className={profile.id === selectedProfile?.id ? "bg-blue-50/70" : "hover:bg-slate-50"}
                    key={profile.id}
                  >
                    <td className="border-b border-line px-4 py-3 font-bold text-ink">
                      {profile.email ?? "без email"}
                    </td>
                    <td className="border-b border-line px-4 py-3 text-muted">
                      <div>{profile.full_name ?? "не указано"}</div>
                      <div className="text-xs">{profile.phone ?? "телефон не указан"}</div>
                    </td>
                    <td className="border-b border-line px-4 py-3">{roleLabels[profile.role]}</td>
                    <td className="border-b border-line px-4 py-3">
                      {courier ? courier.display_name : "нет карточки"}
                    </td>
                    <td className="border-b border-line px-4 py-3">
                      <StatusPill tone={profile.is_active ? "good" : "muted"}>
                        {profile.is_active ? "Активен" : "Выключен"}
                      </StatusPill>
                    </td>
                    <td className="border-b border-line px-4 py-3 text-right">
                      <button
                        className="rounded-md border border-line px-3 py-2 text-xs font-black text-ink hover:border-brand hover:text-brand"
                        onClick={() => selectProfile(profile)}
                      >
                        Открыть
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Panel>

      <Panel className="h-fit p-5 xl:sticky xl:top-6">
        {selectedProfile ? (
          <div className="space-y-4">
            <div>
              <div className="text-xs font-black uppercase tracking-[0.16em] text-muted">Профиль</div>
              <h2 className="mt-1 text-xl font-black text-ink">{selectedProfile.email ?? selectedProfile.id}</h2>
            </div>

            {!isAdmin ? (
              <div className="rounded-md bg-amber-50 px-3 py-2 text-sm font-bold text-warn">
                Управление ролями доступно только admin.
              </div>
            ) : null}

            <label className="block">
              <span className="mb-1 block text-sm font-bold text-ink">Роль</span>
              <select
                className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
                disabled={!isAdmin}
                value={role}
                onChange={(event) => setRole(event.target.value as Role)}
              >
                {roles.map((value) => (
                  <option key={value} value={value}>
                    {roleLabels[value]}
                  </option>
                ))}
              </select>
            </label>

            <Field disabled={!isAdmin} label="Имя" value={fullName} onChange={setFullName} />
            <Field disabled={!isAdmin} label="Телефон" value={phone} onChange={setPhone} />

            <label className="flex items-center gap-2 text-sm font-bold text-ink">
              <input
                checked={isActive}
                disabled={!isAdmin}
                onChange={(event) => setIsActive(event.target.checked)}
                type="checkbox"
              />
              Активный профиль
            </label>

            {role === "courier" ? (
              <div className="space-y-3 rounded-md border border-line bg-slate-50 p-3">
                <div className="text-sm font-black text-ink">Карточка курьера</div>
                <Field disabled={!isAdmin} label="Имя курьера" value={courierName} onChange={setCourierName} />
                <Field disabled={!isAdmin} label="Телефон курьера" value={courierPhone} onChange={setCourierPhone} />
                <Field disabled={!isAdmin} label="Регион" value={courierRegion} onChange={setCourierRegion} />
                <label className="flex items-center gap-2 text-sm font-bold text-ink">
                  <input
                    checked={courierActive}
                    disabled={!isAdmin}
                    onChange={(event) => setCourierActive(event.target.checked)}
                    type="checkbox"
                  />
                  Активный курьер
                </label>
              </div>
            ) : null}

            {message ? <div className="rounded-md bg-emerald-50 px-3 py-2 text-sm font-bold text-good">{message}</div> : null}
            {error ? <div className="rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</div> : null}

            <button
              className="w-full rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:opacity-60"
              disabled={!isAdmin || isSaving}
              onClick={() => void saveProfile()}
            >
              {isSaving ? "Сохраняем..." : "Сохранить профиль"}
            </button>
          </div>
        ) : (
          <div className="text-sm font-semibold text-muted">Профилей пока нет.</div>
        )}
      </Panel>
    </div>
  );
}

function Field({
  disabled,
  label,
  value,
  onChange
}: {
  disabled: boolean;
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-bold text-ink">{label}</span>
      <input
        className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm disabled:bg-slate-100"
        disabled={disabled}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}
