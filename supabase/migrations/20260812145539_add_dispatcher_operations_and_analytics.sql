-- Dispatcher operations, shift reconciliation, bottle ledger, notifications,
-- audit trail, safe import rollback, courier location and analytics.

alter table public.couriers
  add column last_lat numeric(10, 7),
  add column last_lng numeric(10, 7),
  add column last_location_accuracy_m numeric(10, 2),
  add column last_location_at timestamptz,
  add constraint couriers_last_location_range_chk check (
    (last_lat is null or last_lat between -90 and 90)
    and (last_lng is null or last_lng between -180 and 180)
    and (last_location_accuracy_m is null or last_location_accuracy_m between 0 and 100000)
  ),
  add constraint couriers_last_location_pair_chk check ((last_lat is null) = (last_lng is null));

create table public.courier_shifts (
  id uuid primary key default gen_random_uuid(),
  courier_id uuid not null references public.couriers(id) on delete restrict,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  work_date date not null,
  status text not null default 'open' check (status in ('open', 'closed')),
  expected_cash numeric(12, 2) not null default 0 check (expected_cash >= 0),
  expected_card numeric(12, 2) not null default 0 check (expected_card >= 0),
  expected_qr numeric(12, 2) not null default 0 check (expected_qr >= 0),
  expected_online numeric(12, 2) not null default 0 check (expected_online >= 0),
  expected_contract numeric(12, 2) not null default 0 check (expected_contract >= 0),
  actual_cash numeric(12, 2) check (actual_cash is null or actual_cash >= 0),
  actual_card numeric(12, 2) check (actual_card is null or actual_card >= 0),
  actual_qr numeric(12, 2) check (actual_qr is null or actual_qr >= 0),
  actual_online numeric(12, 2) check (actual_online is null or actual_online >= 0),
  actual_contract numeric(12, 2) check (actual_contract is null or actual_contract >= 0),
  expected_full_bottles integer not null default 0,
  expected_empty_bottles integer not null default 0,
  actual_full_bottles integer check (actual_full_bottles is null or actual_full_bottles >= 0),
  actual_empty_bottles integer check (actual_empty_bottles is null or actual_empty_bottles >= 0),
  start_mileage numeric(12, 1) check (start_mileage is null or start_mileage >= 0),
  end_mileage numeric(12, 1) check (end_mileage is null or end_mileage >= 0),
  discrepancy_reason text,
  notes text,
  closed_by uuid references public.profiles(id) on delete set null,
  closed_at timestamptz,
  reopened_by uuid references public.profiles(id) on delete set null,
  reopened_at timestamptz,
  reopen_reason text,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint courier_shifts_courier_date_key unique (courier_id, work_date),
  constraint courier_shifts_date_chk check (work_date >= date '2020-01-01'),
  constraint courier_shifts_mileage_chk check (
    start_mileage is null or end_mileage is null or end_mileage >= start_mileage
  ),
  constraint courier_shifts_text_chk check (
    (discrepancy_reason is null or char_length(discrepancy_reason) <= 1000)
    and (notes is null or char_length(notes) <= 2000)
    and (reopen_reason is null or char_length(reopen_reason) <= 1000)
  )
);

create table public.courier_inventory_movements (
  id uuid primary key default gen_random_uuid(),
  courier_id uuid not null references public.couriers(id) on delete restrict,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  work_date date not null,
  event_type text not null check (event_type in (
    'dispatcher_inventory', 'delivery', 'delivery_correction', 'shift_close', 'manual_adjustment'
  )),
  full_bottles_delta integer not null default 0,
  empty_bottles_delta integer not null default 0,
  source_order_id uuid references public.orders(id) on delete set null,
  source_inventory_id uuid references public.courier_daily_inventory(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint courier_inventory_movement_nonzero_chk check (
    full_bottles_delta <> 0 or empty_bottles_delta <> 0
  ),
  constraint courier_inventory_movement_note_chk check (note is null or char_length(note) <= 1000),
  constraint courier_inventory_movement_metadata_chk check (jsonb_typeof(metadata) = 'object')
);

create table public.operational_issue_actions (
  id uuid primary key default gen_random_uuid(),
  issue_key text not null unique,
  issue_type text not null,
  order_id uuid references public.orders(id) on delete cascade,
  courier_id uuid references public.couriers(id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved', 'dismissed')),
  note text,
  handled_by uuid references public.profiles(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint operational_issue_actions_text_chk check (
    char_length(issue_key) between 3 and 240
    and char_length(issue_type) between 2 and 80
    and (note is null or char_length(note) <= 1000)
  )
);

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  audience text not null check (audience in ('dispatcher', 'client')),
  channel text not null check (channel in ('panel', 'push', 'sms', 'messenger')),
  event_type text not null,
  order_id uuid references public.orders(id) on delete cascade,
  title text not null,
  body text not null,
  recipient text,
  status text not null default 'ready' check (
    status in ('ready', 'waiting_provider', 'sent', 'failed', 'cancelled')
  ),
  dedupe_key text unique,
  provider_message_id text,
  last_error text,
  available_at timestamptz not null default now(),
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_outbox_text_chk check (
    char_length(event_type) between 2 and 80
    and char_length(title) between 1 and 200
    and char_length(body) between 1 and 1000
    and (recipient is null or char_length(recipient) <= 160)
    and (dedupe_key is null or char_length(dedupe_key) <= 300)
    and (last_error is null or char_length(last_error) <= 1000)
  )
);

create table public.staff_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  summary text not null,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint staff_audit_log_text_chk check (
    char_length(action) between 2 and 80
    and char_length(entity_type) between 2 and 80
    and (entity_id is null or char_length(entity_id) <= 240)
    and char_length(summary) between 2 and 500
  ),
  constraint staff_audit_log_json_chk check (
    (before_data is null or jsonb_typeof(before_data) = 'object')
    and (after_data is null or jsonb_typeof(after_data) = 'object')
    and jsonb_typeof(metadata) = 'object'
  )
);

create table public.data_import_changes (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null references public.data_imports(id) on delete cascade,
  entity_table text not null check (entity_table in ('clients', 'client_addresses', 'organizations', 'orders')),
  entity_id uuid not null,
  operation text not null check (operation in ('created', 'updated')),
  before_data jsonb,
  after_data jsonb not null,
  created_at timestamptz not null default now(),
  constraint data_import_changes_entity_key unique (import_id, entity_table, entity_id),
  constraint data_import_changes_json_chk check (
    (before_data is null or jsonb_typeof(before_data) = 'object')
    and jsonb_typeof(after_data) = 'object'
  )
);

alter table public.data_imports
  add column rolled_back_at timestamptz,
  add column rolled_back_by uuid references public.profiles(id) on delete set null,
  add column rollback_reason text;

alter table public.data_imports drop constraint if exists data_imports_status_check;
alter table public.data_imports add constraint data_imports_status_check check (
  status in ('processing', 'completed', 'completed_with_errors', 'failed', 'rolled_back')
);
alter table public.data_imports add constraint data_imports_rollback_reason_chk check (
  rollback_reason is null or char_length(rollback_reason) <= 1000
);

create index courier_shifts_work_date_idx on public.courier_shifts(work_date, status, courier_id);
create index courier_inventory_movements_date_idx on public.courier_inventory_movements(work_date desc, courier_id, created_at desc);
create index operational_issue_actions_status_idx on public.operational_issue_actions(status, updated_at desc);
create index notification_outbox_status_idx on public.notification_outbox(status, created_at desc);
create index staff_audit_log_created_idx on public.staff_audit_log(created_at desc, entity_type);
create index data_import_changes_import_idx on public.data_import_changes(import_id, created_at desc);
create index couriers_last_location_idx on public.couriers(last_location_at desc) where last_location_at is not null;

create trigger courier_shifts_touch_updated_at before update on public.courier_shifts
for each row execute function app_private.touch_updated_at();
create trigger operational_issue_actions_touch_updated_at before update on public.operational_issue_actions
for each row execute function app_private.touch_updated_at();
create trigger notification_outbox_touch_updated_at before update on public.notification_outbox
for each row execute function app_private.touch_updated_at();

alter table public.courier_shifts enable row level security;
alter table public.courier_inventory_movements enable row level security;
alter table public.operational_issue_actions enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.staff_audit_log enable row level security;
alter table public.data_import_changes enable row level security;

revoke all privileges on table public.courier_shifts from anon, authenticated;
revoke all privileges on table public.courier_inventory_movements from anon, authenticated;
revoke all privileges on table public.operational_issue_actions from anon, authenticated;
revoke all privileges on table public.notification_outbox from anon, authenticated;
revoke all privileges on table public.staff_audit_log from anon, authenticated;
revoke all privileges on table public.data_import_changes from anon, authenticated;

grant select, insert, update on public.courier_shifts to authenticated;
grant select on public.courier_inventory_movements to authenticated;
grant select, insert, update on public.operational_issue_actions to authenticated;
grant select, update on public.notification_outbox to authenticated;
grant select on public.staff_audit_log to authenticated;
grant select, insert, update on public.data_import_changes to authenticated;
grant update (last_lat, last_lng, last_location_accuracy_m, last_location_at) on public.couriers to authenticated;
grant delete on public.orders to authenticated;

grant all privileges on table public.courier_shifts to service_role;
grant all privileges on table public.courier_inventory_movements to service_role;
grant all privileges on table public.operational_issue_actions to service_role;
grant all privileges on table public.notification_outbox to service_role;
grant all privileges on table public.staff_audit_log to service_role;
grant all privileges on table public.data_import_changes to service_role;

create policy courier_shifts_staff_select on public.courier_shifts
for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy courier_shifts_staff_insert on public.courier_shifts
for insert to authenticated
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and updated_by = (select auth.uid())
);

