import React from 'react';
import { StyleSheet, SafeAreaView, StatusBar, ScrollView } from 'react-native';
import { AuthProvider, useAuth } from './src/context/AuthContext';
import { Header } from './src/components/Header';
import { TabBar } from './src/components/TabBar';
import { AuthScreen } from './src/screens/AuthScreen';
import { DashboardScreen } from './src/screens/DashboardScreen';
import { ScheduleScreen } from './src/screens/ScheduleScreen';
import { CancellationScreen } from './src/screens/CancellationScreen';
import { AssetsScreen } from './src/screens/AssetsScreen';
import { PaymentsScreen } from './src/screens/PaymentsScreen';
import { ReportsScreen } from './src/screens/ReportsScreen';
import { ProfileScreen } from './src/screens/ProfileScreen';
import { colors, spacing } from './src/theme/theme';

const MainAppContent: React.FC = () => {
  const { isLoggedIn, activeTab } = useAuth();

  if (!isLoggedIn) {
    return <AuthScreen />;
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.surface} />
      <Header />

      <ScrollView contentContainerStyle={styles.contentScroll} keyboardShouldPersistTaps="handled">
        {activeTab === 'DASHBOARD' && <DashboardScreen />}
        {activeTab === 'TIMING' && <ScheduleScreen />}
        {activeTab === 'CANCEL' && <CancellationScreen />}
        {activeTab === 'DEPOSIT' && <AssetsScreen />}
        {activeTab === 'PAYMENT' && <PaymentsScreen />}
        {activeTab === 'REPORTS' && <ReportsScreen />}
        {activeTab === 'PROFILE' && <ProfileScreen />}
      </ScrollView>

      <TabBar />
    </SafeAreaView>
  );
};

export default function App() {
  return (
    <AuthProvider>
      <MainAppContent />
    </AuthProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  contentScroll: {
    padding: spacing.lg,
  },
});
