create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  courier_id uuid references public.couriers(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (
    platform in ('android', 'ios', 'macos', 'windows', 'linux', 'fuchsia')
  ),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_push_tokens_profile_id_idx
on public.device_push_tokens(profile_id);

create index if not exists device_push_tokens_courier_id_idx
on public.device_push_tokens(courier_id)
where courier_id is not null;

create or replace trigger device_push_tokens_touch_updated_at
before update on public.device_push_tokens
for each row execute function app_private.touch_updated_at();

grant select, insert, update, delete on public.device_push_tokens to authenticated;
grant all on public.device_push_tokens to service_role;

alter table public.device_push_tokens enable row level security;

drop policy if exists device_push_tokens_select_own on public.device_push_tokens;
create policy device_push_tokens_select_own
on public.device_push_tokens
for select
to authenticated
using (profile_id = (select auth.uid()));

drop policy if exists device_push_tokens_insert_own on public.device_push_tokens;
create policy device_push_tokens_insert_own
on public.device_push_tokens
for insert
to authenticated
with check (
  profile_id = (select auth.uid())
  and (
    courier_id is null
    or exists (
      select 1
      from public.couriers c
      where c.id = courier_id
        and c.profile_id = (select auth.uid())
    )
  )
);

drop policy if exists device_push_tokens_update_own on public.device_push_tokens;
create policy device_push_tokens_update_own
on public.device_push_tokens
for update
to authenticated
using (profile_id = (select auth.uid()))
with check (
  profile_id = (select auth.uid())
  and (
    courier_id is null
    or exists (
      select 1
      from public.couriers c
      where c.id = courier_id
        and c.profile_id = (select auth.uid())
    )
  )
);

drop policy if exists device_push_tokens_delete_own on public.device_push_tokens;
create policy device_push_tokens_delete_own
on public.device_push_tokens
for delete
to authenticated
using (profile_id = (select auth.uid()));
