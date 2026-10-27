import React from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { DeliveryStatus } from '../types';
import { colors, spacing, radius } from '../theme/theme';

interface DeliveryCardProps {
  status: DeliveryStatus;
  quantity: number;
  timing: string;
}

export const DeliveryCard: React.FC<DeliveryCardProps> = ({ status, quantity, timing }) => {
  const getStatusLabel = (s: DeliveryStatus) => {
    switch (s) {
      case 'DELIVERED':
        return 'Delivered ✓';
      case 'NEAR_CUSTOMER':
        return 'Near You (Arriving Soon 🛵)';
      case 'OUT_FOR_DELIVERY':
        return 'Out for Delivery';
      case 'IN_TRANSIT':
      case 'ASSIGNED':
        return 'In Transit';
      case 'FAILED':
        return 'Delivery Failed';
      case 'CANCELLED':
        return 'Delivery Cancelled';
      default:
        return 'Scheduled';
    }
  };

  const isStepActive = (step: string) => {
    if (status === 'CANCELLED' || status === 'FAILED') return false;
    switch (step) {
      case 'SCHEDULED':
        return true;
      case 'IN_TRANSIT':
        return ['IN_TRANSIT', 'ASSIGNED', 'OUT_FOR_DELIVERY', 'NEAR_CUSTOMER', 'DELIVERED'].includes(status);
      case 'OUT_FOR_DELIVERY':
        return ['OUT_FOR_DELIVERY', 'NEAR_CUSTOMER', 'DELIVERED'].includes(status);
      case 'NEAR_CUSTOMER':
        return ['NEAR_CUSTOMER', 'DELIVERED'].includes(status);
      case 'DELIVERED':
        return status === 'DELIVERED';
      default:
        return false;
    }
  };

  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Text style={styles.cardTitle}>Today's Delivery</Text>
        <View style={styles.statusBadge}>
          <Text style={styles.statusBadgeText}>{getStatusLabel(status)}</Text>
        </View>
      </View>

      <View style={styles.metricRow}>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Milk Quantity</Text>
          <Text style={styles.metricVal}>
            {quantity}L ({quantity >= 1.0 ? '1.0L Bottle' : '0.5L Bottle'})
          </Text>
        </View>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Delivery Window</Text>
          <Text style={styles.metricVal}>{timing || '5:00 AM - 9:30 AM'}</Text>
        </View>
      </View>

      <View style={styles.trackerContainer}>
        <Text style={styles.trackerTitle}>Delivery Progress</Text>
        <View style={styles.trackerStepRow}>
          <Text style={isStepActive('SCHEDULED') ? styles.stepActive : styles.stepPending}>
            {isStepActive('SCHEDULED') ? '✓ Scheduled' : '⚪ Scheduled'}
          </Text>
          <Text style={isStepActive('IN_TRANSIT') ? styles.stepActive : styles.stepPending}>
            {isStepActive('IN_TRANSIT') ? '✓ In Transit' : '⚪ In Transit'}
          </Text>
          <Text style={isStepActive('OUT_FOR_DELIVERY') ? styles.stepActive : styles.stepPending}>
            {isStepActive('OUT_FOR_DELIVERY') ? '✓ Out for Delivery' : '⚪ Dispatched'}
          </Text>
          <Text style={isStepActive('NEAR_CUSTOMER') ? styles.stepActive : styles.stepPending}>
            {isStepActive('NEAR_CUSTOMER') ? '✓ Near You' : '⚪ Near You'}
          </Text>
          <Text style={isStepActive('DELIVERED') ? styles.stepActive : styles.stepPending}>
            {isStepActive('DELIVERED') ? '✓ Delivered' : '⚪ Delivered'}
          </Text>
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
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  statusBadge: {
    backgroundColor: colors.primaryLight,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: radius.full,
    borderWidth: 1,
    borderColor: colors.primaryBorder,
  },
  statusBadgeText: {
    color: colors.primary,
    fontSize: 11,
    fontWeight: '700',
  },
  metricRow: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.md,
  },
  metricBox: {
    flex: 1,
    backgroundColor: colors.background,
    padding: spacing.md,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
  },
  metricLabel: {
    color: colors.textMuted,
    fontSize: 10,
    fontWeight: '600',
  },
  metricVal: {
    color: colors.textPrimary,
    fontSize: 13,
    fontWeight: '700',
    marginTop: 2,
  },
  trackerContainer: {
    marginTop: spacing.md,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  trackerTitle: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '700',
    marginBottom: spacing.sm,
  },
  trackerStepRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    gap: 4,
  },
  stepActive: {
    color: colors.primary,
    fontSize: 11,
    fontWeight: '700',
  },
  stepPending: {
    color: colors.textLight,
    fontSize: 11,
  },
});
