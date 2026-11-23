-- These tables are accessed through row-level policies. TRUNCATE is a
-- table-wide operation and is not governed by those policies.
-- Preserve the existing row-level grants and service_role access.
revoke truncate on table
  public.clients,
  public.client_addresses,
  public.data_imports,
  public.delivery_zones,
  public.organizations
from authenticated;
