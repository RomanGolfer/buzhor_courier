create index if not exists courier_daily_inventory_created_by_idx
  on public.courier_daily_inventory(created_by) where created_by is not null;
create index if not exists courier_daily_inventory_updated_by_idx
  on public.courier_daily_inventory(updated_by) where updated_by is not null;

create index if not exists courier_shifts_courier_date_idx
  on public.courier_shifts(courier_id, work_date desc);
create index if not exists courier_shifts_vehicle_idx
  on public.courier_shifts(vehicle_id) where vehicle_id is not null;
create index if not exists courier_shifts_closed_by_idx
  on public.courier_shifts(closed_by) where closed_by is not null;
create index if not exists courier_shifts_reopened_by_idx
  on public.courier_shifts(reopened_by) where reopened_by is not null;
create index if not exists courier_shifts_updated_by_idx
  on public.courier_shifts(updated_by) where updated_by is not null;

create index if not exists courier_inventory_movements_courier_idx
  on public.courier_inventory_movements(courier_id, work_date desc);
create index if not exists courier_inventory_movements_vehicle_idx
  on public.courier_inventory_movements(vehicle_id) where vehicle_id is not null;
create index if not exists courier_inventory_movements_order_idx
  on public.courier_inventory_movements(source_order_id) where source_order_id is not null;
create index if not exists courier_inventory_movements_inventory_idx
  on public.courier_inventory_movements(source_inventory_id) where source_inventory_id is not null;
create index if not exists courier_inventory_movements_actor_idx
  on public.courier_inventory_movements(actor_profile_id) where actor_profile_id is not null;

create index if not exists operational_issue_actions_order_idx
  on public.operational_issue_actions(order_id) where order_id is not null;
create index if not exists operational_issue_actions_courier_idx
  on public.operational_issue_actions(courier_id) where courier_id is not null;
create index if not exists operational_issue_actions_handler_idx
  on public.operational_issue_actions(handled_by) where handled_by is not null;
create index if not exists notification_outbox_order_idx
  on public.notification_outbox(order_id) where order_id is not null;
create index if not exists staff_audit_log_actor_idx
  on public.staff_audit_log(actor_profile_id) where actor_profile_id is not null;

create index if not exists data_imports_imported_by_idx
  on public.data_imports(imported_by) where imported_by is not null;
create index if not exists data_imports_rolled_back_by_idx
  on public.data_imports(rolled_back_by) where rolled_back_by is not null;
