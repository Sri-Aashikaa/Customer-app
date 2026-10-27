import React from 'react';
import { StyleSheet, View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { colors, spacing, radius } from '../theme/theme';
import { useAuth } from '../context/AuthContext';

export const AssetsScreen: React.FC = () => {
  const { customer, assets, refreshData } = useAuth();

  const bottlesList = assets?.bottles || [];
  const iceBoxesList = assets?.iceBoxes || [];
  const depositsList = assets?.deposits || [];
  const bAlloc = assets?.bottleAlloc;
  const ibAlloc = assets?.iceBoxAlloc;

  // Bottle Metrics
  let bottleIssued = 0;
  let bottleReturned = 0;
  let bottleDamaged = 0;
  let bottleLost = 0;
  let bottleInUse = 0;
  let bottleDeposit = 0;

  if (bottlesList.length > 0) {
    bottleIssued = bottlesList.length;
    bottleReturned = bottlesList.filter((b) => (b.status || '').toUpperCase() === 'RETURNED').length;
    bottleDamaged = bottlesList.filter((b) => (b.condition || '').toUpperCase() === 'DAMAGED' || (b.status || '').toUpperCase() === 'DAMAGED').length;
    bottleLost = bottlesList.filter((b) => (b.condition || '').toUpperCase() === 'LOST' || (b.status || '').toUpperCase() === 'LOST').length;
    bottleInUse = bottlesList.filter((b) => (b.status || '').toUpperCase() === 'ALLOCATED').length;
    if (bottleInUse === 0 && bottleReturned === 0) bottleInUse = bottleIssued - bottleDamaged - bottleLost;
    bottleDeposit = bottlesList.reduce((acc, b) => acc + (Number(b.deposit_per_unit || b.deposit_amount || 50)), 0);
  } else if (bAlloc) {
    bottleIssued = Number(bAlloc.issued_count) || 0;
    bottleReturned = Number(bAlloc.returned_count) || 0;
    bottleDamaged = Number(bAlloc.damaged_count) || 0;
    bottleLost = Number(bAlloc.lost_count) || 0;
    bottleInUse = bottleIssued - bottleReturned - bottleDamaged - bottleLost;
    if (bottleInUse < 0) bottleInUse = bottleIssued;
    bottleDeposit = bottleIssued * 300;
  } else {
    const qty = Math.ceil(customer?.milk_quantity || 2);
    bottleIssued = qty;
    bottleInUse = qty;
    bottleDeposit = qty * 300;
  }

  // Ice Box Metrics
  let iceBoxIssued = 0;
  let iceBoxReturned = 0;
  let iceBoxDamaged = 0;
  let iceBoxLost = 0;
  let iceBoxInUse = 0;
  let iceBoxDeposit = 0;

  if (iceBoxesList.length > 0) {
    iceBoxIssued = iceBoxesList.length;
    iceBoxReturned = iceBoxesList.filter((b) => (b.status || '').toUpperCase() === 'RETURNED').length;
    iceBoxDamaged = iceBoxesList.filter((b) => (b.condition || '').toUpperCase() === 'DAMAGED' || (b.status || '').toUpperCase() === 'DAMAGED').length;
    iceBoxLost = iceBoxesList.filter((b) => (b.condition || '').toUpperCase() === 'LOST' || (b.status || '').toUpperCase() === 'LOST').length;
    iceBoxInUse = iceBoxesList.filter((b) => (b.status || '').toUpperCase() === 'ALLOCATED').length;
    if (iceBoxInUse === 0 && iceBoxReturned === 0) iceBoxInUse = iceBoxIssued - iceBoxDamaged - iceBoxLost;
    iceBoxDeposit = iceBoxesList.reduce((acc, b) => acc + (Number(b.deposit_amount || 600)), 0);
  } else if (ibAlloc) {
    iceBoxIssued = Number(ibAlloc.issued_count) || 0;
    iceBoxReturned = Number(ibAlloc.returned_count) || 0;
    iceBoxDamaged = Number(ibAlloc.damaged_count) || 0;
    iceBoxLost = Number(ibAlloc.lost_count) || 0;
    iceBoxInUse = iceBoxIssued - iceBoxReturned - iceBoxDamaged - iceBoxLost;
    if (iceBoxInUse < 0) iceBoxInUse = iceBoxIssued;
    iceBoxDeposit = iceBoxIssued * 600;
  }

  // Deposits Ledger Calculations
  let totalDepositPaid = 0;
  let totalRefundProcessed = 0;
  let pendingRefund = 0;

  if (depositsList.length > 0) {
    depositsList.forEach((d) => {
      totalDepositPaid += Number(d.deposit_paid || d.total_deposit || 0);
      totalRefundProcessed += Number(d.deposit_refund || 0);
    });
    pendingRefund = totalDepositPaid - totalRefundProcessed;
  } else {
    totalDepositPaid = bottleDeposit + iceBoxDeposit;
    pendingRefund = totalDepositPaid;
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      {/* DEPOSIT SECURITY FUNDS */}
      <View style={styles.card}>
        <View style={styles.headerRow}>
          <Text style={styles.cardTitle}>Asset Security Deposits</Text>
          <TouchableOpacity onPress={() => refreshData()} style={styles.refreshBtn}>
            <Text style={styles.refreshText}>Sync Server</Text>
          </TouchableOpacity>
        </View>
        <Text style={styles.cardSub}>Live Supabase Ledger Data</Text>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Bottle Deposit:</Text>
          <Text style={styles.infoValue}>₹{bottleDeposit.toFixed(2)}</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Ice Box Deposit:</Text>
          <Text style={styles.infoValue}>₹{iceBoxDeposit.toFixed(2)}</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Total Security Deposit Paid:</Text>
          <Text style={styles.highlightGreen}>₹{totalDepositPaid.toFixed(2)}</Text>
        </View>

        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Refund Processed:</Text>
          <Text style={styles.infoValue}>₹{totalRefundProcessed.toFixed(2)}</Text>
        </View>

        <View style={[styles.infoRow, { borderBottomWidth: 0 }]}>
          <Text style={styles.infoLabel}>Pending Refund:</Text>
          <Text style={styles.highlightOrange}>₹{pendingRefund.toFixed(2)}</Text>
        </View>
      </View>

      {/* GLASS BOTTLES SUMMARY */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Glass Bottles Tracker</Text>
        <Text style={styles.cardSub}>500ml & 1.0L Dairy Glass Bottles (glass_bottles table)</Text>

        <View style={styles.grid}>
          <View style={styles.miniBox}>
            <Text style={styles.miniVal}>{bottleIssued} Units</Text>
            <Text style={styles.miniLab}>Issued</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={styles.miniVal}>{bottleReturned} Units</Text>
            <Text style={styles.miniLab}>Returned</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.error }]}>{bottleDamaged} Units</Text>
            <Text style={styles.miniLab}>Damaged</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.error }]}>{bottleLost} Units</Text>
            <Text style={styles.miniLab}>Lost</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.statusBlue }]}>{bottleInUse} Units</Text>
            <Text style={styles.miniLab}>In Use</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.statusGreen }]}>₹{bottleDeposit}</Text>
            <Text style={styles.miniLab}>Deposit</Text>
          </View>
        </View>

        {/* Allocated Bottles List */}
        <Text style={styles.sectionSubTitle}>Allocated Units (Server Records)</Text>
        {bottlesList.length === 0 ? (
          <Text style={styles.emptyText}>Standard daily subscription bottle allocation active.</Text>
        ) : (
          bottlesList.map((b) => (
            <View key={b.id} style={styles.unitRow}>
              <View>
                <Text style={styles.unitCode}>{b.bottle_code || b.id}</Text>
                <Text style={styles.unitMeta}>{b.size || '1L'} • {b.issue_date || 'Assigned'}</Text>
              </View>
              <View style={{ alignItems: 'flex-end' }}>
                <Text style={styles.unitBadge}>{b.status || 'ALLOCATED'}</Text>
                <Text style={styles.unitCond}>Cond: {b.condition || 'GOOD'}</Text>
              </View>
            </View>
          ))
        )}
      </View>

      {/* ICE BOXES SUMMARY */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Insulated Ice Box Tracker</Text>
        <Text style={styles.cardSub}>Thermal Insulated Cold Chain Storage Box (ice_boxes table)</Text>

        <View style={styles.grid}>
          <View style={styles.miniBox}>
            <Text style={styles.miniVal}>{iceBoxIssued} Box</Text>
            <Text style={styles.miniLab}>Issued</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={styles.miniVal}>{iceBoxReturned} Box</Text>
            <Text style={styles.miniLab}>Returned</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.error }]}>{iceBoxDamaged}</Text>
            <Text style={styles.miniLab}>Damaged</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.error }]}>{iceBoxLost}</Text>
            <Text style={styles.miniLab}>Lost</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.statusBlue }]}>{iceBoxInUse} Box</Text>
            <Text style={styles.miniLab}>In Use</Text>
          </View>
          <View style={styles.miniBox}>
            <Text style={[styles.miniVal, { color: colors.statusGreen }]}>₹{iceBoxDeposit}</Text>
            <Text style={styles.miniLab}>Deposit</Text>
          </View>
        </View>

        {/* Allocated Ice Boxes List */}
        <Text style={styles.sectionSubTitle}>Allocated Units (Server Records)</Text>
        {iceBoxesList.length === 0 ? (
          <Text style={styles.emptyText}>No ice boxes allocated to this customer account.</Text>
        ) : (
          iceBoxesList.map((ib) => (
            <View key={ib.id} style={styles.unitRow}>
              <View>
                <Text style={styles.unitCode}>{ib.ice_box_code || ib.id}</Text>
                <Text style={styles.unitMeta}>{ib.size_type || '25L'} • {ib.issue_date || 'Assigned'}</Text>
              </View>
              <View style={{ alignItems: 'flex-end' }}>
                <Text style={[styles.unitBadge, { backgroundColor: '#F3E8FF', color: '#7E22CE' }]}>{ib.status || 'ALLOCATED'}</Text>
                <Text style={styles.unitCond}>Cond: {ib.condition || 'GOOD'}</Text>
              </View>
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingBottom: 40,
    gap: spacing.lg,
  },
  card: {
    backgroundColor: colors.surface,
    padding: spacing.lg,
    borderRadius: radius.lg,
    borderColor: colors.border,
    borderWidth: 1,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  cardSub: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
    marginBottom: spacing.sm,
  },
  refreshBtn: {
    backgroundColor: '#ECFDF5',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  refreshText: {
    fontSize: 11,
    color: colors.primary,
    fontWeight: '700',
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
    fontSize: 13,
    fontWeight: '700',
  },
  highlightOrange: {
    color: '#D97706',
    fontSize: 13,
    fontWeight: '700',
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  miniBox: {
    width: '31%',
    backgroundColor: colors.background,
    padding: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  miniVal: {
    color: colors.primary,
    fontWeight: '700',
    fontSize: 14,
  },
  miniLab: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: 2,
  },
  sectionSubTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: spacing.md,
    marginBottom: spacing.xs,
  },
  emptyText: {
    fontSize: 12,
    color: colors.textMuted,
    fontStyle: 'italic',
    paddingVertical: spacing.xs,
  },
  unitRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#F8FAFC',
    padding: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    marginTop: 6,
  },
  unitCode: {
    fontSize: 13,
    fontWeight: '700',
    fontFamily: 'monospace',
    color: colors.textPrimary,
  },
  unitMeta: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
  },
  unitBadge: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primary,
    backgroundColor: '#ECFDF5',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  unitCond: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 2,
  },
});
