-- Cover foreign keys used by call-event joins and cascade/set-null updates.
create index if not exists call_events_dispatcher_profile_id_idx
on public.call_events(dispatcher_profile_id)
where dispatcher_profile_id is not null;

create index if not exists call_events_courier_id_idx
on public.call_events(courier_id)
where courier_id is not null;

-- Keep the original tracked updated_at index and remove its live duplicate.
drop index if exists public.idx_orders_updated_at;

-- Write policies created with FOR ALL also participate in SELECT checks.
-- Split them by operation so each SELECT evaluates only one permissive policy.
drop policy if exists app_config_admin_write on public.app_config;

drop policy if exists app_config_admin_insert on public.app_config;
create policy app_config_admin_insert
on public.app_config
for insert
to authenticated
with check (app_private.current_user_role() = 'admin');

drop policy if exists app_config_admin_update on public.app_config;
create policy app_config_admin_update
on public.app_config
for update
to authenticated
using (app_private.current_user_role() = 'admin')
with check (app_private.current_user_role() = 'admin');

drop policy if exists app_config_admin_delete on public.app_config;
create policy app_config_admin_delete
on public.app_config
for delete
to authenticated
using (app_private.current_user_role() = 'admin');

drop policy if exists payments_staff_write on public.payments;

drop policy if exists payments_staff_insert on public.payments;
create policy payments_staff_insert
on public.payments
for insert
to authenticated
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists payments_staff_update on public.payments;
create policy payments_staff_update
on public.payments
for update
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists payments_staff_delete on public.payments;
create policy payments_staff_delete
on public.payments
for delete
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'));