create policy courier_shifts_staff_update on public.courier_shifts
for update to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and updated_by = (select auth.uid())
);

create policy courier_inventory_movements_staff_select on public.courier_inventory_movements
for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy operational_issue_actions_staff_select on public.operational_issue_actions
for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy operational_issue_actions_staff_insert on public.operational_issue_actions
for insert to authenticated
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and handled_by = (select auth.uid())
);

create policy operational_issue_actions_staff_update on public.operational_issue_actions
for update to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and handled_by = (select auth.uid())
);

create policy notification_outbox_staff_select on public.notification_outbox
for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy notification_outbox_staff_update on public.notification_outbox
for update to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy staff_audit_log_staff_select on public.staff_audit_log
for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy data_import_changes_admin_select on public.data_import_changes
for select to authenticated
using (
  (select app_private.current_user_role()) = 'admin'
  and exists (
    select 1 from public.data_imports import
    where import.id = data_import_changes.import_id
      and import.imported_by = (select auth.uid())
  )
);

create policy data_import_changes_admin_insert on public.data_import_changes
for insert to authenticated
with check (
  (select app_private.current_user_role()) = 'admin'
  and exists (
    select 1 from public.data_imports import
    where import.id = data_import_changes.import_id
      and import.imported_by = (select auth.uid())
      and import.status = 'processing'
  )
);

create policy data_import_changes_admin_update on public.data_import_changes
for update to authenticated
using (
  (select app_private.current_user_role()) = 'admin'
  and exists (
    select 1 from public.data_imports import
    where import.id = data_import_changes.import_id
      and import.imported_by = (select auth.uid())
      and import.status = 'processing'
  )
)
with check (
  (select app_private.current_user_role()) = 'admin'
  and exists (
    select 1 from public.data_imports import
    where import.id = data_import_changes.import_id
      and import.imported_by = (select auth.uid())
      and import.status = 'processing'
  )
);

create policy orders_admin_delete on public.orders
for delete to authenticated
using ((select app_private.current_user_role()) = 'admin');

create policy couriers_self_location_update on public.couriers
for update to authenticated
using (
  profile_id = (select auth.uid())
  and (select app_private.current_user_role()) = 'courier'
)
with check (
  profile_id = (select auth.uid())
  and (select app_private.current_user_role()) = 'courier'
);

create or replace function app_private.route_slot_end(p_time_slot text)
returns time
language sql
immutable
set search_path = ''
as $$
  select max((match)[1]::time)
  from regexp_matches(
    coalesce(p_time_slot, ''),
    '((?:[01][0-9]|2[0-3]):[0-5][0-9])',
    'g'
  ) as match;
$$;

create or replace function public.report_courier_location(
  p_lat numeric,
  p_lng numeric,
  p_accuracy_m numeric default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if app_private.current_user_role() <> 'courier' then
    raise exception 'courier_role_required' using errcode = '42501';
  end if;
  if p_lat is null or p_lat not between -90 and 90
    or p_lng is null or p_lng not between -180 and 180
    or (p_accuracy_m is not null and p_accuracy_m not between 0 and 100000) then
    raise exception 'invalid_location' using errcode = '22023';
  end if;

  update public.couriers
  set last_lat = p_lat,
      last_lng = p_lng,
      last_location_accuracy_m = p_accuracy_m,
      last_location_at = now()
  where profile_id = auth.uid()
    and is_active = true;

  if not found then
    raise exception 'active_courier_not_found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function app_private.guard_closed_shift_order()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.courier_shifts shift
    where shift.status = 'closed'
      and (
        (old.assigned_courier_id is not null and shift.courier_id = old.assigned_courier_id and shift.work_date = old.delivery_date)
        or (
          tg_op = 'UPDATE'
          and new.assigned_courier_id is not null
          and shift.courier_id = new.assigned_courier_id
          and shift.work_date = new.delivery_date
        )
      )
  ) then
    raise exception 'closed_shift_locked' using errcode = '55000';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function app_private.guard_closed_shift_inventory()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.courier_shifts shift
    where shift.courier_id = old.courier_id
      and shift.work_date = old.work_date
      and shift.status = 'closed'
  ) then
    raise exception 'closed_shift_locked' using errcode = '55000';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger orders_guard_closed_shift
before update or delete on public.orders
for each row execute function app_private.guard_closed_shift_order();

create trigger inventory_guard_closed_shift
before update or delete on public.courier_daily_inventory
for each row execute function app_private.guard_closed_shift_inventory();

create or replace function app_private.capture_inventory_dispatcher_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  full_delta integer;
  empty_delta integer;
  assigned_vehicle_id uuid;
