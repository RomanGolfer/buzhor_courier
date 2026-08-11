revoke insert, update on table public.vehicle_assignments from authenticated;

grant insert (
  vehicle_id,
  courier_id,
  assigned_by,
  assignment_note
) on table public.vehicle_assignments to authenticated;

grant update (
  released_at,
  released_by,
  release_note
) on table public.vehicle_assignments to authenticated;

drop policy if exists vehicle_assignments_staff_insert on public.vehicle_assignments;
create policy vehicle_assignments_staff_insert
on public.vehicle_assignments
for insert
to authenticated
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and assigned_by = (select auth.uid())
  and released_at is null
  and released_by is null
  and exists (
    select 1
    from public.vehicles vehicle
    where vehicle.id = vehicle_assignments.vehicle_id
      and vehicle.service_status = 'ready'
  )
  and exists (
    select 1
    from public.couriers courier
    join public.profiles profile on profile.id = courier.profile_id
    where courier.id = vehicle_assignments.courier_id
      and courier.is_active = true
      and profile.is_active = true
      and profile.role = 'courier'
  )
);

drop policy if exists vehicle_assignments_staff_update on public.vehicle_assignments;
create policy vehicle_assignments_staff_update
on public.vehicle_assignments
for update
to authenticated
using (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and released_at is null
)
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and released_at is not null
  and released_by = (select auth.uid())
);

select pg_notify('pgrst', 'reload schema');
