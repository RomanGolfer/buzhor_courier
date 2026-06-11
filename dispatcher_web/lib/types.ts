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
};

export type Order = {
  id: string;
  order_number: string;
  assigned_courier_id: string | null;
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
};

export type CourierStats = Courier & {
  ordersToday: number;
  deliveredToday: number;
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
