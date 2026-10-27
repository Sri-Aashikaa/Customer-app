import React from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { colors, spacing, radius } from '../theme/theme';

export const ScheduleScreen: React.FC = () => {
  const { customer } = useAuth();

  if (!customer) return null;

  const tomorrow = new Date(Date.now() + 86400000).toLocaleDateString('en-IN', {
    month: 'short',
    day: 'numeric',
    weekday: 'short',
  });

  return (
    <View style={styles.card}>
      <Text style={styles.cardTitle}>Delivery Schedule & Timings</Text>

      <View style={styles.infoRow}>
        <Text style={styles.infoLabel}>Subscription Days:</Text>
        <Text style={styles.infoValue}>Everyday (Monday - Sunday)</Text>
      </View>

      <View style={styles.infoRow}>
        <Text style={styles.infoLabel}>Time Slot Window:</Text>
        <Text style={styles.infoValue}>{customer.delivery_timing || '5:00 AM - 9:30 AM'}</Text>
      </View>

      <View style={styles.infoRow}>
        <Text style={styles.infoLabel}>Next Scheduled Delivery:</Text>
        <Text style={styles.highlightValue}>
          Tomorrow ({tomorrow}) @ {customer.delivery_timing || '5:00 AM - 9:30 AM'}
        </Text>
      </View>

      <View style={styles.infoRow}>
        <Text style={styles.infoLabel}>Daily Quantity:</Text>
        <Text style={styles.infoValue}>{customer.milk_quantity} Liters</Text>
      </View>

      <View style={styles.infoRow}>
        <Text style={styles.infoLabel}>Delivery Location:</Text>
        <Text style={styles.infoValue}>{customer.area || 'Chennai'}</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    padding: spacing.lg,
    borderRadius: radius.lg,
    borderColor: colors.border,
    borderWidth: 1,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.sm + 2,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  infoLabel: {
    color: colors.textMuted,
    fontSize: 13,
  },
  infoValue: {
    color: colors.textPrimary,
    fontSize: 13,
    fontWeight: '700',
  },
  highlightValue: {
    color: colors.primary,
    fontSize: 13,
    fontWeight: '700',
  },
});
