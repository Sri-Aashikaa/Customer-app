import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Modal,
  TextInput,
  ActivityIndicator,
  Alert
} from 'react-native';
import { useAuth } from '../context/AuthContext';
import { ComplaintItem } from '../types';
import { colors, spacing, radius, shadow } from '../theme/theme';
import { EmptyState } from '../components/EmptyState';

type FilterTab = 'ALL' | 'OPEN' | 'INVESTIGATING' | 'RESOLVED';

const CATEGORIES = [
  { key: 'FRESHNESS_ISSUE', label: '🥛 Milk Freshness / Taste', icon: '🥛' },
  { key: 'BOTTLE_ISSUE', label: '🍶 Bottle / Packaging Issue', icon: '🍶' },
  { key: 'DELIVERY_DELAY', label: '🚚 Delivery Missed / Delay', icon: '🚚' },
  { key: 'WRONG_ITEM', label: '📦 Wrong Item / Quantity', icon: '📦' },
  { key: 'OTHER', label: '💬 Other Concern', icon: '💬' },
];

const SUBTYPES_BY_CATEGORY: Record<string, string[]> = {
  FRESHNESS_ISSUE: [
    'Milk Souring / Curdled upon boiling',
    'Unpleasant Smell / Off Taste',
    'Thin or Watery Consistency',
    'Suspicious Particle / Texture',
  ],
  BOTTLE_ISSUE: [
    'Chipped or Cracked Glass Rim',
    'Broken Bottle at Doorstep',
    'Cap Seal Broken / Tampered',
    'Dirty Bottle Exterior / Leakage',
  ],
  DELIVERY_DELAY: [
    'Delivery Not Received at Doorstep',
    'Delivered Very Late After Cutoff',
    'Left at Wrong Door / Apartment',
  ],
  WRONG_ITEM: [
    'Wrong Quantity Delivered (Short)',
    'Wrong Product Type Delivered',
  ],
  OTHER: [
    'Billing or Ledger Dispute',
    'Delivery Partner Behavior',
    'General Quality Inquiry',
  ],
};

