-- Validate CHECK constraints that were added as NOT VALID in the previous
-- hardening migration. NOT VALID skips scanning existing rows at creation time;
-- VALIDATE CONSTRAINT performs the full table scan and promotes the constraint
-- to full enforcement. Run this after confirming no historical rows violate it.
--
-- Diagnostic queries to find violations before running this migration:
--
--   -- profiles
--   SELECT id, full_name, phone FROM public.profiles
--   WHERE (full_name IS NOT NULL AND char_length(full_name) > 160)
--      OR (phone     IS NOT NULL AND char_length(phone)     > 64);
--
--   -- couriers
--   SELECT id, display_name, phone, region FROM public.couriers
--   WHERE char_length(display_name) NOT BETWEEN 1 AND 160
--      OR (phone   IS NOT NULL AND char_length(phone)   > 64)
--      OR (region  IS NOT NULL AND char_length(region)  > 120);
--
--   -- orders (text lengths)
--   SELECT id FROM public.orders
--   WHERE char_length(order_number) NOT BETWEEN 1 AND 64
--      OR char_length(client_name)  NOT BETWEEN 1 AND 160
--      OR (client_phone IS NOT NULL AND char_length(client_phone)     > 64)
--      OR char_length(address)      NOT BETWEEN 1 AND 500
--      OR (district         IS NOT NULL AND char_length(district)         > 120)
--      OR (time_slot        IS NOT NULL AND char_length(time_slot)        > 80)
--      OR (delivery_comment IS NOT NULL AND char_length(delivery_comment) > 1200)
--      OR (failure_reason   IS NOT NULL AND char_length(failure_reason)   > 500);
--
--   -- orders (coordinate range)
--   SELECT id, lat, lng FROM public.orders
--   WHERE (lat IS NOT NULL AND lat NOT BETWEEN -90  AND 90)
--      OR (lng IS NOT NULL AND lng NOT BETWEEN -180 AND 180);

do $$
begin
  if exists (
    select 1 from pg_constraint where conname = 'profiles_text_length_chk'
  ) then
    alter table public.profiles validate constraint profiles_text_length_chk;
  end if;

  if exists (
    select 1 from pg_constraint where conname = 'couriers_text_length_chk'
  ) then
    alter table public.couriers validate constraint couriers_text_length_chk;
  end if;

  if exists (
    select 1 from pg_constraint where conname = 'orders_public_input_length_chk'
  ) then
    alter table public.orders validate constraint orders_public_input_length_chk;
  end if;

  if exists (
    select 1 from pg_constraint where conname = 'orders_coordinate_range_chk'
  ) then
    alter table public.orders validate constraint orders_coordinate_range_chk;
  end if;
end $$;
