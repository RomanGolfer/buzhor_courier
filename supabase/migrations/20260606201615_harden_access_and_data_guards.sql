-- Security hardening: reduce unauthenticated surface area and protect critical admin access.

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;

alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon;

create or replace function app_private.prevent_last_admin_lockout()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if OLD.role = 'admin'
     and OLD.is_active = true
     and (NEW.role <> 'admin' or NEW.is_active = false) then
    if not exists (
      select 1
      from public.profiles p
      where p.id <> OLD.id
        and p.role = 'admin'
        and p.is_active = true
    ) then
      raise exception 'last_active_admin_required';
    end if;
  end if;

  return NEW;
end;
$$;

revoke all on function app_private.prevent_last_admin_lockout() from public;

drop trigger if exists profiles_prevent_last_admin_lockout on public.profiles;
create trigger profiles_prevent_last_admin_lockout
before update of role, is_active on public.profiles
for each row execute function app_private.prevent_last_admin_lockout();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_text_length_chk'
  ) then
    alter table public.profiles
      add constraint profiles_text_length_chk
      check (
        (full_name is null or char_length(full_name) <= 160)
        and (phone is null or char_length(phone) <= 64)
      )
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'couriers_text_length_chk'
  ) then
    alter table public.couriers
      add constraint couriers_text_length_chk
      check (
        char_length(display_name) between 1 and 160
        and (phone is null or char_length(phone) <= 64)
        and (region is null or char_length(region) <= 120)
      )
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'orders_public_input_length_chk'
  ) then
    alter table public.orders
      add constraint orders_public_input_length_chk
      check (
        char_length(order_number) between 1 and 64
        and char_length(client_name) between 1 and 160
        and (client_phone is null or char_length(client_phone) <= 64)
        and char_length(address) between 1 and 500
        and (district is null or char_length(district) <= 120)
        and (time_slot is null or char_length(time_slot) <= 80)
        and (delivery_comment is null or char_length(delivery_comment) <= 1200)
        and (failure_reason is null or char_length(failure_reason) <= 500)
      )
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'orders_coordinate_range_chk'
  ) then
    alter table public.orders
      add constraint orders_coordinate_range_chk
      check (
        (lat is null or lat between -90 and 90)
        and (lng is null or lng between -180 and 180)
      )
      not valid;
  end if;
end $$;
