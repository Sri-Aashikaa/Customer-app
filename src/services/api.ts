import { supabase } from './supabase';
import { SecurityUtils } from './security';

const isUuidString = (val?: string | null): boolean =>
  Boolean(val && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(val.trim()));

const buildCustomerLookupOr = (cleanDigits: string, safeId: string): string => {
  const filters: string[] = [];
  if (cleanDigits.length >= 10) {
    filters.push(`mobile.eq.${cleanDigits}`, `phone.eq.${cleanDigits}`);
  }
  if (safeId) {
    filters.push(`customer_id.eq.${safeId}`);
    if (isUuidString(safeId)) filters.push(`id.eq.${safeId}`);
  }
  return filters.join(',') || 'customer_id.eq.__none__';
};
import {
  CustomerProfile, PaymentItem, CancellationItem, DeliveryItem, PartnerInfo,
  RegisterPayload, LocationUpdatePayload, CustomerReferralSettings, CustomerReferralRecord,
  SubmitCustomerReferralPayload, ComplaintItem
} from '../types';

export const DEFAULT_CUSTOMER_REFERRAL_SETTINGS: CustomerReferralSettings = {
  customer_referral_active: true,
  customer_referrer_reward_type: 'WALLET',
  customer_referrer_reward_value: 100,
  customer_referee_discount_type: 'FLAT',
  customer_referee_discount_value: 50,
  customer_min_order_litres: 15,
  customer_offer_title: 'Refer a Neighbor & Earn ₹100',
  customer_offer_tagline: 'Give ₹50 off, get ₹100 Milk Wallet credit on their first subscription!',
  customer_offer_terms: 'Reward credited automatically after your friend completes their first 7 days of daily raw milk delivery.',
  customer_share_message: '🥛 Try pure farm fresh raw cow milk from Sri Aashikaa! Use my referral code {code} to get ₹{discount} OFF on your first subscription. Order now: {link}',
  app_download_url: 'https://amudhammilk.com/downloads/amudham-customer-app.apk',
};

export function getBatchCode(batchIndex: number): string {
  let s = '';
  let n = batchIndex;
  while (n >= 0) {
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = Math.floor(n / 26) - 1;
  }
  return s;
}

export function formatBatchCustomerId(index: number): string {
  const batchIndex = Math.floor(index / 1000);
  const numInBatch = (index % 1000) + 1;
  const batchCode = getBatchCode(batchIndex);
  const formattedNum = String(numInBatch).padStart(3, '0');
  return `AMU-${batchCode}${formattedNum}`;
}

