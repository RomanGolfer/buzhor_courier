export type Role = "courier" | "dispatcher" | "admin";

export type OrderState =
  | "draft"
  | "assigned"
  | "accepted"
  | "in_progress"
  | "delivered"
  | "failed"
  | "cancelled";

export type PaymentMethod = "card" | "cash" | "qr" | "online" | "contract";

export type FiscalReceiptStatus =
  | "not_required"
  | "pending"
  | "issued"
  | "failed"
  | "needs_review";

export type FiscalReceipt = {
  status: FiscalReceiptStatus;
  operationId?: string | null;
  provider?: string | null;
  receiptUrl?: string | null;
  fiscalDocumentNumber?: string | null;
  fiscalDriveNumber?: string | null;
  fiscalSign?: string | null;
  issuedAt?: string | null;
  error?: string | null;
};

export type ClientRating = {
  rating: number;
  ratedAt?: string | null;
};

export type ClientRatingStats = {
  average: number;
  count: number;
};

export type Profile = {
  id: string;
  role: Role;
  email: string | null;
  full_name: string | null;
  phone: string | null;
  is_active: boolean;
  couriers?: Pick<Courier, "id" | "display_name" | "phone" | "region" | "is_active">[] | null;
};

export type Courier = {
  id: string;
  profile_id: string;
  display_name: string;
  phone: string | null;
  region: string | null;
  is_active: boolean;
  last_lat?: number | null;
  last_lng?: number | null;
  last_location_accuracy_m?: number | null;
  last_location_at?: string | null;
};

export type OperationsSummary = {
  total_orders: number;
  delivered_orders: number;
  active_orders: number;
  unassigned_orders: number;
  failed_orders: number;
  overdue_orders: number;
  open_issues: number;
  planned_bottles: number;
  revenue: number;
};

export type OperationsOrder = {
  id: string;
  order_number: string;
  state: OrderState;
  client_name: string;
  address: string;
  lat: number | null;
  lng: number | null;
  district: string | null;
  time_slot: string | null;
  bottles: number;
  price: number;
  payment_method: PaymentMethod;
  courier_id: string | null;
  courier_name: string | null;
  zone_id: string | null;
  zone_name: string | null;
  zone_color: string | null;
  is_overdue: boolean;
};

export type OperationsCourier = {
  id: string;
  name: string;
  phone: string | null;
  is_active: boolean;
  lat: number | null;
  lng: number | null;
  location_accuracy_m: number | null;
  location_at: string | null;
  vehicle_id: string | null;
  vehicle_plate: string | null;
  total_orders: number;
  delivered_orders: number;
  active_orders: number;
  failed_orders: number;
  planned_bottles: number;
  inventory_configured: boolean;
  loaded_full_bottles: number | null;
  remaining_full_bottles: number | null;
  remaining_empty_bottles: number | null;
  estimated_finish: string | null;
};

export type OperationalIssue = {
  issue_key: string;
  issue_type: string;
  severity: "critical" | "high" | "medium";
  order_id: string | null;
  courier_id: string | null;
  title: string;
  detail: string;
  lat: number | null;
  lng: number | null;
  status: "open" | "acknowledged" | "resolved" | "dismissed";
  note: string | null;
  handled_at: string | null;
  handled_by_name: string | null;
};

export type DispatcherOperations = {
  work_date: string;
  summary: OperationsSummary;
  orders: OperationsOrder[];
  couriers: OperationsCourier[];
  issues: OperationalIssue[];
};

