alter table public.orders
  add column if not exists client_phone_normalized text generated always as (public.normalize_phone(client_phone)) stored;

create index if not exists orders_client_phone_normalized_updated_idx
on public.orders(client_phone_normalized, updated_at desc)
where client_phone_normalized is not null;

create table if not exists public.call_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'generic' check (char_length(provider) between 1 and 64),
  provider_call_id text check (provider_call_id is null or char_length(provider_call_id) <= 160),
  direction text not null check (direction in ('inbound', 'outbound')),
  event_type text not null check (char_length(event_type) between 1 and 80),
  order_id uuid references public.orders(id) on delete set null,
  client_phone text check (client_phone is null or char_length(client_phone) <= 64),
  client_phone_normalized text generated always as (public.normalize_phone(client_phone)) stored,
  dispatcher_profile_id uuid references public.profiles(id) on delete set null,
  courier_id uuid references public.couriers(id) on delete set null,
  started_at timestamptz,
  answered_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  recording_url text check (recording_url is null or char_length(recording_url) <= 2048),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists call_events_provider_call_uidx
on public.call_events(provider, provider_call_id)
where provider_call_id is not null;

create index if not exists call_events_order_created_idx
on public.call_events(order_id, created_at desc)
where order_id is not null;

create index if not exists call_events_phone_created_idx
on public.call_events(client_phone_normalized, created_at desc)
where client_phone_normalized is not null;

create index if not exists call_events_recent_inbound_idx
on public.call_events(created_at desc)
where direction = 'inbound';

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'call_events'
  ) then
    alter publication supabase_realtime add table public.call_events;
  end if;
end $$;

drop trigger if exists call_events_touch_updated_at on public.call_events;
create trigger call_events_touch_updated_at
before update on public.call_events
for each row execute function app_private.touch_updated_at();

grant select, insert, update on public.call_events to authenticated;
grant all on public.call_events to service_role;

alter table public.call_events enable row level security;

drop policy if exists call_events_select_related_or_staff on public.call_events;
create policy call_events_select_related_or_staff
on public.call_events
for select
to authenticated
using (
  app_private.current_user_role() in ('dispatcher', 'admin')
  or courier_id = app_private.current_courier_id()
  or exists (
    select 1
    from public.orders o
    where o.id = call_events.order_id
      and o.assigned_courier_id = app_private.current_courier_id()
  )
);

drop policy if exists call_events_staff_insert on public.call_events;
create policy call_events_staff_insert
on public.call_events
for insert
to authenticated
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists call_events_staff_update on public.call_events;
create policy call_events_staff_update
on public.call_events
for update
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));
