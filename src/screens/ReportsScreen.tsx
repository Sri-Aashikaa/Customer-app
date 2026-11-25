import React, { useState, useMemo } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Share,
  Alert,
  Linking
} from 'react-native';
import { useAuth } from '../context/AuthContext';
import { colors, spacing, radius, shadow } from '../theme/theme';
import { EmptyState } from '../components/EmptyState';

type PeriodFilter = 'THIS_MONTH' | 'LAST_MONTH' | 'LAST_30_DAYS' | 'ALL_TIME';
type SubTab = 'DELIVERIES' | 'PAYMENTS' | 'ASSETS';

export const ReportsScreen: React.FC = () => {
  const {
    customer,
    deliveries,
    payments,
    cancellations,
    assets,
    cumulativeDeliveryAmount,
    setActiveTab,
    pauseOrder,
    resumeOrder
  } = useAuth();
  const [period, setPeriod] = useState<PeriodFilter>('THIS_MONTH');
  const [subTab, setSubTab] = useState<SubTab>('DELIVERIES');

  if (!customer) return null;

  // Calculate start & end ISO dates for the selected filter
  const { startDate, endDate, periodLabel } = useMemo(() => {
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    if (period === 'THIS_MONTH') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
      const monthName = now.toLocaleString('en-IN', { month: 'long', year: 'numeric' });
      return { startDate: start, endDate: todayStr, periodLabel: monthName };
    }
    if (period === 'LAST_MONTH') {
      const start = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString().split('T')[0];
      const end = new Date(now.getFullYear(), now.getMonth(), 0).toISOString().split('T')[0];
      const monthName = new Date(now.getFullYear(), now.getMonth() - 1, 1).toLocaleString('en-IN', { month: 'long', year: 'numeric' });
      return { startDate: start, endDate: end, periodLabel: monthName };
    }
    if (period === 'LAST_30_DAYS') {
      const thirtyDaysAgo = new Date(now);
      thirtyDaysAgo.setDate(now.getDate() - 29);
      return {
        startDate: thirtyDaysAgo.toISOString().split('T')[0],
        endDate: todayStr,
        periodLabel: 'Last 30 Days'
      };
    }
    return { startDate: '2020-01-01', endDate: '2099-12-31', periodLabel: 'All Time' };
  }, [period]);

  // Dynamically filter data
  const filteredDeliveries = useMemo(() => {
    return deliveries.filter(d => {
      if (!d.date) return true;
      return d.date >= startDate && d.date <= endDate;
    });
  }, [deliveries, startDate, endDate]);

  const filteredPayments = useMemo(() => {
    return payments.filter(p => {
      const dt = p.due_date || '';
      if (!dt) return true;
      return dt >= startDate && dt <= endDate;
    });
  }, [payments, startDate, endDate]);

  const filteredCancellations = useMemo(() => {
    return cancellations.filter(c => {
      const dt = c.date || '';
      if (!dt) return true;
      return dt >= startDate && dt <= endDate;
    });
  }, [cancellations, startDate, endDate]);

  // Metrics computation
  const deliveredItems = filteredDeliveries.filter(d => d.status === 'DELIVERED');
  const totalConsumedLiters = deliveredItems.reduce((sum, d) => sum + (Number(d.quantity) || 1.0), 0);
  const totalCompletedDays = deliveredItems.length;
  const approvedPausesCount = filteredCancellations.filter(c => c.status === 'APPROVED').length;

  const rate = customer.rate_per_liter || 65;
  const totalBilled = deliveredItems.reduce((sum, d) => sum + (Number(d.total_amount) || (Number(d.quantity) * rate)), 0);
  const totalPaid = filteredPayments.filter(p => p.status === 'PAID').reduce((sum, p) => sum + (Number(p.paid_amount) || Number(p.total_amount) || 0), 0);
  const balanceDue = Math.max(0, totalBilled - totalPaid);

  // Bottles tracking
  const bottlesHeld = customer.empty_bottles_held || 2;
  const bottlesReturned = customer.bottles_returned || 28;
  const depositHeld = 500;

  // Share audit report handler
  const handleShareReport = async () => {
    try {
      const reportText = [
        `🥛 *SRI AASHIKAA RAW COW MILK — CONSUMPTION REPORT*`,
        `Customer: ${customer.name} (${customer.customer_id || 'ID'})`,
        `Period: ${periodLabel}`,
        `----------------------------------------`,
        `• Milk Delivered: ${totalConsumedLiters.toFixed(1)} Liters`,
        `• Successful Deliveries: ${totalCompletedDays} Days`,
        `• Authorized Pauses: ${approvedPausesCount} Days`,
        `• Total Billed Charges: ₹${totalBilled.toFixed(2)}`,
        `• Total Payments Paid: ₹${totalPaid.toFixed(2)}`,
        `• Outstanding Due: ₹${balanceDue.toFixed(2)}`,
        `• Glass Bottles with Customer: ${bottlesHeld} units`,
        `----------------------------------------`,
        `Generated from Sri Aashikaa Customer Portal on ${new Date().toLocaleDateString('en-IN')}`
      ].join('\n');

      await Share.share({
        message: reportText,
        title: `Sri Aashikaa Milk Consumption Statement - ${periodLabel}`
      });
    } catch (err: any) {
      Alert.alert('Error sharing statement', err?.message);
    }
  };

  const handleOpenInvoice = (url?: string) => {
    if (!url) {
      Alert.alert('Invoice Note', 'Invoice PDF generation is in progress for this subscription cycle.');
      return;
    }
    Linking.openURL(url).catch(() => {
      Alert.alert('Unable to open URL', url);
    });
  };

  return (
    <View style={styles.container}>
      {/* HEADER CARD */}
      <View style={styles.headerCard}>
        <View style={styles.headerTop}>
          <View>
            <Text style={styles.title}>Milk Consumption & Audit</Text>
            <Text style={styles.subtitle}>{periodLabel} • Doorstep Delivery Log</Text>
          </View>

          <TouchableOpacity
            style={styles.shareBtn}
            onPress={handleShareReport}
            activeOpacity={0.8}
          >
            <Text style={styles.shareBtnText}>Share Report</Text>
          </TouchableOpacity>
        </View>

        {/* PERIOD FILTER PILLS */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
          <TouchableOpacity
            style={[styles.chip, period === 'THIS_MONTH' && styles.chipActive]}
            onPress={() => setPeriod('THIS_MONTH')}
            activeOpacity={0.7}
          >
            <Text style={[styles.chipText, period === 'THIS_MONTH' && styles.chipTextActive]}>
              This Month
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.chip, period === 'LAST_MONTH' && styles.chipActive]}
            onPress={() => setPeriod('LAST_MONTH')}
            activeOpacity={0.7}
          >
            <Text style={[styles.chipText, period === 'LAST_MONTH' && styles.chipTextActive]}>
              Last Month
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.chip, period === 'LAST_30_DAYS' && styles.chipActive]}
            onPress={() => setPeriod('LAST_30_DAYS')}
            activeOpacity={0.7}
          >
            <Text style={[styles.chipText, period === 'LAST_30_DAYS' && styles.chipTextActive]}>
              Last 30 Days
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.chip, period === 'ALL_TIME' && styles.chipActive]}
            onPress={() => setPeriod('ALL_TIME')}
            activeOpacity={0.7}
          >
            <Text style={[styles.chipText, period === 'ALL_TIME' && styles.chipTextActive]}>
              All Time
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </View>

      {/* KPI METRIC CARDS */}
      <View style={styles.kpiGrid}>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Total Milk Consumed</Text>
          <Text style={styles.kpiValueLarge}>{totalConsumedLiters.toFixed(1)} L</Text>
          <Text style={styles.kpiSub}>{totalCompletedDays} Completed Deliveries</Text>
        </View>

        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Total Billed Charges</Text>
          <Text style={[styles.kpiValueLarge, { color: colors.secondary }]}>
            ₹{totalBilled.toFixed(2)}
          </Text>
          <Text style={styles.kpiSub}>₹{rate}/L standard pure A2</Text>
        </View>

        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Payments Paid</Text>
          <Text style={[styles.kpiValueLarge, { color: colors.primary }]}>
            ₹{totalPaid.toFixed(2)}
          </Text>
          <Text style={styles.kpiSub}>Reconciled UPI & Cash</Text>
        </View>

        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Balance Overdue</Text>
          <Text style={[styles.kpiValueLarge, { color: balanceDue > 0 ? colors.error : colors.primary }]}>
            ₹{balanceDue.toFixed(2)}
          </Text>
          <Text style={styles.kpiSub}>{balanceDue > 0 ? 'Pending Payment' : 'All Dues Cleared'}</Text>
        </View>
      </View>

      {/* SUB-TABS SELECTOR */}
      <View style={styles.subTabsContainer}>
        <TouchableOpacity
          style={[styles.subTabBtn, subTab === 'DELIVERIES' && styles.subTabBtnActive]}
          onPress={() => setSubTab('DELIVERIES')}
          activeOpacity={0.8}
        >
          <Text style={[styles.subTabBtnText, subTab === 'DELIVERIES' && styles.subTabBtnTextActive]}>
            Deliveries ({filteredDeliveries.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.subTabBtn, subTab === 'PAYMENTS' && styles.subTabBtnActive]}
          onPress={() => setSubTab('PAYMENTS')}
          activeOpacity={0.8}
        >
          <Text style={[styles.subTabBtnText, subTab === 'PAYMENTS' && styles.subTabBtnTextActive]}>
            Billing & Invoices ({filteredPayments.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.subTabBtn, subTab === 'ASSETS' && styles.subTabBtnActive]}
          onPress={() => setSubTab('ASSETS')}
          activeOpacity={0.8}
        >
          <Text style={[styles.subTabBtnText, subTab === 'ASSETS' && styles.subTabBtnTextActive]}>
            Bottles & Assets
          </Text>
        </TouchableOpacity>
      </View>

      {/* TAB CONTENT: DELIVERIES LOG */}
      {subTab === 'DELIVERIES' && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Doorstep Milk Deliveries Log</Text>

          {filteredDeliveries.length === 0 ? (
            <EmptyState
              title="No Delivery Records Found"
              message={`No deliveries recorded for ${periodLabel}.`}
            />
          ) : (
            filteredDeliveries.map((del) => {
              const isDelivered = del.status === 'DELIVERED';
              const isOut = del.status === 'OUT_FOR_DELIVERY';
              const isPaused = del.status === 'PAUSED';
              return (
                <View key={del.id} style={styles.deliveryRow}>
                  <View style={styles.delLeft}>
                    <Text style={styles.delDate}>{del.date}</Text>
                    <Text style={styles.delSlot}>{del.delivery_time || 'Morning 6:00 AM - 7:00 AM'}</Text>
                    {del.notes ? <Text style={styles.delNote}>{del.notes}</Text> : null}
                  </View>

                  <View style={styles.delCenter}>
                    <Text style={styles.delQty}>{del.quantity} Liters</Text>
                    <Text style={styles.delPrice}>₹{del.total_amount?.toFixed(2) || (del.quantity * rate).toFixed(2)}</Text>
                  </View>

                  <View style={styles.delRight}>
                    <View
                      style={[
                        styles.badge,
                        isDelivered && styles.badgeSuccess,
                        isOut && styles.badgeWarning,
                        isPaused && styles.badgePaused,
                        !isDelivered && !isOut && !isPaused && styles.badgeMuted,
                      ]}
                    >
                      <Text
                        style={[
                          styles.badgeText,
                          isDelivered && styles.badgeTextSuccess,
                          isOut && styles.badgeTextWarning,
                          isPaused && styles.badgeTextPaused,
                          !isDelivered && !isOut && !isPaused && styles.badgeTextMuted,
                        ]}
                      >
                        {del.status}
                      </Text>
                    </View>

                    {isDelivered && (
                      <TouchableOpacity
                        style={styles.delActionIssueBtn}
                        onPress={() => setActiveTab('COMPLAINTS')}
                        activeOpacity={0.8}
                      >
                        <Text style={styles.delActionIssueText}>⚠️ Issue</Text>
                      </TouchableOpacity>
                    )}

                    {del.status === 'SCHEDULED' && (
                      <TouchableOpacity
                        style={styles.delActionPauseBtn}
                        onPress={() => {
                          Alert.alert('Hold Delivery?', `Pause milk delivery for ${del.date}?`, [
                            { text: 'Cancel', style: 'cancel' },
                            { text: 'Yes, Hold', onPress: () => pauseOrder(del.id) }
                          ]);
                        }}
                        activeOpacity={0.8}
                      >
                        <Text style={styles.delActionPauseText}>⏸️ Hold</Text>
                      </TouchableOpacity>
                    )}

                    {isPaused && (
                      <TouchableOpacity
                        style={styles.delActionResumeBtn}
                        onPress={() => {
                          Alert.alert('Resume Delivery?', `Resume milk delivery for ${del.date}?`, [
                            { text: 'Cancel', style: 'cancel' },
                            { text: 'Yes, Resume', onPress: () => resumeOrder(del.id) }
                          ]);
                        }}
                        activeOpacity={0.8}
                      >
                        <Text style={styles.delActionResumeText}>▶️ Resume</Text>
                      </TouchableOpacity>
                    )}
                  </View>
                </View>
              );
            })
          )}
        </View>
      )}

      {/* TAB CONTENT: BILLING & PAYMENTS */}
      {subTab === 'PAYMENTS' && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Payment Receipts & Invoices</Text>

          {filteredPayments.length === 0 ? (
            <EmptyState
              title="No Invoices in this Period"
              message="All upcoming bills and payment receipts will appear here."
            />
          ) : (
            filteredPayments.map((p) => {
              const isPaid = p.status === 'PAID';
              return (
                <View key={p.id} style={styles.paymentCard}>
                  <View style={styles.paymentRowTop}>
                    <View>
                      <Text style={styles.invNumber}>{p.invoice_number}</Text>
                      <Text style={styles.invPeriod}>{p.billing_period}</Text>
                    </View>

                    <View style={[styles.badge, isPaid ? styles.badgeSuccess : styles.badgeWarning]}>
                      <Text style={[styles.badgeText, isPaid ? styles.badgeTextSuccess : styles.badgeTextWarning]}>
                        {p.status}
                      </Text>
                    </View>
                  </View>

                  <View style={styles.paymentRowBottom}>
                    <View>
                      <Text style={styles.invDate}>Date: {p.due_date || 'N/A'}</Text>
                      <Text style={styles.invMethod}>Method: {p.payment_method}</Text>
                    </View>

                    <View style={styles.invAmounts}>
                      <Text style={styles.invPaid}>₹{p.paid_amount || p.total_amount}</Text>
                      {p.invoice_url ? (
                        <TouchableOpacity
                          style={styles.invDownloadBtn}
                          onPress={() => handleOpenInvoice(p.invoice_url)}
                          activeOpacity={0.8}
                        >
                          <Text style={styles.invDownloadText}>📄 View Invoice PDF</Text>
                        </TouchableOpacity>
                      ) : null}
                    </View>
                  </View>
                </View>
              );
            })
          )}
        </View>
      )}

      {/* TAB CONTENT: ASSETS SUMMARY */}
      {subTab === 'ASSETS' && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Farm Glass Bottles & Hub Assets</Text>

          <View style={styles.assetStrip}>
            <View style={styles.assetBox}>
              <Text style={styles.assetLabel}>Glass Bottles with You</Text>
              <Text style={styles.assetCount}>{bottlesHeld}</Text>
              <Text style={styles.assetHint}>Return to delivery partner</Text>
            </View>

            <View style={styles.assetBox}>
              <Text style={styles.assetLabel}>Returned Sanitized</Text>
              <Text style={[styles.assetCount, { color: colors.primary }]}>{bottlesReturned}</Text>
              <Text style={styles.assetHint}>Successfully collected</Text>
            </View>
          </View>

          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Packaging Standard:</Text>
            <Text style={styles.infoValue}>100% Eco-Friendly Glass Bottles</Text>
          </View>

          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Refundable Security Deposit:</Text>
            <Text style={[styles.infoValue, { color: colors.accent }]}>₹{depositHeld.toFixed(2)} (Held in Vault)</Text>
          </View>

          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Condition & Sanitization:</Text>
            <Text style={[styles.infoValue, { color: colors.primary }]}>Grade A Hygiene Steam Sterilized</Text>
          </View>

          <Text style={styles.depositNote}>
            * Security deposit is fully refundable at any time when terminating the daily milk subscription.
          </Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: spacing.md,
  },
  headerCard: {
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    ...shadow.sm,
  },
  headerTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  title: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  subtitle: {
    fontSize: 12,
    color: colors.textMuted,
    marginTop: 2,
  },
  shareBtn: {
    backgroundColor: colors.primaryLight,
    borderColor: colors.primaryBorder,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: radius.md,
  },
  shareBtnText: {
    color: colors.primaryDark,
    fontSize: 12,
    fontWeight: '700',
  },
  filterRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    paddingVertical: 4,
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
    fontWeight: '600',
  },
  chipTextActive: {
    color: colors.surface,
    fontWeight: '700',
  },
  kpiGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  kpiCard: {
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    flexBasis: '48%',
    flexGrow: 1,
    ...shadow.sm,
  },
  kpiLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: colors.textMuted,
  },
  kpiValueLarge: {
    fontSize: 20,
    fontWeight: '800',
    color: colors.textPrimary,
    marginVertical: 4,
  },
  kpiSub: {
    fontSize: 10,
    color: colors.textLight,
  },
  subTabsContainer: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: 4,
    gap: 4,
  },
  subTabBtn: {
    flex: 1,
    paddingVertical: spacing.sm,
    alignItems: 'center',
    borderRadius: radius.md,
  },
  subTabBtnActive: {
    backgroundColor: colors.primary,
  },
  subTabBtnText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textMuted,
  },
  subTabBtnTextActive: {
    color: colors.surface,
    fontWeight: '700',
  },
  card: {
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    gap: spacing.sm,
    ...shadow.sm,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  deliveryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.sm + 2,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  delLeft: {
    flex: 1.2,
  },
  delDate: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  delSlot: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 1,
  },
  delNote: {
    fontSize: 10,
    color: colors.textLight,
    fontStyle: 'italic',
  },
  delCenter: {
    flex: 1,
    alignItems: 'center',
  },
  delQty: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  delPrice: {
    fontSize: 11,
    color: colors.primary,
    fontWeight: '600',
  },
  delRight: {
    flex: 1,
    alignItems: 'flex-end',
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radius.full,
    borderWidth: 1,
  },
  badgeSuccess: {
    backgroundColor: colors.statusGreenBg,
    borderColor: colors.primaryBorder,
  },
  badgeWarning: {
    backgroundColor: colors.statusAmberBg,
    borderColor: colors.accent,
  },
  badgeMuted: {
    backgroundColor: colors.background,
    borderColor: colors.border,
  },
  badgePaused: {
    backgroundColor: '#fef3c7',
    borderColor: '#fcd34d',
  },
  badgeText: {
    fontSize: 10,
    fontWeight: '700',
  },
  badgeTextSuccess: {
    color: colors.statusGreen,
  },
  badgeTextWarning: {
    color: colors.statusAmber,
  },
  badgeTextPaused: {
    color: '#b45309',
  },
  badgeTextMuted: {
    color: colors.textMuted,
  },
  delActionIssueBtn: {
    marginTop: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    backgroundColor: '#fff7ed',
    borderWidth: 1,
    borderColor: '#fdba74',
    borderRadius: radius.sm,
  },
  delActionIssueText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#c2410c',
  },
  delActionPauseBtn: {
    marginTop: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
    backgroundColor: '#fef3c7',
    borderWidth: 1,
    borderColor: '#fcd34d',
    borderRadius: radius.sm,
  },
  delActionPauseText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#b45309',
  },
  delActionResumeBtn: {
    marginTop: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
    borderRadius: radius.sm,
  },
  delActionResumeText: {
    fontSize: 9,
    fontWeight: '700',
    color: colors.primary,
  },
  paymentCard: {
    backgroundColor: colors.background,
    padding: spacing.md,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    marginBottom: spacing.xs,
  },
  paymentRowTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.sm,
  },
  invNumber: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  invPeriod: {
    fontSize: 11,
    color: colors.textMuted,
  },
  paymentRowBottom: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
  },
  invDate: {
    fontSize: 11,
    color: colors.textSecondary,
  },
  invMethod: {
    fontSize: 10,
    color: colors.textMuted,
  },
  invAmounts: {
    alignItems: 'flex-end',
  },
  invPaid: {
    fontSize: 15,
    fontWeight: '800',
    color: colors.primary,
  },
  invDownloadBtn: {
    marginTop: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
    backgroundColor: colors.primaryLight,
    borderRadius: radius.sm,
  },
  invDownloadText: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primaryDark,
  },
  assetStrip: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginVertical: spacing.xs,
  },
  assetBox: {
    flex: 1,
    backgroundColor: colors.background,
    padding: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  assetLabel: {
    fontSize: 11,
    color: colors.textMuted,
    textAlign: 'center',
  },
  assetCount: {
    fontSize: 24,
    fontWeight: '800',
    color: colors.textPrimary,
    marginVertical: 2,
  },
  assetHint: {
    fontSize: 10,
    color: colors.textLight,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  infoLabel: {
    fontSize: 12,
    color: colors.textMuted,
  },
  infoValue: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  depositNote: {
    fontSize: 10,
    color: colors.textLight,
    fontStyle: 'italic',
    marginTop: spacing.xs,
  },
});