export type ShiftReconciliationRow = {
  courier_id: string;
  courier_name: string;
  courier_active: boolean;
  vehicle_plate: string | null;
  delivered_orders: number;
  active_orders: number;
  failed_orders: number;
  expected_cash: number;
  expected_card: number;
  expected_qr: number;
  expected_online: number;
  expected_contract: number;
  expected_total: number;
  actual_cash: number | null;
  actual_card: number | null;
  actual_qr: number | null;
  actual_online: number | null;
  actual_contract: number | null;
  cash_difference: number | null;
  non_cash_difference: number | null;
  sold_full_bottles: number;
  collected_empty_bottles: number;
  inventory_configured: boolean;
  expected_full_bottles: number | null;
  expected_empty_bottles: number | null;
  actual_full_bottles: number | null;
  actual_empty_bottles: number | null;
  full_difference: number | null;
  empty_difference: number | null;
  start_mileage: number | null;
  end_mileage: number | null;
  distance_km: number | null;
  status: "open" | "closed";
  was_reopened: boolean;
  discrepancy_reason: string | null;
  notes: string | null;
  closed_at: string | null;
  closed_by_name: string | null;
  reopened_at: string | null;
  reopen_reason: string | null;
  readiness: "closed" | "active_orders" | "inventory_missing" | "ready";
};

export type InventoryMovementRow = {
  id: string;
  work_date: string;
  created_at: string;
  courier_id: string;
  courier_name: string;
  vehicle_plate: string | null;
  event_type: "dispatcher_inventory" | "delivery" | "delivery_correction" | "shift_close" | "manual_adjustment";
  full_bottles_delta: number;
  empty_bottles_delta: number;
  order_number: string | null;
  actor_name: string | null;
  note: string | null;
  metadata: Record<string, unknown>;
};

export type AnalyticsSummary = {
  total_orders: number;
  delivered_orders: number;
  failed_orders: number;
  cancelled_orders: number;
  revenue: number;
  average_order: number;
  full_bottles: number;
  empty_bottles: number;
  unique_clients: number;
  average_rating: number;
  rating_count: number;
  closed_shifts: number;
  shifts_with_discrepancy: number;
};

export type DispatcherAnalytics = {
  date_from: string;
  date_to: string;
  previous_date_from: string;
  previous_date_to: string;
  summary: AnalyticsSummary;
  previous: Pick<AnalyticsSummary, "total_orders" | "delivered_orders" | "failed_orders" | "revenue" | "full_bottles">;
  trend: Array<{ day: string; orders: number; delivered: number; failed: number; revenue: number; full_bottles: number; empty_bottles: number }>;
  payments: Array<{ method: PaymentMethod; orders: number; amount: number }>;
  couriers: Array<{ id: string; display_name: string; total_orders: number; delivered_orders: number; failed_orders: number; revenue: number; full_bottles: number; average_rating: number; rating_count: number }>;
  zones: Array<{ id: string; name: string; color: string; total_orders: number; delivered_orders: number; failed_orders: number; revenue: number }>;
  quality: { missing_coordinates: number; missing_phone: number; without_zone: number; without_courier: number; unconfirmed_payment: number };
};

export type StaffAuditRow = {
  id: string;
  created_at: string;
  actor_name: string;
  actor_role: string | null;
  action: string;
  entity_type: string;
  entity_id: string | null;
  summary: string;
  before_data: Record<string, unknown> | null;
  after_data: Record<string, unknown> | null;
};

export type NotificationOutboxRow = {
  id: string;
  audience: "dispatcher" | "client";
  channel: "panel" | "push" | "sms" | "messenger";
  event_type: string;
  order_id: string | null;
  title: string;
  body: string;
  recipient: string | null;
  status: "ready" | "waiting_provider" | "sent" | "failed" | "cancelled";
  last_error: string | null;
  sent_at: string | null;
  created_at: string;
  orders: Pick<Order, "order_number" | "client_name"> | null;
};

export type GeoJsonPolygon = {
  type: "Polygon";
  coordinates: number[][][];
};

export type DeliveryZone = {
  id: string;
  name: string;
  color: string;
  boundary: GeoJsonPolygon;
  priority: number;
  is_active: boolean;
  customer_order_enabled: boolean;
  auto_expand_enabled: boolean;
  learning_min_deliveries: number;
  learning_lookback_days: number;
  learning_max_distance_m: number;
  learning_radius_m: number;
  last_learning_at: string | null;
  created_at: string;
  updated_at: string;
};

