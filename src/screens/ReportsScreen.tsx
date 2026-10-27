import React, { useState } from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { colors, spacing, radius } from '../theme/theme';

export const ReportsScreen: React.FC = () => {
  const { customer, deliveries, cancellations } = useAuth();
  const [filter, setFilter] = useState<'MONTHLY' | 'WEEKLY' | 'YEARLY'>('MONTHLY');

  if (!customer) return null;

  const totalConsumedLiters = deliveries.reduce((sum, d) => sum + (d.quantity || 1.0), 0) || (customer.milk_quantity * 30);
  const totalCompletedDays = deliveries.length || 30;
  const approvedCancellationsCount = cancellations.filter(c => c.status === 'APPROVED').length;
  const totalBilled = totalConsumedLiters * 65;

  return (
    <View style={styles.card}>
      <Text style={styles.cardTitle}>Milk Consumption Reports</Text>

      {/* FILTER CHIPS */}
      <View style={styles.filterRow}>
        <TouchableOpacity
          style={[styles.chip, filter === 'MONTHLY' && styles.chipActive]}
          onPress={() => setFilter('MONTHLY')}
          activeOpacity={0.7}
        >
          <Text style={[styles.chipText, filter === 'MONTHLY' && styles.chipTextActive]}>
            Monthly
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.chip, filter === 'WEEKLY' && styles.chipActive]}
          onPress={() => setFilter('WEEKLY')}
          activeOpacity={0.7}
        >
          <Text style={[styles.chipText, filter === 'WEEKLY' && styles.chipTextActive]}>
            Weekly
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.chip, filter === 'YEARLY' && styles.chipActive]}
          onPress={() => setFilter('YEARLY')}
          activeOpacity={0.7}
        >
          <Text style={[styles.chipText, filter === 'YEARLY' && styles.chipTextActive]}>
            Yearly
          </Text>
        </TouchableOpacity>
      </View>

      {/* METRIC BREAKDOWN */}
      <View style={styles.metricList}>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Total Milk Consumed:</Text>
          <Text style={styles.infoValue}>{totalConsumedLiters.toFixed(1)} Liters</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Total Deliveries Completed:</Text>
          <Text style={styles.infoValue}>{totalCompletedDays} Days</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Approved Cancellations:</Text>
          <Text style={styles.infoValue}>{approvedCancellationsCount} Days</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Total Billed Amount:</Text>
          <Text style={styles.highlightGreen}>₹{totalBilled.toFixed(2)}</Text>
        </View>
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
  },
  filterRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginVertical: spacing.md,
  },
  chip: {
    backgroundColor: colors.background,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: radius.full,
    borderWidth: 1,
    borderColor: colors.border,
  },
  chipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primaryDark,
  },
  chipText: {
    color: colors.textMuted,
    fontSize: 12,
  },
  chipTextActive: {
    color: colors.surface,
    fontWeight: '700',
  },
  metricList: {
    gap: spacing.xs,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
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
  highlightGreen: {
    color: colors.statusGreen,
    fontSize: 14,
    fontWeight: '700',
  },
});
