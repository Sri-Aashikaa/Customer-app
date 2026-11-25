export type DeliveryStatus = 
  | 'SCHEDULED' 
  | 'ASSIGNED' 
  | 'PREPARING' 
  | 'IN_TRANSIT'
  | 'OUT_FOR_DELIVERY' 
  | 'NEAR_CUSTOMER' 
  | 'DELIVERED' 
  | 'FAILED' 
  | 'CANCELLED'
  | 'PAUSED';

export type PaymentStatus = 'PAID' | 'PARTIAL' | 'PENDING' | 'OVERDUE';
export type PaymentMethod = 'CASH' | 'UPI' | 'BANK_TRANSFER' | 'ONLINE';
export type CancellationStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'EXPIRED';
export type CancellationShift = 'MORNING' | 'EVENING' | 'BOTH';

export interface CustomerProfile {
  id: string;
  customer_id: string;
  name: string;
  mobile: string;
  alternate_mobile?: string;
  alt_mobile?: string;
  address: string;
  location: string;
  latitude: number;
  longitude: number;
  pincode: string;
  area: string;
  city: string;
  district: string;
  state: string;
  milk_quantity: number;
  milk_type?: string;
  rate_per_liter?: number;
  monthly_rate?: number;
  payment_period?: string;
  delivery_timing: string;
  assigned_delivery_person_id: string;
  delivery_partner_name: string;
  delivery_partner_mobile: string;
  delivery_partner_photo: string;
  payment_status: PaymentStatus;
  empty_bottles_held?: number;
  bottles_returned?: number;
  is_paused?: boolean;
  paused_until?: string;
  pause_notes?: string;
}

export interface LocationUpdatePayload {
  address: string;
  area: string;
  city: string;
  district?: string;
  state?: string;
  pincode: string;
  latitude: number;
  longitude: number;
}

export interface PartnerInfo {
  name: string;
  phone: string;
  vehicle: string;
  employee_id: string;
  status: string;
}

export interface DepositSummary {
  total_deposit: number;
  paid_deposit: number;
  refund: number;
  balance: number;
}

export interface BottleSummary {
  issued: number;
  returned: number;
  damaged: number;
  lost: number;
}

export interface IceBoxSummary {
  issued: number;
  returned: number;
  damaged: number;
  lost: number;
}

export interface CancellationItem {
  id: string;
  date: string;
  day: string;
  time: string;
  shift?: CancellationShift;
  reason: string;
  status: CancellationStatus;
}

export interface PaymentItem {
  id: string;
  invoice_number: string;
  billing_period: string;
  total_amount: number;
  paid_amount: number;
  pending_amount: number;
  due_date: string;
  payment_method: PaymentMethod;
  status: PaymentStatus;
  invoice_url?: string;
}

export interface DeliveryItem {
  id: string;
  order_id?: string;
  date: string;
  product_name?: string;
  quantity: number;
  total_amount: number;
  status: DeliveryStatus;
  delivery_time?: string;
  notes?: string;
}

export type ComplaintCategory = 
  | 'QUALITY_ISSUE' 
  | 'BOTTLE_ISSUE' 
  | 'FRESHNESS_ISSUE' 
  | 'DELIVERY_DELAY' 
  | 'WRONG_ITEM' 
  | 'BILLING_DISPUTE' 
  | 'OTHER';

export type ComplaintStatus = 
  | 'OPEN' 
  | 'INVESTIGATING' 
  | 'ACTION_TAKEN' 
  | 'RESOLVED' 
  | 'CLOSED';

export interface ComplaintItem {
  id: string;
  ticket_number: string;
  customer_id: string;
  customer_name: string;
  customer_phone?: string;
  customer_email?: string;
  order_id?: string;
  delivery_date?: string;
  milk_product_name?: string;
  category: string;
  issue_subtype?: string;
  title?: string;
  description: string;
  priority: string;
  status: string;
  action_taken?: string;
  action_type?: string;
  refund_amount?: number;
  action_taken_by?: string;
  action_taken_at?: string;
  email_notified_at?: string;
  email_sent_to?: string;
  created_at: string;
  updated_at?: string;
}

export interface RegisterPayload {
  name: string;
  mobile: string;
  alternate_mobile?: string;
  alt_mobile?: string;
  customer_id: string;
  password: string;
  address: string;
  area: string;
  city: string;
  district: string;
  state: string;
  pincode: string;
  latitude: string;
  longitude: string;
  milk_type?: string;
  milk_quantity?: number;
  delivery_timing?: string;
  delivery_frequency?: string;
  delivery_days?: string;
  payment_plan?: string;
  payment_method?: string;
  bottle_size?: string;
  delivery_instructions?: string;
}

export interface CustomerReferralSettings {
  customer_referral_active: boolean;
  customer_referrer_reward_type: string;
  customer_referrer_reward_value: number;
  customer_referee_discount_type: string;
  customer_referee_discount_value: number;
  customer_min_order_litres: number;
  customer_offer_title: string;
  customer_offer_tagline: string;
  customer_offer_terms: string;
  customer_share_message: string;
  app_download_url: string;
}

export interface CustomerReferralRecord {
  id: string;
  referee_name: string;
  referee_phone: string;
  referee_area?: string;
  status: 'PENDING' | 'REGISTERED' | 'QUALIFIED' | 'REWARDED' | 'REJECTED';
  reward_amount: number;
  referee_discount: number;
  created_at: string;
}

export interface SubmitCustomerReferralPayload {
  referrer_id: string;
  referrer_name: string;
  referrer_phone?: string;
  referral_code: string;
  referee_name: string;
  referee_phone: string;
  referee_area?: string;
  notes?: string;
}
