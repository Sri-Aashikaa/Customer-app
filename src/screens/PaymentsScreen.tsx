import React from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useAuth } from '../context/AuthContext';
import { EmptyState } from '../components/EmptyState';
import { colors, spacing, radius } from '../theme/theme';

export const PaymentsScreen: React.FC = () => {
  const {
    customer,
    payments,
    cumulativeDeliveryAmount,
    nextPaymentDate,
    lastDeliveryDate,
    processPayment,
    isLoading,
  } = useAuth();

  if (!customer) return null;

  const handlePayNow = async () => {
    if (cumulativeDeliveryAmount <= 0) return;
    await processPayment(cumulativeDeliveryAmount);
  };

  const rate = customer.rate_per_liter || 65;
  const dailyAmount = rate * (customer.milk_quantity || 1.0);

  return (
    <View style={styles.container}>
      {/* NEXT PAYMENT DUE CARD */}
      <View style={[styles.card, styles.dueCard]}>
        <Text style={styles.cardTitle}>Monthly Billing & Payment</Text>

        <View style={styles.amountBox}>
          <Text style={styles.amountLabel}>CURRENT BILLING AMOUNT DUE</Text>
          <Text style={styles.amountValue}>₹{cumulativeDeliveryAmount.toFixed(2)}</Text>
          <Text style={styles.amountSub}>Calculated based on completed & dispatched deliveries</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Payment Due Date:</Text>
          <Text style={styles.infoValue}>{nextPaymentDate || 'End of Month'}</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Billing Cycle:</Text>
          <Text style={styles.infoValue}>
            {new Date().toLocaleString('en-IN', { month: 'long', year: 'numeric' })}
          </Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Daily Rate × Quantity:</Text>
          <Text style={styles.amberText}>
            ₹{rate} × {customer.milk_quantity}L = ₹{dailyAmount.toFixed(2)} / day
          </Text>
        </View>

        {lastDeliveryDate ? (
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Last Delivery Counted:</Text>
            <Text style={styles.blueText}>{lastDeliveryDate}</Text>
          </View>
        ) : null}

        {cumulativeDeliveryAmount > 0 && customer.payment_status !== 'PAID' ? (
          <TouchableOpacity
            style={[styles.primaryBtn, isLoading && styles.disabledBtn]}
            onPress={handlePayNow}
            disabled={isLoading}
            activeOpacity={0.8}
          >
            {isLoading ? (
              <ActivityIndicator color={colors.surface} size="small" />
            ) : (
              <Text style={styles.primaryBtnText}>
                Pay ₹{cumulativeDeliveryAmount.toFixed(2)} Now via UPI
              </Text>
            )}
          </TouchableOpacity>
        ) : (
          <View style={styles.paidBadgeBox}>
            <Text style={styles.paidBadgeText}>✓ Account Up to Date</Text>
          </View>
        )}
      </View>

      {/* PAYMENT HISTORY */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Payment History</Text>

        {payments.length > 0 ? (
          payments.map((p) => (
            <View key={p.id} style={styles.historyItem}>
              <View>
                <Text style={styles.historyTitle}>
                  {p.invoice_number} ({p.billing_period})
                </Text>
                <Text style={styles.historySub}>
                  Method: {p.payment_method} • Date: {p.due_date}
                </Text>
              </View>
              <Text
                style={[
                  styles.historyAmount,
                  { color: p.status === 'PAID' ? colors.statusGreen : colors.statusAmber },
                ]}
              >
                ₹{p.total_amount.toFixed(2)}
              </Text>
            </View>
          ))
        ) : (
          <EmptyState
            icon="💳"
            title="No Payment History"
            message="Your completed payment receipts will appear here after billing."
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
  dueCard: {
    borderLeftWidth: 4,
    borderLeftColor: colors.primary,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  amountBox: {
    alignItems: 'center',
    paddingVertical: spacing.md,
    backgroundColor: colors.primaryLight,
    borderRadius: radius.md,
    marginBottom: spacing.md,
  },
  amountLabel: {
    fontSize: 10,
    color: colors.textMuted,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  amountValue: {
    fontSize: 32,
    fontWeight: '800',
    color: colors.primary,
    marginTop: 2,
  },
  amountSub: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 4,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.sm + 2,
    borderTopWidth: 1,
    borderTopColor: colors.border,
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
  amberText: {
    color: colors.accent,
    fontSize: 12,
    fontWeight: '700',
  },
  blueText: {
    color: colors.secondary,
    fontSize: 12,
    fontWeight: '700',
  },
  primaryBtn: {
    backgroundColor: colors.primary,
    padding: spacing.md + 2,
    borderRadius: radius.lg,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  disabledBtn: {
    opacity: 0.7,
  },
  primaryBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 14,
  },
  paidBadgeBox: {
    backgroundColor: colors.primaryLight,
    padding: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  paidBadgeText: {
    color: colors.primary,
    fontWeight: '700',
    fontSize: 13,
  },
  historyItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  historyTitle: {
    fontWeight: '700',
    color: colors.textPrimary,
    fontSize: 13,
  },
  historySub: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 2,
  },
  historyAmount: {
    fontWeight: '700',
    fontSize: 14,
  },
});
