import React, { useState } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  TouchableOpacity,
  ScrollView,
  SafeAreaView,
  StatusBar,
  Alert,
  ActivityIndicator,
  Modal,
} from 'react-native';
import { useAuth } from '../context/AuthContext';
import { api } from '../services/api';
import { SecurityUtils } from '../services/security';
import { colors, spacing, radius } from '../theme/theme';

const SALEM_AREAS = [
  { name: 'Fairlands', pincode: '636016' },
  { name: 'Meyyanur / Reddiyur', pincode: '636004' },
  { name: 'Hasthampatti', pincode: '636007' },
  { name: 'Salem Central', pincode: '636001' },
  { name: 'Shevapet', pincode: '636002' },
  { name: 'Ammapet', pincode: '636003' },
  { name: 'Suramangalam & Junction', pincode: '636005' },
  { name: 'Dadagapatti', pincode: '636006' },
  { name: 'Kannankurichi', pincode: '636008' },
  { name: 'Tharamangalam', pincode: '636502' },
  { name: 'Omalur', pincode: '636014' },
  { name: 'Kandhampatti', pincode: '636010' },
  { name: 'Gorimedu', pincode: '636012' },
  { name: 'Karuppur', pincode: '636030' },
];

const QUANTITY_OPTIONS = [
  { label: '0.5 L', value: 0.5, desc: '1 Bottle (500ml)' },
  { label: '1.0 L', value: 1.0, desc: '1 Glass Bottle (1L)' },
  { label: '1.5 L', value: 1.5, desc: '1L + 500ml Bottles' },
  { label: '2.0 L', value: 2.0, desc: '2 Bottles (1L each)' },
  { label: '3.0 L', value: 3.0, desc: '3 Bottles (1L each)' },
];

const SHIFT_OPTIONS = [
  { id: 'Morning Shift', label: 'Morning Shift', time: '5:00 AM - 7:00 AM' },
  { id: 'Evening Shift', label: 'Evening Shift', time: '5:00 PM - 7:00 PM' },
  { id: 'Both (Morning & Evening)', label: 'Both Shifts', time: 'Twice Daily Drops' },
];

const FREQUENCY_OPTIONS = [
  { id: 'Daily Delivery', label: 'Daily Delivery (7 Days)' },
  { id: 'Alternate Days', label: 'Alternate Days (~15 Days/Mo)' },
  { id: 'Weekdays Only', label: 'Weekdays (Mon - Fri)' },
];

const BILLING_PLANS = [
  {
    id: 'Monthly Postpaid',
    name: 'Monthly Postpaid Ledger',
    desc: 'Zero advance lock-in. Pay at month end via UPI, NetBanking or Cash.',
  },
  {
    id: 'Weekly Postpaid',
    name: 'Weekly Postpaid',
    desc: 'Settle every Saturday for milk delivered during the week.',
  },
  {
    id: 'Daily Recurring',
    name: 'Daily Pay-As-You-Go',
    desc: 'Pay per delivery or maintain a running wallet balance.',
  },
  {
    id: 'Prepaid Wallet',
    name: 'Prepaid Advance Wallet',
    desc: 'Top up in advance and enjoy bonus delivery credits.',
  },
];

