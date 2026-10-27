import React, { createContext, useContext, useState } from 'react';
import { Alert } from 'react-native';
import { CustomerProfile, PartnerInfo, PaymentItem, CancellationItem, DeliveryItem, DeliveryStatus, CancellationShift, RegisterPayload, LocationUpdatePayload } from '../types';
import { ServerAPI } from '../services/api';

export type NavigationTab = 'DASHBOARD' | 'TIMING' | 'CANCEL' | 'DEPOSIT' | 'PAYMENT' | 'REPORTS' | 'PROFILE';

interface AuthContextType {
  isLoggedIn: boolean;
  isLoading: boolean;
  activeTab: NavigationTab;
  setActiveTab: (tab: NavigationTab) => void;
  customer: CustomerProfile | null;
  partnerDetails: PartnerInfo | null;
  payments: PaymentItem[];
  cancellations: CancellationItem[];
  deliveries: DeliveryItem[];
  assets: { bottles: any[]; iceBoxes: any[]; deposits: any[]; bottleAlloc?: any; iceBoxAlloc?: any } | null;
  enterpriseSettings: any | null;
  deliveryStatus: DeliveryStatus;
  cumulativeDeliveryAmount: number;
  lastDeliveryDate: string;
  nextPaymentDate: string;

  login: (id: string, pass: string) => Promise<boolean>;
  register: (form: RegisterPayload) => Promise<boolean>;
  logout: () => void;
  refreshData: () => Promise<void>;
  updateProfile: (name: string, mobile: string, address: string, alternateMobile?: string) => Promise<boolean>;
  updateLocation: (payload: LocationUpdatePayload) => Promise<boolean>;
  changePassword: (oldPass: string, newPass: string) => Promise<boolean>;
  resetPasswordByMobile: (mobileOrId: string, newPass: string) => Promise<boolean>;
  processPayment: (amount: number) => Promise<boolean>;
  requestCancellation: (date: string, shift: CancellationShift, reason: string) => Promise<boolean>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [activeTab, setActiveTab] = useState<NavigationTab>('DASHBOARD');

  const [customer, setCustomer] = useState<CustomerProfile | null>(null);
  const [partnerDetails, setPartnerDetails] = useState<PartnerInfo | null>(null);
  const [payments, setPayments] = useState<PaymentItem[]>([]);
  const [cancellations, setCancellations] = useState<CancellationItem[]>([]);
  const [deliveries, setDeliveries] = useState<DeliveryItem[]>([]);
  const [assets, setAssets] = useState<{ bottles: any[]; iceBoxes: any[]; deposits: any[]; bottleAlloc?: any; iceBoxAlloc?: any } | null>(null);
  const [enterpriseSettings, setEnterpriseSettings] = useState<any | null>(null);
  const [deliveryStatus, setDeliveryStatus] = useState<DeliveryStatus>('SCHEDULED');

  const [cumulativeDeliveryAmount, setCumulativeDeliveryAmount] = useState<number>(0);
  const [lastDeliveryDate, setLastDeliveryDate] = useState<string>('');
  const [nextPaymentDate, setNextPaymentDate] = useState<string>('');

