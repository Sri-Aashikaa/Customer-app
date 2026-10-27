import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { useAuth } from '../context/AuthContext';
import { CancellationShift } from '../types';
import { EmptyState } from '../components/EmptyState';
import { colors, spacing, radius } from '../theme/theme';

export const CancellationScreen: React.FC = () => {
  const { cancellations, requestCancellation, isLoading } = useAuth();

  const [date, setDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [shift, setShift] = useState<CancellationShift>('MORNING');
  const [reason, setReason] = useState<string>('');

  const handleSubmit = async () => {
    if (!date.trim() || !reason.trim()) {
      Alert.alert('Required Fields', 'Please specify a date and enter the reason for cancellation.');
      return;
    }

    const success = await requestCancellation(date.trim(), shift, reason.trim());
    if (success) {
      setReason('');
    }
  };

  return (
    <View style={styles.container}>
      {/* CANCELLATION REQUEST FORM */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Pause Milk Delivery</Text>

        <Text style={styles.inputLabel}>Cancellation Date *</Text>
        <TextInput
          style={styles.input}
          value={date}
          onChangeText={setDate}
          placeholder="YYYY-MM-DD"
          placeholderTextColor={colors.textLight}
        />

        <Text style={styles.inputLabel}>Select Delivery Batch / Shift *</Text>
        <View style={styles.shiftRow}>
          <TouchableOpacity
            onPress={() => setShift('MORNING')}
            style={[styles.shiftChip, shift === 'MORNING' && styles.shiftChipMorning]}
            activeOpacity={0.8}
          >
            <Text style={[styles.shiftTitle, shift === 'MORNING' && styles.shiftTextActive]}>
              🌅 Morning
            </Text>
            <Text style={[styles.shiftSub, shift === 'MORNING' && styles.shiftSubActive]}>
              5:00 - 9:30 AM
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => setShift('EVENING')}
            style={[styles.shiftChip, shift === 'EVENING' && styles.shiftChipEvening]}
            activeOpacity={0.8}
          >
            <Text style={[styles.shiftTitle, shift === 'EVENING' && styles.shiftTextActive]}>
              🌇 Evening
            </Text>
            <Text style={[styles.shiftSub, shift === 'EVENING' && styles.shiftSubActive]}>
              3:00 - 7:30 PM
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => setShift('BOTH')}
            style={[styles.shiftChip, shift === 'BOTH' && styles.shiftChipBoth]}
            activeOpacity={0.8}
          >
            <Text style={[styles.shiftTitle, shift === 'BOTH' && styles.shiftTextActive]}>
              ☀️ Full Day
            </Text>
            <Text style={[styles.shiftSub, shift === 'BOTH' && styles.shiftSubActive]}>
              Both Shifts
            </Text>
          </TouchableOpacity>
        </View>

        <Text style={styles.inputLabel}>Reason for Cancellation *</Text>
        <TextInput
          style={styles.input}
          value={reason}
          onChangeText={setReason}
          placeholder="e.g. Out of town / Surplus milk"
          placeholderTextColor={colors.textLight}
        />

        <TouchableOpacity
          style={[styles.primaryBtn, isLoading && styles.disabledBtn]}
          onPress={handleSubmit}
          disabled={isLoading}
          activeOpacity={0.8}
        >
          {isLoading ? (
            <ActivityIndicator color={colors.surface} size="small" />
          ) : (
            <Text style={styles.primaryBtnText}>Submit Pause Request</Text>
          )}
        </TouchableOpacity>

        <Text style={styles.noticeText}>
          ⚠️ Cutoff Rule: Please submit requests before 8:00 PM for next morning's delivery.
        </Text>
      </View>

      {/* CANCELLATION HISTORY */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Recent Pause Requests</Text>

        {cancellations.length > 0 ? (
          cancellations.map((item) => (
            <View key={item.id} style={styles.historyItem}>
              <View style={styles.historyLeft}>
                <Text style={styles.historyDate}>
                  {item.date} {item.day ? `(${item.day})` : ''}
                </Text>
                <Text style={styles.historyShift}>
                  {item.shift === 'MORNING'
                    ? '🌅 Morning Batch (5:00 - 9:30 AM)'
                    : item.shift === 'EVENING'
                    ? '🌇 Evening Batch (3:00 - 7:30 PM)'
                    : item.shift === 'BOTH'
                    ? '☀️ Full Day (Both Batches)'
                    : item.time}
                </Text>
                <Text style={styles.historyReason}>{item.reason}</Text>
              </View>
              <Text
                style={[
                  styles.statusBadge,
                  { color: item.status === 'APPROVED' ? colors.statusGreen : colors.statusAmber },
                ]}
              >
                {item.status}
              </Text>
            </View>
          ))
        ) : (
          <EmptyState
            icon="🚫"
            title="No Cancellation Requests"
            message="You have no active pause requests. Your daily milk delivery will arrive as scheduled."
          />
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: spacing.lg,
  },
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
    marginBottom: spacing.sm,
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
  shiftRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.xs,
  },
  shiftChip: {
    flex: 1,
    paddingVertical: spacing.md,
    paddingHorizontal: 4,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  shiftChipMorning: {
    backgroundColor: colors.primary,
    borderColor: colors.primaryDark,
  },
  shiftChipEvening: {
    backgroundColor: colors.secondary,
    borderColor: '#4338ca',
  },
  shiftChipBoth: {
    backgroundColor: colors.accent,
    borderColor: '#b45309',
  },
  shiftTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textSecondary,
  },
  shiftTextActive: {
    color: colors.surface,
  },
  shiftSub: {
    fontSize: 9,
    color: colors.textMuted,
    marginTop: 2,
  },
  shiftSubActive: {
    color: colors.surface,
    opacity: 0.9,
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
    fontSize: 14,
  },
  noticeText: {
    fontSize: 11,
    color: colors.accent,
    marginTop: spacing.md,
    lineHeight: 16,
  },
  historyItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  historyLeft: {
    flex: 1,
  },
  historyDate: {
    fontWeight: '700',
    color: colors.textPrimary,
    fontSize: 13,
  },
  historyShift: {
    color: colors.primary,
    fontWeight: '600',
    fontSize: 11,
    marginTop: 2,
  },
  historyReason: {
    color: colors.textMuted,
    fontSize: 12,
    marginTop: 2,
  },
  statusBadge: {
    fontWeight: '700',
    fontSize: 12,
  },
});
