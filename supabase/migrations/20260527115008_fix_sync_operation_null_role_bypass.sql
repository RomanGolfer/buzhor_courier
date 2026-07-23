-- Security hardening: reject invalid or unauthorized sync operations explicitly.
-- The trigger runs as security definer, so users without a staff role must be
-- checked with NULL-safe role handling before any order mutation happens.

create or replace function app_private.process_sync_operation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bottles integer;
  v_client_phone text;
  v_client_phone_normalized text;
  v_client_rating jsonb;
  v_courier_id uuid;
  v_payment_method public.payment_method;
  v_rating integer;
  v_reason text;
  v_returned_bottles integer;
  v_user_role text;
begin
  if NEW.status != 'pending' then
    return NEW;
  end if;

  if NEW.order_id is null then
    NEW.status := 'rejected';
    NEW.last_error := 'order_id_required';
    NEW.acked_at := now();
    return NEW;
  end if;

  if not exists (select 1 from public.orders where id = NEW.order_id) then
    NEW.status := 'rejected';
    NEW.last_error := 'order_not_found';
    NEW.acked_at := now();
    return NEW;
  end if;

  v_user_role := coalesce(app_private.current_user_role()::text, '');

  if v_user_role not in ('dispatcher', 'admin') then
    if not exists (
      select 1 from public.orders
      where id = NEW.order_id
        and assigned_courier_id = app_private.current_courier_id()
    ) then
      NEW.status := 'rejected';
      NEW.last_error := 'order_not_assigned';
      NEW.acked_at := now();
      return NEW;
    end if;
  end if;

  if jsonb_typeof(NEW.payload) is distinct from 'object' then
    NEW.status := 'rejected';
    NEW.last_error := 'invalid_payload';
    NEW.acked_at := now();
    return NEW;
  end if;

  if NEW.operation_type = 'complete' then
    if coalesce(NEW.payload->>'bottles', '') !~ '^\d+$' then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_bottles';
      NEW.acked_at := now();
      return NEW;
    end if;

    if coalesce(NEW.payload->>'returnedBottles', '') !~ '^\d+$' then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_returned_bottles';
      NEW.acked_at := now();
      return NEW;
    end if;

    if not exists (
      select 1
      from pg_type t
      join pg_enum e on e.enumtypid = t.oid
      where t.typname = 'payment_method'
        and e.enumlabel = NEW.payload->>'paymentType'
    ) then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_payment_type';
      NEW.acked_at := now();
      return NEW;
    end if;

    if NEW.payload ? 'scannedItems'
       and jsonb_typeof(NEW.payload->'scannedItems') is distinct from 'object' then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_scanned_items';
      NEW.acked_at := now();
      return NEW;
    end if;

    if NEW.payload ? 'markingCodes'
       and jsonb_typeof(NEW.payload->'markingCodes') is distinct from 'object' then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_marking_codes';
      NEW.acked_at := now();
      return NEW;
    end if;

    if NEW.payload ? 'fiscalReceipt'
       and jsonb_typeof(NEW.payload->'fiscalReceipt') is distinct from 'object' then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_fiscal_receipt';
      NEW.acked_at := now();
      return NEW;
    end if;

    v_bottles := (NEW.payload->>'bottles')::integer;
    v_returned_bottles := (NEW.payload->>'returnedBottles')::integer;
    v_payment_method := (NEW.payload->>'paymentType')::public.payment_method;

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
      delivered_bottles = v_bottles,
      returned_bottles  = v_returned_bottles,
      confirmed_payment = v_payment_method,
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

    NEW.status := 'acked';
    NEW.last_error := null;
    NEW.acked_at := now();

  elsif NEW.operation_type = 'fail' then
    v_reason := nullif(trim(NEW.payload->>'reason'), '');
    if v_reason is null then
      NEW.status := 'rejected';
      NEW.last_error := 'invalid_reason';
      NEW.acked_at := now();
      return NEW;
    end if;

    update public.orders
    set
      state          = 'failed',
      failure_reason = v_reason,
      updated_by     = NEW.actor_profile_id,
      version        = version + 1
    where id = NEW.order_id;

    insert into public.order_events (order_id, actor_profile_id, event_type, payload)
    values (NEW.order_id, NEW.actor_profile_id, 'failed', NEW.payload);

    NEW.status := 'acked';
    NEW.last_error := null;
    NEW.acked_at := now();
  else
    NEW.status := 'rejected';
    NEW.last_error := 'invalid_operation_type';
    NEW.acked_at := now();
  end if;

  return NEW;
end;
$$;

revoke all on function app_private.process_sync_operation() from public;