  const refreshDataForCustomer = async (cust: CustomerProfile) => {
    setIsLoading(true);
    try {
      if (cust.assigned_delivery_person_id) {
        const pInfo = await ServerAPI.fetchPartnerDetails(cust.assigned_delivery_person_id);
        setPartnerDetails(pInfo);
      } else {
        setPartnerDetails(null);
      }

      const payList = await ServerAPI.fetchCustomerPayments(cust.id, cust.mobile);
      setPayments(payList);

      const assetsData = await ServerAPI.fetchCustomerAssets(cust.id, cust.mobile);
      setAssets(assetsData);

      const ent = await ServerAPI.fetchEnterpriseSettings();
      setEnterpriseSettings(ent);

      const cancelList = await ServerAPI.fetchCancellations(cust.id);
      setCancellations(cancelList);

      const delList = await ServerAPI.fetchCustomerDeliveries(cust.id);
      setDeliveries(delList);

      if (delList && delList.length > 0) {
        setDeliveryStatus(delList[0].status);

        const billingCycleStart = new Date();
        billingCycleStart.setDate(1);
        const billingCycleStartStr = billingCycleStart.toISOString().split('T')[0];

        let cumAmount = 0;
        let lastDate = '';
        delList.forEach((d) => {
          const isDelivered = d.status === 'OUT_FOR_DELIVERY' || d.status === 'DELIVERED';
          const isInCycle = d.date >= billingCycleStartStr;
          if (isDelivered && isInCycle) {
            const qty = Number(d.quantity) || cust.milk_quantity || 1.5;
            const rate = 65;
            cumAmount += qty * rate;
            if (!lastDate || d.date > lastDate) {
              lastDate = d.date;
            }
          }
        });

        setCumulativeDeliveryAmount(cumAmount);
        setLastDeliveryDate(lastDate);

        const now = new Date();
        const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        setNextPaymentDate(lastDay.toISOString().split('T')[0]);
      } else {
        setDeliveryStatus('SCHEDULED');
        const qty = cust.milk_quantity || 1.5;
        const rate = 65;
        const today = new Date();
        const dayOfMonth = today.getDate();
        setCumulativeDeliveryAmount(qty * rate * dayOfMonth);

        const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        setNextPaymentDate(lastDay.toISOString().split('T')[0]);
      }
    } catch (err) {
      console.log('Error refreshing customer data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (id: string, pass: string): Promise<boolean> => {
    setIsLoading(true);
    const res = await ServerAPI.loginCustomer(id, pass);
    setIsLoading(false);

    if (res.success && res.data) {
      setCustomer(res.data);
      setIsLoggedIn(true);
      await refreshDataForCustomer(res.data);
      return true;
    } else {
      Alert.alert('Login Error', res.message || 'Unable to log in. Please check credentials.');
      return false;
    }
  };

  const register = async (form: RegisterPayload): Promise<boolean> => {
    setIsLoading(true);
    const res = await ServerAPI.registerCustomer(form);
    setIsLoading(false);

    if (res.success && res.data) {
      setCustomer(res.data);
      setIsLoggedIn(true);
      await refreshDataForCustomer(res.data);
      Alert.alert('Account Created', `Welcome to Amutham Raw Milk, ${res.data.name}!`);
      return true;
    } else {
      Alert.alert('Registration Error', res.message || 'Registration failed.');
      return false;
    }
  };

  const logout = () => {
    setIsLoggedIn(false);
    setCustomer(null);
    setPartnerDetails(null);
    setPayments([]);
    setCancellations([]);
    setDeliveries([]);
    setAssets(null);
    setEnterpriseSettings(null);
    setActiveTab('DASHBOARD');
  };

  const refreshData = async () => {
    if (customer) {
      await refreshDataForCustomer(customer);
    }
  };

  const updateProfile = async (name: string, mobile: string, address: string, alternateMobile?: string): Promise<boolean> => {
    if (!customer) return false;
    setIsLoading(true);
    const res = await ServerAPI.updateProfile(customer.id, name, mobile, address, alternateMobile);
    setIsLoading(false);

    if (res.success) {
      setCustomer({
        ...customer,
        name,
        mobile,
        address,
        ...(alternateMobile !== undefined ? { alternate_mobile: alternateMobile, alt_mobile: alternateMobile } : {})
      });
      Alert.alert('Success', 'Profile details updated on server.');
      return true;
    } else {
      Alert.alert('Update Failed', res.message || 'Failed to update profile.');
      return false;
    }
  };

  const updateLocation = async (payload: LocationUpdatePayload): Promise<boolean> => {
    if (!customer) return false;
    setIsLoading(true);
    const res = await ServerAPI.updateCustomerLocation(customer.id, payload);
    setIsLoading(false);

    if (res.success) {
      setCustomer({
        ...customer,
        address: payload.address,
        area: payload.area,
        city: payload.city,
        pincode: payload.pincode,
        latitude: payload.latitude,
        longitude: payload.longitude,
        location: `${payload.area}, ${payload.city}`,
      });
      Alert.alert('Location Updated', 'Your delivery address and map coordinates updated on server.');
      return true;
    } else {
      Alert.alert('Update Error', res.message || 'Failed to update location details.');
      return false;
    }
  };

  const changePassword = async (oldPass: string, newPass: string): Promise<boolean> => {
    if (!customer) return false;
    setIsLoading(true);
    const res = await ServerAPI.updatePassword(customer.id, oldPass, newPass);
    setIsLoading(false);

    if (res.success) {
      Alert.alert('Password Updated', 'Your account password has been updated on server.');
      return true;
    } else {
      Alert.alert('Password Update Error', res.message || 'Failed to update password.');
      return false;
    }
  };

  const resetPasswordByMobile = async (mobileOrId: string, newPass: string): Promise<boolean> => {
    setIsLoading(true);
    const res = await ServerAPI.resetPasswordByMobile(mobileOrId, newPass);
    setIsLoading(false);

    if (res.success) {
      Alert.alert('Password Reset Successful', 'Your password has been reset on server. Please login with your new password.');
      return true;
    } else {
      Alert.alert('Password Reset Failed', res.message || 'Unable to reset password.');
      return false;
    }
  };

  const processPayment = async (amount: number): Promise<boolean> => {
    if (!customer) return false;
    setIsLoading(true);
    const res = await ServerAPI.processPayment(customer.id, amount);
    setIsLoading(false);

    if (res.success) {
      setCustomer({ ...customer, payment_status: 'PAID' });
      await refreshDataForCustomer(customer);
      Alert.alert('Payment Successful', `Payment of ₹${amount.toFixed(2)} recorded via UPI.\nReference ID: ${res.ref}`);
      return true;
    } else {
      Alert.alert('Payment Error', res.message || 'Payment processing failed.');
      return false;
    }
  };

  const requestCancellation = async (date: string, shift: CancellationShift, reason: string): Promise<boolean> => {
    if (!customer) return false;
    const shiftLabel = shift === 'MORNING' ? 'Morning (5:00 - 9:30 AM)' : shift === 'EVENING' ? 'Evening (3:00 - 7:30 PM)' : 'Full Day (Both Shifts)';
    setIsLoading(true);
    const res = await ServerAPI.requestCancellation(customer.id, date, `[${shiftLabel}] ${reason}`);
    setIsLoading(false);

    if (res.success && res.data) {
      const newEntry: CancellationItem = {
        ...res.data,
        shift,
        time: shiftLabel
      };
      setCancellations([newEntry, ...cancellations]);
      Alert.alert('Request Submitted', `Delivery pause request for ${date} (${shiftLabel}) submitted successfully.`);
      return true;
    } else {
      Alert.alert('Submission Failed', res.message || 'Failed to submit cancellation request.');
      return false;
    }
  };

  return (
    <AuthContext.Provider
      value={{
        isLoggedIn,
        isLoading,
        activeTab,
        setActiveTab,
        customer,
        partnerDetails,
        payments,
        cancellations,
        deliveries,
        assets,
        enterpriseSettings,
        deliveryStatus,
        cumulativeDeliveryAmount,
        lastDeliveryDate,
        nextPaymentDate,
        login,
        register,
        logout,
        refreshData,
        updateProfile,
        updateLocation,
        changePassword,
        resetPasswordByMobile,
        processPayment,
        requestCancellation,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