export const ComplaintsScreen: React.FC = () => {
  const { complaints, deliveries, createComplaint, fetchComplaints, isLoading } = useAuth();

  const [filter, setFilter] = useState<FilterTab>('ALL');
  const [showModal, setShowModal] = useState<boolean>(false);

  // Form State
  const [selectedOrder, setSelectedOrder] = useState<any | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('FRESHNESS_ISSUE');
  const [selectedSubtype, setSelectedSubtype] = useState<string>('Milk Souring / Curdled upon boiling');
  const [description, setDescription] = useState<string>('');
  const [submitting, setSubmitting] = useState<boolean>(false);

  // Filter complaints
  const filteredComplaints = complaints.filter((c) => {
    if (filter === 'ALL') return true;
    if (filter === 'OPEN') return c.status === 'OPEN';
    if (filter === 'INVESTIGATING') return c.status === 'INVESTIGATING';
    if (filter === 'RESOLVED') return c.status === 'RESOLVED' || c.status === 'ACTION_TAKEN' || c.status === 'CLOSED';
    return true;
  });

  const openCount = complaints.filter(c => c.status === 'OPEN').length;
  const inProgressCount = complaints.filter(c => c.status === 'INVESTIGATING').length;
  const resolvedCount = complaints.filter(c => ['RESOLVED', 'ACTION_TAKEN', 'CLOSED'].includes(c.status)).length;

  const handleOpenRaiseModal = (prefillOrder?: any) => {
    if (prefillOrder) {
      setSelectedOrder(prefillOrder);
      setSelectedCategory('FRESHNESS_ISSUE');
      setSelectedSubtype('Milk Souring / Curdled upon boiling');
    } else {
      setSelectedOrder(deliveries.length > 0 ? deliveries[0] : null);
    }
    setShowModal(true);
  };

  const handleCategorySelect = (catKey: string) => {
    setSelectedCategory(catKey);
    const defaults = SUBTYPES_BY_CATEGORY[catKey];
    if (defaults && defaults.length > 0) {
      setSelectedSubtype(defaults[0]);
    } else {
      setSelectedSubtype('');
    }
  };

  const handleSubmit = async () => {
    if (!description.trim()) {
      Alert.alert('Details Required', 'Please describe the issue with bottle freshness or quality.');
      return;
    }

    setSubmitting(true);
    const catObj = CATEGORIES.find(c => c.key === selectedCategory);
    const catLabel = catObj?.label || 'Quality Issue';

    const res = await createComplaint({
      orderId: selectedOrder?.id || undefined,
      deliveryDate: selectedOrder?.date || undefined,
      milkProductName: selectedOrder?.product_name || 'Pure Farm Fresh Raw Cow Milk',
      category: selectedCategory,
      issueSubtype: selectedSubtype,
      title: `${catLabel} - ${selectedSubtype}`,
      description: description.trim(),
      priority: 'HIGH',
    });

    setSubmitting(false);

    if (res.success) {
      setShowModal(false);
      setDescription('');
    }
  };

  const getStatusBadgeStyle = (status: string) => {
    switch (status) {
      case 'OPEN':
        return { bg: '#fef3c7', text: '#b45309', border: '#fcd34d', label: 'Open' };
      case 'INVESTIGATING':
        return { bg: '#eff6ff', text: '#1d4ed8', border: '#bfdbfe', label: 'Under Review' };
      case 'ACTION_TAKEN':
        return { bg: '#f3e8ff', text: '#7e22ce', border: '#d8b4fe', label: 'Action Taken' };
      case 'RESOLVED':
      case 'CLOSED':
        return { bg: '#ecfdf5', text: '#047857', border: '#a7f3d0', label: 'Resolved' };
      default:
        return { bg: colors.background, text: colors.textMuted, border: colors.border, label: status };
    }
  };

  return (
    <View style={styles.container}>
      {/* HEADER CARD */}
      <View style={styles.headerCard}>
        <View style={styles.headerTop}>
          <View>
            <Text style={styles.title}>Quality & Complaints Support</Text>
            <Text style={styles.subtitle}>Report freshness or bottle issues & track team remedies</Text>
          </View>
          <TouchableOpacity
            style={styles.raiseBtn}
            onPress={() => handleOpenRaiseModal()}
            activeOpacity={0.8}
          >
            <Text style={styles.raiseBtnText}>+ Raise Complaint</Text>
          </TouchableOpacity>
        </View>

        {/* METRICS ROW */}
        <View style={styles.metricsRow}>
          <View style={styles.metricBox}>
            <Text style={styles.metricNum}>{complaints.length}</Text>
            <Text style={styles.metricLabel}>Total Filed</Text>
          </View>
          <View style={styles.metricBox}>
            <Text style={[styles.metricNum, { color: '#b45309' }]}>{openCount}</Text>
            <Text style={styles.metricLabel}>Pending Action</Text>
          </View>
          <View style={styles.metricBox}>
            <Text style={[styles.metricNum, { color: '#1d4ed8' }]}>{inProgressCount}</Text>
            <Text style={styles.metricLabel}>Under Review</Text>
          </View>
          <View style={styles.metricBox}>
            <Text style={[styles.metricNum, { color: '#047857' }]}>{resolvedCount}</Text>
            <Text style={styles.metricLabel}>Resolved</Text>
          </View>
        </View>

        {/* FILTER CHIPS */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
          <TouchableOpacity
            style={[styles.filterChip, filter === 'ALL' && styles.filterChipActive]}
            onPress={() => setFilter('ALL')}
          >
            <Text style={[styles.filterChipText, filter === 'ALL' && styles.filterChipTextActive]}>
              All ({complaints.length})
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterChip, filter === 'OPEN' && styles.filterChipActive]}
            onPress={() => setFilter('OPEN')}
          >
            <Text style={[styles.filterChipText, filter === 'OPEN' && styles.filterChipTextActive]}>
              Open ({openCount})
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterChip, filter === 'INVESTIGATING' && styles.filterChipActive]}
            onPress={() => setFilter('INVESTIGATING')}
          >
            <Text style={[styles.filterChipText, filter === 'INVESTIGATING' && styles.filterChipTextActive]}>
              Reviewing ({inProgressCount})
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterChip, filter === 'RESOLVED' && styles.filterChipActive]}
            onPress={() => setFilter('RESOLVED')}
          >
            <Text style={[styles.filterChipText, filter === 'RESOLVED' && styles.filterChipTextActive]}>
              Resolved ({resolvedCount})
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </View>

      {/* COMPLAINTS LIST */}
      {filteredComplaints.length === 0 ? (
        <View style={styles.card}>
          <EmptyState
            icon="🛡️"
            title="No Quality Complaints Found"
            message={
              filter === 'ALL'
                ? 'You have not registered any complaints. All your pure raw milk deliveries are in good standing!'
                : `No complaints found in the "${filter}" category.`
            }
          />
          <TouchableOpacity
            style={styles.emptyActionBtn}
            onPress={() => handleOpenRaiseModal()}
            activeOpacity={0.8}
          >
            <Text style={styles.emptyActionBtnText}>Report Bottle / Milk Freshness Issue</Text>
          </TouchableOpacity>
        </View>
      ) : (
        filteredComplaints.map((c) => {
          const badge = getStatusBadgeStyle(c.status);
          const formattedDate = new Date(c.created_at).toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
          });

          return (
            <View key={c.id} style={styles.complaintCard}>
              {/* TOP STRIP */}
              <View style={styles.cardTopStrip}>
                <View style={styles.ticketBadge}>
                  <Text style={styles.ticketText}>{c.ticket_number}</Text>
                </View>
                <View
                  style={[
                    styles.statusBadge,
                    { backgroundColor: badge.bg, borderColor: badge.border },
                  ]}
                >
                  <Text style={[styles.statusBadgeText, { color: badge.text }]}>
                    {badge.label}
                  </Text>
                </View>
              </View>

              {/* CATEGORY & SUBTYPE */}
              <Text style={styles.cardTitle}>{c.title || c.category.replace(/_/g, ' ')}</Text>
              {c.issue_subtype && (
                <View style={styles.subtypePill}>
                  <Text style={styles.subtypeText}>⚠️ {c.issue_subtype}</Text>
                </View>
              )}

              {/* LINKED ORDER INFO */}
              {(c.delivery_date || c.order_id) && (
                <View style={styles.orderLinkBox}>
                  <Text style={styles.orderLinkText}>
                    📦 Order: {c.delivery_date ? `Delivery on ${c.delivery_date}` : ''}
                    {c.milk_product_name ? ` • ${c.milk_product_name}` : ''}
                  </Text>
                </View>
              )}

              {/* USER DESCRIPTION */}
              <View style={styles.descBox}>
                <Text style={styles.descLabel}>Your Report:</Text>
                <Text style={styles.descText}>{c.description}</Text>
              </View>

              {/* ACTION TAKEN & RESOLUTION BOX */}
              {c.action_taken ? (
                <View style={styles.resolutionBox}>
                  <View style={styles.resolutionHeader}>
                    <Text style={styles.resolutionTitle}>Team Resolution & Action:</Text>
                    {c.action_type && (
                      <View style={styles.actionTypeBadge}>
                        <Text style={styles.actionTypeText}>{c.action_type.replace(/_/g, ' ')}</Text>
                      </View>
                    )}
                  </View>
                  <Text style={styles.resolutionText}>{c.action_taken}</Text>

                  {Number(c.refund_amount) > 0 && (
                    <View style={styles.refundRow}>
                      <Text style={styles.refundLabel}>Refund / Credit Issued:</Text>
                      <Text style={styles.refundAmount}>₹{Number(c.refund_amount).toFixed(2)}</Text>
                    </View>
                  )}

                  {c.action_taken_at && (
                    <Text style={styles.actionDateText}>
                      Resolved on {new Date(c.action_taken_at).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                    </Text>
                  )}
                </View>
              ) : (
                <View style={styles.pendingBox}>
                  <Text style={styles.pendingText}>
                    ⏳ Under investigation by Sri Aashikaa Quality Assurance Team. Action details will appear here once reviewed.
                  </Text>
                </View>
              )}

              {/* FOOTER */}
              <View style={styles.cardFooter}>
                <Text style={styles.footerDate}>Reported: {formattedDate}</Text>
                {c.email_notified_at && (
                  <Text style={styles.footerEmail}>✉️ Acknowledgment emailed</Text>
                )}
              </View>
            </View>
          );
        })
      )}

      {/* RAISE COMPLAINT MODAL */}
      <Modal visible={showModal} animationType="slide" transparent={true}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <View>
                <Text style={styles.modalTitle}>Report Quality / Freshness Issue</Text>
                <Text style={styles.modalSub}>Prompt remedy will be dispatched by our team</Text>
              </View>
              <TouchableOpacity onPress={() => setShowModal(false)}>
                <Text style={styles.modalClose}>✕</Text>
              </TouchableOpacity>
            </View>

            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.modalScroll}>
              {/* ORDER SELECTOR */}
              <Text style={styles.fieldLabel}>1. Select Affected Delivery Order</Text>
              {deliveries.length > 0 ? (
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.orderChipsRow}>
                  {deliveries.slice(0, 5).map((del) => {
                    const isSel = selectedOrder?.id === del.id;
                    return (
                      <TouchableOpacity
                        key={del.id}
                        style={[styles.orderChip, isSel && styles.orderChipActive]}
                        onPress={() => setSelectedOrder(del)}
                      >
                        <Text style={[styles.orderChipDate, isSel && styles.orderChipTextActive]}>
                          {del.date} ({del.quantity}L)
                        </Text>
                        <Text style={[styles.orderChipStatus, isSel && styles.orderChipTextActive]}>
                          {del.status}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
              ) : (
                <Text style={styles.noOrderHint}>No recent delivery records linked. General report will be filed.</Text>
              )}

              {/* CATEGORY SELECTOR */}
              <Text style={styles.fieldLabel}>2. What is the issue category? *</Text>
              <View style={styles.categoryGrid}>
                {CATEGORIES.map((cat) => {
                  const isSel = selectedCategory === cat.key;
                  return (
                    <TouchableOpacity
                      key={cat.key}
                      style={[styles.catBtn, isSel && styles.catBtnActive]}
                      onPress={() => handleCategorySelect(cat.key)}
                    >
                      <Text style={[styles.catBtnText, isSel && styles.catBtnTextActive]}>
                        {cat.label}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </View>

              {/* ISSUE SUBTYPE */}
              {SUBTYPES_BY_CATEGORY[selectedCategory] && (
                <>
                  <Text style={styles.fieldLabel}>3. Specific Problem *</Text>
                  <View style={styles.subtypeRow}>
                    {SUBTYPES_BY_CATEGORY[selectedCategory].map((sub) => {
                      const isSel = selectedSubtype === sub;
                      return (
                        <TouchableOpacity
                          key={sub}
                          style={[styles.subtypeChip, isSel && styles.subtypeChipActive]}
                          onPress={() => setSelectedSubtype(sub)}
                        >
                          <Text style={[styles.subtypeChipText, isSel && styles.subtypeChipTextActive]}>
                            {sub}
                          </Text>
                        </TouchableOpacity>
                      );
                    })}
                  </View>
                </>
              )}

              {/* DETAILED DESCRIPTION */}
              <Text style={styles.fieldLabel}>4. Problem Description & Notes *</Text>
              <TextInput
                style={styles.textArea}
                placeholder="Please describe how the milk or bottle was upon receiving (e.g. curdled on boiling, broken neck of bottle, leaked seal)..."
                placeholderTextColor={colors.textLight}
                value={description}
                onChangeText={setDescription}
                multiline={true}
                numberOfLines={4}
              />

              <View style={styles.assuranceBox}>
                <Text style={styles.assuranceTitle}>🛡️ Sri Aashikaa Quality Guarantee</Text>
                <Text style={styles.assuranceText}>
                  Upon submitting, our QA team receives instant alert with your reference number. You will receive an immediate acknowledgment and replacement or credit.
                </Text>
              </View>

              {/* SUBMIT BUTTON */}
              <TouchableOpacity
                style={[styles.submitBtn, submitting && styles.disabledBtn]}
                onPress={handleSubmit}
                disabled={submitting}
                activeOpacity={0.8}
              >
                {submitting ? (
                  <ActivityIndicator color="#ffffff" />
                ) : (
                  <Text style={styles.submitBtnText}>Submit Quality Complaint</Text>
                )}
              </TouchableOpacity>
            </ScrollView>
          </View>
        </View>
      </Modal>
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
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
  },
  raiseBtn: {
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.md,
    paddingVertical: 7,
    borderRadius: radius.md,
  },
  raiseBtnText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '700',
  },
  metricsRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    marginVertical: spacing.sm,
  },
  metricBox: {
    flex: 1,
    backgroundColor: colors.background,
    padding: spacing.sm,
    borderRadius: radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  metricNum: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  metricLabel: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 2,
    textAlign: 'center',
  },
  filterRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    marginTop: spacing.xs,
  },
  filterChip: {
    backgroundColor: colors.background,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: radius.full,
    borderWidth: 1,
    borderColor: colors.border,
  },
  filterChipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primaryDark,
  },
  filterChipText: {
    fontSize: 11,
    fontWeight: '600',
    color: colors.textMuted,
  },
  filterChipTextActive: {
    color: '#ffffff',
    fontWeight: '700',
  },
  card: {
    backgroundColor: colors.surface,
    padding: spacing.lg,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    ...shadow.sm,
  },
  emptyActionBtn: {
    backgroundColor: colors.primary,
    paddingVertical: 10,
    borderRadius: radius.md,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  emptyActionBtnText: {
    color: '#ffffff',
    fontSize: 13,
    fontWeight: '700',
  },
  complaintCard: {
    backgroundColor: colors.surface,
    padding: spacing.md,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    gap: spacing.xs,
    ...shadow.sm,
  },
  cardTopStrip: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  ticketBadge: {
    backgroundColor: '#eff6ff',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radius.sm,
    borderWidth: 1,
    borderColor: '#bfdbfe',
  },
  ticketText: {
    color: '#1d4ed8',
    fontSize: 11,
    fontWeight: '700',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radius.full,
    borderWidth: 1,
  },
  statusBadgeText: {
    fontSize: 10,
    fontWeight: '700',
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: 2,
  },
  subtypePill: {
    alignSelf: 'flex-start',
    backgroundColor: '#fff7ed',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radius.sm,
    borderWidth: 1,
    borderColor: '#ffedd5',
  },
  subtypeText: {
    color: '#c2410c',
    fontSize: 11,
    fontWeight: '600',
  },
  orderLinkBox: {
    backgroundColor: colors.background,
    padding: spacing.xs,
    borderRadius: radius.sm,
    marginTop: 2,
  },
  orderLinkText: {
    fontSize: 11,
    color: colors.textSecondary,
    fontWeight: '600',
  },
  descBox: {
    backgroundColor: colors.background,
    padding: spacing.sm,
    borderRadius: radius.md,
    marginVertical: 4,
  },
  descLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.textMuted,
    marginBottom: 2,
  },
  descText: {
    fontSize: 12,
    color: colors.textPrimary,
    lineHeight: 17,
  },
  resolutionBox: {
    backgroundColor: '#ecfdf5',
    padding: spacing.sm,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: '#a7f3d0',
    marginVertical: 4,
  },
  resolutionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  resolutionTitle: {
    fontSize: 11,
    fontWeight: '700',
    color: '#065f46',
  },
  actionTypeBadge: {
    backgroundColor: '#10b981',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: radius.sm,
  },
  actionTypeText: {
    color: '#ffffff',
    fontSize: 9,
    fontWeight: '800',
  },
  resolutionText: {
    fontSize: 12,
    color: '#047857',
    lineHeight: 16,
  },
  refundRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 6,
    paddingTop: 6,
    borderTopWidth: 1,
    borderTopColor: '#a7f3d0',
  },
  refundLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: '#065f46',
  },
  refundAmount: {
    fontSize: 14,
    fontWeight: '800',
    color: '#047857',
  },
  actionDateText: {
    fontSize: 9,
    color: '#059669',
    marginTop: 4,
  },
  pendingBox: {
    backgroundColor: '#fffbeb',
    padding: spacing.sm,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: '#fef3c7',
    marginVertical: 4,
  },
  pendingText: {
    fontSize: 11,
    color: '#b45309',
    lineHeight: 16,
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 4,
    paddingTop: 4,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  footerDate: {
    fontSize: 10,
    color: colors.textLight,
  },
  footerEmail: {
    fontSize: 10,
    color: colors.primary,
    fontWeight: '600',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.55)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#ffffff',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '90%',
    padding: spacing.lg,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  modalTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  modalSub: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
  },
  modalClose: {
    fontSize: 20,
    color: colors.textMuted,
  },
  modalScroll: {
    gap: spacing.sm,
    paddingBottom: spacing.lg,
  },
  fieldLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textPrimary,
    marginTop: spacing.xs,
  },
  orderChipsRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    paddingVertical: 4,
  },
  orderChip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
  },
  orderChipActive: {
    backgroundColor: '#ecfdf5',
    borderColor: colors.primary,
  },
  orderChipDate: {
    fontSize: 11,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  orderChipStatus: {
    fontSize: 9,
    color: colors.textMuted,
    marginTop: 2,
  },
  orderChipTextActive: {
    color: colors.primary,
  },
  noOrderHint: {
    fontSize: 11,
    color: colors.textLight,
    fontStyle: 'italic',
  },
  categoryGrid: {
    gap: 6,
  },
  catBtn: {
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
  },
  catBtnActive: {
    backgroundColor: '#eff6ff',
    borderColor: '#3b82f6',
  },
  catBtnText: {
    fontSize: 12,
    color: colors.textPrimary,
  },
  catBtnTextActive: {
    color: '#1d4ed8',
    fontWeight: '700',
  },
  subtypeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  subtypeChip: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: radius.full,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
  },
  subtypeChipActive: {
    backgroundColor: '#fff7ed',
    borderColor: '#ea580c',
  },
  subtypeChipText: {
    fontSize: 11,
    color: colors.textSecondary,
  },
  subtypeChipTextActive: {
    color: '#c2410c',
    fontWeight: '700',
  },
  textArea: {
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: spacing.md,
    fontSize: 13,
    color: colors.textPrimary,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  assuranceBox: {
    backgroundColor: '#ecfdf5',
    padding: spacing.sm,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: '#a7f3d0',
    marginVertical: spacing.xs,
  },
  assuranceTitle: {
    fontSize: 11,
    fontWeight: '700',
    color: '#065f46',
  },
  assuranceText: {
    fontSize: 10,
    color: '#047857',
    marginTop: 2,
    lineHeight: 14,
  },
  submitBtn: {
    backgroundColor: colors.primary,
    paddingVertical: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
    marginTop: spacing.xs,
  },
  disabledBtn: {
    opacity: 0.6,
  },
  submitBtnText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '700',
  },
});