export type DeliveryZoneLearningCandidate = {
  id: string;
  zone_id: string;
  address_text: string;
  lat: number;
  lng: number;
  delivery_count: number;
  distance_m: number;
  status: "observing" | "applied" | "ignored" | "reverted" | "needs_review";
  first_seen_at: string | null;
  last_seen_at: string | null;
  applied_at: string | null;
  ignored_at: string | null;
  reverted_at: string | null;
  last_error: string | null;
};

export type DeliveryZoneLearningCandidateRow = Omit<
  DeliveryZoneLearningCandidate,
  "lat" | "lng" | "distance_m"
> & {
  lat: number | string;
  lng: number | string;
  distance_m: number | string;
};

export type DeliveryCoverage = {
  configured: boolean;
  available: boolean;
  zone_id: string | null;
  zone_name: string | null;
  zone_color: string | null;
};

export type Order = {
  id: string;
  order_number: string;
  assigned_courier_id: string | null;
  delivery_zone_id?: string | null;
  state: OrderState;
  client_name: string;
  client_phone: string | null;
  address: string;
  district: string | null;
  lat: number | null;
  lng: number | null;
  payment_method: PaymentMethod;
  price: number;
  bottles: number;
  marking_codes: Record<string, string[]> | null;
  fiscal_receipt: FiscalReceipt | null;
  client_rating: ClientRating | null;
  client_rating_stats?: ClientRatingStats | null;
  time_slot: string | null;
  delivery_date: string | null;
  delivery_comment: string | null;
  failure_reason: string | null;
  created_at: string;
  updated_at: string;
  couriers?: Pick<Courier, "id" | "display_name"> | null;
  delivery_zones?: Pick<DeliveryZone, "id" | "name" | "color"> | null;
};

export type CourierStats = Courier & {
  ordersToday: number;
  deliveredToday: number;
};

export type CourierDailySalesRow = {
  courier_id: string;
  courier_name: string;
  courier_phone: string | null;
  courier_region: string | null;
  courier_active: boolean;
  vehicle_plate: string | null;
  work_date: string;
  delivered_orders: number;
  active_orders: number;
  failed_orders: number;
  cash_orders: number;
  cash_amount: number;
  card_orders: number;
  card_amount: number;
  qr_orders: number;
  qr_amount: number;
  online_orders: number;
  online_amount: number;
  contract_orders: number;
  contract_amount: number;
  total_amount: number;
  sold_full_bottles: number;
  collected_empty_bottles: number;
  inventory_configured: boolean;
  loaded_full_bottles: number;
  opening_empty_bottles: number;
  unloaded_full_bottles: number;
  unloaded_empty_bottles: number;
  remaining_full_bottles: number | null;
  remaining_empty_bottles: number | null;
  inventory_notes: string | null;
  inventory_updated_at: string | null;
};

export type CourierDailySalesRpcRow = Omit<
  CourierDailySalesRow,
  | "delivered_orders"
  | "active_orders"
  | "failed_orders"
  | "cash_orders"
  | "cash_amount"
  | "card_orders"
  | "card_amount"
  | "qr_orders"
  | "qr_amount"
  | "online_orders"
  | "online_amount"
  | "contract_orders"
  | "contract_amount"
  | "total_amount"
  | "sold_full_bottles"
  | "collected_empty_bottles"
  | "loaded_full_bottles"
  | "opening_empty_bottles"
  | "unloaded_full_bottles"
  | "unloaded_empty_bottles"
  | "remaining_full_bottles"
  | "remaining_empty_bottles"