begin
  if tg_op = 'INSERT' then
    full_delta := new.loaded_full_bottles - new.unloaded_full_bottles;
    empty_delta := new.opening_empty_bottles - new.unloaded_empty_bottles;
  else
    full_delta := (new.loaded_full_bottles - new.unloaded_full_bottles)
      - (old.loaded_full_bottles - old.unloaded_full_bottles);
    empty_delta := (new.opening_empty_bottles - new.unloaded_empty_bottles)
      - (old.opening_empty_bottles - old.unloaded_empty_bottles);
  end if;

  if full_delta = 0 and empty_delta = 0 then return new; end if;

  select assignment.vehicle_id into assigned_vehicle_id
  from public.vehicle_assignments assignment
  where assignment.courier_id = new.courier_id
    and assignment.assigned_at < ((new.work_date + 1)::timestamp at time zone 'Europe/Moscow')
    and (assignment.released_at is null or assignment.released_at >= (new.work_date::timestamp at time zone 'Europe/Moscow'))
  order by assignment.assigned_at desc
  limit 1;

  insert into public.courier_inventory_movements (
    courier_id, vehicle_id, work_date, event_type, full_bottles_delta,
    empty_bottles_delta, source_inventory_id, actor_profile_id, note, metadata
  ) values (
    new.courier_id, assigned_vehicle_id, new.work_date, 'dispatcher_inventory', full_delta,
    empty_delta, new.id, auth.uid(), new.notes,
    jsonb_build_object(
      'loaded_full', new.loaded_full_bottles,
      'opening_empty', new.opening_empty_bottles,
      'unloaded_full', new.unloaded_full_bottles,
      'unloaded_empty', new.unloaded_empty_bottles
    )
  );
  return new;
end;
$$;

create or replace function app_private.capture_order_inventory_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_full integer := 0;
  old_empty integer := 0;
  new_full integer := 0;
  new_empty integer := 0;
  full_delta integer;
  empty_delta integer;
  assigned_vehicle_id uuid;
begin
  if tg_op = 'INSERT' and new.source_system is not null then return new; end if;
  if tg_op <> 'INSERT' and old.state = 'delivered' then
    old_full := coalesce(old.delivered_bottles, old.bottles, 0);
    old_empty := coalesce(old.returned_bottles, 0);
  end if;
  if new.state = 'delivered' then
    new_full := coalesce(new.delivered_bottles, new.bottles, 0);
    new_empty := coalesce(new.returned_bottles, 0);
  end if;

  full_delta := old_full - new_full;
  empty_delta := new_empty - old_empty;
  if full_delta = 0 and empty_delta = 0 then return new; end if;
  if new.assigned_courier_id is null then return new; end if;

  select assignment.vehicle_id into assigned_vehicle_id
  from public.vehicle_assignments assignment
  where assignment.courier_id = new.assigned_courier_id
    and assignment.assigned_at < ((new.delivery_date + 1)::timestamp at time zone 'Europe/Moscow')
    and (assignment.released_at is null or assignment.released_at >= (new.delivery_date::timestamp at time zone 'Europe/Moscow'))
  order by assignment.assigned_at desc
  limit 1;

  insert into public.courier_inventory_movements (
    courier_id, vehicle_id, work_date, event_type, full_bottles_delta,
    empty_bottles_delta, source_order_id, actor_profile_id, note, metadata
  ) values (
    new.assigned_courier_id, assigned_vehicle_id, new.delivery_date,
    case when old_full = 0 and old_empty = 0 then 'delivery' else 'delivery_correction' end,
    full_delta, empty_delta, new.id, coalesce(new.updated_by, auth.uid()), new.delivery_comment,
    jsonb_build_object('order_number', new.order_number, 'delivered_full', new_full, 'returned_empty', new_empty)
  );
  return new;
end;
$$;

create trigger courier_inventory_capture_movement
after insert or update on public.courier_daily_inventory
for each row execute function app_private.capture_inventory_dispatcher_movement();

create trigger orders_capture_inventory_movement
after insert or update on public.orders
for each row execute function app_private.capture_order_inventory_movement();

create or replace function app_private.enqueue_order_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  client_title text;
  client_body text;
