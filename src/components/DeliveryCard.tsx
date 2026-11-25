import React from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { DeliveryStatus } from '../types';
import { colors, spacing, radius } from '../theme/theme';

interface DeliveryCardProps {
  status: DeliveryStatus;
  quantity: number;
  timing: string;
  onReportIssue?: () => void;
  onPause?: () => void;
  onResume?: () => void;
}

export const DeliveryCard: React.FC<DeliveryCardProps> = ({
  status,
  quantity,
  timing,
  onReportIssue,
  onPause,
  onResume,
}) => {
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
      case 'PAUSED':
        return 'Paused / On Hold ⏸️';
      case 'FAILED':
        return 'Delivery Failed';
      case 'CANCELLED':
        return 'Delivery Cancelled';
      default:
        return 'Scheduled';
    }
  };

  const isStepActive = (step: string) => {
    if (status === 'CANCELLED' || status === 'FAILED' || status === 'PAUSED') return false;
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
        <View style={[styles.statusBadge, status === 'PAUSED' && styles.statusBadgePaused]}>
          <Text style={[styles.statusBadgeText, status === 'PAUSED' && styles.statusBadgeTextPaused]}>
            {getStatusLabel(status)}
          </Text>
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

      {/* ACTION BUTTONS (REPORT ISSUE / PAUSE / RESUME) */}
      <View style={styles.actionsContainer}>
        {status === 'DELIVERED' && onReportIssue && (
          <TouchableOpacity style={styles.reportIssueBtn} onPress={onReportIssue} activeOpacity={0.8}>
            <Text style={styles.reportIssueBtnText}>⚠️ Report Bottle / Quality Issue</Text>
          </TouchableOpacity>
        )}

        {status === 'SCHEDULED' && onPause && (
          <TouchableOpacity style={styles.pauseOrderBtn} onPress={onPause} activeOpacity={0.8}>
            <Text style={styles.pauseOrderBtnText}>⏸️ Hold / Pause Today's Delivery</Text>
          </TouchableOpacity>
        )}

        {status === 'PAUSED' && onResume && (
          <TouchableOpacity style={styles.resumeOrderBtn} onPress={onResume} activeOpacity={0.8}>
            <Text style={styles.resumeOrderBtnText}>▶️ Resume Today's Delivery</Text>
          </TouchableOpacity>
        )}
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
  statusBadgePaused: {
    backgroundColor: '#fef3c7',
    borderColor: '#f59e0b',
  },
  statusBadgeTextPaused: {
    color: '#b45309',
  },
  actionsContainer: {
    marginTop: spacing.md,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    gap: spacing.xs,
  },
  reportIssueBtn: {
    backgroundColor: '#fff7ed',
    borderWidth: 1,
    borderColor: '#fdba74',
    paddingVertical: 8,
    paddingHorizontal: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  reportIssueBtnText: {
    color: '#c2410c',
    fontSize: 12,
    fontWeight: '700',
  },
  pauseOrderBtn: {
    backgroundColor: '#fef3c7',
    borderWidth: 1,
    borderColor: '#fcd34d',
    paddingVertical: 8,
    paddingHorizontal: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  pauseOrderBtnText: {
    color: '#b45309',
    fontSize: 12,
    fontWeight: '700',
  },
  resumeOrderBtn: {
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
    paddingVertical: 8,
    paddingHorizontal: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  resumeOrderBtnText: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '700',
  },
});
