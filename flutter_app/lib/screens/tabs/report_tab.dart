import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api.dart';

const _green = Color(0xFF059669);
const _bgCard = Color(0xFFF8FAFC);
const _borderCol = Color(0xFFE2E8F0);

class ReportTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  const ReportTab({super.key, required this.customer});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  // Period filter for the ledger & KPI summary
  String _period = 'this_month'; // 'this_week', 'this_month', 'last_30_days', 'custom'
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  // Selected date for the single-day inspector
  DateTime _inspectedDate = DateTime.now();

  // Status filter for the ledger
  String _statusFilter = 'all'; // 'all', 'delivered', 'paused'

  // Data from server
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _cancellations = [];
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _deliveryPartner;
  Map<String, dynamic>? _pricingConfig;
  double _ratePerLiter = 50.0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _applyPeriod('this_month');
    _load();
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

  String _formatDeliveredTime(Map<String, dynamic> info) {
    if (info['status'] == 'PAUSED') return 'N/A (Paused)';

    // 1. Try explicit delivered_at timestamp
    final rawDeliveredAt = info['delivered_at']?.toString();
    if (rawDeliveredAt != null && rawDeliveredAt.isNotEmpty && rawDeliveredAt != 'null') {
      try {
        final dt = DateTime.parse(rawDeliveredAt).toLocal();
        return DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    // 2. Try delivery_time
    final rawDeliveryTime = info['delivery_time']?.toString();
    if (rawDeliveryTime != null && rawDeliveryTime.isNotEmpty && rawDeliveryTime != 'null') {
      try {
        final dt = DateTime.parse(rawDeliveryTime).toLocal();
        return DateFormat('hh:mm a').format(dt);
      } catch (_) {
        if (rawDeliveryTime.contains(':')) return rawDeliveryTime;
      }
    }

    // 3. Try delivery_timing (e.g., "6:00 AM - 7:00 AM")
    final rawTiming = (info['delivery_timing'] ?? info['timing_slot'] ?? '').toString();
    final timeMatch = RegExp(
            r'(\d{1,2}:\d{2}\s*(?:AM|PM)?(?:\s*-\s*\d{1,2}:\d{2}\s*(?:AM|PM)?)?)',
            caseSensitive: false)
        .firstMatch(rawTiming);
    if (timeMatch != null && timeMatch.group(1) != null) {
      return timeMatch.group(1)!;
    }

    // 4. Fallback based on slot
    final slot = _formatSlotOnly(rawTiming);
    return slot == 'Evening' ? '6:00 PM - 7:00 PM' : '6:00 AM - 7:00 AM';
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _period = period;
      if (period == 'this_week') {
        final monday = today.subtract(Duration(days: today.weekday - 1));
        _startDate = monday;
        _endDate = today;
      } else if (period == 'this_month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = today;
      } else if (period == 'last_30_days') {
        _startDate = today.subtract(const Duration(days: 29));
        _endDate = today;
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final custId = widget.customer['id'] ?? widget.customer['customer_id'] ?? '';

    try {
      final results = await Future.wait([
        SupabaseAPI.fetchDeliveries(
          widget.customer,
          'custom',
          customStartDate: _startDate.subtract(const Duration(days: 30)),
          customEndDate: _endDate.add(const Duration(days: 7)),
        ),
        SupabaseAPI.fetchCancellations(custId.toString()),
        SupabaseAPI.fetchCustomerSubscription(custId.toString()),
        SupabaseAPI.fetchPricingConfig(),
        SupabaseAPI.fetchDeliveryPartnerForCustomer(widget.customer),
      ]);

      if (mounted) {
        setState(() {
          _deliveries = List<Map<String, dynamic>>.from(results[0] as List);
          _cancellations = List<Map<String, dynamic>>.from(results[1] as List);
          _subscription = results[2] as Map<String, dynamic>?;
          _pricingConfig = results[3] as Map<String, dynamic>?;
          _deliveryPartner = results[4] as Map<String, dynamic>?;

          if (_pricingConfig != null && _pricingConfig!['rate_per_liter'] != null) {
            _ratePerLiter = double.tryParse(_pricingConfig!['rate_per_liter'].toString()) ?? 50.0;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Date-Wise Inspection Engine ───────────────────────────────────────────

  /// Computes the exact delivery details for any specified date
  Map<String, dynamic> _getDayDetails(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = date.isAfter(today);
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

    final defaultQty = double.tryParse(
      (_subscription?['daily_quantity'] ?? widget.customer['milk_quantity'] ?? 1.0).toString(),
    ) ?? 1.0;

    final timingSlot = (_subscription?['timing_slot'] ??
            _subscription?['delivery_timing'] ??
            widget.customer['delivery_timing'] ??
            widget.customer['timing_slot'] ??
            'Morning')
        .toString();

    // 1. Check for cancellation on this date
    final cancelMatch = _cancellations.firstWhere(
      (c) {
        final cDate = (c['cancellation_date'] ?? c['cancel_date'] ?? '').toString();
        final status = (c['approval_status'] ?? c['status'] ?? '').toString().toUpperCase();
        return cDate == dateStr && (status == 'APPROVED' || status == 'REQUESTED');
      },
      orElse: () => {},
    );

    if (cancelMatch.isNotEmpty) {
      final reason = cancelMatch['reason']?.toString() ?? 'Paused upon customer request';
      return {
        'date': date,
        'date_str': dateStr,
        'status': 'PAUSED',
        'status_label': 'PAUSED / CANCELLED',
        'quantity': 0.0,
        'amount': 0.0,
        'reason': reason,
        'timing_slot': timingSlot,
        'delivery_timing': timingSlot,
        'delivery_time': null,
        'delivered_at': null,
        'is_future': isFuture,
        'is_today': isToday,
        'has_record': true,
      };
    }

    // 2. Check for explicit delivery log in Supabase
    final deliveryMatch = _deliveries.firstWhere(
      (d) {
        final dDate = (d['delivery_date'] ?? d['created_at'] ?? '').toString().split('T').first;
        return dDate == dateStr;
      },
      orElse: () => {},
    );

    if (deliveryMatch.isNotEmpty) {
      final rawStatus = (deliveryMatch['delivery_status'] ?? 'DELIVERED').toString().toUpperCase();
      final qty = double.tryParse((deliveryMatch['quantity'] ?? deliveryMatch['quantity_delivered'] ?? defaultQty).toString()) ?? defaultQty;
      final amount = deliveryMatch['total_amount'] != null
          ? double.tryParse(deliveryMatch['total_amount'].toString()) ?? (qty * _ratePerLiter)
          : (qty * _ratePerLiter);
      final notes = deliveryMatch['notes']?.toString() ?? 'Delivered to designated drop location';
      final rowTiming = (deliveryMatch['delivery_timing'] ?? deliveryMatch['timing_slot'] ?? timingSlot).toString();

      return {
        'date': date,
        'date_str': dateStr,
        'status': rawStatus,
        'status_label': rawStatus == 'DELIVERED' ? 'DELIVERED' : rawStatus,
        'quantity': qty,
        'amount': amount,
        'reason': notes,
        'timing_slot': rowTiming,
        'delivery_timing': rowTiming,
        'delivery_time': deliveryMatch['delivery_time'],
        'delivered_at': deliveryMatch['delivered_at'],
        'is_future': isFuture,
        'is_today': isToday,
        'has_record': true,
      };
    }

    // 3. Subscription projection if no explicit row
    if (isFuture) {
      return {
        'date': date,
        'date_str': dateStr,
        'status': 'SCHEDULED',
        'status_label': 'SCHEDULED',
        'quantity': defaultQty,
        'amount': defaultQty * _ratePerLiter,
        'reason': 'Scheduled routine delivery drop',
        'timing_slot': timingSlot,
        'delivery_timing': timingSlot,
        'delivery_time': null,
        'delivered_at': null,
        'is_future': true,
        'is_today': false,
        'has_record': false,
      };
    }

    // For past days or today without explicit cancellation, count as successfully delivered
    return {
      'date': date,
      'date_str': dateStr,
      'status': 'DELIVERED',
      'status_label': 'DELIVERED',
      'quantity': defaultQty,
      'amount': defaultQty * _ratePerLiter,
      'reason': isToday ? 'Delivered early morning' : 'Delivered as per active subscription plan',
      'timing_slot': timingSlot,
      'delivery_timing': timingSlot,
      'delivery_time': null,
      'delivered_at': null,
      'is_future': false,
      'is_today': isToday,
      'has_record': false,
    };
  }

  /// Generates the list of dates for the active date range (latest first)
  List<DateTime> _generateDateRange() {
    final list = <DateTime>[];
    DateTime curr = _endDate;
    while (!curr.isBefore(_startDate)) {
      list.add(curr);
      curr = curr.subtract(const Duration(days: 1));
    }
    return list;
  }

  /// Computes aggregate metrics for the selected period
  Map<String, dynamic> _computeSummaryStats(List<DateTime> dates) {
    int deliveredDays = 0;
    int pausedDays = 0;
    double totalLiters = 0.0;
    double totalAmount = 0.0;

    for (final d in dates) {
      final info = _getDayDetails(d);
      if (info['status'] == 'DELIVERED') {
        deliveredDays++;
        totalLiters += (info['quantity'] as double);
        totalAmount += (info['amount'] as double);
      } else if (info['status'] == 'PAUSED') {
        pausedDays++;
      }
    }

    return {
      'delivered_days': deliveredDays,
      'paused_days': pausedDays,
      'liters': totalLiters,
      'amount': totalAmount,
    };
  }

  String _formatBottles(double liters) {
    if (liters <= 0) return 'None';
    if (liters == 0.5) return '1 × 0.5L Glass Bottle';
    if (liters == 1.0) return '1 × 1.0L Glass Bottle';
    if (liters == 1.5) return '1 × 1.0L + 1 × 0.5L Glass Bottles';
    if (liters == 2.0) return '2 × 1.0L Glass Bottles';
    return '${liters.toStringAsFixed(1)}L in Returnable Glass Bottles';
  }

  // ── Date Pickers ──────────────────────────────────────────────────────────

  Future<void> _pickInspectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _inspectedDate = picked);
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _period = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _load();
    }
  }

  // ── Delivery Slip Detail Modal ────────────────────────────────────────────

  void _showDeliverySlipModal(Map<String, dynamic> info) {
    final date = info['date'] as DateTime;
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(date);
    final status = info['status'] as String;
    final isDelivered = status == 'DELIVERED';
    final isPaused = status == 'PAUSED';
    final qty = info['quantity'] as double;
    final amt = info['amount'] as double;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDelivered
                                ? const Color(0xFFDCFCE7)
                                : isPaused
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDelivered
                                ? Icons.check_circle_rounded
                                : isPaused
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.schedule_rounded,
                            color: isDelivered
                                ? _green
                                : isPaused
                                    ? Colors.orange.shade800
                                    : Colors.indigo,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delivery Inspection Slip',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? const Color(0xFFECFDF5)
                        : isPaused
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDelivered
                          ? _green.withValues(alpha: 0.3)
                          : isPaused
                              ? Colors.orange.withValues(alpha: 0.3)
                              : Colors.indigo.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status: ${info['status_label']}',
                        style: TextStyle(
                          color: isDelivered
                              ? _green
                              : isPaused
                                  ? Colors.orange.shade900
                                  : Colors.indigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        isDelivered
                            ? '✅ Verified'
                            : isPaused
                                ? '⏸️ Paused'
                                : '⏰ Scheduled',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt Breakdown Table
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderCol),
                  ),
                  child: Column(
                    children: [
                      _slipRow('Product', _pricingConfig?['milk_product_name'] ?? 'Raw Fresh Farm Cow Milk'),
                      _slipRow('Quantity', isPaused ? '0.0 Liters (Paused)' : '${qty.toStringAsFixed(1)} Liters'),
                      _slipRow('Bottle Packing', _formatBottles(qty)),
                      _slipRow('Rate per Liter', '₹${_ratePerLiter.toStringAsFixed(2)} / Liter'),
                      _slipRow('Delivery Slot', _formatSlotOnly(info['timing_slot'].toString())),
                      if (!isPaused)
                        _slipRow(isDelivered ? 'Delivered Time' : 'Scheduled Time', _formatDeliveredTime(info)),
                      const Divider(height: 16),
                      _slipRow('Day Total Amount', '₹${amt.toStringAsFixed(2)}', isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery Partner & Location Details
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderCol),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery & Logistics Details',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (widget.customer['address'] ?? widget.customer['location'] ?? 'Customer Registered Address').toString(),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining_outlined, size: 18, color: _green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _deliveryPartner != null && _deliveryPartner!['name'] != null
                                  ? 'Delivery Partner: ${_deliveryPartner!['name']} (${_deliveryPartner!['mobile'] ?? 'Assigned'})'
                                  : 'Assigned Partner: Regular Zone Delivery Route',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      if (info['reason'] != null && info['reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isPaused ? Icons.info_outline : Icons.notes_outlined,
                              size: 18,
                              color: isPaused ? Colors.orange : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: ${info['reason']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPaused ? Colors.orange.shade900 : Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Done Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close Slip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slipRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 14 : 12,
              color: isTotal ? _green : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main UI Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allDates = _generateDateRange();
    final stats = _computeSummaryStats(allDates);
    final inspectedInfo = _getDayDetails(_inspectedDate);

    // Filter dates for the daily ledger
    final filteredDates = allDates.where((d) {
      if (_statusFilter == 'all') return true;
      final info = _getDayDetails(d);
      if (_statusFilter == 'delivered') return info['status'] == 'DELIVERED';
      if (_statusFilter == 'paused') return info['status'] == 'PAUSED';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: _green,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            children: [
              // ── Header & Period Tabs ──────────────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assessment_outlined, color: _green, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Delivery & Consumption Reports',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          if (_loading)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inspect daily milk delivery, pause logs, bottle count, and charges date-by-date.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),

                      // Period Selector Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _periodChip('this_week', 'This Week', Icons.calendar_view_week),
                            _periodChip('this_month', 'This Month', Icons.calendar_month),
                            _periodChip('last_30_days', 'Last 30 Days', Icons.history),
                            GestureDetector(
                              onTap: _pickCustomRange,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _period == 'custom' ? _green : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _period == 'custom' ? _green : _borderCol,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      size: 15,
                                      color: _period == 'custom' ? Colors.white : Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _period == 'custom'
                                          ? '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}'
                                          : 'Custom Range 📅',
                                      style: TextStyle(
                                        color: _period == 'custom' ? Colors.white : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Responsive KPI Summary Cards (No ugly wide stretch) ───────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 580;
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_periodLabel(_period)} Overview',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _green.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                                  style: const TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isWide)
                            Row(
                              children: [
                                Expanded(child: _kpiCard('Delivered Days', '${stats['delivered_days']} Days', Icons.local_shipping_outlined, _green)),
                                const SizedBox(width: 8),
                                Expanded(child: _kpiCard('Milk Consumed', '${(stats['liters'] as double).toStringAsFixed(1)} L', Icons.water_drop_outlined, Colors.blue)),
                                const SizedBox(width: 8),
                                Expanded(child: _kpiCard('Period Bill', '₹${(stats['amount'] as double).toStringAsFixed(0)}', Icons.currency_rupee, Colors.purple)),
                                const SizedBox(width: 8),
                                Expanded(child: _kpiCard('Paused Days', '${stats['paused_days']} Days', Icons.pause_circle_outline, Colors.orange)),
                              ],
                            )
                          else
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisExtent: 72,
                              children: [
                                _kpiCard('Delivered Days', '${stats['delivered_days']} Days', Icons.local_shipping_outlined, _green),
                                _kpiCard('Milk Consumed', '${(stats['liters'] as double).toStringAsFixed(1)} L', Icons.water_drop_outlined, Colors.blue),
                                _kpiCard('Period Bill', '₹${(stats['amount'] as double).toStringAsFixed(0)}', Icons.currency_rupee, Colors.purple),
                                _kpiCard('Paused Days', '${stats['paused_days']} Days', Icons.pause_circle_outline, Colors.orange),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // ── Date-Wise Delivery Details Inspector ──────────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _green.withValues(alpha: 0.3), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.search, color: _green, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Date-Wise Delivery Inspector',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _pickInspectedDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _green.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month, size: 14, color: _green),
                                  SizedBox(width: 4),
                                  Text('Pick Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select any specific date to verify delivery arrival, status, bottles & cost.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Quick Jump Date Chips
                      Row(
                        children: [
                          _quickDateChip('Yesterday', DateTime.now().subtract(const Duration(days: 1))),
                          const SizedBox(width: 6),
                          _quickDateChip('Today', DateTime.now()),
                          const SizedBox(width: 6),
                          _quickDateChip('Tomorrow', DateTime.now().add(const Duration(days: 1))),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Day Stepper Navigator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderCol),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Color(0xFF0F172A)),
                              tooltip: 'Previous Day',
                              onPressed: () {
                                setState(() {
                                  _inspectedDate = _inspectedDate.subtract(const Duration(days: 1));
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('EEEE, dd MMMM yyyy').format(_inspectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    _getDayTag(_inspectedDate),
                                    style: const TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Color(0xFF0F172A)),
                              tooltip: 'Next Day',
                              onPressed: () {
                                setState(() {
                                  _inspectedDate = _inspectedDate.add(const Duration(days: 1));
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Selected Day Detail Box
                      _buildInspectedDayCard(inspectedInfo),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Daily Delivery Ledger ─────────────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.view_list_rounded, color: _green, size: 20),
                              const SizedBox(width: 8),
                              const Text('Daily Delivery Ledger',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${filteredDates.length} days',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Complete day-wise breakdown. Tap any day row to view official slip.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips for ledger
                      Row(
                        children: [
                          _filterLedgerChip('all', 'All Days (${allDates.length})'),
                          const SizedBox(width: 6),
                          _filterLedgerChip('delivered', 'Delivered (${stats['delivered_days']})'),
                          const SizedBox(width: 6),
                          _filterLedgerChip('paused', 'Paused (${stats['paused_days']})'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Ledger List
                      if (filteredDates.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderCol),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.event_busy, color: Colors.grey, size: 32),
                              SizedBox(height: 8),
                              Text('No delivery records match this filter for this date range.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDates.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final date = filteredDates[index];
                            final info = _getDayDetails(date);
                            final isSelected = date.year == _inspectedDate.year &&
                                date.month == _inspectedDate.month &&
                                date.day == _inspectedDate.day;

                            return _buildLedgerTile(info, isSelected);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Sub-Widgets ────────────────────────────────────────────────────

  Widget _periodChip(String key, String label, IconData icon) {
    final selected = _period == key;
    return GestureDetector(
      onTap: () {
        _applyPeriod(key);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _green : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _green : _borderCol),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickDateChip(String label, DateTime targetDate) {
    final isSelected = _inspectedDate.year == targetDate.year &&
        _inspectedDate.month == targetDate.month &&
        _inspectedDate.day == targetDate.day;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _inspectedDate = targetDate),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _green.withValues(alpha: 0.1) : _bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? _green : _borderCol, width: isSelected ? 1.5 : 1.0),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? _green : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterLedgerChip(String key, String label) {
    final selected = _statusFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _green : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectedDayCard(Map<String, dynamic> info) {
    final status = info['status'] as String;
    final isDelivered = status == 'DELIVERED';
    final isPaused = status == 'PAUSED';
    final qty = info['quantity'] as double;
    final amt = info['amount'] as double;

    final color = isDelivered ? _green : isPaused ? Colors.orange : Colors.indigo;
    final bgColor = isDelivered
        ? const Color(0xFFECFDF5)
        : isPaused
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFEEF2FF);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status badge & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDelivered
                          ? Icons.check_circle
                          : isPaused
                              ? Icons.pause_circle_filled
                              : Icons.schedule,
                      color: color,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      info['status_label'],
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showDeliverySlipModal(info),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderCol),
                  ),
                  child: const Row(
                    children: [
                      Text('View Slip ➔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quantity & Cost Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isPaused ? '0.0 L' : '${qty.toStringAsFixed(1)} Liters',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                isPaused ? '(Delivery Paused)' : '•  ₹${amt.toStringAsFixed(0)} (@ ₹${_ratePerLiter.toStringAsFixed(0)}/L)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Asset & Slot Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.takeout_dining_outlined, size: 16, color: _green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pack: ${_formatBottles(qty)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Slot: ${_formatSlotOnly(info['timing_slot'].toString())}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
                if (!isPaused) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${isDelivered ? "Delivered" : "Scheduled"} Time: ${_formatDeliveredTime(info)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isPaused ? Icons.warning_amber_rounded : Icons.info_outline,
                      size: 16,
                      color: isPaused ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info['reason'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPaused ? Colors.orange.shade900 : Colors.grey.shade700,
                          fontWeight: isPaused ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTile(Map<String, dynamic> info, bool isSelected) {
    final date = info['date'] as DateTime;
    final status = info['status'] as String;
    final isDelivered = status == 'DELIVERED';
    final isPaused = status == 'PAUSED';
    final qty = info['quantity'] as double;
    final amt = info['amount'] as double;

    final color = isDelivered ? _green : isPaused ? Colors.orange : Colors.indigo;

    return InkWell(
      onTap: () {
        setState(() => _inspectedDate = date);
        _showDeliverySlipModal(info);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _green.withValues(alpha: 0.08) : _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _green : _borderCol,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Calendar Date Box
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderCol),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('d').format(date),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Middle: Day & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('EEEE').format(date),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          info['status_label'],
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPaused
                        ? 'Paused: ${info['reason']}'
                        : 'Raw Farm Milk • Slot: ${_formatSlotOnly(info['timing_slot'].toString())} • ${_formatDeliveredTime(info)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isPaused ? Colors.orange.shade800 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right: Liters & Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPaused ? '0 L' : '${qty.toStringAsFixed(1)} L',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPaused ? Colors.grey : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  isPaused ? '₹0' : '₹${amt.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaused ? Colors.grey : _green,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _periodLabel(String p) {
    switch (p) {
      case 'this_week':
        return 'This Week';
      case 'this_month':
        return 'This Month';
      case 'last_30_days':
        return 'Last 30 Days';
      case 'custom':
        return 'Selected Range';
      default:
        return 'Monthly';
    }
  }

  String _getDayTag(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);

    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today • Active Delivery';
    if (diff == -1) return 'Yesterday • Completed Drop';
    if (diff == 1) return 'Tomorrow • Next Planned Drop';
    if (diff > 1) return '$diff Days Ahead • Scheduled';
    return '${diff.abs()} Days Ago • Historical Log';
  }
}