begin
  if tg_op = 'INSERT' and new.source_system is not null then return new; end if;
  if tg_op = 'UPDATE' and new.state = old.state then return new; end if;

  client_title := case new.state
    when 'assigned' then 'Заказ назначен водителю'
    when 'accepted' then 'Водитель принял заказ'
    when 'in_progress' then 'Заказ в пути'
    when 'delivered' then 'Заказ доставлен'
    when 'failed' then 'Не удалось доставить заказ'
    when 'cancelled' then 'Заказ отменён'
    else null
  end;
  if client_title is null then return new; end if;

  client_body := case new.state
    when 'assigned' then format('Заказ %s передан водителю.', new.order_number)
    when 'accepted' then format('Водитель подтвердил заказ %s.', new.order_number)
    when 'in_progress' then format('Водитель выехал по заказу %s.', new.order_number)
    when 'delivered' then format('Заказ %s доставлен. Спасибо!', new.order_number)
    when 'failed' then format('По заказу %s требуется уточнение доставки.', new.order_number)
    when 'cancelled' then format('Заказ %s отменён.', new.order_number)
  end;

  if new.client_phone is not null then
    insert into public.notification_outbox (
      audience, channel, event_type, order_id, title, body, recipient, status, dedupe_key
    ) values (
      'client', 'sms', 'order_' || new.state::text, new.id, client_title, client_body,
      new.client_phone, 'waiting_provider',
      new.id::text || ':' || new.state::text || ':' || new.version::text || ':client'
    ) on conflict (dedupe_key) do nothing;
  end if;

  if new.state in ('failed', 'cancelled') then
    insert into public.notification_outbox (
      audience, channel, event_type, order_id, title, body, status, dedupe_key
    ) values (
      'dispatcher', 'panel', 'order_' || new.state::text, new.id,
      case when new.state = 'failed' then 'Проблема доставки' else 'Заказ отменён' end,
      format('%s · %s · %s', new.order_number, new.client_name, new.address),
      'ready', new.id::text || ':' || new.state::text || ':' || new.version::text || ':dispatcher'
    ) on conflict (dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

create trigger orders_enqueue_notifications
after insert or update of state on public.orders
for each row execute function app_private.enqueue_order_notifications();

create or replace function app_private.capture_critical_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_json jsonb;
  new_json jsonb;
  record_id text;
begin
  if auth.uid() is null then return case when tg_op = 'DELETE' then old else new end; end if;
  old_json := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  new_json := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  old_json := old_json - array['legacy_data', 'marking_codes', 'scanned_items', 'client_phone', 'phone', 'email'];
  new_json := new_json - array['legacy_data', 'marking_codes', 'scanned_items', 'client_phone', 'phone', 'email'];
  record_id := coalesce(new_json ->> 'id', old_json ->> 'id');

  insert into public.staff_audit_log (
    actor_profile_id, action, entity_type, entity_id, summary, before_data, after_data
  ) values (
    auth.uid(), lower(tg_op), tg_table_name, record_id,
    format('%s: %s', tg_table_name, lower(tg_op)), old_json, new_json
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger orders_staff_audit after insert or update or delete on public.orders
for each row execute function app_private.capture_critical_audit();
create trigger inventory_staff_audit after insert or update or delete on public.courier_daily_inventory
for each row execute function app_private.capture_critical_audit();
create trigger delivery_zones_staff_audit after insert or update or delete on public.delivery_zones
for each row execute function app_private.capture_critical_audit();
create trigger vehicles_staff_audit after insert or update or delete on public.vehicles
for each row execute function app_private.capture_critical_audit();
create trigger vehicle_assignments_staff_audit after insert or update or delete on public.vehicle_assignments
for each row execute function app_private.capture_critical_audit();
create trigger data_imports_staff_audit after insert or update or delete on public.data_imports
for each row execute function app_private.capture_critical_audit();
create trigger courier_shifts_staff_audit after insert or update or delete on public.courier_shifts
for each row execute function app_private.capture_critical_audit();
create trigger operational_issues_staff_audit after insert or update or delete on public.operational_issue_actions
for each row execute function app_private.capture_critical_audit();

create or replace function public.set_operational_issue_status(
  p_issue_key text,
  p_issue_type text,
  p_status text,
  p_note text default null,
  p_order_id uuid default null,
  p_courier_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare saved_id uuid;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;
  if p_issue_key is null or char_length(trim(p_issue_key)) not between 3 and 240
    or p_issue_type is null or char_length(trim(p_issue_type)) not between 2 and 80
    or p_status not in ('open', 'acknowledged', 'resolved', 'dismissed') then
    raise exception 'invalid_issue_action' using errcode = '22023';
  end if;

  insert into public.operational_issue_actions (
    issue_key, issue_type, order_id, courier_id, status, note, handled_by, handled_at
  ) values (
    trim(p_issue_key), trim(p_issue_type), p_order_id, p_courier_id, p_status,
    nullif(trim(p_note), ''), auth.uid(), now()
  )
  on conflict (issue_key) do update
  set status = excluded.status,
      note = excluded.note,
      handled_by = auth.uid(),
      handled_at = now(),
      order_id = coalesce(excluded.order_id, operational_issue_actions.order_id),
      courier_id = coalesce(excluded.courier_id, operational_issue_actions.courier_id)
  returning id into saved_id;
  return saved_id;
end;
$$;

create or replace function public.get_dispatcher_operations(p_work_date date)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare result jsonb;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;
  if p_work_date is null or p_work_date < date '2020-01-01' then
    raise exception 'invalid_work_date' using errcode = '22007';
  end if;

  with order_rows as (
    select
      customer_order.id,
      customer_order.order_number,
      customer_order.state::text as state,
      customer_order.client_name,
      customer_order.address,
      customer_order.lat,
      customer_order.lng,
      customer_order.district,
      customer_order.time_slot,
      customer_order.bottles,
      customer_order.price,
      customer_order.payment_method::text as payment_method,
      customer_order.assigned_courier_id as courier_id,
      courier.display_name as courier_name,
      customer_order.delivery_zone_id,
      zone.name as zone_name,
      zone.color as zone_color,
      customer_order.failure_reason,
      app_private.route_slot_end(customer_order.time_slot) as slot_end,
      (
        customer_order.state in ('draft', 'assigned', 'accepted', 'in_progress')
        and (
          customer_order.delivery_date < (now() at time zone 'Europe/Moscow')::date
          or (
            customer_order.delivery_date = (now() at time zone 'Europe/Moscow')::date
            and app_private.route_slot_end(customer_order.time_slot) is not null
            and app_private.route_slot_end(customer_order.time_slot) < (now() at time zone 'Europe/Moscow')::time
          )
        )
      ) as is_overdue
    from public.orders customer_order
    left join public.couriers courier on courier.id = customer_order.assigned_courier_id
    left join public.delivery_zones zone on zone.id = customer_order.delivery_zone_id
    where customer_order.delivery_date = p_work_date
  ),
  courier_rows as (
    select
      courier.id,
      courier.display_name,
      courier.phone,
      courier.is_active,
      courier.last_lat,
      courier.last_lng,
      courier.last_location_accuracy_m,
      courier.last_location_at,
      vehicle.id as vehicle_id,
      vehicle.license_plate,
      count(order_row.id) filter (where order_row.state not in ('failed', 'cancelled')) as total_orders,
      count(order_row.id) filter (where order_row.state = 'delivered') as delivered_orders,
      count(order_row.id) filter (where order_row.state in ('assigned', 'accepted', 'in_progress')) as active_orders,
      count(order_row.id) filter (where order_row.state = 'failed') as failed_orders,
      coalesce(sum(order_row.bottles) filter (where order_row.state not in ('failed', 'cancelled')), 0) as planned_bottles,
      inventory.id is not null as inventory_configured,
      inventory.loaded_full_bottles,
      inventory.loaded_full_bottles
        - coalesce(sum(coalesce(customer_order.delivered_bottles, customer_order.bottles, 0)) filter (where customer_order.state = 'delivered'), 0)
        - inventory.unloaded_full_bottles as remaining_full_bottles,
      inventory.opening_empty_bottles
        + coalesce(sum(coalesce(customer_order.returned_bottles, 0)) filter (where customer_order.state = 'delivered'), 0)
        - inventory.unloaded_empty_bottles as remaining_empty_bottles,
      max(app_private.route_slot_end(order_row.time_slot)) filter (
        where order_row.state in ('assigned', 'accepted', 'in_progress')
      ) as estimated_finish
    from public.couriers courier
    left join order_rows order_row on order_row.courier_id = courier.id
    left join public.orders customer_order on customer_order.id = order_row.id
    left join public.courier_daily_inventory inventory
      on inventory.courier_id = courier.id and inventory.work_date = p_work_date
    left join lateral (
      select selected_vehicle.id, selected_vehicle.license_plate
      from public.vehicle_assignments assignment
      join public.vehicles selected_vehicle on selected_vehicle.id = assignment.vehicle_id
      where assignment.courier_id = courier.id
        and assignment.assigned_at < ((p_work_date + 1)::timestamp at time zone 'Europe/Moscow')
        and (assignment.released_at is null or assignment.released_at >= (p_work_date::timestamp at time zone 'Europe/Moscow'))
      order by assignment.assigned_at desc
      limit 1
    ) vehicle on true
    where courier.is_active = true or order_row.id is not null
    group by courier.id, vehicle.id, vehicle.license_plate, inventory.id
  ),
  issue_base as (
    select
      'order:' || order_row.id || ':unassigned' as issue_key,
      'unassigned_order' as issue_type,
      'high' as severity,
      order_row.id as order_id,
      null::uuid as courier_id,
      'Заказ не назначен' as title,
      order_row.order_number || ' · ' || order_row.client_name || ' · ' || order_row.address as detail,
      order_row.lat,
      order_row.lng
    from order_rows order_row
    where order_row.courier_id is null and order_row.state in ('draft', 'assigned')

    union all
    select 'order:' || id || ':failed', 'failed_delivery', 'critical', id, courier_id,
      'Доставка не выполнена', order_number || ' · ' || coalesce(failure_reason, address), lat, lng
    from order_rows where state = 'failed'

    union all
    select 'order:' || id || ':overdue', 'overdue_order', 'critical', id, courier_id,
      'Заказ опаздывает', order_number || ' · интервал ' || coalesce(time_slot, 'не указан') || ' · ' || address, lat, lng
    from order_rows where is_overdue

    union all
    select 'order:' || id || ':no-coordinates', 'missing_coordinates', 'medium', id, courier_id,
      'Нет координат адреса', order_number || ' · ' || address, lat, lng
    from order_rows where lat is null or lng is null

    union all
    select 'courier:' || id || ':loading', 'inventory_missing', 'medium', null, id,
      'Не заполнена загрузка', display_name || ' · ' || coalesce(license_plate, 'машина не назначена'), last_lat, last_lng
    from courier_rows where total_orders > 0 and not inventory_configured

    union all
    select 'courier:' || id || ':shortage', 'inventory_shortage', 'critical', null, id,
      'Отрицательный остаток', display_name || ' · полных: ' || remaining_full_bottles || ' · тары: ' || remaining_empty_bottles, last_lat, last_lng
    from courier_rows where inventory_configured and (remaining_full_bottles < 0 or remaining_empty_bottles < 0)

    union all
    select 'courier:' || id || ':capacity', 'capacity_overload', 'high', null, id,
      'Не хватает загрузки', display_name || ' · запланировано ' || planned_bottles || ' · загружено ' || loaded_full_bottles, last_lat, last_lng
    from courier_rows where inventory_configured and planned_bottles > loaded_full_bottles

    union all
    select 'courier:' || id || ':location', 'stale_location', 'medium', null, id,
      'Нет свежей геопозиции', display_name || ' · активных заказов: ' || active_orders, last_lat, last_lng
    from courier_rows
    where active_orders > 0 and (last_location_at is null or last_location_at < now() - interval '30 minutes')
  ),
  issues as (
    select issue_base.*,
      coalesce(action.status, 'open') as status,
      action.note,
      action.handled_at,
      handler.full_name as handled_by_name
    from issue_base
    left join public.operational_issue_actions action on action.issue_key = issue_base.issue_key
    left join public.profiles handler on handler.id = action.handled_by
  )
  select jsonb_build_object(
    'work_date', p_work_date,
    'summary', jsonb_build_object(
      'total_orders', (select count(*) from order_rows),
      'delivered_orders', (select count(*) from order_rows where state = 'delivered'),
      'active_orders', (select count(*) from order_rows where state in ('assigned', 'accepted', 'in_progress')),
      'unassigned_orders', (select count(*) from order_rows where courier_id is null and state in ('draft', 'assigned')),
      'failed_orders', (select count(*) from order_rows where state = 'failed'),
      'overdue_orders', (select count(*) from order_rows where is_overdue),
      'open_issues', (select count(*) from issues where status not in ('resolved', 'dismissed')),
      'planned_bottles', (select coalesce(sum(bottles), 0) from order_rows where state not in ('failed', 'cancelled')),
      'revenue', (select coalesce(sum(price), 0) from order_rows where state = 'delivered')
    ),
    'orders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id, 'order_number', order_number, 'state', state, 'client_name', client_name,
        'address', address, 'lat', lat, 'lng', lng, 'district', district, 'time_slot', time_slot,
        'bottles', bottles, 'price', price, 'payment_method', payment_method,
        'courier_id', courier_id, 'courier_name', courier_name,
        'zone_id', delivery_zone_id, 'zone_name', zone_name, 'zone_color', zone_color,
        'is_overdue', is_overdue
      ) order by coalesce(slot_end, time '23:59'), order_number)
      from order_rows
    ), '[]'::jsonb),
    'couriers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id, 'name', display_name, 'phone', phone, 'is_active', is_active,
        'lat', last_lat, 'lng', last_lng, 'location_accuracy_m', last_location_accuracy_m,
        'location_at', last_location_at, 'vehicle_id', vehicle_id, 'vehicle_plate', license_plate,
        'total_orders', total_orders, 'delivered_orders', delivered_orders,
        'active_orders', active_orders, 'failed_orders', failed_orders,
        'planned_bottles', planned_bottles, 'inventory_configured', inventory_configured,
        'loaded_full_bottles', loaded_full_bottles,
        'remaining_full_bottles', remaining_full_bottles,
        'remaining_empty_bottles', remaining_empty_bottles,
        'estimated_finish', case when estimated_finish is null then null else to_char(estimated_finish, 'HH24:MI') end
      ) order by is_active desc, display_name)
      from courier_rows
    ), '[]'::jsonb),
    'issues', coalesce((
      select jsonb_agg(to_jsonb(issues) order by
        case severity when 'critical' then 1 when 'high' then 2 else 3 end,
        title
      ) from issues
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

create or replace function public.list_shift_reconciliation(p_work_date date)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare result jsonb;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'courier_id', sales.courier_id,
    'courier_name', sales.courier_name,
    'courier_active', sales.courier_active,
    'vehicle_plate', sales.vehicle_plate,
    'delivered_orders', sales.delivered_orders,
    'active_orders', sales.active_orders,
    'failed_orders', sales.failed_orders,
    'expected_cash', sales.cash_amount,
    'expected_card', sales.card_amount,
    'expected_qr', sales.qr_amount,
    'expected_online', sales.online_amount,
    'expected_contract', sales.contract_amount,
    'expected_total', sales.total_amount,
    'actual_cash', shift.actual_cash,
    'actual_card', shift.actual_card,
    'actual_qr', shift.actual_qr,
    'actual_online', shift.actual_online,
    'actual_contract', shift.actual_contract,
    'cash_difference', case when shift.actual_cash is null then null else shift.actual_cash - sales.cash_amount end,
    'non_cash_difference', case when shift.actual_card is null then null else
      shift.actual_card + shift.actual_qr + shift.actual_online + shift.actual_contract
      - sales.card_amount - sales.qr_amount - sales.online_amount - sales.contract_amount end,
    'sold_full_bottles', sales.sold_full_bottles,
    'collected_empty_bottles', sales.collected_empty_bottles,
    'inventory_configured', sales.inventory_configured,
    'expected_full_bottles', sales.remaining_full_bottles,
    'expected_empty_bottles', sales.remaining_empty_bottles,
    'actual_full_bottles', shift.actual_full_bottles,
    'actual_empty_bottles', shift.actual_empty_bottles,
    'full_difference', case when shift.actual_full_bottles is null then null else shift.actual_full_bottles - sales.remaining_full_bottles end,
    'empty_difference', case when shift.actual_empty_bottles is null then null else shift.actual_empty_bottles - sales.remaining_empty_bottles end,
    'start_mileage', shift.start_mileage,
    'end_mileage', shift.end_mileage,
    'distance_km', case when shift.start_mileage is null or shift.end_mileage is null then null else shift.end_mileage - shift.start_mileage end,
    'status', coalesce(shift.status, 'open'),
    'was_reopened', shift.reopened_at is not null,
    'discrepancy_reason', shift.discrepancy_reason,
    'notes', shift.notes,
    'closed_at', shift.closed_at,
    'closed_by_name', closer.full_name,
    'reopened_at', shift.reopened_at,
    'reopen_reason', shift.reopen_reason,
    'readiness', case
      when shift.status = 'closed' then 'closed'
      when sales.active_orders > 0 then 'active_orders'
      when not sales.inventory_configured then 'inventory_missing'
      else 'ready'
    end
  ) order by sales.courier_active desc, sales.courier_name), '[]'::jsonb)
  into result
  from public.list_courier_daily_sales(p_work_date) sales
  left join public.courier_shifts shift
    on shift.courier_id = sales.courier_id and shift.work_date = p_work_date
  left join public.profiles closer on closer.id = shift.closed_by;
  return result;