export async function getNextAmuCustomerId(): Promise<string> {
  try {
    const { data: latest } = await supabase
      .from('customers')
      .select('customer_id')
      .ilike('customer_id', 'AMU-%')
      .order('customer_id', { ascending: false })
      .limit(100);

    let maxSeq = 0;
    const regex = /^AMU-([A-Z]+)(\d+)$/i;
    for (const rec of latest || []) {
      const match = (rec.customer_id || '').match(regex);
      if (match) {
        const code = match[1].toUpperCase();
        const num = parseInt(match[2], 10);
        let batchIdx = 0;
        for (let i = 0; i < code.length; i++) {
          batchIdx = batchIdx * 26 + (code.charCodeAt(i) - 64);
        }
        batchIdx -= 1;
        const seq = batchIdx * 1000 + num;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    const { count } = await supabase.from('customers').select('*', { count: 'exact', head: true });
    const target = Math.max(maxSeq, count || 0);
    return formatBatchCustomerId(target);
  } catch {
    return 'AMU-A001';
  }
}

/**
 * Production Server API Service for Customer Application
 */
export const ServerAPI = {
  /**
   * Authenticate customer with Supabase database
   */
  async loginCustomer(loginId: string, passwordInput: string): Promise<{ success: boolean; data?: CustomerProfile; message?: string }> {
    try {
      const cleanDigits = SecurityUtils.sanitizeMobileDigits(loginId);
      const safeId = SecurityUtils.sanitizePostgrestParam(loginId);

      if (cleanDigits.length < 10 && !safeId) {
        return { success: false, message: 'Please enter a valid 10-digit Mobile Number or Customer ID.' };
      }

      // 0. Check Login Rate Limit / Brute-force Lockout
      const lockout = SecurityUtils.rateLimiter.checkLockout(cleanDigits || safeId);
      if (lockout.isLocked) {
        return {
          success: false,
          message: `Too many failed login attempts. Account temporarily locked for security. Please try again in ${lockout.remainingSeconds} seconds.`
        };
      }

      const query = supabase
        .from('customers')
        .select('*')
        .or(buildCustomerLookupOr(cleanDigits, safeId));

      const { data, error } = await query;

      if (error) {
        return { success: false, message: `Authentication error: ${error.message}` };
      }

      if (!data || data.length === 0) {
        return { success: false, message: `No customer account found with ID or Mobile Number "${loginId}".` };
      }

      const user = data[0];
      const status = (user.status || user.account_status || '').toUpperCase();
      if (status === 'DELETED' || status === 'INACTIVE' || status === 'SUSPENDED') {
        return { success: false, message: 'This account has been deleted or deactivated. You cannot log in.' };
      }

      // Cryptographic Password Verification
      const isPasswordValid = SecurityUtils.verifyPassword(passwordInput, user.password);
      if (!isPasswordValid) {
        SecurityUtils.rateLimiter.recordFailedAttempt(cleanDigits || safeId);
        return { success: false, message: 'Invalid password. Please check your credentials and try again.' };
      }

      // Password verified successfully: clear failure counts
      SecurityUtils.rateLimiter.recordSuccessfulLogin(cleanDigits || safeId);

      // Upgrade legacy plaintext password to salted SHA-256 hash automatically
      if (SecurityUtils.isLegacyPlaintext(user.password)) {
        try {
          const secureHash = SecurityUtils.hashPassword(passwordInput);
          await supabase.from('customers').update({ password: secureHash }).eq('id', user.id);
        } catch (_) {}
      }

      const qty = Number(user.milk_quantity) || 1.5;

      const profile: CustomerProfile = {
        id: user.id,
        customer_id: user.customer_id || user.id,
        name: user.name || 'Valued Customer',
        mobile: user.mobile || cleanDigits,
        address: user.address || '',
        location: user.location || 'Chennai, Tamil Nadu',
        latitude: Number(user.latitude) || 13.0827,
        longitude: Number(user.longitude) || 80.2707,
        pincode: user.pincode || '600040',
        area: user.location ? user.location.split(',')[0].trim() : 'Anna Nagar',
        city: user.location ? (user.location.split(',')[1] || 'Chennai').trim() : 'Chennai',
        district: user.district || 'Chennai',
        state: user.state || 'Tamil Nadu',
        milk_quantity: qty,
        milk_type: user.milk_type || 'Pure Farm Fresh Raw Cow Milk (A2)',
        monthly_rate: user.monthly_rate || Math.round(qty * 65 * 30),
        delivery_timing: user.delivery_timing || '5:00 AM - 9:30 AM',
        assigned_delivery_person_id: user.assigned_delivery_person_id || '',
        delivery_partner_name: user.delivery_partner_name || 'Delivery Partner',
        delivery_partner_mobile: user.delivery_partner_mobile || '',
        delivery_partner_photo: user.delivery_partner_photo || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        payment_status: user.payment_status === 'PAID' ? 'PAID' : 'PENDING',
        is_paused: Boolean(user.is_paused),
        paused_until: user.paused_until || undefined,
        pause_notes: user.pause_notes || undefined
      };

      return { success: true, data: profile };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Failed to connect to server.' };
    }
  },

  /**
   * Register a new customer in Supabase database
   */
  async registerCustomer(payload: RegisterPayload): Promise<{ success: boolean; data?: CustomerProfile; message?: string }> {
    try {
      let assignedId = SecurityUtils.sanitizePostgrestParam((payload.customer_id || '').toUpperCase());
      if (!assignedId || !assignedId.startsWith('AMU-')) {
        assignedId = await getNextAmuCustomerId();
      }
      const cleanDigits = SecurityUtils.sanitizeMobileDigits(payload.mobile);
      if (!cleanDigits || cleanDigits.length < 10) {
        return { success: false, message: 'A valid 10-digit mobile number is required.' };
      }
      if (!payload.password || payload.password.trim().length < 6) {
        return { success: false, message: 'Password must be at least 6 characters long.' };
      }

      // 1. Check duplicate mobile number
      const { data: existingMobile } = await supabase
        .from('customers')
        .select('id, mobile')
        .or(`mobile.eq.${cleanDigits},phone.eq.${cleanDigits}`)
        .limit(1);

      if (existingMobile && existingMobile.length > 0) {
        return { success: false, message: `Mobile number "${cleanDigits}" is already registered. Please login.` };
      }

      // 2. Check duplicate customer_id
      const { data: existingId } = await supabase
        .from('customers')
        .select('id')
        .eq('customer_id', assignedId);

      if (existingId && existingId.length > 0) {
        return { success: false, message: `Customer ID "${assignedId}" is already taken.` };
      }

      // 3. Insert into customers table with Salted SHA-256 password hash
      const qty = payload.milk_quantity !== undefined ? Number(payload.milk_quantity) : 1.0;
      const milkType = payload.milk_type || 'Pure Fresh Cow Milk';
      const timing = payload.delivery_timing || 'Morning Shift';
      const frequency = payload.delivery_frequency || 'Daily Delivery';
      const paymentPlan = payload.payment_plan || 'Monthly Postpaid';
      const area = payload.area || 'Salem Central';
      const city = payload.city || 'Salem';
      const pincode = payload.pincode || '636004';
      const rate = milkType.toLowerCase().includes('buffalo') ? 80 : 65;
      const monthlyRate = Math.round(qty * rate * 30);
      const altMobile = SecurityUtils.sanitizeMobileDigits(payload.alternate_mobile || payload.alt_mobile || '');
      const securePasswordHash = SecurityUtils.hashPassword(payload.password);

      const custPayload: Record<string, any> = {
        customer_id: assignedId,
        name: SecurityUtils.sanitizeText(payload.name),
        mobile: cleanDigits,
        phone: cleanDigits,
        password: securePasswordHash,
        address: SecurityUtils.sanitizeText(payload.address),
        location: `${SecurityUtils.sanitizeText(area)}, ${SecurityUtils.sanitizeText(city)}`,
        area: SecurityUtils.sanitizeText(area),
        city: SecurityUtils.sanitizeText(city),
        pincode: SecurityUtils.sanitizeText(pincode),
        latitude: parseFloat(payload.latitude) || 11.6643,
        longitude: parseFloat(payload.longitude) || 78.1460,
        milk_type: milkType,
        milk_quantity: qty,
        delivery_timing: timing,
        delivery_days: frequency,
        subscription_plan: 'Daily Subscription',
        payment_plan: paymentPlan,
        payment_status: 'PENDING',
        account_status: 'ACTIVE',
        is_active: true,
        is_paid: false,
        monthly_rate: monthlyRate,
        empty_bottles_held: 2,
        bottles_returned: 0
      };

      if (altMobile) {
        custPayload.alternate_mobile = altMobile;
        custPayload.alt_mobile = altMobile;
      }

      let { data: insertedCust, error: insertErr } = await supabase
        .from('customers')
        .insert(custPayload)
        .select()
        .single();

      if (insertErr && (insertErr.message.includes('alternate_mobile') || insertErr.message.includes('alt_mobile'))) {
        delete custPayload.alternate_mobile;
        delete custPayload.alt_mobile;
        const res = await supabase.from('customers').insert(custPayload).select().single();
        insertedCust = res.data;
        insertErr = res.error;
      }

      if (insertErr || !insertedCust) {
        return { success: false, message: insertErr?.message || 'Failed to insert customer' };
      }

      const customerId = insertedCust.id;

      // 4. Insert customer_locations
      try {
        await supabase.from('customer_locations').insert({
          customer_id: customerId,
          address: payload.address.trim(),
          pincode: pincode,
          area: area,
          city: city,
          district: 'Salem',
          state: 'Tamil Nadu',
          latitude: parseFloat(payload.latitude) || 11.6643,
          longitude: parseFloat(payload.longitude) || 78.1460,
          is_primary: true
        });
      } catch (_) {}

      // 5. Insert initial subscription into customer_subscriptions
      try {
        await supabase.from('customer_subscriptions').insert({
          customer_id: assignedId,
          plan_name: 'Daily Subscription',
          quantity: qty,
          daily_quantity: qty,
          frequency: frequency,
          delivery_days: frequency,
          timing_slot: timing,
          billing_cycle: paymentPlan,
          status: 'ACTIVE',
          start_date: new Date().toISOString().split('T')[0]
        });
      } catch (_) {}

      // 6. Create initial order in orders table so Admin Panel Orders Master displays it
      try {
        const todayDate = new Date().toISOString().split('T')[0];
        const tmrw = new Date();
        tmrw.setDate(tmrw.getDate() + 1);
        const tmrwDate = tmrw.toISOString().split('T')[0];

        await supabase.from('orders').insert({
          id: `ord-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
          order_number: `ORD-${Date.now().toString().slice(-6)}`,
          customer_id: assignedId,
          customer_name: payload.name.trim(),
          mobile: cleanDigits,
          address: payload.address.trim(),
          location: `${area}, ${city}`,
          area: area,
          route_name: 'Salem Morning Route 1',
          milk_product_id: milkType.toLowerCase().includes('buffalo') ? 'prod-buffalo' : 'prod-cow',
          milk_product_name: milkType,
          quantity: qty,
          quantity_liters: qty,
          rate_per_liter: rate,
          total_amount: Math.round(qty * rate),
          delivery_timing: timing,
          subscription_plan: 'Daily Subscription',
          order_date: todayDate,
          scheduled_date: tmrwDate,
          order_status: 'PENDING',
          delivery_status: 'SCHEDULED',
          payment_status: 'PENDING',
          notes: `New customer subscription created via Customer Mobile App. Preferred Plan: ${paymentPlan}. Drop: ${payload.delivery_instructions || 'Doorstep'}`
        });
      } catch (_) {}

      const profile: CustomerProfile = {
        id: customerId,
        customer_id: assignedId,
        name: payload.name.trim(),
        mobile: cleanDigits,
        alternate_mobile: altMobile,
        alt_mobile: altMobile,
        address: payload.address.trim(),
        location: `${area}, ${city}`,
        latitude: parseFloat(payload.latitude) || 11.6643,
        longitude: parseFloat(payload.longitude) || 78.1460,
        pincode: pincode,
        area: area,
        city: city,
        district: 'Salem',
        state: 'Tamil Nadu',
        milk_quantity: qty,
        milk_type: milkType,
        monthly_rate: monthlyRate,
        delivery_timing: timing,
        assigned_delivery_person_id: '',
        delivery_partner_name: 'Unassigned (Auto Allocation Pending)',
        delivery_partner_mobile: '',
        delivery_partner_photo: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        payment_status: 'PAID'
      };

      return { success: true, data: profile };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Registration failed.' };
    }
  },

  /**
   * Reset password by Customer ID or Mobile (Forgot Password Flow)
   */
  async resetPasswordByMobile(mobileOrId: string, newPassword: string): Promise<{ success: boolean; message?: string }> {
    try {
      const cleanInput = mobileOrId.trim();
      const cleanDigits = SecurityUtils.sanitizeMobileDigits(cleanInput);
      const safeId = SecurityUtils.sanitizePostgrestParam(cleanInput);

      if (cleanDigits.length < 10 && !safeId) {
        return { success: false, message: 'Valid 10-digit mobile number or Customer ID is required.' };
      }
      if (!newPassword || newPassword.trim().length < 6) {
        return { success: false, message: 'Password must be at least 6 characters long.' };
      }

      const query = supabase
        .from('customers')
        .select('id')
        .or(buildCustomerLookupOr(cleanDigits, safeId));

      const { data, error } = await query;
      if (error || !data || data.length === 0) {
        return { success: false, message: `No account matching "${cleanInput}" found.` };
      }

      const userId = data[0].id;
      const securePasswordHash = SecurityUtils.hashPassword(newPassword.trim());
      const { error: updateErr } = await supabase
        .from('customers')
        .update({ password: securePasswordHash })
        .eq('id', userId);

      if (updateErr) {
        return { success: false, message: `Failed to update password: ${updateErr.message}` };
      }

      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Password reset error.' };
    }
  },

  /**
   * Update password for an authenticated customer
   */
  async updatePassword(customerId: string, oldPassword: string, newPassword: string): Promise<{ success: boolean; message?: string }> {
    try {
      const safeCustId = SecurityUtils.sanitizePostgrestParam(customerId);
      if (!safeCustId) {
        return { success: false, message: 'Invalid customer identifier.' };
      }
      if (!newPassword || newPassword.trim().length < 6) {
        return { success: false, message: 'New password must be at least 6 characters long.' };
      }

      const { data, error } = await supabase
        .from('customers')
        .select('password')
        .eq('id', safeCustId)
        .single();

      if (error || !data) {
        return { success: false, message: 'Could not fetch customer credentials.' };
      }

      const isValidOld = SecurityUtils.verifyPassword(oldPassword, data.password);
      if (!isValidOld) {
        return { success: false, message: 'Current password is incorrect.' };
      }

      const securePasswordHash = SecurityUtils.hashPassword(newPassword.trim());
      const { error: updateErr } = await supabase
        .from('customers')
        .update({ password: securePasswordHash })
        .eq('id', safeCustId);

      if (updateErr) {
        return { success: false, message: updateErr.message };
      }

      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Failed to update password.' };
    }
  },

  /**
   * Update detailed customer location (Address, Area, City, Pincode, Lat, Lng)
   */
  async updateCustomerLocation(customerId: string, payload: LocationUpdatePayload): Promise<{ success: boolean; message?: string }> {
    try {
      const locString = `${payload.area}, ${payload.city}`;
      const { error } = await supabase
        .from('customers')
        .update({
          address: payload.address,
          location: locString,
          pincode: payload.pincode,
          latitude: payload.latitude,
          longitude: payload.longitude,
        })
        .eq('id', customerId);

      if (error) {
        return { success: false, message: error.message };
      }

      // Also upsert/insert into customer_locations table
      try {
        await supabase.from('customer_locations').insert({
          customer_id: customerId,
          address: payload.address,
          pincode: payload.pincode,
          area: payload.area,
          city: payload.city,
          district: payload.district || 'Chennai',
          state: payload.state || 'Tamil Nadu',
          latitude: payload.latitude,
          longitude: payload.longitude,
          is_primary: true
        });
      } catch (_) {}

      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Location update failed.' };
    }
  },

  /**
   * Fetch Delivery Partner details from employees table in Supabase
   */
  async fetchPartnerDetails(partnerId: string): Promise<PartnerInfo | null> {
    const safePartnerId = SecurityUtils.sanitizePostgrestParam(partnerId);
    if (!safePartnerId) return null;
    try {
      const { data } = await supabase
        .from('employees')
        .select('*')
        .or(`id.eq.${safePartnerId},employee_id.eq.${safePartnerId}`)
        .maybeSingle();

      if (data) {
        return {
          name: data.name || 'Delivery Partner',
          phone: data.mobile || '',
          vehicle: data.vehicle_number || 'Vehicle Assigned',
          employee_id: data.employee_id || data.id,
          status: data.status || 'Active'
        };
      }
    } catch (err) {
      console.log('Error fetching partner details:', err);
    }
    return null;
  },

  /**
   * Helper to resolve all customer IDs for a customer / mobile
   */
  async resolveCustomerIds(customerId: string, mobile?: string): Promise<string[]> {
    const ids = new Set<string>();
    const safeCustId = SecurityUtils.sanitizePostgrestParam(customerId);
    if (safeCustId) ids.add(safeCustId);

    const cleanDigits = SecurityUtils.sanitizeMobileDigits(mobile);
    if (cleanDigits.length >= 10) {
      try {
        const { data } = await supabase
          .from('customers')
          .select('id, customer_id')
          .or(`mobile.eq.${cleanDigits},phone.eq.${cleanDigits}`);
        (data || []).forEach((c: any) => {
          if (c.id) ids.add(c.id);
          if (c.customer_id) ids.add(c.customer_id);
        });
      } catch (_) {}
    }
    return Array.from(ids);
  },

  /**
   * Fetch Enterprise Settings from enterprise_settings table in Supabase
   */
  async fetchEnterpriseSettings(): Promise<any | null> {
    try {
      // 1. Prioritize primary_enterprise_config
      const { data: primary } = await supabase
        .from('enterprise_settings')
        .select('*')
        .eq('id', 'primary_enterprise_config')
        .single();
      if (primary) {
        return {
          ...primary,
          office_latitude: primary.office_latitude !== undefined && primary.office_latitude !== null ? Number(primary.office_latitude) : 11.664325,
          office_longitude: primary.office_longitude !== undefined && primary.office_longitude !== null ? Number(primary.office_longitude) : 78.146014,
          google_maps_url: primary.google_maps_url || 'https://maps.google.com/?q=11.664325,78.146014'
        };
      }

      // 2. Try sri_aashikaa_website_config
      const { data: webConfig } = await supabase
        .from('enterprise_settings')
        .select('*')
        .eq('id', 'sri_aashikaa_website_config')
        .single();
      if (webConfig) {
        return {
          ...webConfig,
          office_latitude: webConfig.office_latitude !== undefined && webConfig.office_latitude !== null ? Number(webConfig.office_latitude) : 11.664325,
          office_longitude: webConfig.office_longitude !== undefined && webConfig.office_longitude !== null ? Number(webConfig.office_longitude) : 78.146014,
          google_maps_url: webConfig.google_maps_url || 'https://maps.google.com/?q=11.664325,78.146014'
        };
      }

      // 3. Fallback to any row with head_office_address or ordered by updated_at
      const { data } = await supabase
        .from('enterprise_settings')
        .select('*')
        .not('head_office_address', 'is', null)
        .order('updated_at', { ascending: false })
        .limit(1);
      if (data && data.length > 0) {
        return {
          ...data[0],
          office_latitude: data[0].office_latitude !== undefined && data[0].office_latitude !== null ? Number(data[0].office_latitude) : 11.664325,
          office_longitude: data[0].office_longitude !== undefined && data[0].office_longitude !== null ? Number(data[0].office_longitude) : 78.146014,
          google_maps_url: data[0].google_maps_url || 'https://maps.google.com/?q=11.664325,78.146014'
        };
      }
    } catch (err) {
      console.log('Error fetching enterprise_settings:', err);
    }

    return {
      company_name: 'SRI AASHIKAA MILKS',
      support_phone: '+91 98765 43210',
      secondary_phone: '+91 94432 10987',
      support_email: 'contact@sriaashikaa.com',
      head_office_address: 'Plot 42, Dairy Tech Park, Salem / Erode Highway, Tamil Nadu',
      branch_address: 'Salem Central Hub, 4-A Meyyanur Bypass, Salem - 636004',
      office_latitude: 11.664325,
      office_longitude: 78.146014,
      google_maps_url: 'https://maps.google.com/?q=11.664325,78.146014',
      website_url: 'https://sriaashikaa.com',
    };
  },

  /**
   * Fetch Payment history for customer from Supabase payments table
   */
  async fetchCustomerPayments(customerId: string, mobile?: string): Promise<PaymentItem[]> {
    try {
      const ids = await this.resolveCustomerIds(customerId, mobile);
      const query = ids.length > 0
        ? supabase.from('payments').select('*').in('customer_id', ids).order('created_at', { ascending: false })
        : supabase.from('payments').select('*').eq('customer_id', customerId).order('created_at', { ascending: false });

      const { data } = await query;

      if (data && data.length > 0) {
        return data.map((p) => ({
          id: p.id,
          invoice_number: p.invoice_number || p.reference_number || p.id,
          billing_period: p.billing_period || 'Subscription Bill',
          total_amount: Number(p.total_amount) || 0,
          paid_amount: Number(p.paid_amount) || 0,
          pending_amount: Number(p.pending_amount) || 0,
          due_date: p.payment_date || (p.created_at ? new Date(p.created_at).toISOString().split('T')[0] : ''),
          payment_method: (p.payment_method as any) || 'UPI',
          status: p.payment_status === 'PAID' ? 'PAID' : 'PENDING',
          invoice_url: p.invoice_url || undefined
        }));
      }
    } catch (err) {
      console.log('Error fetching payments:', err);
    }
    return [];
  },

  /**
   * Fetch Customer Assets (glass_bottles, ice_boxes, deposits, allocations)
   */
  async fetchCustomerAssets(customerId: string, mobile?: string): Promise<{
    bottles: any[];
    iceBoxes: any[];
    deposits: any[];
    bottleAlloc?: any;
    iceBoxAlloc?: any;
  }> {
    try {
      const ids = await this.resolveCustomerIds(customerId, mobile);
      const [
        { data: bottles },
        { data: iceBoxes },
        { data: deposits },
        { data: bAlloc },
        { data: ibAlloc }
      ] = await Promise.all([
        supabase.from('glass_bottles').select('*').in('assigned_customer_id', ids),
        supabase.from('ice_boxes').select('*').in('assigned_customer_id', ids),
        supabase.from('deposits').select('*').in('customer_id', ids),
        supabase.from('bottle_allocations').select('*').in('customer_id', ids),
        supabase.from('ice_box_allocations').select('*').in('customer_id', ids)
      ]);

      return {
        bottles: bottles || [],
        iceBoxes: iceBoxes || [],
        deposits: deposits || [],
        bottleAlloc: (bAlloc && bAlloc.length > 0) ? bAlloc[0] : null,
        iceBoxAlloc: (ibAlloc && ibAlloc.length > 0) ? ibAlloc[0] : null
      };
    } catch (err) {
      console.log('Error fetching customer assets:', err);
      return { bottles: [], iceBoxes: [], deposits: [] };
    }
  },

  /**
   * Submit payment transaction to Supabase
   */
  async processPayment(customerId: string, amount: number): Promise<{ success: boolean; ref?: string; message?: string }> {
    try {
      const now = new Date();
      const ym = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}`;
      const payId = `INV-${ym}-${Math.floor(10000 + Math.random() * 90000)}`;
      const upiRef = `UPI-${Math.floor(100000000000 + Math.random() * 900000000000)}`;

      const { error } = await supabase.from('payments').insert({
        customer_id: customerId,
        invoice_number: payId,
        billing_period: 'Monthly Milk Subscription Payment',
        total_milk_amount: amount,
        other_charges: 0.00,
        discount: 0.00,
        total_amount: amount,
        paid_amount: amount,
        pending_amount: 0.00,
        payment_method: 'UPI',
        payment_status: 'PAID',
        reference_number: upiRef
      });

      if (error) {
        return { success: false, message: error.message };
      }

      await supabase
        .from('customers')
        .update({ payment_status: 'PAID' })
        .eq('id', customerId);

      return { success: true, ref: upiRef };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Payment processing failed.' };
    }
  },

  /**
   * Update Customer Profile on Supabase
   */
  async updateProfile(customerId: string, name: string, mobile: string, address: string, alternateMobile?: string): Promise<{ success: boolean; message?: string }> {
    try {
      const safeCustId = SecurityUtils.sanitizePostgrestParam(customerId);
      if (!safeCustId) {
        return { success: false, message: 'Invalid customer identifier.' };
      }
      const cleanName = SecurityUtils.sanitizeText(name, 100);
      const cleanMobile = SecurityUtils.sanitizeMobileDigits(mobile);
      const cleanAddress = SecurityUtils.sanitizeText(address, 300);
      const cleanAltMobile = alternateMobile ? SecurityUtils.sanitizeMobileDigits(alternateMobile) : undefined;

      if (cleanMobile.length < 10) {
        return { success: false, message: 'A valid 10-digit mobile number is required.' };
      }

      const updateData: Record<string, any> = {
        name: cleanName,
        mobile: cleanMobile,
        phone: cleanMobile,
        address: cleanAddress,
      };
      if (cleanAltMobile) {
        updateData.alternate_mobile = cleanAltMobile;
        updateData.alt_mobile = cleanAltMobile;
      }

      let { error } = await supabase
        .from('customers')
        .update(updateData)
        .eq('id', safeCustId);

      if (error && (error.message.includes('alternate_mobile') || error.message.includes('alt_mobile'))) {
        delete updateData.alternate_mobile;
        delete updateData.alt_mobile;
        const res = await supabase.from('customers').update(updateData).eq('id', safeCustId);
        error = res.error;
      }

      if (error) {
        return { success: false, message: error.message };
      }
      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Profile update failed.' };
    }
  },

  /**
   * Request a milk cancellation on Supabase
   */
  async requestCancellation(customerId: string, cancellationDate: string, reason: string): Promise<{ success: boolean; data?: CancellationItem; message?: string }> {
    try {
      const safeCustId = SecurityUtils.sanitizePostgrestParam(customerId);
      if (!safeCustId) {
        return { success: false, message: 'Invalid customer identifier.' };
      }
      const cleanReason = SecurityUtils.sanitizeText(reason, 250);

      const { data, error } = await supabase
        .from('cancellation_requests')
        .insert({
          customer_id: safeCustId,
          cancellation_date: cancellationDate,
          reason: cleanReason,
          approval_status: 'REQUESTED'
        })
        .select()
        .single();

      if (error) {
        return { success: false, message: error.message };
      }

      const item: CancellationItem = {
        id: data.id,
        date: data.cancellation_date,
        day: new Date(data.cancellation_date).toLocaleDateString('en-US', { weekday: 'long' }),
        time: '5:00 AM - 9:30 AM',
        reason: data.reason || reason,
        status: data.approval_status === 'APPROVED' ? 'APPROVED' : 'PENDING'
      };

      return { success: true, data: item };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Cancellation request failed.' };
    }
  },

  /**
   * Fetch customer cancellations from Supabase
   */
  async fetchCancellations(customerId: string): Promise<CancellationItem[]> {
    try {
      const { data } = await supabase
        .from('cancellation_requests')
        .select('*')
        .eq('customer_id', customerId)
        .order('created_at', { ascending: false });

      if (data && data.length > 0) {
        return data.map((item) => ({
          id: item.id,
          date: item.cancellation_date,
          day: item.cancellation_date ? new Date(item.cancellation_date).toLocaleDateString('en-US', { weekday: 'long' }) : 'Scheduled Day',
          time: item.start_time || '5:00 AM - 9:30 AM',
          reason: item.reason || 'No reason specified',
          status: item.approval_status === 'APPROVED' ? 'APPROVED' : 'PENDING'
        }));
      }
    } catch (err) {
      console.log('Error fetching cancellations:', err);
    }
    return [];
  },

  /**
   * Fetch customer delivery/order list from Supabase deliveries & assignments table
   */
  async fetchCustomerDeliveries(customerId: string, mobile?: string): Promise<DeliveryItem[]> {
    try {
      const todayStr = new Date().toISOString().split('T')[0];
      const items: DeliveryItem[] = [];
      const ids = await this.resolveCustomerIds(customerId, mobile);
      const cleanDigits = SecurityUtils.sanitizeMobileDigits(mobile);

      // 1. Fetch historical and today deliveries
      let query = supabase.from('deliveries').select('*');
      if (ids.length > 0 && cleanDigits.length >= 10) {
        query = query.or(`customer_id.in.(${ids.join(',')}),mobile.eq.${cleanDigits}`);
      } else if (ids.length > 0) {
        query = query.in('customer_id', ids);
      } else if (cleanDigits.length >= 10) {
        query = query.eq('mobile', cleanDigits);
      } else {
        query = query.eq('customer_id', customerId);
      }

      const { data } = await query.order('delivery_date', { ascending: false });

      if (data && data.length > 0) {
        items.push(...data.map((d: any) => ({
          id: d.id,
          order_id: d.order_id || d.order_number || d.id,
          product_name: d.product_name || d.milk_product || 'Pure Farm Fresh Raw Cow Milk',
          date: d.delivery_date || (d.created_at ? d.created_at.split('T')[0] : ''),
          quantity: Number(d.quantity) || 1.0,
          total_amount: Number(d.total_amount) || (Number(d.quantity) * 65),
          status: (d.delivery_status?.toUpperCase() as any) || 'SCHEDULED',
          delivery_time: d.delivery_time || '6:30 AM',
          notes: d.notes || ''
        })));
      }

      // 2. If no delivery recorded for today, check active delivery_assignments
      const hasToday = items.some(i => i.date === todayStr);
      if (!hasToday) {
        try {
          const { data: assignData } = await supabase
            .from('delivery_assignments')
            .select('*')
            .eq('customer_id', customerId)
            .eq('assigned_date', todayStr)
            .eq('is_active', true)
            .limit(1);

          if (assignData && assignData.length > 0) {
            items.unshift({
              id: assignData[0].id,
              date: todayStr,
              quantity: 1.5,
              total_amount: 97.5,
              status: 'OUT_FOR_DELIVERY',
              delivery_time: 'Out for delivery',
              notes: 'Delivery ride started by partner'
            });
          }
        } catch (_) {}
      }

      return items;
    } catch (err) {
      console.log('Error fetching deliveries:', err);
    }
    return [];
  },

  /**
   * Check app release version from Supabase enterprise_settings
   */
  async checkAppUpdate(): Promise<{
    hasUpdate: boolean;
    currentVersion: string;
    latestVersion: string;
    updateUrl: string;
    releaseNotes: string;
    forceUpdate: boolean;
  }> {
    const currentVersion = '1.0.1';
    try {
      const { data } = await supabase
        .from('enterprise_settings')
        .select('*')
        .limit(1)
        .maybeSingle();

      if (data) {
        const latestVersion = (data.latest_app_version || data.app_version || '1.0.1').toString().trim();
        const updateUrl = (data.app_update_url || data.website_url || 'https://amudhammilk.com').toString().trim();
        const releaseNotes = (data.app_release_notes || 'Performance improvements and bug fixes.').toString();
        const forceUpdate = data.force_update === true;

        const hasUpdate = latestVersion !== currentVersion;
        return {
          hasUpdate,
          currentVersion,
          latestVersion,
          updateUrl,
          releaseNotes,
          forceUpdate,
        };
      }
    } catch (err) {
      console.log('Error checking app update:', err);
    }

    return {
      hasUpdate: false,
      currentVersion,
      latestVersion: currentVersion,
      updateUrl: '',
      releaseNotes: '',
      forceUpdate: false,
    };
  },

  /**
   * Check if customer has outstanding pending payments/dues
   */
  async checkCustomerPendingDues(customerId: string): Promise<{ hasPendingDues: boolean; pendingAmount: number }> {
    try {
      const { data: payments } = await supabase
        .from('payments')
        .select('*')
        .eq('customer_id', customerId);

      let pendingTotal = 0;
      if (payments && payments.length > 0) {
        for (const p of payments) {
          const status = (p.payment_status || p.status || '').toUpperCase();
          const pendingAmt = Number(p.pending_amount) || 0;
          if (status === 'PENDING' || status === 'OVERDUE') {
            const tot = Number(p.total_amount) || 0;
            const paid = Number(p.paid_amount) || 0;
            const diff = tot - paid;
            pendingTotal += pendingAmt > 0 ? pendingAmt : (diff > 0 ? diff : tot);
          } else if (pendingAmt > 0) {
            pendingTotal += pendingAmt;
          }
        }
      }
      return { hasPendingDues: pendingTotal > 0, pendingAmount: pendingTotal };
    } catch (err) {
      console.log('Error checking pending dues:', err);
      return { hasPendingDues: false, pendingAmount: 0 };
    }
  },

  /**
   * Permanently delete / deactivate customer account
   */
  async deleteCustomerAccount(customerId: string): Promise<boolean> {
    try {
      await supabase.from('customer_subscriptions').update({ status: 'CANCELLED' }).eq('customer_id', customerId);
      await supabase.from('cancellation_requests').update({ approval_status: 'CANCELLED' }).eq('customer_id', customerId);
      const { error: delErr } = await supabase.from('customers').update({
        status: 'DELETED',
        account_status: 'DELETED',
        password: `DELETED_${Date.now()}`,
        is_paid: false,
        updated_at: new Date().toISOString(),
      }).eq('id', customerId);

      if (delErr) {
        // Fallback if 'DELETED' is not in database enum
        await supabase.from('customers').update({
          status: 'SUSPENDED',
          account_status: 'SUSPENDED',
          password: `DELETED_${Date.now()}`,
          is_paid: false,
          updated_at: new Date().toISOString(),
        }).eq('id', customerId);
      }
      return true;
    } catch (err) {
      console.log('Error deleting customer account:', err);
      return false;
    }
  },

  /**
   * Fetch live Referral Settings & Offers from Supabase server
   */
  async fetchReferralSettings(): Promise<CustomerReferralSettings> {
    try {
      // 1. Try native referral_settings table
      const { data: nativeData } = await supabase
        .from('referral_settings')
        .select('*')
        .eq('id', 'primary_referral_config')
        .maybeSingle();

      if (nativeData) {
        return {
          customer_referral_active: nativeData.customer_referral_active !== false,
          customer_referrer_reward_type: nativeData.customer_referrer_reward_type || 'WALLET',
          customer_referrer_reward_value: Number(nativeData.customer_referrer_reward_value) || 100,
          customer_referee_discount_type: nativeData.customer_referee_discount_type || 'FLAT',
          customer_referee_discount_value: Number(nativeData.customer_referee_discount_value) || 50,
          customer_min_order_litres: Number(nativeData.customer_min_order_litres) || 15,
          customer_offer_title: nativeData.customer_offer_title || 'Refer a Neighbor & Earn ₹100',
          customer_offer_tagline: nativeData.customer_offer_tagline || 'Give ₹50 off, get ₹100 Milk Wallet credit!',
          customer_offer_terms: nativeData.customer_offer_terms || 'Credited on their first week of delivery.',
          customer_share_message: nativeData.customer_share_message || DEFAULT_CUSTOMER_REFERRAL_SETTINGS.customer_share_message,
          app_download_url: nativeData.app_download_url || DEFAULT_CUSTOMER_REFERRAL_SETTINGS.app_download_url,
        };
      }

      // 2. Fall back to enterprise_settings config row
      const { data: entData } = await supabase
        .from('enterprise_settings')
        .select('*')
        .eq('id', 'primary_referral_config')
        .maybeSingle();

      if (entData && entData.app_release_notes) {
        try {
          const parsed = JSON.parse(entData.app_release_notes);
          return {
            customer_referral_active: parsed.customer_referral_active !== false,
            customer_referrer_reward_type: parsed.customer_referrer_reward_type || 'WALLET',
            customer_referrer_reward_value: Number(parsed.customer_referrer_reward_value) || 100,
            customer_referee_discount_type: parsed.customer_referee_discount_type || 'FLAT',
            customer_referee_discount_value: Number(parsed.customer_referee_discount_value) || 50,
            customer_min_order_litres: Number(parsed.customer_min_order_litres) || 15,
            customer_offer_title: parsed.customer_offer_title || 'Refer a Neighbor & Earn ₹100',
            customer_offer_tagline: parsed.customer_offer_tagline || 'Give ₹50 off, get ₹100 Milk Wallet credit!',
            customer_offer_terms: parsed.customer_offer_terms || 'Credited on their first week of delivery.',
            customer_share_message: parsed.customer_share_message || DEFAULT_CUSTOMER_REFERRAL_SETTINGS.customer_share_message,
            app_download_url: parsed.app_download_url || DEFAULT_CUSTOMER_REFERRAL_SETTINGS.app_download_url,
          };
        } catch (_) {}
      }
    } catch (e) {
      console.log('Error fetching referral settings from server:', e);
    }
    return DEFAULT_CUSTOMER_REFERRAL_SETTINGS;
  },

  /**
   * Fetch customer's own referral history from Supabase
   */
  async fetchCustomerReferrals(customerId: string): Promise<CustomerReferralRecord[]> {
    try {
      const cleanId = String(customerId || '').trim();
      if (!cleanId) return [];

      // 1. Try native referrals table
      const { data: nativeList } = await supabase
        .from('referrals')
        .select('*')
        .eq('referrer_id', cleanId)
        .order('created_at', { ascending: false });

      if (nativeList && nativeList.length > 0) {
        return nativeList.map((r: any) => ({
          id: r.id,
          referee_name: r.referee_name,
          referee_phone: r.referee_phone,
          referee_area: r.referee_area,
          status: r.status,
          reward_amount: Number(r.reward_amount) || 100,
          referee_discount: Number(r.referee_discount) || 50,
          created_at: r.created_at || new Date().toISOString()
        }));
      }

      // 2. Fall back to cms_enquiries
      const { data: enqList } = await supabase
        .from('cms_enquiries')
        .select('*')
        .eq('source', 'CUSTOMER_REFERRAL')
        .order('created_at', { ascending: false });

      if (enqList && enqList.length > 0) {
        const matches: CustomerReferralRecord[] = [];
        for (const e of enqList) {
          try {
            const meta = JSON.parse(e.notes || '{}');
            if (meta.referrer_id === cleanId || e.message?.includes(cleanId)) {
              matches.push({
                id: e.id,
                referee_name: e.name,
                referee_phone: e.mobile,
                referee_area: meta.referee_area || '',
                status: meta.status || 'PENDING',
                reward_amount: Number(meta.reward_amount) || 100,
                referee_discount: Number(meta.referee_discount) || 50,
                created_at: e.created_at || new Date().toISOString()
              });
            }
          } catch (_) {}
        }
        return matches;
      }
    } catch (err) {
      console.log('Error fetching customer referrals:', err);
    }
    return [];
  },

  /**
   * Submit a new friend referral from customer app to server
   */
  async submitCustomerReferral(payload: SubmitCustomerReferralPayload): Promise<{ success: boolean; message?: string }> {
    try {
      const cleanPhone = payload.referee_phone.replaceAll(/[^0-9]/g, '');
      if (cleanPhone.length < 10) {
        return { success: false, message: 'Please enter a valid 10-digit mobile number for your friend.' };
      }

      const settings = await ServerAPI.fetchReferralSettings();
      const row = {
        referrer_type: 'CUSTOMER',
        referrer_id: payload.referrer_id,
        referrer_name: payload.referrer_name,
        referrer_phone: payload.referrer_phone || '',
        referral_code: payload.referral_code,
        referral_type: 'CUSTOMER_TO_CUSTOMER',
        referee_name: payload.referee_name.trim(),
        referee_phone: cleanPhone,
        referee_area: payload.referee_area || 'Chennai Area',
        status: 'PENDING',
        reward_amount: settings.customer_referrer_reward_value,
        reward_type: settings.customer_referrer_reward_type,
        referee_discount: settings.customer_referee_discount_value,
        referee_discount_type: settings.customer_referee_discount_type,
        offer_title: settings.customer_offer_title,
        notes: payload.notes || 'Submitted via Customer App',
        created_at: new Date().toISOString()
      };

      // 1. Try native referrals table
      const { error: nativeErr } = await supabase.from('referrals').insert(row);
      if (nativeErr) {
        // 2. Fall back to cms_enquiries
        const { error: enqErr } = await supabase.from('cms_enquiries').insert({
          name: payload.referee_name.trim(),
          mobile: cleanPhone,
          product_interest: 'Pure Cow Milk (A2)',
          message: `Referred by Customer ${payload.referrer_name} (${payload.referral_code})`,
          source: 'CUSTOMER_REFERRAL',
          status: 'NEW',
          notes: JSON.stringify(row)
        });
        if (enqErr) {
          return { success: false, message: `Failed to save referral: ${enqErr.message}` };
        }
      }

      return {
        success: true,
        message: `Referral submitted for ${payload.referee_name}! They will receive their ₹${settings.customer_referee_discount_value} welcome discount, and your ₹${settings.customer_referrer_reward_value} reward will be credited once verified.`
      };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Server connection error.' };
    }
  },

  createAdditionalMilkOrder: async (payload: {
    customer: any;
    deliveryDate: string;
    deliverySlot: string;
    quantity: number;
    ratePerLiter?: number;
    notes?: string;
  }): Promise<{ success: boolean; data?: any; error?: string }> => {
    try {
      const c = payload.customer;
      const custId = c.id || c.customer_id;
      const effectiveRate = payload.ratePerLiter || 65;
      const totalAmount = payload.quantity * effectiveRate;
      const dateParts = payload.deliveryDate.replace(/-/g, '');
      const randomSuffix = Math.floor(100 + Math.random() * 900);
      const orderNumber = `ORD-${dateParts}-${randomSuffix}`;

      const orderData = {
        order_number: orderNumber,
        customer_id: custId,
        customer_name: c.name || 'Customer',
        mobile: c.mobile || c.phone || '',
        address: c.address || '',
        location: c.location || c.area || 'General Zone',
        area: c.area || c.location || 'General Zone',
        delivery_date: payload.deliveryDate,
        order_date: payload.deliveryDate,
        delivery_timing: payload.deliverySlot,
        delivery_status: 'SCHEDULED',
        order_status: 'SCHEDULED',
        milk_product_id: c.milk_product_id || 'Raw cow milk',
        milk_product_name: c.milk_type || 'Raw cow milk',
        quantity: payload.quantity,
        rate_per_liter: effectiveRate,
        total_amount: totalAmount,
        subscription_plan: 'Additional Order',
        payment_status: 'PENDING',
        assigned_delivery_person_id: c.assigned_delivery_person_id || null,
        assigned_delivery_person_name: c.delivery_partner_name || 'Unassigned',
        notes: payload.notes || 'Additional milk order requested by customer'
      };

      const { data, error } = await supabase.from('deliveries').insert(orderData).select().single();
      if (error) {
        return { success: false, error: error.message };
      }
      return { success: true, data };
    } catch (err: any) {
      return { success: false, error: err.message || 'Server error' };
    }
  },

  fetchAdditionalMilkOrders: async (customerId: string): Promise<any[]> => {
    try {
      const ids = await ServerAPI.resolveCustomerIds(customerId);
      const { data } = await supabase
        .from('deliveries')
        .select('*')
        .in('customer_id', ids)
        .eq('subscription_plan', 'Additional Order')
        .order('delivery_date', { ascending: false })
        .limit(10);
      return data || [];
    } catch (_) {
      return [];
    }
  },

  fetchOrderTimingsConfig: async (): Promise<any> => {
    try {
      const { data } = await supabase
        .from('enterprise_settings')
        .select('*')
        .eq('id', 'primary_timing_config')
        .maybeSingle();

      if (data && data.app_release_notes) {
        try {
          const parsed = JSON.parse(data.app_release_notes);
          return parsed;
        } catch (_) {}
      }

      const { data: ent } = await supabase
        .from('enterprise_settings')
        .select('*')
        .eq('id', 'primary_enterprise_config')
        .maybeSingle();

      return {
        morning_cutoff_time: ent?.morning_cutoff_time || '09:00 AM',
        evening_cutoff_time: ent?.evening_cutoff_time || '05:00 PM',
        morning_slot_start: '05:00 AM',
        morning_slot_end: '09:30 AM',
        evening_slot_start: '05:00 PM',
        evening_slot_end: '08:00 PM',
        morning_slot_label: ent?.default_shift || 'Morning (5:00 AM - 9:30 AM)',
        evening_slot_label: 'Evening (5:00 PM - 8:00 PM)',
        morning_slot_enabled: true,
        evening_slot_enabled: true,
        allow_pause_until: ent?.allow_pause_until || '09:00 PM',
        auto_allocate_time: ent?.auto_allocate_time || '04:00 AM',
        allow_same_day_orders: true,
        max_advance_days: 30
      };
    } catch (_) {
      return {
        morning_cutoff_time: '09:00 AM',
        evening_cutoff_time: '05:00 PM',
        morning_slot_start: '05:00 AM',
        morning_slot_end: '09:30 AM',
        evening_slot_start: '05:00 PM',
        evening_slot_end: '08:00 PM',
        morning_slot_label: 'Morning (5:00 AM - 9:30 AM)',
        evening_slot_label: 'Evening (5:00 PM - 8:00 PM)',
        morning_slot_enabled: true,
        evening_slot_enabled: true,
        allow_pause_until: '09:00 PM',
        auto_allocate_time: '04:00 AM',
        allow_same_day_orders: true,
        max_advance_days: 30
      };
    }
  },

  unserviceableLocationMessage: 'We are not available at your location yet, but we will quickly reach to your location',

  defaultServiceablePincodes: [
    '636004', '636016', '636007', '636001', '636002', '636003',
    '636005', '636006', '636008', '636502', '636014', '636010',
    '636009', '636012', '636030', '600040', '600017'
  ],

  /**
   * Fetch active serviceable pincodes list
   */
  async fetchServiceablePincodes(): Promise<string[]> {
    try {
      const { data, error } = await supabase
        .from('serviceable_pincodes')
        .select('pincode')
        .eq('is_active', true);

      if (!error && data && data.length > 0) {
        return data.map((d: any) => String(d.pincode || '').trim()).filter(Boolean);
      }
    } catch (_) {}

    try {
      const { data: ent } = await supabase
        .from('enterprise_settings')
        .select('app_release_notes')
        .eq('id', 'primary_serviceable_pincodes')
        .single();

      if (ent?.app_release_notes) {
        const parsed = JSON.parse(ent.app_release_notes);
        if (Array.isArray(parsed)) {
          const list = parsed
            .filter((p: any) => p.is_active !== false)
            .map((p: any) => String(p.pincode || '').trim())
            .filter(Boolean);
          if (list.length > 0) return list;
        }
      }
    } catch (_) {}

    return this.defaultServiceablePincodes;
  },

  /**
   * Check if a pincode is currently serviceable
   */
  async isPincodeServiceable(pincode?: string): Promise<boolean> {
    if (!pincode) return false;
    const clean = String(pincode).replace(/\D/g, '').trim();
    if (!clean) return false;
    const list = await this.fetchServiceablePincodes();
    return list.includes(clean);
  },

  /**
   * Record unserviceable customer location request for Admin Panel
   */
  async recordUnserviceableLocationRequest(payload: {
    pincode: string;
    areaName?: string;
    city?: string;
    customerName?: string;
    customerMobile?: string;
    fullAddress?: string;
    latitude?: number;
    longitude?: number;
    notes?: string;
  }): Promise<void> {
    const cleanPin = String(payload.pincode || '').replace(/\D/g, '').trim();
    if (!cleanPin) return;

    const reqId = `req-${Date.now()}`;
    const nowIso = new Date().toISOString();
    const data = {
      id: reqId,
      pincode: cleanPin,
      area_name: payload.areaName || 'Salem Zone',
      city: payload.city || 'Salem',
      state: 'Tamil Nadu',
      customer_name: payload.customerName || 'Customer Lead',
      customer_mobile: payload.customerMobile || '',
      full_address: payload.fullAddress || '',
      latitude: payload.latitude,
      longitude: payload.longitude,
      request_count: 1,
      status: 'PENDING',
      notes: payload.notes || 'Customer attempted registration/order from unserviceable pincode',
      created_at: nowIso,
      updated_at: nowIso,
    };

    // Write strictly to pincode_delivery_requests; never mutate enterprise_settings from client
    try {
      await supabase.from('pincode_delivery_requests').insert(data);
    } catch (_) {}
  },

  /**
   * Fetch customer complaints list from Supabase customer_complaints table
   */
  async fetchCustomerComplaints(customerId: string, mobile?: string): Promise<ComplaintItem[]> {
    try {
      const ids = await this.resolveCustomerIds(customerId, mobile);
      const cleanDigits = SecurityUtils.sanitizeMobileDigits(mobile);

      let query = supabase.from('customer_complaints').select('*');
      if (ids.length > 0 && cleanDigits.length >= 10) {
        query = query.or(`customer_id.in.(${ids.join(',')}),customer_phone.eq.${cleanDigits}`);
      } else if (ids.length > 0) {
        query = query.in('customer_id', ids);
      } else if (cleanDigits.length >= 10) {
        query = query.eq('customer_phone', cleanDigits);
      } else {
        query = query.eq('customer_id', customerId);
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) {
        console.log('Error fetching customer complaints:', error.message);
        return [];
      }

      return (data || []).map((c: any) => ({
        id: c.id,
        ticket_number: c.ticket_number || `CMP-${c.id.slice(0, 8)}`,
        customer_id: c.customer_id,
        customer_name: c.customer_name || 'Customer',
        customer_phone: c.customer_phone,
        customer_email: c.customer_email,
        order_id: c.order_id,
        delivery_date: c.delivery_date,
        milk_product_name: c.milk_product_name,
        category: c.category || 'QUALITY_ISSUE',
        issue_subtype: c.issue_subtype,
        title: c.title,
        description: c.description || '',
        priority: c.priority || 'HIGH',
        status: c.status || 'OPEN',
        action_taken: c.action_taken,
        action_type: c.action_type,
        refund_amount: Number(c.refund_amount) || 0,
        action_taken_by: c.action_taken_by,
        action_taken_at: c.action_taken_at,
        email_notified_at: c.email_notified_at,
        email_sent_to: c.email_sent_to,
        created_at: c.created_at || new Date().toISOString(),
        updated_at: c.updated_at
      }));
    } catch (err) {
      console.log('Error in fetchCustomerComplaints:', err);
      return [];
    }
  },

  /**
   * Register a new complaint for bottle freshness or milk quality
   */
  async createCustomerComplaint(params: {
    customer: CustomerProfile;
    orderId?: string;
    deliveryDate?: string;
    milkProductName?: string;
    category: string;
    issueSubtype?: string;
    title?: string;
    description: string;
    priority?: string;
  }): Promise<{ success: boolean; ticketNumber?: string; message?: string }> {
    try {
      const now = new Date();
      const datePart = now.toISOString().slice(0, 10).replace(/-/g, '');
      const randomPart = Math.floor(1000 + Math.random() * 9000);
      const ticketNumber = `CMP-${datePart}-${randomPart}`;

      const complaintData: any = {
        ticket_number: ticketNumber,
        customer_id: params.customer.id,
        customer_name: params.customer.name,
        customer_phone: params.customer.mobile,
        order_id: params.orderId || null,
        delivery_date: params.deliveryDate || null,
        milk_product_name: params.milkProductName || 'Pure Farm Fresh Raw Cow Milk',
        category: params.category,
        issue_subtype: params.issueSubtype || null,
        title: params.title || `${params.category.replace(/_/g, ' ')} - Order issue reported`,
        description: params.description.trim(),
        priority: params.priority || 'HIGH',
        status: 'OPEN',
        created_at: now.toISOString(),
        updated_at: now.toISOString()
      };

      const { data, error } = await supabase
        .from('customer_complaints')
        .insert(complaintData)
        .select()
        .single();

      if (error) {
        return { success: false, message: error.message };
      }

      return { success: true, ticketNumber: data?.ticket_number || ticketNumber };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Failed to submit complaint.' };
    }
  },

  /**
   * Pause/Hold a specific delivery order
   */
  async pauseCustomerOrder(orderId: string, customerId?: string): Promise<{ success: boolean; message?: string }> {
    try {
      const { error } = await supabase
        .from('deliveries')
        .update({
          delivery_status: 'PAUSED',
          order_status: 'PAUSED',
          notes: 'Delivery held/paused by customer request'
        })
        .eq('id', orderId);

      if (error) {
        return { success: false, message: error.message };
      }
      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Failed to pause order.' };
    }
  },

  /**
   * Resume a paused delivery order
   */
  async resumeCustomerOrder(orderId: string, customerId?: string): Promise<{ success: boolean; message?: string }> {
    try {
      const { error } = await supabase
        .from('deliveries')
        .update({
          delivery_status: 'SCHEDULED',
          order_status: 'SCHEDULED',
          notes: 'Delivery resumed by customer'
        })
        .eq('id', orderId);

      if (error) {
        return { success: false, message: error.message };
      }
      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Failed to resume order.' };
    }
  },

  /**
   * Pause or resume customer daily subscription (Hold all orders until return)
   */
  async toggleCustomerSubscriptionPause(customerId: string, isPaused: boolean, notes?: string): Promise<{ success: boolean; message?: string }> {
    try {
      const { error: custErr } = await supabase
        .from('customers')
        .update({
          is_paused: isPaused,
          pause_notes: notes || (isPaused ? 'Subscription held by customer' : null)
        })
        .eq('id', customerId);

      if (custErr) {
        return { success: false, message: custErr.message };
      }

      const today = new Date().toISOString().split('T')[0];
      if (isPaused) {
        await supabase
          .from('deliveries')
          .update({
            delivery_status: 'PAUSED',
            order_status: 'PAUSED',
            notes: 'Subscription paused by customer'
          })
          .eq('customer_id', customerId)
          .gte('delivery_date', today)
          .eq('delivery_status', 'SCHEDULED');
      } else {
        await supabase
          .from('deliveries')
          .update({
            delivery_status: 'SCHEDULED',
            order_status: 'SCHEDULED',
            notes: 'Subscription resumed by customer'
          })
          .eq('customer_id', customerId)
          .gte('delivery_date', today)
          .eq('delivery_status', 'PAUSED');
      }

      return { success: true };
    } catch (err: any) {
      return { success: false, message: err?.message || 'Failed to update subscription status.' };
    }
  }
};

export const api = ServerAPI;


