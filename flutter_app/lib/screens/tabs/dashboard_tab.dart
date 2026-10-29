import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/session_service.dart';

const _green = Color(0xFF059669);

class DashboardTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Function(int tabIndex)? onNavigateToTab;
  final Function(Map<String, dynamic> updatedCustomer)? onUpdated;
  const DashboardTab({
    super.key,
    required this.customer,
    this.onNavigateToTab,
    this.onUpdated,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Map<String, dynamic> _customer;
  Map<String, dynamic>? _partner;
  Map<String, dynamic>? _orderTimings;
  Map<String, dynamic>? _pendingInvoice;
  List<Map<String, dynamic>> _additionalOrders = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _cancellations = [];
  double _pendingAmount = 0.0;
  double _ratePerLiter = 65.0;
  int _deliveryStep = 0; // -1=Cancelled, 0=Preparing, 1=PickedUp/OutForDelivery, 2=NearYou, 3=Delivered
  String _deliveryStatusLabel = 'Scheduled';
  String _deliveryNotes = '';
  String _todayDeliveredTime = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _customer = Map<String, dynamic>.from(widget.customer);
    _loadServerData();
  }

  @override
  void didUpdateWidget(DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customer != oldWidget.customer) {
      _customer = Map<String, dynamic>.from(widget.customer);
    }
  }

  Future<void> _loadServerData() async {
    final p = await SupabaseAPI.fetchDeliveryPartnerForCustomer(_customer);
    final del = await SupabaseAPI.fetchTodayDelivery(_customer);
    final freshCust = await SupabaseAPI.fetchCustomerDetails(_customer);
    final pending = await SupabaseAPI.fetchActivePendingPayment(_customer);
    final pricing = await SupabaseAPI.fetchPricingConfig();
    final timings = await SupabaseAPI.fetchOrderTimingsConfig();
    final addOrders = await SupabaseAPI.fetchAdditionalMilkOrders(_customer);
    final payments = await SupabaseAPI.fetchPayments(_customer);
    final deliveries = await SupabaseAPI.fetchDeliveries(_customer, 'weekly');
    final custId = _customer['id'] ?? _customer['customer_id'] ?? '';
    final cancellations = await SupabaseAPI.fetchCancellations(custId);

    if (mounted) {
      setState(() {
        _partner = p;
        _orderTimings = timings;
        _additionalOrders = addOrders;
        _payments = payments;
        _deliveries = deliveries;
        _cancellations = cancellations;
        _pendingInvoice = pending;
        _pendingAmount = double.tryParse((pending?['pending_amount'] ?? pending?['total_amount'] ?? 0).toString()) ?? 0.0;

        // Dynamically detect rate: customer rate > monthly rate / 30 > delivery rate > pricing > 65.0
        double effectiveRate = 65.0;
        if (freshCust != null && freshCust['rate_per_liter'] != null && (double.tryParse(freshCust['rate_per_liter'].toString()) ?? 0) > 0) {
          effectiveRate = double.tryParse(freshCust['rate_per_liter'].toString())!;
        } else if (freshCust != null && freshCust['monthly_rate'] != null && (double.tryParse(freshCust['monthly_rate'].toString()) ?? 0) > 0) {
          effectiveRate = (double.tryParse(freshCust['monthly_rate'].toString())! / 30.0).roundToDouble();
        } else if (_customer['rate_per_liter'] != null && (double.tryParse(_customer['rate_per_liter'].toString()) ?? 0) > 0) {
          effectiveRate = double.tryParse(_customer['rate_per_liter'].toString())!;
        } else if (_customer['monthly_rate'] != null && (double.tryParse(_customer['monthly_rate'].toString()) ?? 0) > 0) {
          effectiveRate = (double.tryParse(_customer['monthly_rate'].toString())! / 30.0).roundToDouble();
        } else if (deliveries.isNotEmpty && deliveries.first['rate_per_liter'] != null && (double.tryParse(deliveries.first['rate_per_liter'].toString()) ?? 0) > 0) {
          effectiveRate = double.tryParse(deliveries.first['rate_per_liter'].toString())!;
        } else if (del != null && del['rate_per_liter'] != null && (double.tryParse(del['rate_per_liter'].toString()) ?? 0) > 0) {
          effectiveRate = double.tryParse(del['rate_per_liter'].toString())!;
        } else if (pricing['rate_per_liter'] != null) {
          final cr = double.tryParse(pricing['rate_per_liter'].toString()) ?? 65.0;
          if (cr > 0 && cr != 50.0) effectiveRate = cr;
        }
        _ratePerLiter = effectiveRate;

        if (freshCust != null) {
          _customer = {
            ..._customer,
            ...freshCust,
          };
          widget.onUpdated?.call(_customer);
          UserSession.saveSession(_customer);
        }

        if (del != null) {
          final status = (del['delivery_status'] ?? '').toString().toUpperCase();
          _deliveryNotes = del['notes']?.toString() ?? '';

          String foundTime = '';
          final rawDeliveredAt = del['delivered_at']?.toString();
          if (rawDeliveredAt != null && rawDeliveredAt.isNotEmpty && rawDeliveredAt != 'null') {
            try {
              final dt = DateTime.parse(rawDeliveredAt).toLocal();
              foundTime = DateFormat('hh:mm a').format(dt);
            } catch (_) {}
          }
          if (foundTime.isEmpty) {
            final rawDelTime = del['delivery_time']?.toString();
            if (rawDelTime != null && rawDelTime.isNotEmpty && rawDelTime != 'null') {
              try {
                final dt = DateTime.parse(rawDelTime).toLocal();
                foundTime = DateFormat('hh:mm a').format(dt);
              } catch (_) {
                if (rawDelTime.contains(':')) foundTime = rawDelTime;
              }
            }
          }
          if (foundTime.isEmpty) {
            final rawTiming = (del['delivery_timing'] ?? _customer['delivery_timing'] ?? '').toString();
            final timeMatch = RegExp(r'(\d{1,2}:\d{2}\s*(?:AM|PM)?(?:\s*-\s*\d{1,2}:\d{2}\s*(?:AM|PM)?)?)', caseSensitive: false)
                .firstMatch(rawTiming);
            if (timeMatch != null && timeMatch.group(1) != null) {
              foundTime = timeMatch.group(1)!;
            } else {
              foundTime = _formatSlotOnly(rawTiming) == 'Evening' ? '6:00 PM - 7:00 PM' : '6:00 AM - 7:00 AM';
            }
          }
          _todayDeliveredTime = foundTime;

          if (status == 'CANCELLED') {
            _deliveryStep = -1;
            _deliveryStatusLabel = 'Paused Today';
          } else if (status == 'DELIVERED') {
            _deliveryStep = 3;
            _deliveryStatusLabel = 'Delivered';
          } else if (status == 'NEAR_CUSTOMER') {
            _deliveryStep = 2;
            _deliveryStatusLabel = 'Near You';
          } else if (status == 'OUT_FOR_DELIVERY' || status == 'ASSIGNED' || status == 'IN_TRANSIT') {
            _deliveryStep = 1;
            _deliveryStatusLabel = 'Out for Delivery';
          } else {
            _deliveryStep = 0;
            _deliveryStatusLabel = 'Preparing';
          }
        } else {
          _deliveryStep = 0;
          _deliveryStatusLabel = 'Preparing';
          final rawTiming = (_customer['delivery_timing'] ?? '').toString();
          final timeMatch = RegExp(r'(\d{1,2}:\d{2}\s*(?:AM|PM)?(?:\s*-\s*\d{1,2}:\d{2}\s*(?:AM|PM)?)?)', caseSensitive: false)
              .firstMatch(rawTiming);
          if (timeMatch != null && timeMatch.group(1) != null) {
            _todayDeliveredTime = timeMatch.group(1)!;
          } else {
            _todayDeliveredTime = _formatSlotOnly(rawTiming) == 'Evening' ? '6:00 PM - 7:00 PM' : '6:00 AM - 7:00 AM';
          }
        }

        _loading = false;
      });
    }
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final number = clean.length == 10 ? '91$clean' : clean;
    final uri = Uri.parse('https://wa.me/$number?text=Hello%20Amudham%20Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatSlotOnly(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('both')) return 'Both';
    if (l.contains('evening') ||
        (l.contains('pm') &&
            (l.contains('4:') ||
                l.contains('5:') ||
                l.contains('6:') ||
                l.contains('7:') ||
                l.contains('8:')))) {
      return 'Evening';
    }
    return 'Morning';
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    final cycle = (c['payment_period'] ?? c['billing_cycle'] ?? 'Weekly').toString();
    final qty = c['milk_quantity'] != null
        ? double.tryParse(c['milk_quantity'].toString()) ?? 1.0
        : 1.0;
    final slot = _formatSlotOnly((c['delivery_timing'] ?? c['delivery_slot'] ?? 'Morning').toString());

    final cycleLower = cycle.toLowerCase();
    int calculatedRate;
    String rateSubtitle;
    if (cycleLower == 'daily') {
      calculatedRate = (qty * _ratePerLiter).round();
      rateSubtitle = 'Per Day (₹${_ratePerLiter.toInt()}/L)';
    } else if (cycleLower == 'monthly') {
      calculatedRate = (qty * 30 * _ratePerLiter).round();
      rateSubtitle = 'Per Month (30 Days @ ₹${_ratePerLiter.toInt()}/L)';
    } else {
      calculatedRate = (qty * 7 * _ratePerLiter).round();
      rateSubtitle = 'Per Week (7 Days @ ₹${_ratePerLiter.toInt()}/L)';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime cycleStartDate;
    DateTime nextDueDate;
    String dueDayLabel;

    if (cycleLower == 'daily') {
      cycleStartDate = today;
      nextDueDate = today;
      dueDayLabel = 'Daily';
    } else if (cycleLower == 'monthly') {
      cycleStartDate = DateTime(now.year, now.month, 1);
      if (today.day == 1) {
        nextDueDate = today;
      } else {
        nextDueDate = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
      }
      dueDayLabel = '1st of Month';
    } else {
      // Weekly: closes on Saturday
      final daysSinceSunday = today.weekday % 7;
      cycleStartDate = today.subtract(Duration(days: daysSinceSunday));
      final diffToSaturday = DateTime.saturday - today.weekday;
      if (diffToSaturday == 0) {
        nextDueDate = today;
      } else if (diffToSaturday < 0) {
        nextDueDate = today.add(const Duration(days: 6));
      } else {
        nextDueDate = today.add(Duration(days: diffToSaturday));
      }
      dueDayLabel = 'Saturday';
    }

    final int daysUntilDue = nextDueDate.difference(today).inDays;
    final bool isDueToday = daysUntilDue == 0;

    // Check cancellations in current cycle
    final approvedCancelledDates = _cancellations
        .where((can) {
          final s = (can['approval_status'] ?? can['status'] ?? '').toString().toUpperCase();
          return s == 'APPROVED' || s == 'REQUESTED';
        })
        .map((can) => (can['cancellation_date'] ?? can['cancel_date'] ?? '').toString())
        .toSet();

    // Calculate delivered amount in this cycle
    double deliveredAmount = 0.0;
    double deliveredLiters = 0.0;

    if (cycleLower == 'daily') {
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      if (!approvedCancelledDates.contains(todayStr)) {
        deliveredLiters = qty;
        deliveredAmount = qty * _ratePerLiter;
      }
    } else if (cycleLower == 'monthly') {
      int cancelDays = 0;
      for (int i = 1; i <= today.day; i++) {
        final dStr = DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, i));
        if (approvedCancelledDates.contains(dStr)) cancelDays++;
      }
      final activeDays = (today.day - cancelDays).clamp(0, 31);
      deliveredLiters = activeDays * qty;
      deliveredAmount = deliveredLiters * _ratePerLiter;
    } else {
      // Weekly: calculate based on deliveries table or elapsed days
      if (_deliveries.isNotEmpty) {
        final validDeliveries = _deliveries.where((d) {
          final s = (d['delivery_status'] ?? '').toString().toUpperCase();
          if (s == 'CANCELLED') return false;
          final dDate = (d['delivery_date'] ?? d['created_at'] ?? '').toString().split('T').first;
          final pDate = DateTime.tryParse(dDate);
          if (pDate != null && pDate.isBefore(cycleStartDate)) return false;
          return true;
        }).toList();

        for (var d in validDeliveries) {
          final dQty = double.tryParse((d['quantity'] ?? qty).toString()) ?? qty;
          final dRate = double.tryParse((d['rate_per_liter'] ?? _ratePerLiter).toString()) ?? _ratePerLiter;
          final dAmt = double.tryParse((d['total_amount'] ?? (dQty * dRate)).toString()) ?? (dQty * dRate);
          deliveredLiters += dQty;
          deliveredAmount += dAmt;
        }
      } else {
        int cancelDays = 0;
        final elapsedDays = today.difference(cycleStartDate).inDays + 1;
        for (int i = 0; i < elapsedDays && i < 7; i++) {
          final dStr = DateFormat('yyyy-MM-dd').format(cycleStartDate.add(Duration(days: i)));
          if (approvedCancelledDates.contains(dStr)) cancelDays++;
        }
        final activeDays = (elapsedDays - cancelDays).clamp(0, 7);
        deliveredLiters = activeDays * qty;
        deliveredAmount = deliveredLiters * _ratePerLiter;
      }
    }

    // Add additional orders in current cycle
    for (var ao in _additionalOrders) {
      final aoDateStr = (ao['order_date'] ?? ao['delivery_date'] ?? ao['created_at'] ?? '').toString().split('T').first;
      final aoDate = DateTime.tryParse(aoDateStr);
      if (aoDate != null && !aoDate.isBefore(cycleStartDate)) {
        final aoQty = double.tryParse((ao['quantity'] ?? 0).toString()) ?? 0.0;
        final aoAmt = double.tryParse((ao['total_amount'] ?? (aoQty * _ratePerLiter)).toString()) ?? (aoQty * _ratePerLiter);
        deliveredLiters += aoQty;
        deliveredAmount += aoAmt;
      }
    }

    // Check if paid for current cycle
    bool isPaid = false;
    final milkPayments = _payments.where((p) {
      final status = (p['payment_status'] ?? p['status'] ?? '').toString().toUpperCase();
      if (status != 'PAID' && status != 'COMPLETED') return false;
      final period = (p['billing_period'] ?? '').toString().toLowerCase();
      if (period.contains('deposit')) return false;
      final pDateStr = (p['payment_date'] ?? p['created_at'] ?? '').toString().split('T').first;
      final pDate = DateTime.tryParse(pDateStr);
      if (pDate == null || pDate.isBefore(cycleStartDate)) return false;
      final paidAmt = double.tryParse((p['paid_amount'] ?? p['total_amount'] ?? 0).toString()) ?? 0.0;
      return paidAmt >= (deliveredAmount > 0 ? deliveredAmount : 1.0);
    }).toList();

    if (milkPayments.isNotEmpty) {
      isPaid = true;
    } else if (c['payment_status'] == 'PAID' && _pendingAmount <= 0) {
      isPaid = true;
    }

    // Check if overdue from a prior cycle
    bool isOverdue = false;
    double overdueAmount = 0.0;
    if (_pendingInvoice != null) {
      final invDateStr = (_pendingInvoice?['payment_date'] ?? _pendingInvoice?['created_at'] ?? '').toString().split('T').first;
      final invDate = DateTime.tryParse(invDateStr);
      if (invDate != null && invDate.isBefore(cycleStartDate)) {
        isOverdue = true;
        overdueAmount = double.tryParse((_pendingInvoice?['pending_amount'] ?? _pendingInvoice?['total_amount'] ?? 0).toString()) ?? 0.0;
      }
    }

    final double dueAmount = isOverdue
        ? overdueAmount
        : (deliveredAmount > 0 ? deliveredAmount : calculatedRate.toDouble());

    return RefreshIndicator(
      onRefresh: _loadServerData,
      color: _green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── Welcome Customer Header Banner ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_green, Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Text(
                  (c['name'] ?? 'C').toString().characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 22, color: _green, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Welcome, ${c['name'] ?? 'Valued Customer'} 👋',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Live Sync', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${c['customer_id'] ?? c['id'] ?? ''} • ${c['address'] ?? c['location'] ?? 'Chennai'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
            ]),
          ),

          // ── Today's Delivery Status Card ─────────────────────────────────
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(
                children: [
                  const Text("Today's Delivery", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_loading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
                  ]
                ],
              ),
              _statusBadge(
                _deliveryStatusLabel,
                _deliveryStep == -1
                    ? Colors.orange
                    : (_deliveryStep == 3 ? Colors.blue : _green),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _metricBox('Daily Quantity', '$qty L')),
              const SizedBox(width: 12),
              Expanded(child: _metricBox('Delivery Slot', slot.replaceAll('🌅 ', '').replaceAll('🌇 ', '').replaceAll('☀️ ', ''))),
            ]),
            if (_deliveryStep != -1 && _todayDeliveredTime.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _deliveryStep == 3 ? Icons.check_circle_outline : Icons.access_time,
                      size: 14,
                      color: _deliveryStep == 3 ? _green : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _deliveryStep == 3
                          ? 'Delivered Time: $_todayDeliveredTime'
                          : 'Expected Time: $_todayDeliveredTime',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _deliveryStep == 3 ? _green : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            if (_deliveryStep == -1) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle, color: Color(0xFFD97706), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery Paused for Today',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                          Text(_deliveryNotes.isNotEmpty ? _deliveryNotes : 'Deliveries resume on the next scheduled day.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text('Live Delivery Progress (Supabase Synced)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _green)),
              const SizedBox(height: 12),
              Row(children: [
                _trackerDot(0, 'Preparing'),
                _trackerLine(0),
                _trackerDot(1, 'Out for Delivery'),
                _trackerLine(1),
                _trackerDot(2, 'Near You'),
                _trackerLine(2),
                _trackerDot(3, 'Delivered'),
              ]),
            ],
          ])),
          const SizedBox(height: 16),

          // ── Next Delivery Date & Time Banner ──────────────────────────────
          Card(
            color: const Color(0xFFECFDF5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFA7F3D0), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Next Scheduled Delivery',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          'Tomorrow (${DateTime.now().add(const Duration(days: 1)).day}/${DateTime.now().add(const Duration(days: 1)).month}/${DateTime.now().year})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Scheduled: $qty L • ${slot.replaceAll('🌅 ', '').replaceAll('🌇 ', '').replaceAll('☀️ ', '')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Additional Milk Order Action Button Card ─────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _checkServiceabilityAndOpenAdditionalOrder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🥛', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Order Additional Milk',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'EXTRA',
                                    style: TextStyle(
                                      color: Color(0xFF78350F),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Need more milk? Select date & slot for extra delivery',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Color(0xFF047857), size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Additional Orders Active List (if any) ─────────────────────────
          if (_additionalOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history, size: 18, color: _green),
                          SizedBox(width: 6),
                          Text(
                            'Your Additional Milk Orders',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_additionalOrders.length} Order${_additionalOrders.length > 1 ? "s" : ""}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _green),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._additionalOrders.map((ord) {
                    final status = (ord['delivery_status'] ?? ord['order_status'] ?? 'SCHEDULED').toString().toUpperCase();
                    final date = (ord['delivery_date'] ?? ord['order_date'] ?? '').toString();
                    final timing = (ord['delivery_timing'] ?? '').toString();
                    final q = ord['quantity'] ?? 1;
                    final amt = ord['total_amount'] ?? 0;
                    final isScheduled = status == 'SCHEDULED';
                    final isCancelled = status == 'CANCELLED';

                    Color badgeColor = _green;
                    if (isCancelled) {
                      badgeColor = Colors.red;
                    } else if (status == 'DELIVERED') {
                      badgeColor = Colors.blue;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCancelled ? Colors.grey.shade200 : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCancelled ? '❌' : '🥛',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Date: $date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    Text(
                                      '₹$amt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isCancelled ? Colors.grey : _green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$q L • ${_formatSlotOnly(timing)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isScheduled) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.redAccent),
                              tooltip: 'Cancel this extra order',
                              onPressed: () => _confirmCancelAdditionalOrder(ord),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Delivery Partner Details (Only shown if assigned in delivery_assignments) ───
          if (_partner != null && _partner!.isNotEmpty) ...[
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Assigned Delivery Partner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFECFDF5),
                  child: Text(
                    ((_partner!['name'] ?? 'P').toString().trim().isNotEmpty
                            ? (_partner!['name'] ?? 'P').toString().trim().characters.first
                            : 'P')
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: _green, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_partner!['name'] ?? 'Delivery Partner',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if ((_partner!['employee_id'] ?? _partner!['id']) != null)
                    Text('Partner ID: ${_partner!['employee_id'] ?? _partner!['id']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (_partner!['vehicle_number'] != null && _partner!['vehicle_number'].toString().trim().isNotEmpty)
                    Text(_partner!['vehicle_number'].toString(),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if ((_partner!['mobile'] ?? _partner!['phone']) != null &&
                      (_partner!['mobile'] ?? _partner!['phone']).toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.phone, size: 13, color: _green),
                      const SizedBox(width: 4),
                      Text((_partner!['mobile'] ?? _partner!['phone']).toString(),
                          style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ],
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.call, size: 16, color: _green),
                    label: const Text('Call Partner', style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final ph = (_partner!['mobile'] ?? _partner!['phone'] ?? '').toString();
                      if (ph.isNotEmpty) _makeCall(ph);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat, size: 16, color: Colors.white),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final ph = (_partner!['mobile'] ?? _partner!['phone'] ?? '').toString();
                      if (ph.isNotEmpty) _openWhatsApp(ph);
                    },
                  ),
                ),
              ]),
            ])),
            const SizedBox(height: 16),
          ],

          // ── Payment Status & Rate Summary ─────────────────────────────────
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onNavigateToTab?.call(4),
                child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Status', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? _green.withValues(alpha: 0.1)
                              : (isDueToday || isOverdue)
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPaid
                                  ? 'Paid ✅'
                                  : (isDueToday || isOverdue)
                                      ? 'Pay Now'
                                      : 'Active 📅',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? _green
                                    : (isDueToday || isOverdue)
                                        ? Colors.orange.shade800
                                        : const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isPaid
                                  ? Icons.check_circle_outline
                                  : (isDueToday || isOverdue)
                                      ? Icons.payment
                                      : Icons.calendar_today,
                              size: 10,
                              color: isPaid
                                  ? _green
                                  : (isDueToday || isOverdue)
                                      ? Colors.orange.shade800
                                      : const Color(0xFF0284C7),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPaid
                        ? 'PAID ✅'
                        : (isDueToday || isOverdue)
                            ? 'DUE TODAY (₹${dueAmount.toInt()}) ⚠️'
                            : 'NO DUES TODAY ✅',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isPaid
                          ? _green
                          : (isDueToday || isOverdue)
                              ? Colors.orange.shade800
                              : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPaid
                        ? 'Cycle: ${cycle.toUpperCase()}'
                        : (isDueToday || isOverdue)
                            ? 'Due Today ($dueDayLabel)'
                            : 'Due $dueDayLabel ($daysUntilDue ${daysUntilDue == 1 ? "day" : "days"} left)',
                    style: TextStyle(
                      color: (isDueToday || isOverdue) ? Colors.orange.shade800 : Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ])),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onNavigateToTab?.call(4),
                child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rate Summary', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹$calculatedRate',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(rateSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ])),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _confirmCancelAdditionalOrder(Map<String, dynamic> ord) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Additional Order?'),
        content: Text(
          'Are you sure you want to cancel the additional milk order of ${ord['quantity']} L scheduled for ${ord['delivery_date'] ?? ord['order_date']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseAPI.cancelAdditionalMilkOrder(ord['id'].toString());
                await _loadServerData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Additional milk order cancelled successfully.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel order: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showUnserviceableDialog(String pincode) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.location_off_outlined, color: Color(0xFFD97706), size: 30),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delivery Notice',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Pincode: $pincode',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '“We are not available at your location yet, but we will quickly reach to your location”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'We have logged your location in our operations panel and will notify you as soon as morning & evening delivery commences here!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Understood, Thank You!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkServiceabilityAndOpenAdditionalOrder() async {
    final custPincode = (_customer['pincode'] ?? '').toString().trim();
    if (custPincode.isNotEmpty) {
      final serviceable = await SupabaseAPI.isPincodeServiceable(custPincode);
      if (!serviceable) {
        if (!mounted) return;
        _showUnserviceableDialog(custPincode);
        return;
      }
    }
    _showAdditionalOrderBottomSheet();
  }

  void _showAdditionalOrderBottomSheet() {
    final now = DateTime.now();
    final timings = _orderTimings ?? const {};
    final morningCutoffStr = (timings['morning_cutoff_time'] ?? '09:00 AM').toString();
    final eveningCutoffStr = (timings['evening_cutoff_time'] ?? '05:00 PM').toString();

    final morningSlotLabel = 'Morning';
    final eveningSlotLabel = 'Evening';

    final morningEnabled = timings['morning_slot_enabled'] != false;
    final eveningEnabled = timings['evening_slot_enabled'] != false;
    final allowSameDay = timings['allow_same_day_orders'] != false;
    final maxAdvanceDays = int.tryParse((timings['max_advance_days'] ?? 30).toString()) ?? 30;

    final nowMins = now.hour * 60 + now.minute;
    final morningCutoffMins = SupabaseAPI.parseTimeToMinutes(morningCutoffStr, defaultMinutes: 9 * 60);
    final eveningCutoffMins = SupabaseAPI.parseTimeToMinutes(eveningCutoffStr, defaultMinutes: 17 * 60);

    final isMorningPassedToday = nowMins >= morningCutoffMins;
    final isEveningPassedToday = nowMins >= eveningCutoffMins;
    final isTodayAvailable = allowSameDay && !isEveningPassedToday;

    final tomorrow = now.add(const Duration(days: 1));
    DateTime selectedDate = isTodayAvailable ? now : tomorrow;

    String selectedSlot = morningSlotLabel;
    final custSlot = (_customer['delivery_timing'] ?? _customer['delivery_slot'] ?? '').toString().toLowerCase();
    if (selectedDate.day == now.day && isMorningPassedToday) {
      selectedSlot = eveningSlotLabel;
    } else if (custSlot.contains('evening') && eveningEnabled) {
      selectedSlot = eveningSlotLabel;
    } else if (morningEnabled) {
      selectedSlot = morningSlotLabel;
    } else {
      selectedSlot = eveningSlotLabel;
    }

    double selectedQty = 1.0;
    final notesController = TextEditingController();
    bool submitting = false;
    final double rate = _ratePerLiter > 0 ? _ratePerLiter : 65.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final totalAmount = (selectedQty * rate);
          final isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
          final isTomorrow = selectedDate.year == tomorrow.year && selectedDate.month == tomorrow.month && selectedDate.day == tomorrow.day;
          final dayAfter = now.add(const Duration(days: 2));
          final isDayAfter = selectedDate.year == dayAfter.year && selectedDate.month == dayAfter.month && selectedDate.day == dayAfter.day;

          final canSelectMorning = isToday ? (!isMorningPassedToday && morningEnabled) : morningEnabled;
          final canSelectEvening = isToday ? (!isEveningPassedToday && eveningEnabled) : eveningEnabled;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('🥛', style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Additional Milk',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'One-time extra delivery order',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Info Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: _green, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This extra order will be saved to your scheduled orders for this specific date and will not alter your regular daily subscription.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. SELECT DELIVERY DATE
                  const Text('1. Select Delivery Date',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isTodayAvailable)
                        ChoiceChip(
                          label: Text('Today (${now.day}/${now.month})'),
                          selected: isToday,
                          selectedColor: _green.withValues(alpha: 0.18),
                          labelStyle: TextStyle(
                            color: isToday ? _green : Colors.black87,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(() {
                                selectedDate = now;
                                if (isMorningPassedToday) {
                                  selectedSlot = eveningSlotLabel;
                                }
                              });
                            }
                          },
                        ),
                      ChoiceChip(
                        label: Text('Tomorrow (${tomorrow.day}/${tomorrow.month})'),
                        selected: isTomorrow,
                        selectedColor: _green.withValues(alpha: 0.18),
                        labelStyle: TextStyle(
                          color: isTomorrow ? _green : Colors.black87,
                          fontWeight: isTomorrow ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedDate = tomorrow);
                        },
                      ),
                      ChoiceChip(
                        label: Text('Day After (${dayAfter.day}/${dayAfter.month})'),
                        selected: isDayAfter,
                        selectedColor: _green.withValues(alpha: 0.18),
                        labelStyle: TextStyle(
                          color: isDayAfter ? _green : Colors.black87,
                          fontWeight: isDayAfter ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedDate = dayAfter);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month, size: 16, color: _green),
                        label: Text(
                          !isToday && !isTomorrow && !isDayAfter
                              ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                              : 'Pick Date 📅',
                          style: TextStyle(
                            color: !isToday && !isTomorrow && !isDayAfter ? _green : Colors.black87,
                            fontWeight: !isToday && !isTomorrow && !isDayAfter ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: modalCtx,
                            initialDate: selectedDate,
                            firstDate: now,
                            lastDate: now.add(Duration(days: maxAdvanceDays)),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(primary: _green),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. SELECT DELIVERY SLOT
                  const Text('2. Select Delivery Slot',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (canSelectMorning)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('🌅 Morning',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            selected: selectedSlot.contains('Morning'),
                            selectedColor: _green.withValues(alpha: 0.18),
                            checkmarkColor: _green,
                            labelStyle: TextStyle(
                              color: selectedSlot.contains('Morning') ? _green : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (sel) {
                              if (sel) setModalState(() => selectedSlot = 'Morning');
                            },
                          ),
                        ),
                      if (canSelectMorning && canSelectEvening) const SizedBox(width: 8),
                      if (canSelectEvening)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('🌇 Evening',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            selected: selectedSlot.contains('Evening'),
                            selectedColor: _green.withValues(alpha: 0.18),
                            checkmarkColor: _green,
                            labelStyle: TextStyle(
                              color: selectedSlot.contains('Evening') ? _green : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (sel) {
                              if (sel) setModalState(() => selectedSlot = 'Evening');
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. SELECT QUANTITY
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('3. Extra Quantity',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      Text('Rate: ₹${rate.toInt()}/L',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantity to Add:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: _green, size: 28),
                              onPressed: selectedQty > 0.5
                                  ? () => setModalState(() => selectedQty = (selectedQty - 0.5))
                                  : null,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 64),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '${selectedQty.toStringAsFixed(1)} L',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _green),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: _green, size: 28),
                              onPressed: selectedQty < 20.0
                                  ? () => setModalState(() => selectedQty = (selectedQty + 0.5))
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Quantity Chips
                  Wrap(
                    spacing: 8,
                    children: [0.5, 1.0, 1.5, 2.0, 3.0, 5.0].map((q) {
                      final isSel = selectedQty == q;
                      return ChoiceChip(
                        label: Text('$q L'),
                        selected: isSel,
                        selectedColor: _green.withValues(alpha: 0.18),
                        labelStyle: TextStyle(
                          color: isSel ? _green : Colors.black87,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedQty = q);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 4. OPTIONAL INSTRUCTIONS
                  const Text('4. Special Instructions (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Leave in cold box / ring doorbell',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ORDER SUMMARY CARD
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Date:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Selected Slot:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            Text(
                              selectedSlot,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Additional Milk Quantity:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            Text(
                              '${selectedQty.toStringAsFixed(1)} L (${_customer['milk_type'] ?? 'Raw Cow Milk'})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Order Amount:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                            Text(
                              '₹${totalAmount.toStringAsFixed(totalAmount % 1 == 0 ? 0 : 2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SUBMIT BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            setModalState(() => submitting = true);
                            try {
                              await SupabaseAPI.createAdditionalMilkOrder(
                                customer: _customer,
                                deliveryDate: selectedDate,
                                deliverySlot: selectedSlot,
                                quantity: selectedQty,
                                ratePerLiter: rate,
                                milkProductId: _customer['milk_product_id'],
                                milkProductName: _customer['milk_type'] ?? 'Raw cow milk',
                                notes: notesController.text.trim(),
                              );

                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }
                              await _loadServerData();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '🎉 Additional Order for ${selectedQty.toStringAsFixed(1)} L on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} placed successfully!',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: _green,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to place additional order: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setModalState(() => submitting = false);
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Confirm & Place Additional Order • ₹${totalAmount.toStringAsFixed(totalAmount % 1 == 0 ? 0 : 2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _trackerDot(int step, String label) {
    final done = _deliveryStep >= step;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: done ? _green : Colors.grey.shade200,
          shape: BoxShape.circle,
          border: Border.all(color: done ? _green : Colors.grey.shade300, width: 2),
        ),
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 8, color: done ? _green : Colors.grey)),
    ]);
  }

  Widget _trackerLine(int step) {
    return Expanded(child: Container(
      height: 3, margin: const EdgeInsets.only(bottom: 18),
      color: _deliveryStep > step ? _green : Colors.grey.shade200,
    ));
  }

  Widget _card(Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16), child: child));

  Widget _metricBox(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );

  Widget _statusBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}