end;
$$;

create or replace function public.close_courier_shift(
  p_courier_id uuid,
  p_work_date date,
  p_actual_cash numeric,
  p_actual_card numeric,
  p_actual_qr numeric,
  p_actual_online numeric,
  p_actual_contract numeric,
  p_actual_full_bottles integer,
  p_actual_empty_bottles integer,
  p_start_mileage numeric default null,
  p_end_mileage numeric default null,
  p_discrepancy_reason text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  sales record;
  assigned_vehicle_id uuid;
  saved_id uuid;
  has_discrepancy boolean;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;
  select * into sales
  from public.list_courier_daily_sales(p_work_date)
  where courier_id = p_courier_id;
  if not found then raise exception 'courier_not_found' using errcode = 'P0002'; end if;
  if sales.active_orders > 0 then raise exception 'active_orders_remain' using errcode = '55000'; end if;
  if not sales.inventory_configured then raise exception 'inventory_not_configured' using errcode = '55000'; end if;
  if p_actual_cash is null or p_actual_cash < 0
    or p_actual_card is null or p_actual_card < 0
    or p_actual_qr is null or p_actual_qr < 0
    or p_actual_online is null or p_actual_online < 0
    or p_actual_contract is null or p_actual_contract < 0
    or p_actual_full_bottles is null or p_actual_full_bottles < 0
    or p_actual_empty_bottles is null or p_actual_empty_bottles < 0
    or (p_start_mileage is not null and p_start_mileage < 0)
    or (p_end_mileage is not null and p_end_mileage < 0)
    or (p_start_mileage is not null and p_end_mileage is not null and p_end_mileage < p_start_mileage) then
    raise exception 'invalid_shift_values' using errcode = '22023';
  end if;

  has_discrepancy := p_actual_cash <> sales.cash_amount
    or p_actual_card <> sales.card_amount
    or p_actual_qr <> sales.qr_amount
    or p_actual_online <> sales.online_amount
    or p_actual_contract <> sales.contract_amount
    or p_actual_full_bottles <> sales.remaining_full_bottles
    or p_actual_empty_bottles <> sales.remaining_empty_bottles;
  if has_discrepancy and char_length(coalesce(nullif(trim(p_discrepancy_reason), ''), '')) < 5 then
    raise exception 'discrepancy_reason_required' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.courier_shifts
    where courier_id = p_courier_id and work_date = p_work_date and status = 'closed'
  ) then
    raise exception 'shift_already_closed' using errcode = '55000';
  end if;

  select assignment.vehicle_id into assigned_vehicle_id
  from public.vehicle_assignments assignment
  where assignment.courier_id = p_courier_id
    and assignment.assigned_at < ((p_work_date + 1)::timestamp at time zone 'Europe/Moscow')
    and (assignment.released_at is null or assignment.released_at >= (p_work_date::timestamp at time zone 'Europe/Moscow'))
  order by assignment.assigned_at desc limit 1;

  insert into public.courier_shifts (
    courier_id, vehicle_id, work_date, status,
    expected_cash, expected_card, expected_qr, expected_online, expected_contract,
    actual_cash, actual_card, actual_qr, actual_online, actual_contract,
    expected_full_bottles, expected_empty_bottles, actual_full_bottles, actual_empty_bottles,
    start_mileage, end_mileage, discrepancy_reason, notes,
    closed_by, closed_at, updated_by
  ) values (
    p_courier_id, assigned_vehicle_id, p_work_date, 'closed',
    sales.cash_amount, sales.card_amount, sales.qr_amount, sales.online_amount, sales.contract_amount,
    p_actual_cash, p_actual_card, p_actual_qr, p_actual_online, p_actual_contract,
    sales.remaining_full_bottles, sales.remaining_empty_bottles, p_actual_full_bottles, p_actual_empty_bottles,
    p_start_mileage, p_end_mileage, nullif(trim(p_discrepancy_reason), ''), nullif(trim(p_notes), ''),
    auth.uid(), now(), auth.uid()
  )
  on conflict (courier_id, work_date) do update
  set vehicle_id = excluded.vehicle_id,
      status = 'closed',
      expected_cash = excluded.expected_cash,
      expected_card = excluded.expected_card,
      expected_qr = excluded.expected_qr,
      expected_online = excluded.expected_online,
      expected_contract = excluded.expected_contract,
      actual_cash = excluded.actual_cash,
      actual_card = excluded.actual_card,
      actual_qr = excluded.actual_qr,
      actual_online = excluded.actual_online,
      actual_contract = excluded.actual_contract,
      expected_full_bottles = excluded.expected_full_bottles,
      expected_empty_bottles = excluded.expected_empty_bottles,
      actual_full_bottles = excluded.actual_full_bottles,
      actual_empty_bottles = excluded.actual_empty_bottles,
      start_mileage = excluded.start_mileage,
      end_mileage = excluded.end_mileage,
      discrepancy_reason = excluded.discrepancy_reason,
      notes = excluded.notes,
      closed_by = auth.uid(),
      closed_at = now(),
      updated_by = auth.uid()
  returning id into saved_id;

  return saved_id;
