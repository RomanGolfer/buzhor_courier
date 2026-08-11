create table public.clients (
  id uuid primary key default gen_random_uuid(),
  legacy_id text,
  full_name text not null,
  phone text,
  phone_normalized text generated always as (public.normalize_phone(phone)) stored,
  email text,
  status text,
  loyalty_points numeric(12, 2) not null default 0,
  tare_debt integer not null default 0,
  notes text,
  dedupe_key text not null unique,
  source_system text,
  legacy_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clients_text_length_chk check (
    char_length(full_name) between 1 and 160
    and (legacy_id is null or char_length(legacy_id) <= 160)
    and (phone is null or char_length(phone) <= 64)
    and (email is null or char_length(email) <= 320)
    and (status is null or char_length(status) <= 80)
    and (notes is null or char_length(notes) <= 2000)
    and char_length(dedupe_key) between 1 and 240
    and (source_system is null or char_length(source_system) <= 120)
  ),
  constraint clients_loyalty_points_chk check (loyalty_points >= 0),
  constraint clients_tare_debt_chk check (tare_debt >= 0),
  constraint clients_legacy_data_object_chk check (jsonb_typeof(legacy_data) = 'object')
);

create table public.client_addresses (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  legacy_id text,
  address_text text not null,
  zone_name text,
  district text,
  locality text,
  street text,
  house text,
  building text,
  structure text,
  entrance text,
  floor text,
  apartment text,
  lat numeric(10, 7),
  lng numeric(10, 7),
  dedupe_key text not null,
  source_system text,
  legacy_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint client_addresses_client_dedupe_uidx unique (client_id, dedupe_key),
  constraint client_addresses_text_length_chk check (
    char_length(address_text) between 1 and 500
    and (legacy_id is null or char_length(legacy_id) <= 160)
    and (zone_name is null or char_length(zone_name) <= 160)
    and (district is null or char_length(district) <= 160)
    and (locality is null or char_length(locality) <= 160)
    and (street is null or char_length(street) <= 200)
    and (house is null or char_length(house) <= 40)
    and (building is null or char_length(building) <= 40)
    and (structure is null or char_length(structure) <= 40)
    and (entrance is null or char_length(entrance) <= 40)
    and (floor is null or char_length(floor) <= 40)
    and (apartment is null or char_length(apartment) <= 40)
    and char_length(dedupe_key) between 1 and 240
    and (source_system is null or char_length(source_system) <= 120)
  ),
  constraint client_addresses_coordinate_range_chk check (
    (lat is null or lat between -90 and 90)
    and (lng is null or lng between -180 and 180)
  ),
  constraint client_addresses_legacy_data_object_chk check (jsonb_typeof(legacy_data) = 'object')
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  legacy_id text,
  name text not null,
  inn text,
  kpp text,
  phone text,
  email text,
  address_text text,
  tare_debt integer not null default 0,
  dedupe_key text not null unique,
  source_system text,
  legacy_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organizations_text_length_chk check (
    char_length(name) between 1 and 240
    and (legacy_id is null or char_length(legacy_id) <= 160)
    and (inn is null or char_length(inn) <= 32)
    and (kpp is null or char_length(kpp) <= 32)
    and (phone is null or char_length(phone) <= 64)
    and (email is null or char_length(email) <= 320)
    and (address_text is null or char_length(address_text) <= 500)
    and char_length(dedupe_key) between 1 and 240
    and (source_system is null or char_length(source_system) <= 120)
  ),
  constraint organizations_tare_debt_chk check (tare_debt >= 0),
  constraint organizations_legacy_data_object_chk check (jsonb_typeof(legacy_data) = 'object')
);

create table public.data_imports (
  id uuid primary key default gen_random_uuid(),
  entity_kind text not null check (entity_kind in ('clients', 'organizations', 'orders')),
  status text not null default 'processing' check (
    status in ('processing', 'completed', 'completed_with_errors', 'failed')
  ),
  source_system text not null,
  filename text not null,
  checksum text,
  total_rows integer not null default 0 check (total_rows between 0 and 50000),
  imported_rows integer not null default 0 check (imported_rows >= 0),
  updated_rows integer not null default 0 check (updated_rows >= 0),
  skipped_rows integer not null default 0 check (skipped_rows >= 0),
  failed_rows integer not null default 0 check (failed_rows >= 0),
  error_summary jsonb not null default '[]'::jsonb,
  imported_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint data_imports_text_length_chk check (
    char_length(source_system) between 1 and 120
    and char_length(filename) between 1 and 255
    and (checksum is null or char_length(checksum) <= 128)
  ),
  constraint data_imports_error_summary_array_chk check (jsonb_typeof(error_summary) = 'array')
);

alter table public.orders
  add column client_id uuid references public.clients(id) on delete set null,
  add column organization_id uuid references public.organizations(id) on delete set null,
  add column source_system text,
  add column source_record_id text,
  add column legacy_data jsonb not null default '{}'::jsonb;

alter table public.orders
  add constraint orders_source_fields_length_chk check (
    (source_system is null or char_length(source_system) <= 120)
    and (source_record_id is null or char_length(source_record_id) <= 160)
  ),
  add constraint orders_legacy_data_object_chk check (jsonb_typeof(legacy_data) = 'object');

create index clients_phone_normalized_idx
on public.clients(phone_normalized)
where phone_normalized is not null;

