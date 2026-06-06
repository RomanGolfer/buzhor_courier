-- Reassert the Supabase RLS baseline for all sensitive public tables.
-- Do not FORCE RLS here: app_private security-definer helpers intentionally
-- read these tables to evaluate policies without recursive policy checks.

alter table public.profiles enable row level security;
alter table public.couriers enable row level security;
alter table public.orders enable row level security;
alter table public.order_events enable row level security;
alter table public.sync_operations enable row level security;
alter table public.payments enable row level security;
alter table public.app_config enable row level security;
alter table public.client_ratings enable row level security;

do $$
declare
  v_missing text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ')
  into v_missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'profiles',
      'couriers',
      'orders',
      'order_events',
      'sync_operations',
      'payments',
      'app_config',
      'client_ratings'
    )
    and c.relkind = 'r'
    and c.relrowsecurity = false;

  if v_missing is not null then
    raise exception 'rls_not_enabled:%', v_missing;
  end if;
end $$;
