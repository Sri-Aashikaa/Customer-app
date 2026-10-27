import React from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { colors, spacing, radius } from '../theme/theme';

export const Header: React.FC = () => {
  const { customer, logout } = useAuth();

  if (!customer) return null;

  return (
    <View style={styles.headerContainer}>
      <View style={styles.profileSection}>
        <View style={styles.logoBadge}>
          <Text style={styles.logoEmoji}>🥛</Text>
        </View>
        <View style={styles.textContainer}>
          <Text style={styles.customerName}>{customer.name}</Text>
          <Text style={styles.customerSub}>
            ID: {customer.customer_id} • {customer.area || 'Chennai'}
          </Text>
        </View>
      </View>
      <TouchableOpacity style={styles.logoutBtn} onPress={logout} activeOpacity={0.7}>
        <Text style={styles.logoutBtnText}>Logout</Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  headerContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    backgroundColor: colors.surface,
  },
  profileSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm + 2,
  },
  logoBadge: {
    width: 38,
    height: 38,
    borderRadius: radius.md,
    backgroundColor: colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  logoEmoji: {
    fontSize: 18,
  },
  textContainer: {
    justifyContent: 'center',
  },
  customerName: {
    color: colors.textPrimary,
    fontWeight: '700',
    fontSize: 15,
  },
  customerSub: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 1,
  },
  logoutBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    backgroundColor: colors.background,
    borderRadius: radius.sm,
    borderWidth: 1,
    borderColor: colors.border,
  },
  logoutBtnText: {
    color: colors.textSecondary,
    fontSize: 12,
    fontWeight: '600',
  },
});
