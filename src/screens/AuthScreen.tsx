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
import { colors, spacing, radius } from '../theme/theme';

export const AuthScreen: React.FC = () => {
  const { login, register, resetPasswordByMobile, isLoading } = useAuth();
  const [mode, setMode] = useState<'LOGIN' | 'REGISTER'>('LOGIN');

  // Login form state
  const [loginId, setLoginId] = useState<string>('');
  const [loginPassword, setLoginPassword] = useState<string>('');

  // Password reset modal state
  const [showResetModal, setShowResetModal] = useState<boolean>(false);
  const [resetInputId, setResetInputId] = useState<string>('');
  const [resetNewPassword, setResetNewPassword] = useState<string>('');
  const [resetConfirmPassword, setResetConfirmPassword] = useState<string>('');

  // Register form state
  const [regForm, setRegForm] = useState({
    name: '',
    mobile: '',
    alternate_mobile: '',
    customer_id: '',
    password: '',
    address: '',
    area: 'Anna Nagar',
    city: 'Chennai',
    district: 'Chennai',
    state: 'Tamil Nadu',
    pincode: '600040',
    latitude: '13.0827',
    longitude: '80.2707',
  });

  const handleLoginSubmit = async () => {
    if (!loginId.trim() || !loginPassword.trim()) {
      Alert.alert('Required Fields', 'Please enter your Mobile Number or Customer ID and Password.');
      return;
    }
    await login(loginId.trim(), loginPassword.trim());
  };

  const handleRegisterSubmit = async () => {
    if (!regForm.name.trim() || !regForm.mobile.trim() || !regForm.password.trim() || !regForm.address.trim()) {
      Alert.alert('Missing Fields', 'Please complete all required fields (Full Name, Mobile, Password, and Address).');
      return;
    }

    if (regForm.mobile.trim().length < 10) {
      Alert.alert('Invalid Mobile', 'Please enter a valid 10-digit mobile number.');
      return;
    }

    // Check Pincode Serviceability
    const pin = regForm.pincode.trim();
    const isServiceable = await api.isPincodeServiceable(pin);
    if (!isServiceable) {
      await api.recordUnserviceableLocationRequest({
        pincode: pin || 'Unspecified',
        areaName: regForm.area,
        city: 'Chennai',
        customerName: regForm.name,
        customerMobile: regForm.mobile,
        fullAddress: regForm.address,
      });
      Alert.alert(
        'Delivery Notice',
        `“We are not available at your location yet, but we will quickly reach to your location”\n\nYour location request for Pincode ${pin} has been recorded in our operations panel. We will notify you when delivery opens in your area!`,
        [{ text: 'Understood, Thank You!' }]
      );
      return;
    }

    await register(regForm);
  };

  const handleResetPasswordSubmit = async () => {
    if (!resetInputId.trim() || !resetNewPassword.trim()) {
      Alert.alert('Missing Fields', 'Please enter Mobile Number / Customer ID and your New Password.');
      return;
    }

    if (resetNewPassword !== resetConfirmPassword) {
      Alert.alert('Password Mismatch', 'New Password and Confirm Password do not match.');
      return;
    }

    const ok = await resetPasswordByMobile(resetInputId.trim(), resetNewPassword.trim());
    if (ok) {
      setShowResetModal(false);
      setResetInputId('');
      setResetNewPassword('');
      setResetConfirmPassword('');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        {/* BRAND HEADER */}
        <View style={styles.brandHeader}>
          <Text style={styles.logoEmoji}>🥛</Text>
          <Text style={styles.brandTitle}>Amutham Raw Milk</Text>
          <Text style={styles.brandSubtitle}>Fresh Farm Milk Delivered Daily</Text>
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
              placeholder="e.g. +91 98401 23456 or CUST-1001"
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

            <TouchableOpacity
              onPress={() => setShowResetModal(true)}
              style={styles.forgotBtn}
            >
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

            <TouchableOpacity onPress={() => setMode('REGISTER')} style={styles.switchContainer}>
              <Text style={styles.switchText}>
                New Customer? <Text style={styles.switchHighlight}>Register Account</Text>
              </Text>
            </TouchableOpacity>
          </View>
        ) : (
          /* REGISTRATION FORM */
          <View style={styles.card}>
            <Text style={styles.cardTitle}>New Customer Registration</Text>

            <Text style={styles.inputLabel}>Full Name *</Text>
            <TextInput
              style={styles.input}
              value={regForm.name}
              onChangeText={(v) => setRegForm({ ...regForm, name: v })}
              placeholder="e.g. Ramanathan K"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Primary Mobile Number *</Text>
            <TextInput
              style={styles.input}
              value={regForm.mobile}
              onChangeText={(v) => setRegForm({ ...regForm, mobile: v })}
              placeholder="+91 98401 23456"
              placeholderTextColor={colors.textLight}
              keyboardType="phone-pad"
            />

            <Text style={styles.inputLabel}>Alternate Mobile Number (Family / WhatsApp)</Text>
            <TextInput
              style={styles.input}
              value={regForm.alternate_mobile}
              onChangeText={(v) => setRegForm({ ...regForm, alternate_mobile: v })}
              placeholder="e.g. +91 98409 87654 (Optional)"
              placeholderTextColor={colors.textLight}
              keyboardType="phone-pad"
            />

            <Text style={styles.inputLabel}>Customer ID (Optional - Auto-assigned if blank)</Text>
            <TextInput
              style={styles.input}
              value={regForm.customer_id}
              onChangeText={(v) => setRegForm({ ...regForm, customer_id: v })}
              placeholder="e.g. AMU-A001"
              placeholderTextColor={colors.textLight}
              autoCapitalize="characters"
            />

            <Text style={styles.inputLabel}>Create Password *</Text>
            <TextInput
              style={styles.input}
              value={regForm.password}
              onChangeText={(v) => setRegForm({ ...regForm, password: v })}
              secureTextEntry
              placeholder="Set account password"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Street Address *</Text>
            <TextInput
              style={styles.input}
              value={regForm.address}
              onChangeText={(v) => setRegForm({ ...regForm, address: v })}
              placeholder="Door No, Flat Name, Street"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Area & Pincode</Text>
            <View style={styles.rowInputs}>
              <TextInput
                style={[styles.input, { flex: 1 }]}
                value={regForm.area}
                onChangeText={(v) => setRegForm({ ...regForm, area: v })}
                placeholder="Area"
                placeholderTextColor={colors.textLight}
              />
              <TextInput
                style={[styles.input, { flex: 1 }]}
                value={regForm.pincode}
                onChangeText={(v) => setRegForm({ ...regForm, pincode: v })}
                placeholder="600040"
                placeholderTextColor={colors.textLight}
                keyboardType="numeric"
              />
            </View>

            <TouchableOpacity
              style={[styles.primaryBtn, isLoading && styles.disabledBtn]}
              onPress={handleRegisterSubmit}
              disabled={isLoading}
              activeOpacity={0.8}
            >
              {isLoading ? (
                <ActivityIndicator color={colors.surface} size="small" />
              ) : (
                <Text style={styles.primaryBtnText}>Register Account</Text>
              )}
            </TouchableOpacity>

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
            <Text style={styles.modalSubtitle}>Enter your Mobile Number or Customer ID to reset your password on the server.</Text>

            <Text style={styles.inputLabel}>Mobile Number or Customer ID *</Text>
            <TextInput
              style={styles.input}
              value={resetInputId}
              onChangeText={setResetInputId}
              placeholder="e.g. +91 98401 23456 or CUST-1001"
              placeholderTextColor={colors.textLight}
              autoCapitalize="none"
            />

            <Text style={styles.inputLabel}>New Password *</Text>
            <TextInput
              style={styles.input}
              value={resetNewPassword}
              onChangeText={setResetNewPassword}
              secureTextEntry
              placeholder="Enter new password"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Confirm New Password *</Text>
            <TextInput
              style={styles.input}
              value={resetConfirmPassword}
              onChangeText={setResetConfirmPassword}
              secureTextEntry
              placeholder="Confirm new password"
              placeholderTextColor={colors.textLight}
            />

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={styles.cancelModalBtn}
                onPress={() => setShowResetModal(false)}
              >
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.submitModalBtn, isLoading && styles.disabledBtn]}
                onPress={handleResetPasswordSubmit}
                disabled={isLoading}
              >
                {isLoading ? (
                  <ActivityIndicator color={colors.surface} size="small" />
                ) : (
                  <Text style={styles.submitModalBtnText}>Reset Password</Text>
                )}
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
    padding: spacing.xl,
    justifyContent: 'center',
  },
  brandHeader: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  logoEmoji: {
    fontSize: 48,
  },
  brandTitle: {
    fontSize: 24,
    fontWeight: '800',
    color: colors.textPrimary,
    marginTop: spacing.sm,
  },
  brandSubtitle: {
    fontSize: 13,
    color: colors.textMuted,
    marginTop: 2,
  },
  card: {
    backgroundColor: colors.surface,
    padding: spacing.lg,
    borderRadius: radius.xl,
    borderColor: colors.border,
    borderWidth: 1,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  inputLabel: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: spacing.md,
    marginBottom: 4,
    fontWeight: '600',
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
  forgotBtn: {
    alignSelf: 'flex-end',
    marginTop: 6,
  },
  forgotBtnText: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '600',
  },
  rowInputs: {
    flexDirection: 'row',
    gap: spacing.sm,
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
    fontWeight: '700',
    fontSize: 15,
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
    fontWeight: '700',
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
