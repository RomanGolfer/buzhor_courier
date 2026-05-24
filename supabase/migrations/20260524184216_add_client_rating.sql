alter table public.orders
  add column if not exists client_rating jsonb;

create or replace function public.normalize_phone(value text)
returns text
language sql
immutable
parallel safe
as $$
  with digits as (
    select regexp_replace(coalesce(value, ''), '\D', '', 'g') as phone
  )
  select case
    when phone = '' then null
    when length(phone) = 11 and left(phone, 1) = '8' then '7' || substring(phone from 2)
    when length(phone) = 10 then '7' || phone
    else phone
  end
  from digits;
$$;

create table if not exists public.client_ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  courier_id uuid references public.couriers(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  client_phone text,
  client_phone_normalized text,
  rating integer not null check (rating between 1 and 5),
  created_at timestamptz not null default now()
);

create index if not exists orders_client_rating_idx
on public.orders ((client_rating->>'rating'))
where client_rating is not null;

create index if not exists client_ratings_phone_idx
on public.client_ratings(client_phone_normalized)
where client_phone_normalized is not null;

grant execute on function public.normalize_phone(text) to authenticated;
grant select on public.client_ratings to authenticated;
grant all on public.client_ratings to service_role;

alter table public.client_ratings enable row level security;

drop policy if exists client_ratings_staff_select on public.client_ratings;
create policy client_ratings_staff_select
on public.client_ratings
for select
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'));

drop policy if exists client_ratings_courier_select_own on public.client_ratings;
create policy client_ratings_courier_select_own
on public.client_ratings
for select
to authenticated
using (courier_id = app_private.current_courier_id());

create or replace function app_private.process_sync_operation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_rating jsonb;
  v_rating integer;
  v_client_phone text;
  v_client_phone_normalized text;
  v_courier_id uuid;
begin
  if NEW.status != 'pending' then
    return NEW;
  end if;

  if NEW.operation_type = 'complete' and NEW.order_id is not null then
    select
      o.client_phone,
      public.normalize_phone(o.client_phone),
      coalesce(NEW.courier_id, o.assigned_courier_id, app_private.current_courier_id())
    into v_client_phone, v_client_phone_normalized, v_courier_id
    from public.orders o
    where o.id = NEW.order_id;

    v_client_rating := NEW.payload->'clientRating';

    update public.orders
    set
      state = 'delivered',
      delivered_bottles = (NEW.payload->>'bottles')::integer,
      returned_bottles  = (NEW.payload->>'returnedBottles')::integer,
      confirmed_payment = (NEW.payload->>'paymentType')::public.payment_method,
      delivery_comment  = nullif(NEW.payload->>'comment', ''),
      scanned_items     = coalesce(NEW.payload->'scannedItems', '{}'::jsonb),
      marking_codes     = coalesce(NEW.payload->'markingCodes', '{}'::jsonb),
      fiscal_receipt    = coalesce(
        NEW.payload->'fiscalReceipt',
        '{"status":"not_required"}'::jsonb
      ),
      client_rating     = v_client_rating,
      updated_by        = NEW.actor_profile_id,
      version           = version + 1
    where id = NEW.order_id;

    if jsonb_typeof(v_client_rating) = 'object'
       and coalesce(v_client_rating->>'rating', '') ~ '^\d+$' then
      v_rating := least(5, greatest(1, (v_client_rating->>'rating')::integer));

      insert into public.client_ratings (
        order_id,
        courier_id,
        actor_profile_id,
        client_phone,
        client_phone_normalized,
        rating
      )
      values (
        NEW.order_id,
        v_courier_id,
        NEW.actor_profile_id,
        v_client_phone,
        v_client_phone_normalized,
        v_rating
      )
      on conflict (order_id) do nothing;
    end if;

    insert into public.order_events (order_id, actor_profile_id, event_type, payload)
    values (NEW.order_id, NEW.actor_profile_id, 'delivered', NEW.payload);

    NEW.status   := 'acked';
    NEW.acked_at := now();

  elsif NEW.operation_type = 'fail' and NEW.order_id is not null then
    update public.orders
    set
      state          = 'failed',
      failure_reason = NEW.payload->>'reason',
      updated_by     = NEW.actor_profile_id,
      version        = version + 1
    where id = NEW.order_id;

    insert into public.order_events (order_id, actor_profile_id, event_type, payload)
    values (NEW.order_id, NEW.actor_profile_id, 'failed', NEW.payload);

    NEW.status   := 'acked';
    NEW.acked_at := now();
  end if;

  return NEW;
end;
$$;

create or replace trigger sync_operations_process
before insert on public.sync_operations
for each row execute function app_private.process_sync_operation();

revoke all on function app_private.process_sync_operation() from public;
