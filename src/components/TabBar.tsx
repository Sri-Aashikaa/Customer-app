import React from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { useAuth, NavigationTab } from '../context/AuthContext';
import { colors, spacing } from '../theme/theme';

interface TabDef {
  key: NavigationTab;
  label: string;
  icon: string;
}

const TABS: TabDef[] = [
  { key: 'DASHBOARD', label: 'Home', icon: '🏠' },
  { key: 'CANCEL', label: 'Cancel', icon: '🚫' },
  { key: 'DEPOSIT', label: 'Assets', icon: '📦' },
  { key: 'PAYMENT', label: 'Payment', icon: '💳' },
  { key: 'REPORTS', label: 'Reports', icon: '📊' },
  { key: 'PROFILE', label: 'Profile', icon: '👤' },
];

export const TabBar: React.FC = () => {
  const { activeTab, setActiveTab } = useAuth();

  return (
    <View style={styles.tabBar}>
      {TABS.map((tab) => {
        const isActive = activeTab === tab.key;
        return (
          <TouchableOpacity
            key={tab.key}
            onPress={() => setActiveTab(tab.key)}
            style={styles.tabItem}
            activeOpacity={0.7}
          >
            <Text style={isActive ? styles.tabIconActive : styles.tabIcon}>{tab.icon}</Text>
            <Text style={isActive ? styles.tabTextActive : styles.tabText}>{tab.label}</Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
};

const styles = StyleSheet.create({
  tabBar: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingVertical: spacing.sm,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabIcon: {
    fontSize: 18,
    color: colors.textLight,
  },
  tabIconActive: {
    fontSize: 18,
    color: colors.primary,
  },
  tabText: {
    fontSize: 10,
    color: colors.textLight,
    marginTop: 2,
  },
  tabTextActive: {
    fontSize: 10,
    color: colors.primary,
    fontWeight: '700',
    marginTop: 2,
  },
});