end;
$$;

create or replace function public.reopen_courier_shift(
  p_courier_id uuid,
  p_work_date date,
  p_reason text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare saved_id uuid;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required' using errcode = '42501';
  end if;
  if char_length(coalesce(nullif(trim(p_reason), ''), '')) < 5 then
    raise exception 'reopen_reason_required' using errcode = '22023';
  end if;
  update public.courier_shifts
  set status = 'open',
      reopened_by = auth.uid(),
      reopened_at = now(),
      reopen_reason = trim(p_reason),
      updated_by = auth.uid()
  where courier_id = p_courier_id
    and work_date = p_work_date
    and status = 'closed'
  returning id into saved_id;
  if saved_id is null then raise exception 'closed_shift_not_found' using errcode = 'P0002'; end if;
  return saved_id;
end;
$$;

create or replace function public.list_inventory_movements(
  p_date_from date,
  p_date_to date,
  p_courier_id uuid default null,
  p_limit integer default 500
)
returns table (
  id uuid,
  work_date date,
  created_at timestamptz,
  courier_id uuid,
  courier_name text,
  vehicle_plate text,
  event_type text,
  full_bottles_delta integer,
  empty_bottles_delta integer,
  order_number text,
  actor_name text,
  note text,
  metadata jsonb
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;
  return query
  select movement.id, movement.work_date, movement.created_at, movement.courier_id,
    courier.display_name, vehicle.license_plate, movement.event_type,
    movement.full_bottles_delta, movement.empty_bottles_delta,
    customer_order.order_number, actor.full_name, movement.note, movement.metadata
  from public.courier_inventory_movements movement
  join public.couriers courier on courier.id = movement.courier_id
  left join public.vehicles vehicle on vehicle.id = movement.vehicle_id
  left join public.orders customer_order on customer_order.id = movement.source_order_id
  left join public.profiles actor on actor.id = movement.actor_profile_id
  where movement.work_date between p_date_from and p_date_to
    and (p_courier_id is null or movement.courier_id = p_courier_id)
  order by movement.created_at desc
  limit least(greatest(coalesce(p_limit, 500), 1), 2000);
end;
$$;

create or replace function public.list_staff_audit(
  p_limit integer default 300,
  p_entity_type text default null
)
returns table (
  id uuid,
  created_at timestamptz,
  actor_name text,
  actor_role text,
  action text,
  entity_type text,
  entity_id text,
  summary text,
  before_data jsonb,
  after_data jsonb
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;
  return query
  select audit.id, audit.created_at, coalesce(profile.full_name, 'Система'), profile.role::text,
    audit.action, audit.entity_type, audit.entity_id, audit.summary, audit.before_data, audit.after_data
  from public.staff_audit_log audit
  left join public.profiles profile on profile.id = audit.actor_profile_id
  where p_entity_type is null or audit.entity_type = p_entity_type
  order by audit.created_at desc
  limit least(greatest(coalesce(p_limit, 300), 1), 2000);
end;
$$;

create or replace function public.get_dispatcher_analytics(
  p_date_from date,
  p_date_to date
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  result jsonb;
  period_days integer;
  previous_from date;
  previous_to date;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required' using errcode = '42501';
  end if;
  period_days := p_date_to - p_date_from + 1;
  if p_date_from is null or p_date_to is null or period_days < 1 or period_days > 366 then
    raise exception 'invalid_analytics_period' using errcode = '22007';
  end if;
  previous_to := p_date_from - 1;
  previous_from := previous_to - period_days + 1;

  with current_orders as (
    select * from public.orders where delivery_date between p_date_from and p_date_to
  ),
  previous_orders as (
    select * from public.orders where delivery_date between previous_from and previous_to
  ),
  days as (
    select generate_series(p_date_from, p_date_to, interval '1 day')::date as day
  ),
  trend as (
    select day.day,
      count(customer_order.id) as orders,
      count(customer_order.id) filter (where customer_order.state = 'delivered') as delivered,
      count(customer_order.id) filter (where customer_order.state = 'failed') as failed,
      coalesce(sum(customer_order.price) filter (where customer_order.state = 'delivered'), 0) as revenue,
      coalesce(sum(coalesce(customer_order.delivered_bottles, customer_order.bottles, 0)) filter (where customer_order.state = 'delivered'), 0) as full_bottles,
      coalesce(sum(coalesce(customer_order.returned_bottles, 0)) filter (where customer_order.state = 'delivered'), 0) as empty_bottles
    from days day
    left join current_orders customer_order on customer_order.delivery_date = day.day
    group by day.day order by day.day
  ),
  payments as (
    select coalesce(confirmed_payment, payment_method)::text as method,
      count(*) as orders,
      coalesce(sum(price), 0) as amount
    from current_orders where state = 'delivered'
    group by coalesce(confirmed_payment, payment_method)
  ),
  courier_stats as (
    select courier.id, courier.display_name,
      count(customer_order.id) as total_orders,
      count(customer_order.id) filter (where customer_order.state = 'delivered') as delivered_orders,
      count(customer_order.id) filter (where customer_order.state = 'failed') as failed_orders,
      coalesce(sum(customer_order.price) filter (where customer_order.state = 'delivered'), 0) as revenue,
      coalesce(sum(coalesce(customer_order.delivered_bottles, customer_order.bottles, 0)) filter (where customer_order.state = 'delivered'), 0) as full_bottles,
      coalesce(avg(rating.rating), 0) as average_rating,
      count(distinct rating.id) as rating_count
    from public.couriers courier
    join current_orders customer_order on customer_order.assigned_courier_id = courier.id
    left join public.client_ratings rating on rating.order_id = customer_order.id
    group by courier.id, courier.display_name
  ),
  zone_stats as (
    select coalesce(zone.id::text, 'none') as id,
      coalesce(zone.name, 'Без зоны') as name,
      coalesce(zone.color, '#94a3b8') as color,
      count(customer_order.id) as total_orders,
      count(customer_order.id) filter (where customer_order.state = 'delivered') as delivered_orders,
      count(customer_order.id) filter (where customer_order.state = 'failed') as failed_orders,
      coalesce(sum(customer_order.price) filter (where customer_order.state = 'delivered'), 0) as revenue
    from current_orders customer_order
    left join public.delivery_zones zone on zone.id = customer_order.delivery_zone_id
    group by zone.id, zone.name, zone.color
  )
  select jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'previous_date_from', previous_from,
    'previous_date_to', previous_to,
    'summary', jsonb_build_object(
      'total_orders', (select count(*) from current_orders),
      'delivered_orders', (select count(*) from current_orders where state = 'delivered'),
      'failed_orders', (select count(*) from current_orders where state = 'failed'),
      'cancelled_orders', (select count(*) from current_orders where state = 'cancelled'),
      'revenue', (select coalesce(sum(price), 0) from current_orders where state = 'delivered'),
      'average_order', (select coalesce(avg(price), 0) from current_orders where state = 'delivered'),
      'full_bottles', (select coalesce(sum(coalesce(delivered_bottles, bottles, 0)), 0) from current_orders where state = 'delivered'),
      'empty_bottles', (select coalesce(sum(coalesce(returned_bottles, 0)), 0) from current_orders where state = 'delivered'),
      'unique_clients', (select count(distinct coalesce(client_id::text, client_phone_normalized, lower(client_name))) from current_orders),
      'average_rating', (select coalesce(avg(rating.rating), 0) from public.client_ratings rating join current_orders customer_order on customer_order.id = rating.order_id),
      'rating_count', (select count(*) from public.client_ratings rating join current_orders customer_order on customer_order.id = rating.order_id),
      'closed_shifts', (select count(*) from public.courier_shifts where work_date between p_date_from and p_date_to and status = 'closed'),
      'shifts_with_discrepancy', (select count(*) from public.courier_shifts where work_date between p_date_from and p_date_to and status = 'closed' and nullif(trim(discrepancy_reason), '') is not null)
    ),
    'previous', jsonb_build_object(
      'total_orders', (select count(*) from previous_orders),
      'delivered_orders', (select count(*) from previous_orders where state = 'delivered'),
      'failed_orders', (select count(*) from previous_orders where state = 'failed'),
      'revenue', (select coalesce(sum(price), 0) from previous_orders where state = 'delivered'),
      'full_bottles', (select coalesce(sum(coalesce(delivered_bottles, bottles, 0)), 0) from previous_orders where state = 'delivered')
    ),
    'trend', coalesce((select jsonb_agg(to_jsonb(trend) order by day) from trend), '[]'::jsonb),
    'payments', coalesce((select jsonb_agg(to_jsonb(payments) order by amount desc) from payments), '[]'::jsonb),
    'couriers', coalesce((select jsonb_agg(to_jsonb(courier_stats) order by revenue desc, display_name) from courier_stats), '[]'::jsonb),
    'zones', coalesce((select jsonb_agg(to_jsonb(zone_stats) order by total_orders desc, name) from zone_stats), '[]'::jsonb),
    'quality', jsonb_build_object(
      'missing_coordinates', (select count(*) from current_orders where lat is null or lng is null),
      'missing_phone', (select count(*) from current_orders where client_phone is null or trim(client_phone) = ''),
      'without_zone', (select count(*) from current_orders where delivery_zone_id is null),
      'without_courier', (select count(*) from current_orders where assigned_courier_id is null and state in ('draft', 'assigned')),
      'unconfirmed_payment', (select count(*) from current_orders where state = 'delivered' and confirmed_payment is null)
    )
  ) into result;
  return result;
end;
$$;

create or replace function public.record_data_import_change(
  p_import_id uuid,
  p_entity_table text,
  p_entity_id uuid,
  p_operation text,
  p_before_data jsonb,
  p_after_data jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare saved_id uuid;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required' using errcode = '42501';
  end if;
  if p_entity_table not in ('clients', 'client_addresses', 'organizations', 'orders')
    or p_operation not in ('created', 'updated')
    or p_entity_id is null or p_after_data is null or jsonb_typeof(p_after_data) <> 'object'
    or (p_before_data is not null and jsonb_typeof(p_before_data) <> 'object') then
    raise exception 'invalid_import_change' using errcode = '22023';
  end if;

  insert into public.data_import_changes (
    import_id, entity_table, entity_id, operation, before_data, after_data
  ) values (
    p_import_id, p_entity_table, p_entity_id, p_operation, p_before_data, p_after_data
  )
  on conflict (import_id, entity_table, entity_id) do update
  set after_data = excluded.after_data
  returning id into saved_id;
  return saved_id;
end;
$$;

create or replace function public.rollback_data_import(p_import_id uuid, p_reason text)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  import_record record;
  change_record record;
  changed_count integer := 0;
  current_updated_at timestamptz;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required' using errcode = '42501';
  end if;
  if char_length(coalesce(nullif(trim(p_reason), ''), '')) < 5 then
    raise exception 'rollback_reason_required' using errcode = '22023';
  end if;

  select * into import_record
  from public.data_imports
  where id = p_import_id and imported_by = auth.uid()
  for update;
  if not found then raise exception 'import_not_found' using errcode = 'P0002'; end if;
  if import_record.status not in ('completed', 'completed_with_errors', 'failed') then
    raise exception 'import_not_rollbackable' using errcode = '55000';
  end if;
  if not exists (select 1 from public.data_import_changes where import_id = p_import_id) then
    raise exception 'import_change_log_missing' using errcode = '55000';
  end if;

  -- Refuse the whole rollback if any imported record was edited after completion.
  for change_record in
    select * from public.data_import_changes where import_id = p_import_id
  loop
    current_updated_at := null;
    if change_record.entity_table = 'orders' then
      select updated_at into current_updated_at from public.orders where id = change_record.entity_id;
      if exists (
        select 1 from public.order_events
        where order_id = change_record.entity_id
          and created_at > import_record.completed_at
          and event_type <> 'legacy_imported'
      ) then
        raise exception 'import_record_changed:orders:%', change_record.entity_id using errcode = '55000';
      end if;
    elsif change_record.entity_table = 'clients' then
      select updated_at into current_updated_at from public.clients where id = change_record.entity_id;
    elsif change_record.entity_table = 'client_addresses' then
      select updated_at into current_updated_at from public.client_addresses where id = change_record.entity_id;
    elsif change_record.entity_table = 'organizations' then
      select updated_at into current_updated_at from public.organizations where id = change_record.entity_id;
    end if;
    if current_updated_at is not null and current_updated_at > coalesce(import_record.completed_at, import_record.updated_at) then
      raise exception 'import_record_changed:%:%', change_record.entity_table, change_record.entity_id using errcode = '55000';
    end if;
  end loop;

  for change_record in
    select * from public.data_import_changes
    where import_id = p_import_id
    order by created_at desc, id desc
  loop
    if change_record.entity_table = 'orders' and change_record.operation = 'created' then
      delete from public.orders where id = change_record.entity_id;
    elsif change_record.entity_table = 'clients' and change_record.operation = 'created' then
      delete from public.clients where id = change_record.entity_id;
    elsif change_record.entity_table = 'client_addresses' and change_record.operation = 'created' then
      delete from public.client_addresses where id = change_record.entity_id;
    elsif change_record.entity_table = 'organizations' and change_record.operation = 'created' then
      delete from public.organizations where id = change_record.entity_id;
    elsif change_record.entity_table = 'clients' and change_record.operation = 'updated' then
      update public.clients set
        legacy_id = change_record.before_data ->> 'legacy_id',
        full_name = change_record.before_data ->> 'full_name',
        phone = change_record.before_data ->> 'phone',
        email = change_record.before_data ->> 'email',
        status = change_record.before_data ->> 'status',
        loyalty_points = coalesce((change_record.before_data ->> 'loyalty_points')::numeric, 0),
        tare_debt = coalesce((change_record.before_data ->> 'tare_debt')::integer, 0),
        notes = change_record.before_data ->> 'notes',
        source_system = change_record.before_data ->> 'source_system',
        legacy_data = coalesce(change_record.before_data -> 'legacy_data', '{}'::jsonb)
      where id = change_record.entity_id;
    elsif change_record.entity_table = 'client_addresses' and change_record.operation = 'updated' then
      update public.client_addresses set
        legacy_id = change_record.before_data ->> 'legacy_id',
        address_text = change_record.before_data ->> 'address_text',
        zone_name = change_record.before_data ->> 'zone_name',
        district = change_record.before_data ->> 'district',
        locality = change_record.before_data ->> 'locality',
        street = change_record.before_data ->> 'street',
        house = change_record.before_data ->> 'house',
        building = change_record.before_data ->> 'building',
        structure = change_record.before_data ->> 'structure',
        entrance = change_record.before_data ->> 'entrance',
        floor = change_record.before_data ->> 'floor',
        apartment = change_record.before_data ->> 'apartment',
        lat = (change_record.before_data ->> 'lat')::numeric,
        lng = (change_record.before_data ->> 'lng')::numeric,
        source_system = change_record.before_data ->> 'source_system',
        legacy_data = coalesce(change_record.before_data -> 'legacy_data', '{}'::jsonb)
      where id = change_record.entity_id;
    elsif change_record.entity_table = 'organizations' and change_record.operation = 'updated' then
      update public.organizations set
        legacy_id = change_record.before_data ->> 'legacy_id',
        name = change_record.before_data ->> 'name',
        inn = change_record.before_data ->> 'inn',
        kpp = change_record.before_data ->> 'kpp',
        phone = change_record.before_data ->> 'phone',
        email = change_record.before_data ->> 'email',
        address_text = change_record.before_data ->> 'address_text',
        tare_debt = coalesce((change_record.before_data ->> 'tare_debt')::integer, 0),
        source_system = change_record.before_data ->> 'source_system',
        legacy_data = coalesce(change_record.before_data -> 'legacy_data', '{}'::jsonb)
      where id = change_record.entity_id;
    end if;
    changed_count := changed_count + 1;
  end loop;

  update public.data_imports
  set status = 'rolled_back',
      rolled_back_at = now(),
      rolled_back_by = auth.uid(),
      rollback_reason = trim(p_reason)
  where id = p_import_id;
  return changed_count;
end;
$$;

revoke all on function public.report_courier_location(numeric, numeric, numeric) from public, anon, authenticated;
revoke all on function public.set_operational_issue_status(text, text, text, text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.get_dispatcher_operations(date) from public, anon, authenticated;
revoke all on function public.list_shift_reconciliation(date) from public, anon, authenticated;
revoke all on function public.close_courier_shift(uuid, date, numeric, numeric, numeric, numeric, numeric, integer, integer, numeric, numeric, text, text) from public, anon, authenticated;
revoke all on function public.reopen_courier_shift(uuid, date, text) from public, anon, authenticated;
revoke all on function public.list_inventory_movements(date, date, uuid, integer) from public, anon, authenticated;
revoke all on function public.list_staff_audit(integer, text) from public, anon, authenticated;
revoke all on function public.get_dispatcher_analytics(date, date) from public, anon, authenticated;
revoke all on function public.record_data_import_change(uuid, text, uuid, text, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.rollback_data_import(uuid, text) from public, anon, authenticated;

grant execute on function public.report_courier_location(numeric, numeric, numeric) to authenticated, service_role;
grant execute on function public.set_operational_issue_status(text, text, text, text, uuid, uuid) to authenticated, service_role;
grant execute on function public.get_dispatcher_operations(date) to authenticated, service_role;
grant execute on function public.list_shift_reconciliation(date) to authenticated, service_role;
grant execute on function public.close_courier_shift(uuid, date, numeric, numeric, numeric, numeric, numeric, integer, integer, numeric, numeric, text, text) to authenticated, service_role;
grant execute on function public.reopen_courier_shift(uuid, date, text) to authenticated, service_role;
grant execute on function public.list_inventory_movements(date, date, uuid, integer) to authenticated, service_role;
grant execute on function public.list_staff_audit(integer, text) to authenticated, service_role;
grant execute on function public.get_dispatcher_analytics(date, date) to authenticated, service_role;
grant execute on function public.record_data_import_change(uuid, text, uuid, text, jsonb, jsonb) to authenticated, service_role;
grant execute on function public.rollback_data_import(uuid, text) to authenticated, service_role;

revoke all on function app_private.capture_inventory_dispatcher_movement() from public, anon, authenticated;
revoke all on function app_private.capture_order_inventory_movement() from public, anon, authenticated;
revoke all on function app_private.enqueue_order_notifications() from public, anon, authenticated;
revoke all on function app_private.capture_critical_audit() from public, anon, authenticated;

comment on table public.courier_shifts is 'Daily driver reconciliation and immutable shift close state.';
comment on table public.courier_inventory_movements is 'Signed bottle movement ledger: positive values enter a vehicle, negative values leave it.';
comment on table public.notification_outbox is 'Panel and client notification queue. waiting_provider means an external delivery provider is not connected yet.';
comment on table public.staff_audit_log is 'Sanitized critical-change audit trail for dispatcher and administrator review.';
comment on function public.get_dispatcher_analytics(date, date) is 'Consistent dispatcher KPIs, trends and breakdowns for a period of up to 366 days.';

select pg_notify('pgrst', 'reload schema');
