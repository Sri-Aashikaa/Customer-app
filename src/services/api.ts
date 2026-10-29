import { supabase } from './supabase';
import {
  CustomerProfile, PaymentItem, CancellationItem, DeliveryItem, PartnerInfo,
  RegisterPayload, LocationUpdatePayload, CustomerReferralSettings, CustomerReferralRecord,
  SubmitCustomerReferralPayload
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
  customer_share_message: '🥛 Try pure farm fresh raw cow milk from Amutham! Use my referral code {code} to get ₹{discount} OFF on your first subscription. Order now: {link}',
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
      const cleanId = loginId.trim();
      const cleanDigits = cleanId.replaceAll(/[^0-9]/g, '');
      const last10Digits = cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits;

      let query = supabase.from('customers').select('*');
      if (last10Digits.length >= 6) {
        query = query.or(`mobile.ilike.%${last10Digits}%,customer_id.eq.${cleanId},id.eq.${cleanId}`);
      } else {
        query = query.or(`customer_id.eq.${cleanId},id.eq.${cleanId}`);
      }

      const { data, error } = await query;

      if (error) {
        return { success: false, message: `Authentication error: ${error.message}` };
      }

      if (!data || data.length === 0) {
        return { success: false, message: `No customer account found with ID or Mobile Number "${cleanId}".` };
      }

      const user = data[0];
      const status = (user.status || user.account_status || '').toUpperCase();
      if (status === 'DELETED' || status === 'INACTIVE' || status === 'SUSPENDED') {
        return { success: false, message: 'This account has been deleted or deactivated. You cannot log in.' };
      }

      // Strict Password Verification
      if (user.password && user.password !== passwordInput) {
        return { success: false, message: 'Invalid password. Please check your credentials and try again.' };
      }

      const qty = Number(user.milk_quantity) || 1.5;

      const profile: CustomerProfile = {
        id: user.id,
        customer_id: user.customer_id || user.id,
        name: user.name || 'Valued Customer',
        mobile: user.mobile || cleanId,
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
        payment_status: user.payment_status === 'PAID' ? 'PAID' : 'PENDING'
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
      let assignedId = (payload.customer_id || '').trim().toUpperCase();
      if (!assignedId || !assignedId.startsWith('AMU-')) {
        assignedId = await getNextAmuCustomerId();
      }
      const mobile = payload.mobile.trim();
      const cleanDigits = mobile.replaceAll(/[^0-9]/g, '');
      const last10Digits = cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits;

      // 1. Check duplicate mobile number
      if (last10Digits) {
        const { data: existingMobile } = await supabase
          .from('customers')
          .select('id, mobile')
          .ilike('mobile', `%${last10Digits}%`);

        if (existingMobile && existingMobile.length > 0) {
          return { success: false, message: `Mobile number "${mobile}" is already registered.` };
        }
      }

      // 2. Check duplicate customer_id
      const { data: existingId } = await supabase
        .from('customers')
        .select('id')
        .eq('customer_id', assignedId);

      if (existingId && existingId.length > 0) {
        return { success: false, message: `Customer ID "${assignedId}" is already taken.` };
      }

      // 3. Insert into customers table
      const qty = payload.milk_quantity !== undefined ? Number(payload.milk_quantity) : 1.5;
      const timing = payload.delivery_timing || '5:00 AM - 9:30 AM';
      const monthlyRate = Math.round(qty * 65 * 30);
      const altMobile = (payload.alternate_mobile || payload.alt_mobile || '').trim();

      const custPayload: Record<string, any> = {
        customer_id: assignedId,
        name: payload.name.trim(),
        mobile: mobile,
        password: payload.password,
        address: payload.address.trim(),
        location: `${payload.area || 'Anna Nagar'}, ${payload.city || 'Chennai'}`,
        latitude: parseFloat(payload.latitude) || 13.0827,
        longitude: parseFloat(payload.longitude) || 80.2707,
        milk_quantity: qty,
        delivery_timing: timing,
        payment_status: 'PAID',
        account_status: 'ACTIVE',
        monthly_rate: monthlyRate
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
        // Fallback without alternate_mobile in case remote db column is not yet migrated
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
          pincode: payload.pincode || '600040',
          area: payload.area || 'Anna Nagar',
          city: payload.city || 'Chennai',
          district: payload.district || 'Chennai',
          state: payload.state || 'Tamil Nadu',
          latitude: parseFloat(payload.latitude) || 13.0827,
          longitude: parseFloat(payload.longitude) || 80.2707,
          is_primary: true
        });
      } catch (_) {}

      const profile: CustomerProfile = {
        id: customerId,
        customer_id: assignedId,
        name: payload.name.trim(),
        mobile: mobile,
        alternate_mobile: altMobile,
        alt_mobile: altMobile,
        address: payload.address.trim(),
        location: `${payload.area || 'Anna Nagar'}, ${payload.city || 'Chennai'}`,
        latitude: parseFloat(payload.latitude) || 13.0827,
        longitude: parseFloat(payload.longitude) || 80.2707,
        pincode: payload.pincode || '600040',
        area: payload.area || 'Anna Nagar',
        city: payload.city || 'Chennai',
        district: payload.district || 'Chennai',
        state: payload.state || 'Tamil Nadu',
        milk_quantity: qty,
        milk_type: 'Pure Farm Fresh Raw Cow Milk (A2)',
        monthly_rate: monthlyRate,
        delivery_timing: timing,
        assigned_delivery_person_id: '',
        delivery_partner_name: 'Unassigned',
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
      const cleanDigits = cleanInput.replaceAll(/[^0-9]/g, '');
      const last10 = cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits;

      let query = supabase.from('customers').select('id');
      if (last10.length >= 6) {
        query = query.or(`mobile.ilike.%${last10}%,customer_id.eq.${cleanInput},id.eq.${cleanInput}`);
      } else {
        query = query.or(`customer_id.eq.${cleanInput},id.eq.${cleanInput}`);
      }

      const { data, error } = await query;
      if (error || !data || data.length === 0) {
        return { success: false, message: `No account matching "${cleanInput}" found.` };
      }

      const userId = data[0].id;
      const { error: updateErr } = await supabase
        .from('customers')
        .update({ password: newPassword })
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
      const { data, error } = await supabase
        .from('customers')
        .select('password')
        .eq('id', customerId)
        .single();

      if (error || !data) {
        return { success: false, message: 'Could not fetch customer credentials.' };
      }

      if (data.password && data.password !== oldPassword) {
        return { success: false, message: 'Current password is incorrect.' };
      }

      const { error: updateErr } = await supabase
        .from('customers')
        .update({ password: newPassword })
        .eq('id', customerId);

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
    if (!partnerId) return null;
    try {
      const { data } = await supabase
        .from('employees')
        .select('*')
        .or(`id.eq.${partnerId},employee_id.eq.${partnerId}`)
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
    if (customerId) ids.add(customerId);

    const cleanDigits = (mobile || '').replace(/[^0-9]/g, '');
    const last10 = cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits;

    if (last10.length >= 10) {
      try {
        const { data } = await supabase
          .from('customers')
          .select('id, customer_id')
          .or(`mobile.ilike.%${last10}%,phone.ilike.%${last10}%`);
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
      const { data } = await supabase
        .from('enterprise_settings')
        .select('*')
        .limit(1);
      if (data && data.length > 0) {
        return data[0];
      }
    } catch (err) {
      console.log('Error fetching enterprise_settings:', err);
    }
    return null;
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
          status: p.payment_status === 'PAID' ? 'PAID' : 'PENDING'
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
      const payId = `PAY-${Date.now().toString().slice(-6)}`;
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
      const updateData: Record<string, any> = { name, mobile, address };
      if (alternateMobile !== undefined) {
        updateData.alternate_mobile = alternateMobile;
        updateData.alt_mobile = alternateMobile;
      }

      let { error } = await supabase
        .from('customers')
        .update(updateData)
        .eq('id', customerId);

      if (error && (error.message.includes('alternate_mobile') || error.message.includes('alt_mobile'))) {
        delete updateData.alternate_mobile;
        delete updateData.alt_mobile;
        const res = await supabase.from('customers').update(updateData).eq('id', customerId);
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
      const { data, error } = await supabase
        .from('cancellation_requests')
        .insert({
          customer_id: customerId,
          cancellation_date: cancellationDate,
          reason: reason,
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
  async fetchCustomerDeliveries(customerId: string): Promise<DeliveryItem[]> {
    try {
      const todayStr = new Date().toISOString().split('T')[0];
      const items: DeliveryItem[] = [];

      // 1. Fetch historical and today deliveries
      const { data } = await supabase
        .from('deliveries')
        .select('*')
        .eq('customer_id', customerId)
        .order('delivery_date', { ascending: false });

      if (data && data.length > 0) {
        items.push(...data.map((d: any) => ({
          id: d.id,
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
      await supabase.from('customers').update({
        status: 'DELETED',
        account_status: 'DELETED',
        password: `DELETED_${Date.now()}`,
        is_paid: false,
        updated_at: new Date().toISOString(),
      }).eq('id', customerId);
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
    '600040', '600017', '600020', '600042', '600010', '600004', '600116', '600096', '636004', '636007'
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
      area_name: payload.areaName || 'Unspecified',
      city: payload.city || 'Chennai',
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

    try {
      await supabase.from('pincode_delivery_requests').insert(data);
      return;
    } catch (_) {}

    try {
      const { data: ent } = await supabase
        .from('enterprise_settings')
        .select('app_release_notes')
        .eq('id', 'primary_pincode_requests')
        .single();

      let list: any[] = [];
      if (ent?.app_release_notes) {
        try {
          const parsed = JSON.parse(ent.app_release_notes);
          if (Array.isArray(parsed)) list = parsed;
        } catch (_) {}
      }

      const existingIdx = list.findIndex(
        (r) =>
          r.pincode === cleanPin &&
          (payload.customerMobile ? r.customer_mobile === payload.customerMobile : true)
      );

      if (existingIdx >= 0) {
        list[existingIdx].request_count = (list[existingIdx].request_count || 1) + 1;
        list[existingIdx].updated_at = nowIso;
      } else {
        list.unshift(data);
      }

      await supabase.from('enterprise_settings').upsert({
        id: 'primary_pincode_requests',
        company_name: 'Customer Pincode Delivery Requests',
        app_release_notes: JSON.stringify(list),
        updated_at: nowIso,
      });
    } catch (_) {}
  }
};

export const api = ServerAPI;


