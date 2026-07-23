alter table public.profiles
add column if not exists email text;

create unique index if not exists profiles_email_lower_idx
on public.profiles (lower(email))
where email is not null;

update public.profiles p
set email = u.email,
    updated_at = now()
from auth.users u
where u.id = p.id
  and p.email is distinct from u.email;

create or replace function app_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, email, full_name, phone)
  values (
    new.id,
    coalesce((new.raw_app_meta_data ->> 'role')::public.app_role, 'courier'),
    nullif(new.email, ''),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do update
  set email = excluded.email,
      updated_at = now();

  return new;
end;
$$;
