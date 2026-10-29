import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, TouchableOpacity, Linking, Modal, TextInput, Alert, ActivityIndicator } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { DeliveryCard } from '../components/DeliveryCard';
import { PartnerCard } from '../components/PartnerCard';
import { colors, spacing, radius } from '../theme/theme';
import { ServerAPI } from '../services/api';

export const DashboardScreen: React.FC = () => {
  const { customer, partnerDetails, deliveryStatus, setActiveTab, enterpriseSettings } = useAuth();
  const [showOrderModal, setShowOrderModal] = useState(false);
  const [selectedSlot, setSelectedSlot] = useState('Morning (5:00 AM - 9:30 AM)');
  const [selectedQty, setSelectedQty] = useState(1.0);
  const [orderDate, setOrderDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().split('T')[0];
  });
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [additionalOrders, setAdditionalOrders] = useState<any[]>([]);
  const [orderTimings, setOrderTimings] = useState<any>(null);

  useEffect(() => {
    ServerAPI.fetchOrderTimingsConfig().then(res => {
      if (res) {
        setOrderTimings(res);
        if (res.morning_slot_label) {
          setSelectedSlot(res.morning_slot_label);
        }
      }
    });
  }, []);

  useEffect(() => {
    if (customer?.id || customer?.customer_id) {
      loadAdditionalOrders();
    }
  }, [customer?.id, customer?.customer_id]);

  const loadAdditionalOrders = async () => {
    if (!customer) return;
    const orders = await ServerAPI.fetchAdditionalMilkOrders(customer.id || customer.customer_id);
    setAdditionalOrders(orders);
  };

  if (!customer) return null;

  const latestVer = enterpriseSettings?.latest_app_version || '1.0.1';
  const hasUpdate = latestVer !== '1.0.1' && Boolean(enterpriseSettings?.latest_app_version);

  const rate = 65;
  const totalAmount = selectedQty * rate;

  const handleOpenOrderModal = async () => {
    const pin = (customer?.pincode || '').trim();
    if (pin) {
      const isServiceable = await ServerAPI.isPincodeServiceable(pin);
      if (!isServiceable) {
        await ServerAPI.recordUnserviceableLocationRequest({
          pincode: pin,
          areaName: customer?.area,
          city: customer?.city || 'Chennai',
          customerName: customer?.name,
          customerMobile: customer?.mobile,
          fullAddress: customer?.address,
        });
        Alert.alert(
          'Delivery Notice',
          `“We are not available at your location yet, but we will quickly reach to your location”\n\nYour location request for Pincode ${pin} has been recorded in our operations panel.`,
          [{ text: 'Understood' }]
        );
        return;
      }
    }
    setShowOrderModal(true);
  };

  const handlePlaceOrder = async () => {
    setSubmitting(true);
    try {
      const pin = (customer?.pincode || '').trim();
      if (pin) {
        const isServiceable = await ServerAPI.isPincodeServiceable(pin);
        if (!isServiceable) {
          setShowOrderModal(false);
          await ServerAPI.recordUnserviceableLocationRequest({
            pincode: pin,
            areaName: customer?.area,
            city: customer?.city || 'Chennai',
            customerName: customer?.name,
            customerMobile: customer?.mobile,
            fullAddress: customer?.address,
          });
          Alert.alert(
            'Delivery Notice',
            `“We are not available at your location yet, but we will quickly reach to your location”\n\nYour location request for Pincode ${pin} has been recorded in our operations panel.`,
            [{ text: 'Understood' }]
          );
          return;
        }
      }

      const res = await ServerAPI.createAdditionalMilkOrder({
        customer,
        deliveryDate: orderDate,
        deliverySlot: selectedSlot,
        quantity: selectedQty,
        ratePerLiter: rate,
        notes: notes.trim(),
      });

      if (res.success) {
        setShowOrderModal(false);
        setNotes('');
        await loadAdditionalOrders();
        Alert.alert(
          'Order Confirmed 🎉',
          `Your additional milk order for ${selectedQty}L on ${orderDate} (${selectedSlot}) has been scheduled!`
        );
      } else {
        Alert.alert('Order Failed', res.error || 'Failed to place additional order.');
      }
    } catch (e: any) {
      Alert.alert('Order Error', e.message || 'An error occurred.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <View style={styles.container}>
      {/* WELCOME BANNER */}
      <View style={styles.welcomeBanner}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{(customer.name || 'C').charAt(0).toUpperCase()}</Text>
        </View>
        <View style={styles.welcomeInfo}>
          <View style={styles.welcomeRow}>
            <Text style={styles.welcomeTitle}>Welcome, {customer.name} 👋</Text>
            <View style={styles.syncBadge}>
              <Text style={styles.syncText}>Live</Text>
            </View>
          </View>
          <Text style={styles.welcomeSubtitle}>
            ID: {customer.customer_id} • {customer.area || customer.location}
          </Text>
        </View>
      </View>

      {/* IN-APP UPDATE NOTIFICATION IF SERVER HAS NEW VERSION */}
      {hasUpdate && (
        <TouchableOpacity
          style={styles.updateCard}
          onPress={() => {
            const url = enterpriseSettings?.app_update_url || 'https://amudhammilk.com';
            Linking.openURL(url);
          }}
        >
          <View style={styles.updateIcon}>
            <Text style={{ fontSize: 20 }}>🚀</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.updateTitle}>New Update Available (v{latestVer})</Text>
            <Text style={styles.updateDesc}>Tap to download the latest features and bug fixes.</Text>
          </View>
        </TouchableOpacity>
      )}

      {/* QUICK ACTIONS ROW */}
      <View style={styles.quickActionsGrid}>
        <TouchableOpacity style={styles.actionItem} onPress={() => setActiveTab('CANCEL')}>
          <View style={[styles.actionIconBg, { backgroundColor: '#fef3c7' }]}>
            <Text style={{ fontSize: 18 }}>⏸️</Text>
          </View>
          <Text style={styles.actionLabel}>Pause Milk</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionItem} onPress={() => setActiveTab('TIMING')}>
          <View style={[styles.actionIconBg, { backgroundColor: '#ecfdf5' }]}>
            <Text style={{ fontSize: 18 }}>🥛</Text>
          </View>
          <Text style={styles.actionLabel}>Change Qty</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionItem} onPress={() => setActiveTab('DEPOSIT')}>
          <View style={[styles.actionIconBg, { backgroundColor: '#eff6ff' }]}>
            <Text style={{ fontSize: 18 }}>📦</Text>
          </View>
          <Text style={styles.actionLabel}>Bottles</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionItem} onPress={() => setActiveTab('PAYMENT')}>
          <View style={[styles.actionIconBg, { backgroundColor: '#fdf2f8' }]}>
            <Text style={{ fontSize: 18 }}>💳</Text>
          </View>
          <Text style={styles.actionLabel}>Pay Bill</Text>
        </TouchableOpacity>
      </View>

      {/* TODAY'S DELIVERY CARD */}
      <DeliveryCard
        status={deliveryStatus}
        quantity={customer.milk_quantity}
        timing={customer.delivery_timing}
      />

      {/* ORDER ADDITIONAL MILK BANNER CARD */}
      <TouchableOpacity
        style={styles.additionalOrderBanner}
        onPress={handleOpenOrderModal}
        activeOpacity={0.88}
      >
        <View style={styles.additionalOrderIconBg}>
          <Text style={{ fontSize: 24 }}>🥛</Text>
        </View>
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            <Text style={styles.additionalOrderTitle}>Order Additional Milk</Text>
            <View style={styles.extraTag}>
              <Text style={styles.extraTagText}>EXTRA</Text>
            </View>
          </View>
          <Text style={styles.additionalOrderSub}>
            Need more milk? Select a date & slot for extra delivery
          </Text>
        </View>
        <View style={styles.addIconCircle}>
          <Text style={{ color: colors.primary, fontWeight: 'bold', fontSize: 16 }}>+</Text>
        </View>
      </TouchableOpacity>

      {/* ADDITIONAL ORDERS ACTIVE LIST */}
      {additionalOrders.length > 0 && (
        <View style={styles.additionalOrdersCard}>
          <View style={styles.additionalOrdersHeader}>
            <Text style={styles.additionalOrdersTitle}>Your Additional Orders</Text>
            <View style={styles.countBadge}>
              <Text style={styles.countBadgeText}>{additionalOrders.length} Extra</Text>
            </View>
          </View>
          {additionalOrders.map((ord: any) => {
            const isCancelled = ord.delivery_status === 'CANCELLED';
            return (
              <View key={ord.id} style={styles.orderItemRow}>
                <Text style={{ fontSize: 18 }}>{isCancelled ? '❌' : '🥛'}</Text>
                <View style={{ flex: 1, marginLeft: 10 }}>
                  <Text style={[styles.orderItemDate, isCancelled && { textDecorationLine: 'line-through' }]}>
                    Date: {ord.delivery_date} • {ord.delivery_timing}
                  </Text>
                  <Text style={styles.orderItemSub}>
                    {ord.quantity}L • ₹{ord.total_amount} • {ord.delivery_status}
                  </Text>
                </View>
              </View>
            );
          })}
        </View>
      )}

      {/* ASSIGNED DELIVERY PARTNER CARD */}
      <PartnerCard partner={partnerDetails} />

      {/* QUICK SUMMARY CARDS */}
      <View style={styles.row}>
        <View style={styles.summaryCard}>
          <Text style={styles.metricLabel}>Payment Status</Text>
          <Text
            style={[
              styles.metricVal,
              { color: customer.payment_status === 'PAID' ? colors.statusGreen : colors.statusAmber },
            ]}
          >
            {customer.payment_status}
          </Text>
          <Text style={styles.subText}>Monthly Billing Cycle</Text>
        </View>

        <View style={styles.summaryCard}>
          <Text style={styles.metricLabel}>Monthly Plan</Text>
          <Text style={[styles.metricVal, { color: colors.primary }]}>₹{customer.monthly_rate}</Text>
          <Text style={styles.subText}>₹65 / Liter Standard</Text>
        </View>
      </View>

      {/* ADDITIONAL MILK ORDER MODAL */}
      <Modal visible={showOrderModal} animationType="slide" transparent={true}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                <Text style={{ fontSize: 24 }}>🥛</Text>
                <View>
                  <Text style={styles.modalTitle}>Order Additional Milk</Text>
                  <Text style={styles.modalSub}>One-time extra delivery order</Text>
                </View>
              </View>
              <TouchableOpacity onPress={() => setShowOrderModal(false)}>
                <Text style={{ fontSize: 20, color: colors.textMuted }}>✕</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.infoBanner}>
              <Text style={styles.infoBannerText}>
                This extra order will be added to your scheduled orders for the chosen date without affecting your recurring subscription.
              </Text>
            </View>

            {/* DATE SELECTION */}
            {(() => {
              const now = new Date();
              const currentMins = now.getHours() * 60 + now.getMinutes();
              const parseMins = (str?: string, def = 540) => {
                if (!str) return def;
                const match = str.trim().match(/^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$/i);
                if (!match) return def;
                let h = parseInt(match[1], 10);
                const m = parseInt(match[2], 10);
                const mod = match[3]?.toUpperCase();
                if (mod === 'PM' && h < 12) h += 12;
                if (mod === 'AM' && h === 12) h = 0;
                return h * 60 + m;
              };

              const morningCutoffMins = parseMins(orderTimings?.morning_cutoff_time, 9 * 60);
              const eveningCutoffMins = parseMins(orderTimings?.evening_cutoff_time, 17 * 60);

              const morningPassedToday = currentMins >= morningCutoffMins;
              const eveningPassedToday = currentMins >= eveningCutoffMins;
              const canOrderToday = orderTimings?.allow_same_day_orders !== false && !eveningPassedToday;

              const morningSlotLabel = 'Morning';
              const eveningSlotLabel = 'Evening';
              const morningStart = orderTimings?.morning_slot_start || '5:00 AM';
              const morningEnd = orderTimings?.morning_slot_end || '9:30 AM';
              const eveningStart = orderTimings?.evening_slot_start || '5:00 PM';
              const eveningEnd = orderTimings?.evening_slot_end || '8:00 PM';

              const offsets = canOrderToday ? [0, 1, 2] : [1, 2, 3];
              const isTodaySelected = orderDate === now.toISOString().split('T')[0];

              return (
                <>
                  <Text style={styles.fieldLabel}>1. Select Delivery Date (YYYY-MM-DD)</Text>
                  <View style={styles.chipRow}>
                    {offsets.map((offset) => {
                      const target = new Date();
                      target.setDate(target.getDate() + offset);
                      const iso = target.toISOString().split('T')[0];
                      const isSel = orderDate === iso;
                      const label = offset === 0 ? 'Today' : offset === 1 ? 'Tomorrow' : offset === 2 ? 'Day After' : `${target.getDate()}/${target.getMonth() + 1}`;
                      return (
                        <TouchableOpacity
                          key={iso}
                          style={[styles.chip, isSel && styles.chipActive]}
                          onPress={() => {
                            setOrderDate(iso);
                            if (offset === 0 && morningPassedToday) {
                              setSelectedSlot(eveningSlotLabel);
                            }
                          }}
                        >
                          <Text style={[styles.chipText, isSel && styles.chipTextActive]}>
                            {label} ({target.getDate()}/${target.getMonth() + 1})
                          </Text>
                        </TouchableOpacity>
                      );
                    })}
                  </View>

                  {/* SLOT SELECTION */}
                  <Text style={styles.fieldLabel}>2. Select Delivery Slot</Text>
                  <View style={styles.chipRow}>
                    {!(isTodaySelected && morningPassedToday) && (
                      <TouchableOpacity
                        style={[styles.chip, selectedSlot.includes('Morning') && styles.chipActive]}
                        onPress={() => setSelectedSlot(morningSlotLabel)}
                      >
                        <Text style={[styles.chipText, selectedSlot.includes('Morning') && styles.chipTextActive]}>
                          🌅 Morning
                        </Text>
                      </TouchableOpacity>
                    )}
                    {!(isTodaySelected && eveningPassedToday) && (
                      <TouchableOpacity
                        style={[styles.chip, selectedSlot.includes('Evening') && styles.chipActive]}
                        onPress={() => setSelectedSlot(eveningSlotLabel)}
                      >
                        <Text style={[styles.chipText, selectedSlot.includes('Evening') && styles.chipTextActive]}>
                          🌇 Evening
                        </Text>
                      </TouchableOpacity>
                    )}
                  </View>
                </>
              );
            })()}

            {/* QUANTITY SELECTION */}
            <Text style={styles.fieldLabel}>3. Extra Milk Quantity</Text>
            <View style={styles.stepperContainer}>
              <TouchableOpacity
                style={styles.stepperBtn}
                onPress={() => setSelectedQty(Math.max(0.5, selectedQty - 0.5))}
              >
                <Text style={styles.stepperBtnText}>-</Text>
              </TouchableOpacity>
              <Text style={styles.stepperValue}>{selectedQty.toFixed(1)} L</Text>
              <TouchableOpacity
                style={styles.stepperBtn}
                onPress={() => setSelectedQty(Math.min(20, selectedQty + 0.5))}
              >
                <Text style={styles.stepperBtnText}>+</Text>
              </TouchableOpacity>
            </View>

            {/* SUMMARY CARD */}
            <View style={styles.orderSummaryCard}>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Delivery Date:</Text>
                <Text style={styles.summaryVal}>{orderDate}</Text>
              </View>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Slot:</Text>
                <Text style={styles.summaryVal}>{selectedSlot.split(' ')[0]}</Text>
              </View>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Quantity:</Text>
                <Text style={styles.summaryVal}>{selectedQty} Liter(s)</Text>
              </View>
              <View style={[styles.summaryRow, { marginTop: 8, borderTopWidth: 1, borderTopColor: '#a7f3d0', paddingTop: 8 }]}>
                <Text style={[styles.summaryLabel, { fontWeight: '700', fontSize: 14 }]}>Total Amount:</Text>
                <Text style={{ fontWeight: '700', fontSize: 18, color: colors.primary }}>₹{totalAmount}</Text>
              </View>
            </View>

            {/* INSTRUCTIONS */}
            <TextInput
              style={styles.input}
              placeholder="Special instructions (optional)"
              placeholderTextColor={colors.textLight}
              value={notes}
              onChangeText={setNotes}
            />

            {/* CONFIRM BUTTON */}
            <TouchableOpacity
              style={styles.confirmBtn}
              onPress={handlePlaceOrder}
              disabled={submitting}
            >
              {submitting ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.confirmBtnText}>Confirm Additional Order • ₹{totalAmount}</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: spacing.lg,
  },
  welcomeBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radius.xl,
    padding: spacing.lg,
    gap: spacing.md,
  },
  avatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: colors.primary,
    fontSize: 22,
    fontWeight: 'bold',
  },
  welcomeInfo: {
    flex: 1,
  },
  welcomeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  welcomeTitle: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '700',
  },
  syncBadge: {
    backgroundColor: 'rgba(255, 255, 255, 0.25)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: radius.full,
  },
  syncText: {
    color: '#ffffff',
    fontSize: 10,
    fontWeight: '700',
  },
  welcomeSubtitle: {
    color: 'rgba(255, 255, 255, 0.85)',
    fontSize: 12,
    marginTop: 2,
  },
  updateCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderWidth: 1,
    borderColor: '#bfdbfe',
    borderRadius: radius.lg,
    padding: spacing.md,
    gap: spacing.md,
  },
  updateIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#dbeafe',
    alignItems: 'center',
    justifyContent: 'center',
  },
  updateTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#1e40af',
  },
  updateDesc: {
    fontSize: 11,
    color: '#3b82f6',
    marginTop: 2,
  },
  quickActionsGrid: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  actionItem: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xs,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  actionIconBg: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.xs,
  },
  actionLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: colors.textPrimary,
    textAlign: 'center',
  },
  row: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  summaryCard: {
    flex: 1,
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
  },
  metricLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '600',
  },
  metricVal: {
    fontSize: 15,
    fontWeight: '700',
    marginTop: 4,
  },
  subText: {
    fontSize: 10,
    color: colors.textLight,
    marginTop: 2,
  },
  additionalOrderBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radius.lg,
    padding: spacing.md,
    gap: spacing.md,
  },
  additionalOrderIconBg: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  additionalOrderTitle: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '700',
  },
  extraTag: {
    backgroundColor: '#fcd34d',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: radius.sm,
  },
  extraTagText: {
    color: '#78350f',
    fontSize: 9,
    fontWeight: '900',
  },
  additionalOrderSub: {
    color: 'rgba(255, 255, 255, 0.8)',
    fontSize: 11,
    marginTop: 2,
  },
  addIconCircle: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: '#ffffff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  additionalOrdersCard: {
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
  },
  additionalOrdersHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  additionalOrdersTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  countBadge: {
    backgroundColor: '#ecfdf5',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: radius.full,
  },
  countBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primary,
  },
  orderItemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  orderItemDate: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textPrimary,
  },
  orderItemSub: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#ffffff',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: spacing.lg,
    gap: spacing.sm,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  modalTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  modalSub: {
    fontSize: 11,
    color: colors.textMuted,
  },
  infoBanner: {
    backgroundColor: '#ecfdf5',
    padding: spacing.sm,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: '#a7f3d0',
    marginVertical: spacing.xs,
  },
  infoBannerText: {
    fontSize: 11,
    color: '#065f46',
  },
  fieldLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: spacing.xs,
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  chip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
  },
  chipActive: {
    backgroundColor: '#ecfdf5',
    borderColor: colors.primary,
  },
  chipText: {
    fontSize: 12,
    color: colors.textPrimary,
  },
  chipTextActive: {
    color: colors.primary,
    fontWeight: '700',
  },
  stepperContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.lg,
    paddingVertical: spacing.xs,
  },
  stepperBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  stepperBtnText: {
    fontSize: 20,
    fontWeight: '700',
    color: colors.primary,
  },
  stepperValue: {
    fontSize: 18,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  orderSummaryCard: {
    backgroundColor: '#ecfdf5',
    padding: spacing.md,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: '#a7f3d0',
    marginVertical: spacing.xs,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginVertical: 2,
  },
  summaryLabel: {
    fontSize: 12,
    color: '#334155',
  },
  summaryVal: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 12,
    color: colors.textPrimary,
    backgroundColor: colors.background,
  },
  confirmBtn: {
    backgroundColor: colors.primary,
    borderRadius: radius.md,
    paddingVertical: spacing.md,
    alignItems: 'center',
    marginTop: spacing.xs,
  },
  confirmBtnText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '700',
  },
});