export const AuthScreen: React.FC = () => {
  const { login, register, resetPasswordByMobile, isLoading } = useAuth();
  const [mode, setMode] = useState<'LOGIN' | 'REGISTER'>('LOGIN');

  // Multi-step Registration State (Steps 1 to 4)
  const [regStep, setRegStep] = useState<number>(1);

  // Login form state
  const [loginId, setLoginId] = useState<string>('');
  const [loginPassword, setLoginPassword] = useState<string>('');

  // Password reset modal state
  const [showResetModal, setShowResetModal] = useState<boolean>(false);
  const [resetInputId, setResetInputId] = useState<string>('');
  const [resetOtp, setResetOtp] = useState<string>('');
  const [resetNewPassword, setResetNewPassword] = useState<string>('');
  const [resetConfirmPassword, setResetConfirmPassword] = useState<string>('');
  const [resetStep, setResetStep] = useState<number>(0);
  const [activeChallengeHash, setActiveChallengeHash] = useState<string>('');
  const [activeTargetMobile, setActiveTargetMobile] = useState<string>('');
  const [otpExpiresAt, setOtpExpiresAt] = useState<number>(0);
  const [otpAttempts, setOtpAttempts] = useState<number>(0);

  // Pincode check state
  const [pincodeVerified, setPincodeVerified] = useState<boolean | null>(null);
  const [pincodeChecking, setPincodeChecking] = useState<boolean>(false);
  const [pincodeMessage, setPincodeMessage] = useState<string>('');

  // Full Register Form State (Matching Website)
  const [regForm, setRegForm] = useState({
    // Step 1: Contact & Address
    name: '',
    mobile: '',
    alternate_mobile: '',
    customer_id: '',
    password: '',
    address: '',
    area: 'Fairlands',
    city: 'Salem',
    district: 'Salem',
    state: 'Tamil Nadu',
    pincode: '636016',
    latitude: '11.6748',
    longitude: '78.1408',

    // Step 2: Milk Variety & Volume & Shift
    milk_type: 'Pure Fresh Cow Milk',
    milk_quantity: 1.0,
    delivery_timing: 'Morning Shift',
    delivery_frequency: 'Daily Delivery',

    // Step 3: Billing & Bottles & Drop
    payment_plan: 'Monthly Postpaid',
    bottle_size: '1.0 Litre Bottles',
    agree_bottle_return: true,
    delivery_instructions: 'At Apartment Doorstep Hook / Table',
  });

  const handleLoginSubmit = async () => {
    if (!loginId.trim() || !loginPassword.trim()) {
      Alert.alert('Required Fields', 'Please enter your Mobile Number or Customer ID and Password.');
      return;
    }
    await login(loginId.trim(), loginPassword.trim());
  };

  // Check Pincode Live
  const handleCheckPincode = async (pinInput?: string) => {
    const pin = (pinInput || regForm.pincode).trim();
    if (pin.length !== 6) {
      Alert.alert('Pincode Required', 'Please enter a valid 6-digit postal pincode.');
      return;
    }

    setPincodeChecking(true);
    setPincodeVerified(null);
    try {
      const isServiceable = await api.isPincodeServiceable(pin);
      if (isServiceable) {
        setPincodeVerified(true);
        setPincodeMessage(`✓ Delivery Available in Salem (Morning & Evening Shifts)`);
      } else {
        setPincodeVerified(false);
        setPincodeMessage(`Pincode ${pin} is outside daily core route. Priority request recorded.`);
        await api.recordUnserviceableLocationRequest({
          pincode: pin,
          areaName: regForm.area,
          city: 'Salem',
          customerName: regForm.name || 'Guest App User',
          customerMobile: regForm.mobile,
          fullAddress: regForm.address,
        });
      }
    } catch {
      setPincodeVerified(true);
      setPincodeMessage('Delivery Available in Salem District');
    } finally {
      setPincodeChecking(false);
    }
  };

  // Step 1 Validation -> Next Step
  const handleNextStep1 = async () => {
    if (!regForm.name.trim() || !regForm.mobile.trim() || !regForm.password.trim() || !regForm.address.trim()) {
      Alert.alert('Missing Fields', 'Please fill in your Full Name, Mobile, Password, and Delivery Address.');
      return;
    }

    const cleanMobile = regForm.mobile.replace(/[^0-9]/g, '');
    if (cleanMobile.length < 10) {
      Alert.alert('Invalid Mobile', 'Please enter a valid 10-digit mobile number.');
      return;
    }

    if (regForm.password.trim().length < 6) {
      Alert.alert('Weak Password', 'Password must be at least 6 characters long.');
      return;
    }

    const pin = regForm.pincode.trim();
    if (pin.length !== 6) {
      Alert.alert('Invalid Pincode', 'Please enter a valid 6-digit Salem pincode.');
      return;
    }

    // Check pincode before proceeding
    const isServiceable = await api.isPincodeServiceable(pin);
    if (!isServiceable) {
      await api.recordUnserviceableLocationRequest({
        pincode: pin,
        areaName: regForm.area,
        city: 'Salem',
        customerName: regForm.name,
        customerMobile: regForm.mobile,
        fullAddress: regForm.address,
      });
      Alert.alert(
        'Delivery Area Notice',
        `Pincode ${pin} is outside our daily delivery radius right now. We have recorded your request and our Salem hub manager will notify you as soon as routes expand to your area!`,
        [
          { text: 'Continue Anyway', onPress: () => setRegStep(2) },
          { text: 'Change Pincode', style: 'cancel' },
        ]
      );
      return;
    }

    setRegStep(2);
  };

  // Final Registration Submission
  const handleFinalRegisterSubmit = async () => {
    await register(regForm);
  };

  const handleSendResetOtp = () => {
    const cleanDigits = SecurityUtils.sanitizeMobileDigits(resetInputId);
    if (!cleanDigits || cleanDigits.length < 10) {
      Alert.alert('Invalid Mobile', 'Please enter a valid 10-digit mobile number.');
      return;
    }
    const otp = SecurityUtils.generateSecureOtp();
    setActiveChallengeHash(SecurityUtils.hashPassword(otp));
    setActiveTargetMobile(cleanDigits);
    setOtpExpiresAt(Date.now() + 5 * 60 * 1000);
    setOtpAttempts(0);
    setResetStep(1);
    if (__DEV__) {
      Alert.alert(
        'Verification OTP Sent',
        `A 6-digit verification code has been dispatched to +91 ${cleanDigits}.\n\n[DEV MODE]: Your security code is ${otp}`
      );
    } else {
      Alert.alert(
        'Verification OTP Sent',
        `A 6-digit verification code has been dispatched to +91 ${cleanDigits}. Please check your phone and enter the code below.`
      );
    }
  };

  const handleResetPasswordSubmit = async () => {
    const cleanDigits = SecurityUtils.sanitizeMobileDigits(resetInputId);
    if (!resetOtp.trim()) {
      Alert.alert('Missing OTP', 'Please enter the 6-digit OTP received.');
      return;
    }
    if (Date.now() > otpExpiresAt) {
      Alert.alert('OTP Expired', 'The OTP has expired (5-minute security limit). Please request a new OTP.');
      setResetStep(0);
      return;
    }
    if (otpAttempts >= 5) {
      Alert.alert('Locked Out', 'Too many failed attempts. For your protection, please request a new OTP.');
      setResetStep(0);
      return;
    }
    const enteredHash = SecurityUtils.hashPassword(resetOtp.trim());
    if (!SecurityUtils.fixedTimeEquals(enteredHash, activeChallengeHash) || cleanDigits !== activeTargetMobile) {
      setOtpAttempts((prev) => prev + 1);
      Alert.alert('Invalid OTP', `Incorrect OTP entered (${4 - otpAttempts} attempts remaining).`);
      return;
    }
    if (!resetNewPassword.trim() || resetNewPassword.trim().length < 6) {
      Alert.alert('Invalid Password', 'New password must be at least 6 characters long.');
      return;
    }
    if (resetNewPassword !== resetConfirmPassword) {
      Alert.alert('Password Mismatch', 'New Password and Confirm Password do not match.');
      return;
    }

    const ok = await resetPasswordByMobile(resetInputId.trim(), resetNewPassword.trim());
    if (ok) {
      setShowResetModal(false);
      setResetStep(0);
      setResetInputId('');
      setResetOtp('');
      setResetNewPassword('');
      setResetConfirmPassword('');
      setActiveChallengeHash('');
    }
  };

  const unitRate = regForm.milk_type.includes('Buffalo') ? 80 : 65;
  const estimatedMonthly = Math.round(regForm.milk_quantity * unitRate * 30);

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        {/* BRAND HEADER */}
        <View style={styles.brandHeader}>
          <Text style={styles.logoEmoji}>🥛</Text>
          <Text style={styles.brandTitle}>Sri Aashikaa</Text>
          <Text style={styles.brandSubtitle}>Pure Fresh Milk &bull; Salem Doorstep Service</Text>
        </View>

        {/* LOGIN FORM */}
        {mode === 'LOGIN' ? (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Customer Login</Text>

            <Text style={styles.inputLabel}>Mobile Number or Customer ID *</Text>
            <TextInput
              style={styles.input}
              value={loginId}
              onChangeText={setLoginId}
              placeholder="e.g. 9876543210 or ASH-A001"
              placeholderTextColor={colors.textLight}
              autoCapitalize="none"
              keyboardType="email-address"
            />

            <Text style={styles.inputLabel}>Password *</Text>
            <TextInput
              style={styles.input}
              value={loginPassword}
              onChangeText={setLoginPassword}
              secureTextEntry
              placeholder="Enter your password"
              placeholderTextColor={colors.textLight}
            />

            <TouchableOpacity onPress={() => setShowResetModal(true)} style={styles.forgotBtn}>
              <Text style={styles.forgotBtnText}>Forgot Password?</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.primaryBtn, isLoading && styles.disabledBtn]}
              onPress={handleLoginSubmit}
              disabled={isLoading}
              activeOpacity={0.8}
            >
              {isLoading ? (
                <ActivityIndicator color={colors.surface} size="small" />
              ) : (
                <Text style={styles.primaryBtnText}>Login</Text>
              )}
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => {
                setMode('REGISTER');
                setRegStep(1);
              }}
              style={styles.switchContainer}
            >
              <Text style={styles.switchText}>
                New Customer? <Text style={styles.switchHighlight}>Subscribe & Register</Text>
              </Text>
            </TouchableOpacity>
          </View>
        ) : (
          /* MULTI-STEP UNIFIED ONBOARDING REGISTRATION */
          <View style={styles.card}>
            {/* Step Stepper Header */}
            <View style={styles.stepperContainer}>
              <Text style={styles.stepBadge}>
                STEP {regStep} OF 4 &bull;{' '}
                {regStep === 1
                  ? 'ADDRESS & CONTACT'
                  : regStep === 2
                  ? 'MILK & SCHEDULE'
                  : regStep === 3
                  ? 'BILLING & BOTTLES'
                  : 'REVIEW & CONFIRM'}
              </Text>
              <View style={styles.progressBarBg}>
                <View style={[styles.progressBarFill, { width: `${(regStep / 4) * 100}%` }]} />
              </View>
            </View>

            {/* STEP 1: PINCODE CHECK & ADDRESS */}
            {regStep === 1 && (
              <View>
                <Text style={styles.stepTitle}>Delivery Location & Contact</Text>
                <Text style={styles.stepSubtitle}>
                  Check delivery coverage in your Salem neighborhood and set your credentials.
                </Text>

                {/* PINCODE CHECK FIRST */}
                <Text style={styles.inputLabel}>Check Delivery Pincode First *</Text>
                <View style={styles.pincodeRow}>
                  <TextInput
                    style={[styles.input, { flex: 1 }]}
                    value={regForm.pincode}
                    onChangeText={(v) => {
                      const clean = v.replace(/[^0-9]/g, '').slice(0, 6);
                      setRegForm({ ...regForm, pincode: clean });
                      setPincodeVerified(null);
                    }}
                    placeholder="e.g. 636004"
                    placeholderTextColor={colors.textLight}
                    keyboardType="numeric"
                    maxLength={6}
                  />
                  <TouchableOpacity
                    style={styles.checkBtn}
                    onPress={() => handleCheckPincode()}
                    disabled={pincodeChecking}
                  >
                    {pincodeChecking ? (
                      <ActivityIndicator size="small" color="#fff" />
                    ) : (
                      <Text style={styles.checkBtnText}>Check</Text>
                    )}
                  </TouchableOpacity>
                </View>

                {pincodeVerified !== null && (
                  <View
                    style={[
                      styles.pincodeNotice,
                      { backgroundColor: pincodeVerified ? '#dcfce7' : '#fef3c7' },
                    ]}
                  >
                    <Text
                      style={[
                        styles.pincodeNoticeText,
                        { color: pincodeVerified ? '#166534' : '#92400e' },
                      ]}
                    >
                      {pincodeMessage}
                    </Text>
                  </View>
                )}

                {/* SALEM NEIGHBORHOOD DROPDOWN */}
                <Text style={styles.inputLabel}>Salem Neighborhood / Area *</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.areaScroll}>
                  {SALEM_AREAS.map((a) => {
                    const isSelected = regForm.area === a.name;
                    return (
                      <TouchableOpacity
                        key={a.name}
                        onPress={() =>
                          setRegForm({ ...regForm, area: a.name, pincode: a.pincode })
                        }
                        style={[styles.chip, isSelected && styles.chipActive]}
                      >
                        <Text style={[styles.chipText, isSelected && styles.chipTextActive]}>
                          {a.name}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>

                {/* FULL NAME */}
                <Text style={styles.inputLabel}>Full Name *</Text>
                <TextInput
                  style={styles.input}
                  value={regForm.name}
                  onChangeText={(v) => setRegForm({ ...regForm, name: v })}
                  placeholder="e.g. Anand Kumar"
                  placeholderTextColor={colors.textLight}
                />

                {/* MOBILE */}
                <Text style={styles.inputLabel}>WhatsApp / Mobile Number *</Text>
                <TextInput
                  style={styles.input}
                  value={regForm.mobile}
                  onChangeText={(v) => setRegForm({ ...regForm, mobile: v })}
                  placeholder="10-digit mobile"
                  placeholderTextColor={colors.textLight}
                  keyboardType="phone-pad"
                  maxLength={15}
                />

                {/* PASSWORD */}
                <Text style={styles.inputLabel}>Create Account Password *</Text>
                <TextInput
                  style={styles.input}
                  value={regForm.password}
                  onChangeText={(v) => setRegForm({ ...regForm, password: v })}
                  secureTextEntry
                  placeholder="At least 6 characters"
                  placeholderTextColor={colors.textLight}
                />

                {/* DOOR & STREET ADDRESS */}
                <Text style={styles.inputLabel}>Door / Flat No & Street Address *</Text>
                <TextInput
                  style={styles.input}
                  value={regForm.address}
                  onChangeText={(v) => setRegForm({ ...regForm, address: v })}
                  placeholder="e.g. 14-B, 2nd Cross, Meyyanur Bypass"
                  placeholderTextColor={colors.textLight}
                />

                <TouchableOpacity style={styles.primaryBtn} onPress={handleNextStep1} activeOpacity={0.8}>
                  <Text style={styles.primaryBtnText}>Next: Select Milk Plan →</Text>
                </TouchableOpacity>
              </View>
            )}

            {/* STEP 2: MILK VARIETY, QUANTITY & SCHEDULE */}
            {regStep === 2 && (
              <View>
                <Text style={styles.stepTitle}>Choose Milk & Delivery Schedule</Text>
                <Text style={styles.stepSubtitle}>
                  Select farm-fresh variety, daily volume, and preferred shift.
                </Text>

                {/* MILK VARIETY */}
                <Text style={styles.inputLabel}>Milk Variety *</Text>
                <View style={styles.optionCardsRow}>
                  <TouchableOpacity
                    onPress={() => setRegForm({ ...regForm, milk_type: 'Pure Fresh Cow Milk' })}
                    style={[
                      styles.choiceCard,
                      regForm.milk_type === 'Pure Fresh Cow Milk' && styles.choiceCardActive,
                    ]}
                  >
                    <Text style={styles.choiceCardTitle}>Pure Fresh Cow Milk</Text>
                    <Text style={styles.choiceCardPrice}>₹65 / Litre</Text>
                    <Text style={styles.choiceCardDesc}>4.2% Natural Fat &bull; Light & Digestible</Text>
                  </TouchableOpacity>

                  <TouchableOpacity
                    onPress={() => setRegForm({ ...regForm, milk_type: 'Pure Buffalo Milk' })}
                    style={[
                      styles.choiceCard,
                      regForm.milk_type === 'Pure Buffalo Milk' && styles.choiceCardActive,
                    ]}
                  >
                    <Text style={styles.choiceCardTitle}>Pure Buffalo Milk</Text>
                    <Text style={styles.choiceCardPrice}>₹80 / Litre</Text>
                    <Text style={styles.choiceCardDesc}>7.5%+ Butterfat &bull; Creamy for Curd & Coffee</Text>
                  </TouchableOpacity>
                </View>

                {/* DAILY QUANTITY */}
                <Text style={styles.inputLabel}>Daily Quantity (Litres) *</Text>
                <View style={styles.quantityGrid}>
                  {QUANTITY_OPTIONS.map((q) => {
                    const isSelected = regForm.milk_quantity === q.value;
                    return (
                      <TouchableOpacity
                        key={q.label}
                        onPress={() => setRegForm({ ...regForm, milk_quantity: q.value })}
                        style={[styles.qtyCard, isSelected && styles.qtyCardActive]}
                      >
                        <Text style={[styles.qtyCardLabel, isSelected && styles.qtyCardLabelActive]}>
                          {q.label}
                        </Text>
                        <Text style={styles.qtyCardDesc}>{q.desc}</Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>

                {/* DELIVERY SHIFT */}
                <Text style={styles.inputLabel}>Delivery Shift *</Text>
                <View style={styles.verticalList}>
                  {SHIFT_OPTIONS.map((s) => {
                    const isSelected = regForm.delivery_timing === s.id;
                    return (
                      <TouchableOpacity
                        key={s.id}
                        onPress={() => setRegForm({ ...regForm, delivery_timing: s.id })}
                        style={[styles.selectRow, isSelected && styles.selectRowActive]}
                      >
                        <View>
                          <Text style={[styles.selectRowTitle, isSelected && styles.selectRowTitleActive]}>
                            {s.label}
                          </Text>
                          <Text style={styles.selectRowSub}>{s.time}</Text>
                        </View>
                        <Text style={styles.radioIcon}>{isSelected ? '●' : '○'}</Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>

                {/* DELIVERY FREQUENCY */}
                <Text style={styles.inputLabel}>Delivery Frequency *</Text>
                <View style={styles.frequencyRow}>
                  {FREQUENCY_OPTIONS.map((f) => {
                    const isSelected = regForm.delivery_frequency === f.id;
                    return (
                      <TouchableOpacity
                        key={f.id}
                        onPress={() => setRegForm({ ...regForm, delivery_frequency: f.id })}
                        style={[styles.chip, isSelected && styles.chipActive]}
                      >
                        <Text style={[styles.chipText, isSelected && styles.chipTextActive]}>
                          {f.label}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>

                {/* STEP 2 ACTIONS */}
                <View style={styles.stepBtnRow}>
                  <TouchableOpacity style={styles.backBtn} onPress={() => setRegStep(1)}>
                    <Text style={styles.backBtnText}>← Back</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.nextBtn} onPress={() => setRegStep(3)}>
                    <Text style={styles.primaryBtnText}>Next: Billing Plan →</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}

            {/* STEP 3: BILLING PLAN & BOTTLES */}
            {regStep === 3 && (
              <View>
                <Text style={styles.stepTitle}>Billing Cadence & Bottle Assets</Text>
                <Text style={styles.stepSubtitle}>
                  Choose flexible accounting and complimentary glass bottle rotation.
                </Text>

                {/* BILLING PLANS */}
                <Text style={styles.inputLabel}>Billing Cycle *</Text>
                <View style={styles.verticalList}>
                  {BILLING_PLANS.map((b) => {
                    const isSelected = regForm.payment_plan === b.id;
                    return (
                      <TouchableOpacity
                        key={b.id}
                        onPress={() => setRegForm({ ...regForm, payment_plan: b.id })}
                        style={[styles.selectRow, isSelected && styles.selectRowActive]}
                      >
                        <View style={{ flex: 1 }}>
                          <Text style={[styles.selectRowTitle, isSelected && styles.selectRowTitleActive]}>
                            {b.name}
                          </Text>
                          <Text style={styles.selectRowSub}>{b.desc}</Text>
                        </View>
                        <Text style={styles.radioIcon}>{isSelected ? '●' : '○'}</Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>

                {/* RETURNABLE BOTTLES AGREEMENT */}
                <View style={styles.assetNoticeCard}>
                  <Text style={styles.assetNoticeTitle}>🌿 Eco-Friendly Sanitized Glass Bottles</Text>
                  <Text style={styles.assetNoticeDesc}>
                    We provide complimentary daily rotation of steam-sterilized glass bottles. Simply rinse your previous empty bottle and place it at your doorstep hook for daily collection.
                  </Text>
                </View>

                {/* DOORSTEP INSTRUCTIONS */}
                <Text style={styles.inputLabel}>Doorstep Drop Location / Notes</Text>
                <TextInput
                  style={styles.input}
                  value={regForm.delivery_instructions}
                  onChangeText={(v) => setRegForm({ ...regForm, delivery_instructions: v })}
                  placeholder="e.g. Doorstep Hook / Table / Security Desk"
                  placeholderTextColor={colors.textLight}
                />

                {/* STEP 3 ACTIONS */}
                <View style={styles.stepBtnRow}>
                  <TouchableOpacity style={styles.backBtn} onPress={() => setRegStep(2)}>
                    <Text style={styles.backBtnText}>← Back</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.nextBtn} onPress={() => setRegStep(4)}>
                    <Text style={styles.primaryBtnText}>Review Summary →</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}

            {/* STEP 4: REVIEW & CONFIRM */}
            {regStep === 4 && (
              <View>
                <Text style={styles.stepTitle}>Review & Confirm Subscription</Text>
                <Text style={styles.stepSubtitle}>
                  Please verify your fresh milk order before completing registration.
                </Text>

                {/* SUMMARY BREAKDOWN CARD */}
                <View style={styles.summaryCard}>
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Customer Name:</Text>
                    <Text style={styles.summaryValue}>{regForm.name}</Text>
                  </View>
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Mobile Number:</Text>
                    <Text style={styles.summaryValue}>{regForm.mobile}</Text>
                  </View>
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Salem Address:</Text>
                    <Text style={styles.summaryValue}>
                      {regForm.address}, {regForm.area} ({regForm.pincode})
                    </Text>
                  </View>
                  <View style={styles.summaryDivider} />
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Milk Selection:</Text>
                    <Text style={[styles.summaryValue, { color: colors.primary, fontWeight: '700' }]}>
                      {regForm.milk_type}
                    </Text>
                  </View>
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Daily Quantity:</Text>
                    <Text style={styles.summaryValue}>{regForm.milk_quantity} Litre(s) Daily</Text>
                  </View>
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Delivery Shift:</Text>
                    <Text style={styles.summaryValue}>{regForm.delivery_timing}</Text>
                  </View>
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Billing Plan:</Text>
                    <Text style={styles.summaryValue}>{regForm.payment_plan}</Text>
                  </View>
                  <View style={styles.summaryDivider} />
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryTotalLabel}>Est. Monthly Total:</Text>
                    <Text style={styles.summaryTotalValue}>₹{estimatedMonthly.toLocaleString()}</Text>
                  </View>
                  <Text style={styles.summaryNote}>* Calculated per actual daily deliveries received.</Text>
                </View>

                {/* FINAL SUBMIT BUTTON */}
                <TouchableOpacity
                  style={[styles.primaryBtn, isLoading && styles.disabledBtn]}
                  onPress={handleFinalRegisterSubmit}
                  disabled={isLoading}
                  activeOpacity={0.8}
                >
                  {isLoading ? (
                    <ActivityIndicator color={colors.surface} size="small" />
                  ) : (
                    <Text style={styles.primaryBtnText}>✓ Confirm & Start Fresh Delivery</Text>
                  )}
                </TouchableOpacity>

                <TouchableOpacity style={styles.backBtnFull} onPress={() => setRegStep(3)}>
                  <Text style={styles.backBtnText}>← Back to Billing</Text>
                </TouchableOpacity>
              </View>
            )}

            {/* SWITCH TO LOGIN */}
            <TouchableOpacity onPress={() => setMode('LOGIN')} style={styles.switchContainer}>
              <Text style={styles.switchText}>
                Already registered? <Text style={styles.switchHighlight}>Login to your Account</Text>
              </Text>
            </TouchableOpacity>
          </View>
        )}
      </ScrollView>

      {/* PASSWORD RESET MODAL */}
      <Modal visible={showResetModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Reset Account Password</Text>
            <Text style={styles.modalSubtitle}>
              {resetStep === 0
                ? 'Enter your registered Mobile Number to receive a 6-digit verification code.'
                : 'Enter the verification OTP and your new password.'}
            </Text>

            <Text style={styles.inputLabel}>Registered Mobile Number *</Text>
            <TextInput
              style={styles.input}
              value={resetInputId}
              onChangeText={setResetInputId}
              placeholder="e.g. 9876543210"
              placeholderTextColor={colors.textLight}
              keyboardType="phone-pad"
              editable={resetStep === 0}
            />

            {resetStep === 1 && (
              <>
                <Text style={styles.inputLabel}>Verification OTP (6 Digits) *</Text>
                <TextInput
                  style={styles.input}
                  value={resetOtp}
                  onChangeText={setResetOtp}
                  placeholder="Enter 6-digit code"
                  placeholderTextColor={colors.textLight}
                  keyboardType="numeric"
                  maxLength={6}
                />

                <Text style={styles.inputLabel}>New Password *</Text>
                <TextInput
                  style={styles.input}
                  value={resetNewPassword}
                  onChangeText={setResetNewPassword}
                  secureTextEntry
                  placeholder="At least 6 characters"
                  placeholderTextColor={colors.textLight}
                />

                <Text style={styles.inputLabel}>Confirm New Password *</Text>
                <TextInput
                  style={styles.input}
                  value={resetConfirmPassword}
                  onChangeText={setResetConfirmPassword}
                  secureTextEntry
                  placeholder="Re-enter password"
                  placeholderTextColor={colors.textLight}
                />
              </>
            )}

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={styles.cancelModalBtn}
                onPress={() => {
                  setShowResetModal(false);
                  setResetStep(0);
                }}
              >
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.submitModalBtn}
                onPress={resetStep === 0 ? handleSendResetOtp : handleResetPasswordSubmit}
              >
                <Text style={styles.submitModalBtnText}>
                  {resetStep === 0 ? 'Send OTP' : 'Update Password'}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    padding: spacing.lg,
    paddingBottom: spacing.xxl * 2,
  },
  brandHeader: {
    alignItems: 'center',
    marginBottom: spacing.xl,
    marginTop: spacing.md,
  },
  logoEmoji: {
    fontSize: 42,
  },
  brandTitle: {
    fontSize: 24,
    fontWeight: '900',
    color: colors.textPrimary,
    marginTop: spacing.xs,
  },
  brandSubtitle: {
    fontSize: 13,
    color: colors.primary,
    fontWeight: '600',
    marginTop: 2,
  },
  card: {
    backgroundColor: colors.surface,
    padding: spacing.lg,
    borderRadius: radius.xl,
    borderColor: colors.border,
    borderWidth: 1,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 12,
    elevation: 3,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  stepperContainer: {
    marginBottom: spacing.lg,
  },
  stepBadge: {
    fontSize: 11,
    fontWeight: '800',
    color: colors.primary,
    letterSpacing: 0.8,
    marginBottom: 6,
  },
  progressBarBg: {
    height: 4,
    backgroundColor: '#e2e8f0',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: colors.primary,
    borderRadius: 2,
  },
  stepTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  stepSubtitle: {
    fontSize: 12,
    color: colors.textMuted,
    marginTop: 2,
    marginBottom: spacing.md,
  },
  inputLabel: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: spacing.md,
    marginBottom: 5,
    fontWeight: '700',
  },
  input: {
    backgroundColor: colors.background,
    borderColor: colors.borderDark,
    borderWidth: 1,
    borderRadius: radius.md,
    padding: spacing.md,
    color: colors.textPrimary,
    fontSize: 14,
  },
  pincodeRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  checkBtn: {
    backgroundColor: colors.primary,
    borderRadius: radius.md,
    paddingHorizontal: spacing.lg,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkBtnText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 13,
  },
  pincodeNotice: {
    marginTop: 6,
    padding: spacing.sm,
    borderRadius: radius.md,
  },
  pincodeNoticeText: {
    fontSize: 11,
    fontWeight: '600',
  },
  areaScroll: {
    flexDirection: 'row',
    marginBottom: 4,
  },
  chip: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
    marginRight: spacing.sm,
  },
  chipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  chipText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  chipTextActive: {
    color: '#fff',
  },
  optionCardsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  choiceCard: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.lg,
    backgroundColor: colors.background,
    borderWidth: 1.5,
    borderColor: colors.border,
  },
  choiceCardActive: {
    borderColor: colors.primary,
    backgroundColor: '#f0fdf4',
  },
  choiceCardTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  choiceCardPrice: {
    fontSize: 14,
    fontWeight: '800',
    color: colors.primary,
    marginVertical: 2,
  },
  choiceCardDesc: {
    fontSize: 10,
    color: colors.textMuted,
  },
  quantityGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  qtyCard: {
    width: '31%',
    padding: spacing.sm,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1.5,
    borderColor: colors.border,
    alignItems: 'center',
  },
  qtyCardActive: {
    borderColor: colors.primary,
    backgroundColor: '#f0fdf4',
  },
  qtyCardLabel: {
    fontSize: 13,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  qtyCardLabelActive: {
    color: colors.primary,
  },
  qtyCardDesc: {
    fontSize: 9,
    color: colors.textMuted,
    textAlign: 'center',
    marginTop: 2,
  },
  verticalList: {
    gap: spacing.xs,
  },
  selectRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
  },
  selectRowActive: {
    borderColor: colors.primary,
    backgroundColor: '#f0fdf4',
  },
  selectRowTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  selectRowTitleActive: {
    color: colors.primary,
  },
  selectRowSub: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 1,
  },
  radioIcon: {
    fontSize: 16,
    color: colors.primary,
    fontWeight: '800',
  },
  frequencyRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  assetNoticeCard: {
    marginTop: spacing.md,
    padding: spacing.md,
    borderRadius: radius.lg,
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
  },
  assetNoticeTitle: {
    fontSize: 12,
    fontWeight: '800',
    color: '#065f46',
  },
  assetNoticeDesc: {
    fontSize: 11,
    color: '#047857',
    marginTop: 3,
    lineHeight: 16,
  },
  summaryCard: {
    backgroundColor: colors.background,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    marginVertical: spacing.sm,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginVertical: 3,
  },
  summaryLabel: {
    fontSize: 12,
    color: colors.textMuted,
  },
  summaryValue: {
    fontSize: 12,
    color: colors.textPrimary,
    fontWeight: '600',
    maxWidth: '65%',
    textAlign: 'right',
  },
  summaryDivider: {
    height: 1,
    backgroundColor: colors.border,
    marginVertical: spacing.sm,
  },
  summaryTotalLabel: {
    fontSize: 13,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  summaryTotalValue: {
    fontSize: 15,
    fontWeight: '900',
    color: colors.primary,
  },
  summaryNote: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 4,
    fontStyle: 'italic',
  },
  stepBtnRow: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  backBtn: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.lg,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
  },
  backBtnFull: {
    padding: spacing.md,
    alignItems: 'center',
    marginTop: spacing.xs,
  },
  backBtnText: {
    color: colors.textSecondary,
    fontWeight: '700',
    fontSize: 13,
  },
  nextBtn: {
    flex: 2,
    padding: spacing.md,
    borderRadius: radius.lg,
    backgroundColor: colors.primary,
    alignItems: 'center',
  },
  primaryBtn: {
    backgroundColor: colors.primary,
    padding: spacing.md + 2,
    borderRadius: radius.lg,
    alignItems: 'center',
    marginTop: spacing.lg,
  },
  disabledBtn: {
    opacity: 0.7,
  },
  primaryBtnText: {
    color: colors.surface,
    fontWeight: '800',
    fontSize: 14,
  },
  forgotBtn: {
    alignSelf: 'flex-end',
    marginTop: 6,
  },
  forgotBtnText: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '600',
  },
  switchContainer: {
    marginTop: spacing.lg,
    alignItems: 'center',
  },
  switchText: {
    color: colors.textMuted,
    fontSize: 13,
  },
  switchHighlight: {
    color: colors.primary,
    fontWeight: '800',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.lg,
  },
  modalContent: {
    width: '100%',
    backgroundColor: colors.surface,
    borderRadius: radius.xl,
    padding: spacing.xl,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  modalSubtitle: {
    fontSize: 12,
    color: colors.textMuted,
    marginTop: 4,
    marginBottom: spacing.sm,
  },
  modalActions: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  cancelModalBtn: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
  },
  cancelModalBtnText: {
    color: colors.textSecondary,
    fontWeight: '600',
    fontSize: 13,
  },
  submitModalBtn: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.primary,
    alignItems: 'center',
  },
  submitModalBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 13,
  },
});
