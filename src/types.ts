export type DeliveryStatus = 
  | 'SCHEDULED' 
  | 'ASSIGNED' 
  | 'PREPARING' 
  | 'IN_TRANSIT'
  | 'OUT_FOR_DELIVERY' 
  | 'NEAR_CUSTOMER' 
  | 'DELIVERED' 
  | 'FAILED' 
  | 'CANCELLED';

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
}

export interface DeliveryItem {
  id: string;
  date: string;
  quantity: number;
  total_amount: number;
  status: DeliveryStatus;
  delivery_time?: string;
  notes?: string;
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
  milk_quantity?: number;
  delivery_timing?: string;
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
