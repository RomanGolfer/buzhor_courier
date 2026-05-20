create schema if not exists app_private;

revoke all on schema app_private from public;
revoke all on schema app_private from anon;
revoke all on schema app_private from authenticated;

do $$
begin
  create type public.app_role as enum ('courier', 'dispatcher', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.order_state as enum (
    'draft',
    'assigned',
    'accepted',
    'in_progress',
    'delivered',
    'failed',
    'cancelled'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_method as enum ('card', 'cash', 'qr', 'online', 'contract');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_status as enum (
    'pending',
    'created',
    'paid',
    'failed',
    'cancelled',
    'expired'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.sync_operation_type as enum (
    'acknowledge_receipt',
    'complete',
    'fail',
    'payment_check',
    'upsert_from_dispatcher'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.sync_operation_status as enum (
    'pending',
    'in_flight',
    'acked',
    'rejected',
    'needs_review'
  );
exception
  when duplicate_object then null;
end $$;

create or replace function app_private.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'courier',
  full_name text,
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.couriers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  display_name text not null,
  phone text,
  region text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  assigned_courier_id uuid references public.couriers(id) on delete set null,
  state public.order_state not null default 'draft',
  client_name text not null,
  client_phone text,
  address text not null,
  district text,
  lat numeric(10, 7),
  lng numeric(10, 7),
  payment_method public.payment_method not null default 'cash',
  price numeric(12, 2) not null default 0 check (price >= 0),
  bottles integer not null default 0 check (bottles >= 0),
  extras jsonb not null default '{}'::jsonb,
  scanned_items jsonb not null default '{}'::jsonb,
  delivered_bottles integer check (delivered_bottles is null or delivered_bottles >= 0),
  returned_bottles integer check (returned_bottles is null or returned_bottles >= 0),
  confirmed_payment public.payment_method,
  delivery_comment text,
  failure_reason text,
  version integer not null default 1 check (version > 0),
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.sync_operations (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null unique,
  operation_type public.sync_operation_type not null,
  status public.sync_operation_status not null default 'pending',
  order_id uuid references public.orders(id) on delete set null,
  order_version integer check (order_version is null or order_version > 0),
  courier_id uuid references public.couriers(id) on delete set null,
  actor_profile_id uuid not null references public.profiles(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  acked_at timestamptz
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text,
  provider_payment_id text,
  amount numeric(12, 2) not null check (amount >= 0),
  status public.payment_status not null default 'pending',
  qr_payload text,
  paid_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_payment_id)
);

create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists couriers_profile_id_idx on public.couriers(profile_id);
create index if not exists orders_assigned_courier_state_idx on public.orders(assigned_courier_id, state);
create index if not exists orders_updated_at_idx on public.orders(updated_at desc);
create index if not exists order_events_order_id_created_at_idx on public.order_events(order_id, created_at desc);
create index if not exists sync_operations_actor_status_idx on public.sync_operations(actor_profile_id, status);
create index if not exists sync_operations_courier_status_idx on public.sync_operations(courier_id, status);
create index if not exists payments_order_id_status_idx on public.payments(order_id, status);

create or replace trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function app_private.touch_updated_at();

create or replace trigger couriers_touch_updated_at
before update on public.couriers
for each row execute function app_private.touch_updated_at();

create or replace trigger orders_touch_updated_at
before update on public.orders
for each row execute function app_private.touch_updated_at();

create or replace trigger sync_operations_touch_updated_at
before update on public.sync_operations
for each row execute function app_private.touch_updated_at();

create or replace trigger payments_touch_updated_at
before update on public.payments
for each row execute function app_private.touch_updated_at();

create or replace trigger app_config_touch_updated_at
before update on public.app_config
for each row execute function app_private.touch_updated_at();

create or replace function app_private.current_user_role()
returns public.app_role
language sql
security definer
stable
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
    and p.is_active = true
  limit 1;
$$;

create or replace function app_private.current_courier_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select c.id
  from public.couriers c
  join public.profiles p on p.id = c.profile_id
  where p.id = auth.uid()
    and p.is_active = true
    and c.is_active = true
  limit 1;
$$;

create or replace function app_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, full_name, phone)
  values (
    new.id,
    coalesce((new.raw_app_meta_data ->> 'role')::public.app_role, 'courier'),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function app_private.handle_new_user();

revoke all on function app_private.current_user_role() from public;
revoke all on function app_private.current_courier_id() from public;
revoke all on function app_private.handle_new_user() from public;
grant usage on schema app_private to authenticated;
grant execute on function app_private.current_user_role() to authenticated;
grant execute on function app_private.current_courier_id() to authenticated;

grant select on public.app_config to authenticated;
grant select on public.profiles to authenticated;
grant select on public.couriers to authenticated;
grant select on public.orders to authenticated;
grant select on public.order_events to authenticated;
grant select, insert on public.sync_operations to authenticated;
grant select on public.payments to authenticated;

grant all on public.profiles to service_role;
grant all on public.couriers to service_role;
grant all on public.orders to service_role;
grant all on public.order_events to service_role;
grant all on public.sync_operations to service_role;
grant all on public.payments to service_role;
grant all on public.app_config to service_role;

alter table public.profiles enable row level security;
alter table public.couriers enable row level security;
alter table public.orders enable row level security;
alter table public.order_events enable row level security;
alter table public.sync_operations enable row level security;
alter table public.payments enable row level security;
alter table public.app_config enable row level security;

drop policy if exists profiles_select_own_or_staff on public.profiles;
create policy profiles_select_own_or_staff
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and (
    id = (select auth.uid())
    or app_private.current_user_role() in ('dispatcher', 'admin')
  )
);

drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update
on public.profiles
for update
to authenticated
using (app_private.current_user_role() = 'admin')
with check (app_private.current_user_role() = 'admin');

drop policy if exists couriers_select_own_or_staff on public.couriers;
create policy couriers_select_own_or_staff
on public.couriers
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or app_private.current_user_role() in ('dispatcher', 'admin')
);

drop policy if exists couriers_staff_insert on public.couriers;
create policy couriers_staff_insert
on public.couriers
for insert
to authenticated
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists couriers_staff_update on public.couriers;
create policy couriers_staff_update
on public.couriers
for update
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists app_config_select_authenticated on public.app_config;
create policy app_config_select_authenticated
on public.app_config
for select
to authenticated
using ((select auth.uid()) is not null);

drop policy if exists app_config_admin_write on public.app_config;
create policy app_config_admin_write
on public.app_config
for all
to authenticated
using (app_private.current_user_role() = 'admin')
with check (app_private.current_user_role() = 'admin');

drop policy if exists orders_select_assigned_or_staff on public.orders;
create policy orders_select_assigned_or_staff
on public.orders
for select
to authenticated
using (
  assigned_courier_id = app_private.current_courier_id()
  or app_private.current_user_role() in ('dispatcher', 'admin')
);

drop policy if exists orders_staff_insert on public.orders;
create policy orders_staff_insert
on public.orders
for insert
to authenticated
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists orders_staff_update on public.orders;
create policy orders_staff_update
on public.orders
for update
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists order_events_select_related_or_staff on public.order_events;
create policy order_events_select_related_or_staff
on public.order_events
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_events.order_id
      and (
        o.assigned_courier_id = app_private.current_courier_id()
        or app_private.current_user_role() in ('dispatcher', 'admin')
      )
  )
);

