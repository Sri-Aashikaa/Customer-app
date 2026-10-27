import React from 'react';
import { StyleSheet, View, Text, Image, TouchableOpacity, Alert } from 'react-native';
import { PartnerInfo } from '../types';
import { colors, spacing, radius } from '../theme/theme';

interface PartnerCardProps {
  partner: PartnerInfo | null;
}

export const PartnerCard: React.FC<PartnerCardProps> = ({ partner }) => {
  const handleCall = () => {
    if (!partner || !partner.phone) {
      Alert.alert('Contact Error', 'No phone number available for delivery partner.');
      return;
    }
    Alert.alert('Contacting Delivery Partner', `Dialing ${partner.phone}...`);
  };

  return (
    <View style={styles.card}>
      <Text style={styles.cardTitle}>Assigned Delivery Partner</Text>
      {partner ? (
        <View style={styles.partnerRow}>
          <Image
            source={{ uri: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80' }}
            style={styles.partnerPhoto}
          />
          <View style={styles.partnerInfo}>
            <Text style={styles.partnerName}>{partner.name}</Text>
            <Text style={styles.partnerSub}>
              ID: {partner.employee_id} • {partner.vehicle}
            </Text>
            {partner.phone ? (
              <Text style={styles.partnerPhone}>{partner.phone}</Text>
            ) : null}
          </View>
          {partner.phone ? (
            <TouchableOpacity style={styles.callBtn} onPress={handleCall} activeOpacity={0.8}>
              <Text style={styles.callBtnText}>Call</Text>
            </TouchableOpacity>
          ) : null}
        </View>
      ) : (
        <View style={styles.unassignedContainer}>
          <Text style={styles.unassignedText}>
            Your delivery area route is assigned automatically every morning.
          </Text>
        </View>
      )}
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
  partnerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginTop: spacing.sm,
  },
  partnerPhoto: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  partnerInfo: {
    flex: 1,
  },
  partnerName: {
    color: colors.textPrimary,
    fontWeight: '700',
    fontSize: 14,
  },
  partnerSub: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 2,
  },
  partnerPhone: {
    color: colors.primary,
    fontWeight: '700',
    fontSize: 12,
    marginTop: 2,
  },
  callBtn: {
    backgroundColor: colors.primary,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: radius.md,
  },
  callBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 12,
  },
  unassignedContainer: {
    marginTop: spacing.sm,
    padding: spacing.md,
    backgroundColor: colors.background,
    borderRadius: radius.md,
  },
  unassignedText: {
    fontSize: 12,
    color: colors.textMuted,
    lineHeight: 18,
  },
});