create index clients_updated_at_idx on public.clients(updated_at desc);
create index client_addresses_client_updated_idx on public.client_addresses(client_id, updated_at desc);
create index organizations_updated_at_idx on public.organizations(updated_at desc);
create index data_imports_created_at_idx on public.data_imports(created_at desc);
create index orders_client_updated_idx on public.orders(client_id, updated_at desc);
create index orders_organization_updated_idx on public.orders(organization_id, updated_at desc);

create unique index orders_source_record_uidx
on public.orders(source_system, source_record_id)
where source_system is not null and source_record_id is not null;

create trigger clients_touch_updated_at
before update on public.clients
for each row execute function app_private.touch_updated_at();

create trigger client_addresses_touch_updated_at
before update on public.client_addresses
for each row execute function app_private.touch_updated_at();

create trigger organizations_touch_updated_at
before update on public.organizations
for each row execute function app_private.touch_updated_at();

create trigger data_imports_touch_updated_at
before update on public.data_imports
for each row execute function app_private.touch_updated_at();

-- Seed the new directories from orders already present in the project.
with order_clients as (
  select
    o.client_name,
    o.client_phone,
    o.address,
    o.updated_at,
    case
      when nullif(public.normalize_phone(o.client_phone), '') is not null
        then 'phone:' || public.normalize_phone(o.client_phone)
      else 'order:' || md5(lower(trim(o.client_name)) || '|' || lower(trim(o.address)))
    end as dedupe_key
  from public.orders o
), latest_clients as (
  select distinct on (dedupe_key)
    client_name,
    client_phone,
    dedupe_key
  from order_clients
  order by dedupe_key, updated_at desc
)
insert into public.clients (full_name, phone, dedupe_key, source_system)
select client_name, client_phone, dedupe_key, 'current-orders'
from latest_clients
on conflict (dedupe_key) do nothing;

with order_addresses as (
  select distinct on (c.id, lower(trim(o.address)))
    c.id as client_id,
    o.address,
    o.district,
    o.lat,
    o.lng,
    'address:' || md5(lower(trim(o.address))) as dedupe_key
  from public.orders o
  join public.clients c on c.dedupe_key = case
    when nullif(public.normalize_phone(o.client_phone), '') is not null
      then 'phone:' || public.normalize_phone(o.client_phone)
    else 'order:' || md5(lower(trim(o.client_name)) || '|' || lower(trim(o.address)))
  end
  order by c.id, lower(trim(o.address)), o.updated_at desc
)
insert into public.client_addresses (
  client_id,
  address_text,
  district,
  lat,
  lng,
  dedupe_key,
  source_system
)
select client_id, address, district, lat, lng, dedupe_key, 'current-orders'
from order_addresses
on conflict (client_id, dedupe_key) do nothing;

update public.orders o
set client_id = c.id
from public.clients c
where c.dedupe_key = case
  when nullif(public.normalize_phone(o.client_phone), '') is not null
    then 'phone:' || public.normalize_phone(o.client_phone)
  else 'order:' || md5(lower(trim(o.client_name)) || '|' || lower(trim(o.address)))
end;

with contract_organizations as (
  select distinct on (lower(trim(o.client_name)))
    o.client_name,
    o.client_phone,
    o.address,
    'name:' || md5(lower(trim(o.client_name))) as dedupe_key
  from public.orders o
  where o.payment_method = 'contract'
  order by lower(trim(o.client_name)), o.updated_at desc
)
insert into public.organizations (name, phone, address_text, dedupe_key, source_system)
select client_name, client_phone, address, dedupe_key, 'current-orders'
from contract_organizations
on conflict (dedupe_key) do nothing;

update public.orders o
set organization_id = organization.id
from public.organizations organization
where o.payment_method = 'contract'
  and organization.dedupe_key = 'name:' || md5(lower(trim(o.client_name)));

grant select, insert, update, delete on public.clients to authenticated;
grant select, insert, update, delete on public.client_addresses to authenticated;
grant select, insert, update, delete on public.organizations to authenticated;
grant select, insert, update on public.data_imports to authenticated;

grant all on public.clients to service_role;
grant all on public.client_addresses to service_role;
grant all on public.organizations to service_role;
grant all on public.data_imports to service_role;

alter table public.clients enable row level security;
alter table public.client_addresses enable row level security;
alter table public.organizations enable row level security;
alter table public.data_imports enable row level security;

create policy clients_staff_select
on public.clients for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy clients_staff_insert
on public.clients for insert to authenticated
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy clients_staff_update
on public.clients for update to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy clients_staff_delete
on public.clients for delete to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy client_addresses_staff_select
on public.client_addresses for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy client_addresses_staff_insert
on public.client_addresses for insert to authenticated
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy client_addresses_staff_update
on public.client_addresses for update to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy client_addresses_staff_delete
on public.client_addresses for delete to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy organizations_staff_select
on public.organizations for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy organizations_staff_insert
on public.organizations for insert to authenticated
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy organizations_staff_update
on public.organizations for update to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy organizations_staff_delete
on public.organizations for delete to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy data_imports_admin_select
on public.data_imports for select to authenticated
using (
  (select app_private.current_user_role()) = 'admin'
  and imported_by = (select auth.uid())
);

create policy data_imports_admin_insert
on public.data_imports for insert to authenticated
with check (
  (select app_private.current_user_role()) = 'admin'
  and imported_by = (select auth.uid())
);

create policy data_imports_admin_update
on public.data_imports for update to authenticated
using (
  (select app_private.current_user_role()) = 'admin'
  and imported_by = (select auth.uid())
)
with check (
  (select app_private.current_user_role()) = 'admin'
  and imported_by = (select auth.uid())
);

select pg_notify('pgrst', 'reload schema');
