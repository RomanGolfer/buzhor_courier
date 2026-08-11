create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  license_plate text not null,
  license_plate_normalized text generated always as (
    regexp_replace(upper(license_plate), '[^0-9A-ZА-Я]', '', 'g')
  ) stored,
  make text,
  model text,
  color text,
  service_status text not null default 'ready'
    check (service_status in ('ready', 'maintenance', 'inactive')),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicles_license_plate_length_check
    check (char_length(license_plate_normalized) between 5 and 15)
);

create unique index vehicles_license_plate_normalized_idx
on public.vehicles (license_plate_normalized);

create index vehicles_service_status_idx
on public.vehicles (service_status, license_plate_normalized);

create trigger vehicles_touch_updated_at
before update on public.vehicles
for each row execute function app_private.touch_updated_at();

create table public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  courier_id uuid not null references public.couriers(id) on delete restrict,
  assigned_by uuid references public.profiles(id) on delete set null default auth.uid(),
  assigned_at timestamptz not null default now(),
  released_by uuid references public.profiles(id) on delete set null,
  released_at timestamptz,
  assignment_note text,
  release_note text,
  created_at timestamptz not null default now(),
  constraint vehicle_assignments_release_time_check
    check (released_at is null or released_at >= assigned_at)
);

create unique index vehicle_assignments_one_active_vehicle_idx
on public.vehicle_assignments (vehicle_id)
where released_at is null;

create unique index vehicle_assignments_one_active_courier_idx
on public.vehicle_assignments (courier_id)
where released_at is null;

create index vehicle_assignments_vehicle_history_idx
on public.vehicle_assignments (vehicle_id, assigned_at desc);

create index vehicle_assignments_courier_history_idx
on public.vehicle_assignments (courier_id, assigned_at desc);

alter table public.vehicles enable row level security;
alter table public.vehicle_assignments enable row level security;

revoke all privileges on table public.vehicles from anon, authenticated;
revoke all privileges on table public.vehicle_assignments from anon, authenticated;

grant select, insert, update on table public.vehicles to authenticated;
grant select, insert, update on table public.vehicle_assignments to authenticated;
grant all privileges on table public.vehicles to service_role;
grant all privileges on table public.vehicle_assignments to service_role;

create policy vehicles_staff_select
on public.vehicles
for select
to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy vehicles_admin_insert
on public.vehicles
for insert
to authenticated
with check ((select app_private.current_user_role()) = 'admin');

create policy vehicles_admin_update
on public.vehicles
for update
to authenticated
using ((select app_private.current_user_role()) = 'admin')
with check ((select app_private.current_user_role()) = 'admin');

create policy vehicle_assignments_staff_select
on public.vehicle_assignments
for select
to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy vehicle_assignments_staff_insert
on public.vehicle_assignments
for insert
to authenticated
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and assigned_by = (select auth.uid())
  and released_at is null
  and released_by is null
);

create policy vehicle_assignments_staff_update
on public.vehicle_assignments
for update
to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and (
    released_at is null
    or (
      released_by = (select auth.uid())
      and released_at is not null
    )
  )
);