drop policy if exists order_events_staff_insert on public.order_events;
create policy order_events_staff_insert
on public.order_events
for insert
to authenticated
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists sync_operations_select_own_or_staff on public.sync_operations;
create policy sync_operations_select_own_or_staff
on public.sync_operations
for select
to authenticated
using (
  actor_profile_id = (select auth.uid())
  or courier_id = app_private.current_courier_id()
  or app_private.current_user_role() in ('dispatcher', 'admin')
);

drop policy if exists sync_operations_insert_own on public.sync_operations;
create policy sync_operations_insert_own
on public.sync_operations
for insert
to authenticated
with check (
  actor_profile_id = (select auth.uid())
  and (
    courier_id is null
    or courier_id = app_private.current_courier_id()
    or app_private.current_user_role() in ('dispatcher', 'admin')
  )
);

drop policy if exists sync_operations_staff_update on public.sync_operations;
create policy sync_operations_staff_update
on public.sync_operations
for update
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists payments_select_related_or_staff on public.payments;
create policy payments_select_related_or_staff
on public.payments
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = payments.order_id
      and (
        o.assigned_courier_id = app_private.current_courier_id()
        or app_private.current_user_role() in ('dispatcher', 'admin')
      )
  )
);

drop policy if exists payments_staff_write on public.payments;
create policy payments_staff_write
on public.payments
for all
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

insert into public.app_config (key, value, version)
values
  (
    'pricing',
    '{"water":{"singleBottle":400,"multiBottle":300},"extras":{"mechanicalPump":500,"petBottleDeposit":400}}'::jsonb,
    1
  ),
  (
    'dispatcher_contact',
    '{"phone":"+79385358777"}'::jsonb,
    1
  ),
  (
    'sync',
    '{"pollIntervalSeconds":60,"maxRetryBackoffSeconds":900}'::jsonb,
    1
  )
on conflict (key) do update
set value = excluded.value,
    version = public.app_config.version + 1,
    updated_at = now();