> & {
  delivered_orders: number | string;
  active_orders: number | string;
  failed_orders: number | string;
  cash_orders: number | string;
  cash_amount: number | string;
  card_orders: number | string;
  card_amount: number | string;
  qr_orders: number | string;
  qr_amount: number | string;
  online_orders: number | string;
  online_amount: number | string;
  contract_orders: number | string;
  contract_amount: number | string;
  total_amount: number | string;
  sold_full_bottles: number | string;
  collected_empty_bottles: number | string;
  loaded_full_bottles: number | string;
  opening_empty_bottles: number | string;
  unloaded_full_bottles: number | string;
  unloaded_empty_bottles: number | string;
  remaining_full_bottles: number | string | null;
  remaining_empty_bottles: number | string | null;
};

export type VehicleServiceStatus = "ready" | "maintenance" | "inactive";

export type VehicleFleetRow = {
  id: string;
  license_plate: string;
  make: string | null;
  model: string | null;
  color: string | null;
  service_status: VehicleServiceStatus;
  notes: string | null;
  current_assignment_id: string | null;
  current_courier_id: string | null;
  current_courier_name: string | null;
  current_courier_phone: string | null;
  assigned_at: string | null;
  created_at: string;
  updated_at: string;
};

export type VehicleAssignmentHistoryRow = {
  id: string;
  vehicle_id: string;
  license_plate: string;
  courier_id: string;
  courier_name: string;
  assigned_by_name: string | null;
  assigned_at: string;
  released_by_name: string | null;
  released_at: string | null;
  assignment_note: string | null;
  release_note: string | null;
};

export type CallDirection = "inbound" | "outbound";

export type CallEvent = {
  id: string;
  provider: string;
  provider_call_id: string | null;
  direction: CallDirection;
  event_type: string;
  order_id: string | null;
  client_phone: string | null;
  client_phone_normalized: string | null;
  dispatcher_profile_id: string | null;
  courier_id: string | null;
  started_at: string | null;
  answered_at: string | null;
  ended_at: string | null;
  duration_seconds: number | null;
  recording_url: string | null;
  payload: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

export type ClientDirectoryRow = {
  key: string;
  legacy_id: string | null;
  name: string;
  phone: string | null;
  email: string | null;
  status: string | null;
  loyalty_points: number;
  tare_debt: number;
  address: string;
  district: string | null;
  order_count: number;
  last_order_number: string | null;
  last_order_at: string;
  rating_average: number | null;
  rating_count: number;
};

export type AddressDirectoryRow = {
  key: string;
  client_name: string;
  client_phone: string | null;
  address: string;
  zone_name: string | null;
  district: string | null;
  lat: number | null;
  lng: number | null;
  order_count: number;
  last_order_at: string;
};

export type OrganizationDirectoryRow = {
  key: string;
  legacy_id: string | null;
  name: string;
  inn: string | null;
  kpp: string | null;
  phone: string | null;
  email: string | null;
  address: string;
  tare_debt: number;
  order_count: number;
  last_order_at: string;
};

export type DataImportHistoryRow = {
  id: string;
  entity_kind: "clients" | "organizations" | "orders";
  status: "processing" | "completed" | "completed_with_errors" | "failed" | "rolled_back";
  source_system: string;
  filename: string;
  total_rows: number;
  imported_rows: number;
  updated_rows: number;
  skipped_rows: number;
  failed_rows: number;
  error_summary: string[];
  created_at: string;
  completed_at: string | null;
  rolled_back_at: string | null;
  rollback_reason: string | null;
  change_count: number;
};

export type OrderEventFeedRow = {
  id: string;
  event_type: string;
  payload: Record<string, unknown>;
  created_at: string;
  orders: Pick<Order, "id" | "order_number" | "client_name" | "address"> | null;
  profiles: Pick<Profile, "full_name"> | null;
};

export type ClientFeedbackRow = {
  id: string;
  rating: number;
  client_phone: string | null;
  created_at: string;
  orders: Pick<Order, "id" | "order_number" | "client_name" | "address"> | null;
  couriers: Pick<Courier, "id" | "display_name"> | null;
};