create or replace function public.list_vehicle_fleet()
returns table (
  id uuid,
  license_plate text,
  make text,
  model text,
  color text,
  service_status text,
  notes text,
  current_assignment_id uuid,
  current_courier_id uuid,
  current_courier_name text,
  current_courier_phone text,
  assigned_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    vehicle.id,
    vehicle.license_plate,
    vehicle.make,
    vehicle.model,
    vehicle.color,
    vehicle.service_status,
    vehicle.notes,
    current_assignment.id,
    current_assignment.courier_id,
    current_assignment.courier_name,
    current_assignment.courier_phone,
    current_assignment.assigned_at,
    vehicle.created_at,
    vehicle.updated_at
  from public.vehicles vehicle
  left join lateral (
    select
      assignment.id,
      assignment.courier_id,
      courier.display_name as courier_name,
      courier.phone as courier_phone,
      assignment.assigned_at
    from public.vehicle_assignments assignment
    join public.couriers courier on courier.id = assignment.courier_id
    where assignment.vehicle_id = vehicle.id
      and assignment.released_at is null
    order by assignment.assigned_at desc
    limit 1
  ) current_assignment on true
  order by
    case vehicle.service_status
      when 'ready' then 0
      when 'maintenance' then 1
      else 2
    end,
    vehicle.license_plate_normalized;
$$;

create or replace function public.list_vehicle_assignment_history(
  p_vehicle_id uuid default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  vehicle_id uuid,
  license_plate text,
  courier_id uuid,
  courier_name text,
  assigned_by_name text,
  assigned_at timestamptz,
  released_by_name text,
  released_at timestamptz,
  assignment_note text,
  release_note text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    assignment.id,
    assignment.vehicle_id,
    vehicle.license_plate,
    assignment.courier_id,
    courier.display_name,
    assigned_profile.full_name,
    assignment.assigned_at,
    released_profile.full_name,
    assignment.released_at,
    assignment.assignment_note,
    assignment.release_note
  from public.vehicle_assignments assignment
  join public.vehicles vehicle on vehicle.id = assignment.vehicle_id
  join public.couriers courier on courier.id = assignment.courier_id
  left join public.profiles assigned_profile on assigned_profile.id = assignment.assigned_by
  left join public.profiles released_profile on released_profile.id = assignment.released_by
  where p_vehicle_id is null or assignment.vehicle_id = p_vehicle_id
  order by assignment.assigned_at desc
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

create or replace function public.save_vehicle(
  p_license_plate text,
  p_make text,
  p_model text,
  p_color text,
  p_service_status text,
  p_notes text,
  p_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_plate text;
  saved_vehicle_id uuid;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required'
      using errcode = '42501';
  end if;

  normalized_plate := regexp_replace(upper(coalesce(p_license_plate, '')), '[^0-9A-ZА-Я]', '', 'g');
  if char_length(normalized_plate) < 5 or char_length(normalized_plate) > 15 then
    raise exception 'invalid_vehicle_license_plate'
      using errcode = '23514';
  end if;

  if p_service_status is null or p_service_status not in ('ready', 'maintenance', 'inactive') then
    raise exception 'invalid_vehicle_service_status'
      using errcode = '23514';
  end if;

  if p_id is null then
    insert into public.vehicles (
      license_plate,
      make,
      model,
      color,
      service_status,
      notes,
      created_by,
      updated_by
    )
    values (
      upper(trim(p_license_plate)),
      nullif(trim(p_make), ''),
      nullif(trim(p_model), ''),
      nullif(trim(p_color), ''),
      p_service_status,
      nullif(trim(p_notes), ''),
      auth.uid(),
      auth.uid()
    )
    returning vehicles.id into saved_vehicle_id;
  else
    update public.vehicles
    set license_plate = upper(trim(p_license_plate)),
        make = nullif(trim(p_make), ''),
        model = nullif(trim(p_model), ''),
        color = nullif(trim(p_color), ''),
        service_status = p_service_status,
        notes = nullif(trim(p_notes), ''),
        updated_by = auth.uid()
    where vehicles.id = p_id
    returning vehicles.id into saved_vehicle_id;

    if saved_vehicle_id is null then
      raise exception 'vehicle_not_found'
        using errcode = 'P0002';
    end if;
  end if;

  if p_service_status <> 'ready' then
    update public.vehicle_assignments
    set released_at = now(),
        released_by = auth.uid(),
        release_note = case p_service_status
          when 'maintenance' then 'Автомобиль отправлен на обслуживание'
          else 'Автомобиль выведен из эксплуатации'
        end
    where vehicle_assignments.vehicle_id = saved_vehicle_id
      and vehicle_assignments.released_at is null;
  end if;

  return saved_vehicle_id;
end;
$$;

create or replace function public.assign_vehicle(
  p_vehicle_id uuid,
  p_courier_id uuid,
  p_note text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_assignment_id uuid;
  saved_assignment_id uuid;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
      using errcode = '42501';
  end if;

  perform 1
  from public.vehicles vehicle
  where vehicle.id = p_vehicle_id
    and vehicle.service_status = 'ready'
  for update;

  if not found then
    raise exception 'vehicle_not_ready_or_missing'
      using errcode = 'P0002';
  end if;

  perform 1
  from public.couriers courier
  join public.profiles profile on profile.id = courier.profile_id
  where courier.id = p_courier_id
    and courier.is_active = true
    and profile.is_active = true
    and profile.role = 'courier'
  for update of courier;

  if not found then
    raise exception 'active_courier_not_found'
      using errcode = 'P0002';
  end if;

  select assignment.id
  into existing_assignment_id
  from public.vehicle_assignments assignment
  where assignment.vehicle_id = p_vehicle_id
    and assignment.courier_id = p_courier_id
    and assignment.released_at is null;

  if existing_assignment_id is not null then
    return existing_assignment_id;
  end if;

  update public.vehicle_assignments assignment
  set released_at = now(),
      released_by = auth.uid(),
      release_note = 'Автоматически освобождён при переназначении'
  where assignment.released_at is null
    and (
      assignment.vehicle_id = p_vehicle_id
      or assignment.courier_id = p_courier_id
    );

  insert into public.vehicle_assignments (
    vehicle_id,
    courier_id,
    assigned_by,
    assignment_note
  )
  values (
    p_vehicle_id,
    p_courier_id,
    auth.uid(),
    nullif(trim(p_note), '')
  )
  returning vehicle_assignments.id into saved_assignment_id;

  return saved_assignment_id;
end;
$$;

create or replace function public.release_vehicle(
  p_vehicle_id uuid,
  p_note text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  released_assignment_id uuid;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
      using errcode = '42501';
  end if;

  perform 1
  from public.vehicles vehicle
  where vehicle.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'vehicle_not_found'
      using errcode = 'P0002';
  end if;

  update public.vehicle_assignments assignment
  set released_at = now(),
      released_by = auth.uid(),
      release_note = coalesce(nullif(trim(p_note), ''), 'Автомобиль освобождён диспетчером')
  where assignment.vehicle_id = p_vehicle_id
    and assignment.released_at is null
  returning assignment.id into released_assignment_id;

  if released_assignment_id is null then
    raise exception 'active_vehicle_assignment_not_found'
      using errcode = 'P0002';
  end if;

  return released_assignment_id;
end;
$$;

revoke all on function public.list_vehicle_fleet() from public, anon, authenticated;
revoke all on function public.list_vehicle_assignment_history(uuid, integer) from public, anon, authenticated;
revoke all on function public.save_vehicle(text, text, text, text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.assign_vehicle(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.release_vehicle(uuid, text) from public, anon, authenticated;

grant execute on function public.list_vehicle_fleet() to authenticated, service_role;
grant execute on function public.list_vehicle_assignment_history(uuid, integer) to authenticated, service_role;
grant execute on function public.save_vehicle(text, text, text, text, text, text, uuid) to authenticated, service_role;
grant execute on function public.assign_vehicle(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.release_vehicle(uuid, text) to authenticated, service_role;

comment on table public.vehicles is
  'Fleet registry with unique normalized license plates and service availability.';

comment on table public.vehicle_assignments is
  'Append-only vehicle-to-courier assignment history. Active rows have no released_at.';

comment on function public.assign_vehicle(uuid, uuid, text) is
  'Assigns one ready vehicle to one active courier, closing conflicting active assignments.';

select pg_notify('pgrst', 'reload schema');
