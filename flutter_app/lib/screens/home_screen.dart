import 'package:flutter/material.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/timing_tab.dart';
import 'tabs/cancel_tab.dart';
import 'tabs/deposit_tab.dart';
import 'tabs/payment_tab.dart';
import 'tabs/report_tab.dart';
import 'tabs/profile_tab.dart';

const kGreen = Color(0xFF059669);

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const HomeScreen({super.key, required this.customer});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  late Map<String, dynamic> _customer;

  @override
  void initState() {
    super.initState();
    _customer = Map<String, dynamic>.from(widget.customer);
  }

  void _onCustomerUpdated(Map<String, dynamic> updated) {
    setState(() => _customer = updated);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(
        customer: _customer,
        onNavigateToTab: (index) => setState(() => _idx = index),
        onUpdated: _onCustomerUpdated,
      ),
      TimingTab(customer: _customer, onUpdated: _onCustomerUpdated),
      CancelTab(customer: _customer),
      DepositTab(customer: _customer),
      PaymentTab(customer: _customer, onPaymentDone: () => setState(() => _customer['is_paid'] = true)),
      ReportTab(customer: _customer),
      ProfileTab(
        customer: _customer,
        onUpdated: _onCustomerUpdated,
        onNavigateToTab: (index) => setState(() => _idx = index),
      ),
    ];

    const navItems = [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.schedule_outlined), activeIcon: Icon(Icons.schedule), label: 'Timing'),
      BottomNavigationBarItem(icon: Icon(Icons.do_not_disturb_alt_outlined), activeIcon: Icon(Icons.do_not_disturb_alt), label: 'Cancel'),
      BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Assets'),
      BottomNavigationBarItem(icon: Icon(Icons.payment_outlined), activeIcon: Icon(Icons.payment), label: 'Payment'),
      BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Reports'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('🥛', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Amudham Raw Milk',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis),
              Text('${_customer['name'] ?? 'Valued Customer'} • ${_customer['customer_id'] ?? _customer['id'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: kGreen, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
      body: IndexedStack(index: _idx, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kGreen,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: navItems,
      ),
    );
  }
}
