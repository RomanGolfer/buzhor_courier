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

export type Profile = {
  id: string;
  role: Role;
  full_name: string | null;
  phone: string | null;
  is_active: boolean;
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
  time_slot: string | null;
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
