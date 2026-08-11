alter table public.data_imports
  drop constraint data_imports_imported_by_fkey,
  alter column imported_by drop not null;

alter table public.data_imports
  add constraint data_imports_imported_by_fkey
  foreign key (imported_by)
  references public.profiles(id)
  on delete set null;

drop policy data_imports_admin_select on public.data_imports;
create policy data_imports_admin_select
on public.data_imports for select to authenticated
using ((select app_private.current_user_role()) = 'admin');

select pg_notify('pgrst', 'reload schema');
