import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api.dart';

const _green = Color(0xFF059669);

class CancelTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CancelTab({super.key, required this.customer});
  @override
  State<CancelTab> createState() => _CancelTabState();
}

class _CancelTabState extends State<CancelTab> {
  List<Map<String, dynamic>> _cancellations = [];
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _submitting = false;

  bool _isBulkMode = false;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  DateTimeRange? _bulkDateRange;
  List<DateTime> _selectedBulkDates = [];
  String _selectedTime = 'Morning';
  String _morningPauseCutoff = '8:00 PM';
  String _eveningPauseCutoff = '2:00 PM';
  final _reasonCtrl = TextEditingController();

  final _times = ['Morning', 'Evening', 'Entire Day'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CancelTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  bool _isDeliveryDay(DateTime date, String plan) {
    final dayNameMap = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    final dayShortMap = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    final dayName = dayNameMap[date.weekday]!;
    final dayShort = dayShortMap[date.weekday]!;
    final cleanPlan = plan.trim();

    if (cleanPlan == 'Daily' || cleanPlan == 'Monday-Sunday') {
      return true;
    } else if (cleanPlan == 'Monday-Saturday') {
      return date.weekday != DateTime.sunday;
    } else if (cleanPlan.contains('Weekdays') || cleanPlan == 'Monday-Friday') {
      return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday;
    } else if (cleanPlan.contains('Alternate')) {
      return date.weekday == DateTime.monday ||
          date.weekday == DateTime.wednesday ||
          date.weekday == DateTime.friday ||
          date.weekday == DateTime.sunday;
    } else {
      return cleanPlan.contains(dayShort) || cleanPlan.contains(dayName);
    }
  }

  DateTime _findFirstValidDate(String plan) {
    DateTime date = DateTime.now().add(const Duration(days: 1));
    int attempts = 0;
    while (!_isDeliveryDay(date, plan) && attempts < 14) {
      date = date.add(const Duration(days: 1));
      attempts++;
    }
    return date;
  }

  Future<void> _load() async {
    final custId = widget.customer['id'] ?? widget.customer['customer_id'] ?? '';
    final list = await SupabaseAPI.fetchCancellations(custId);
    final sub = await SupabaseAPI.fetchCustomerSubscription(custId);

    final plan = sub?['delivery_days'] ?? widget.customer['delivery_days'] ?? 'Daily';
    DateTime validDate = DateTime.now().add(const Duration(days: 1));
    if (!_isDeliveryDay(validDate, plan)) {
      validDate = _findFirstValidDate(plan);
    }

    final rawSlot = sub?['timing_slot'] ??
        widget.customer['delivery_timing'] ??
        widget.customer['delivery_slot'] ??
        'Morning';

    String autoSelectedSlot = 'Morning';
    if (rawSlot.toString().toLowerCase().contains('evening')) {
      autoSelectedSlot = 'Evening';
    } else if (rawSlot.toString().toLowerCase().contains('entire') ||
        rawSlot.toString().toLowerCase().contains('both')) {
      autoSelectedSlot = 'Entire Day';
    } else {
      autoSelectedSlot = 'Morning';
    }

    final timings = await SupabaseAPI.fetchOrderTimingsConfig();
    final mPause = (timings['morning_pause_cutoff'] ?? '8:00 PM').toString();
    final ePause = (timings['evening_pause_cutoff'] ?? '2:00 PM').toString();

    if (mounted) {
      setState(() {
        _cancellations = list;
        _subscription = sub;
        _selectedDate = validDate;
        _selectedTime = autoSelectedSlot;
        _morningPauseCutoff = mPause;
        _eveningPauseCutoff = ePause;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final plan = _subscription?['delivery_days'] ??
        widget.customer['delivery_days'] ??
        'Daily';

    DateTime initial = _selectedDate;
    if (!_isDeliveryDay(initial, plan)) {
      initial = _findFirstValidDate(plan);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      selectableDayPredicate: (date) => _isDeliveryDay(date, plan),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _green),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _applyPresetDays(int targetCount) {
    final plan = _subscription?['delivery_days'] ??
        widget.customer['delivery_days'] ??
        'Daily';

    final List<DateTime> list = [];
    DateTime cur = DateTime.now().add(const Duration(days: 1));
    int attempts = 0;
    while (list.length < targetCount && attempts < 60) {
      if (_isDeliveryDay(cur, plan)) {
        list.add(DateTime(cur.year, cur.month, cur.day));
      }
      cur = cur.add(const Duration(days: 1));
      attempts++;
    }

    if (list.isNotEmpty) {
      setState(() {
        _selectedBulkDates = list;
        _bulkDateRange = DateTimeRange(start: list.first, end: list.last);
      });
    }
  }

  void _applyWeekendPreset() {
    final plan = _subscription?['delivery_days'] ??
        widget.customer['delivery_days'] ??
        'Daily';

    final List<DateTime> list = [];
    DateTime cur = DateTime.now().add(const Duration(days: 1));
    while (cur.weekday != DateTime.saturday) {
      cur = cur.add(const Duration(days: 1));
    }
    final sat = DateTime(cur.year, cur.month, cur.day);
    final sun = sat.add(const Duration(days: 1));

    if (_isDeliveryDay(sat, plan)) list.add(sat);
    if (_isDeliveryDay(sun, plan)) list.add(sun);

    if (list.isNotEmpty) {
      setState(() {
        _selectedBulkDates = list;
        _bulkDateRange = DateTimeRange(start: list.first, end: list.last);
      });
    } else {
      _snack('Weekends are not included in your delivery plan ($plan)', error: true);
    }
  }

  Future<void> _pickDateRange() async {
    final plan = _subscription?['delivery_days'] ??
        widget.customer['delivery_days'] ??
        'Daily';

    final initialRange = _bulkDateRange ??
        DateTimeRange(
          start: DateTime.now().add(const Duration(days: 1)),
          end: DateTime.now().add(const Duration(days: 5)),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: initialRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _green,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final List<DateTime> list = [];
      DateTime cur = picked.start;
      while (!cur.isAfter(picked.end)) {
        if (_isDeliveryDay(cur, plan)) {
          list.add(DateTime(cur.year, cur.month, cur.day));
        }
        cur = cur.add(const Duration(days: 1));
      }

      setState(() {
        _bulkDateRange = picked;
        _selectedBulkDates = list;
      });

      if (list.isEmpty) {
        _snack('No scheduled delivery days found in selected range for plan: $plan', error: true);
      }
    }
  }

  void _removeBulkDate(DateTime d) {
    setState(() {
      _selectedBulkDates.removeWhere((item) =>
          item.year == d.year && item.month == d.month && item.day == d.day);
    });
  }

  void _clearBulkDates() {
    setState(() {
      _selectedBulkDates.clear();
      _bulkDateRange = null;
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _snack('Please enter a reason for cancellation', error: true);
      return;
    }

    final custId = widget.customer['id'] ?? widget.customer['customer_id'] ?? '';
    final existingDates = _cancellations
        .where((c) => (c['approval_status'] ?? c['status']) != 'REJECTED')
        .map((c) => (c['cancellation_date'] ?? c['cancel_date'] ?? '').toString())
        .toSet();

    setState(() => _submitting = true);
    try {
      if (_isBulkMode) {
        if (_selectedBulkDates.isEmpty) {
          _snack('Please select at least 1 date for bulk cancellation', error: true);
          setState(() => _submitting = false);
          return;
        }

        final dateStrings = _selectedBulkDates
            .map((d) => DateFormat('yyyy-MM-dd').format(d))
            .toList();

        final alreadyRequested = dateStrings.where((d) => existingDates.contains(d)).toList();
        final newDatesToCancel = dateStrings.where((d) => !existingDates.contains(d)).toList();

        if (newDatesToCancel.isEmpty) {
          _snack('All selected dates have already been requested or approved.', error: true);
          setState(() => _submitting = false);
          return;
        }

        final count = await SupabaseAPI.submitBulkCancellations(
          custId,
          newDatesToCancel,
          reason,
          timeSlot: _selectedTime,
        );

        _reasonCtrl.clear();
        setState(() {
          _selectedBulkDates.clear();
          _bulkDateRange = null;
        });
        await _load();
        if (!mounted) return;

        if (alreadyRequested.isNotEmpty) {
          _snack('✅ $count cancellation(s) submitted! (${alreadyRequested.length} date(s) were already requested)', error: false);
        } else {
          _snack('✅ $count delivery cancellation request(s) submitted!', error: false);
        }
      } else {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        if (existingDates.contains(dateStr)) {
          _snack('A cancellation request for $dateStr has already been submitted.', error: true);
          setState(() => _submitting = false);
          return;
        }

        await SupabaseAPI.submitCancellation(
          custId,
          dateStr,
          reason,
          timeSlot: _selectedTime,
        );
        _reasonCtrl.clear();
        await _load();
        if (!mounted) return;
        _snack('✅ Cancellation request submitted!', error: false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _bulkPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _green)),
      backgroundColor: _green.withValues(alpha: 0.08),
      side: BorderSide(color: _green.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _subscription?['delivery_days'] ??
        widget.customer['delivery_days'] ??
        'Monday-Sunday';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Request Form ─────────────────────────────────────────────────
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Request Delivery Cancellation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    currentPlan,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: _green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Morning delivery cutoff: Before $_morningPauseCutoff (prev night) • Evening cutoff: Before $_eveningPauseCutoff',
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // ── Mode Switcher: Single Day vs Bulk Dates ───────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isBulkMode = false),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: !_isBulkMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: !_isBulkMode
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_outlined, size: 16, color: !_isBulkMode ? _green : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text('Single Day',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !_isBulkMode ? _green : Colors.grey.shade600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isBulkMode = true;
                          if (_selectedBulkDates.isEmpty) {
                            _applyPresetDays(3);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _isBulkMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _isBulkMode
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.date_range_outlined, size: 16, color: _isBulkMode ? _green : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text('Bulk Date Selection',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _isBulkMode ? _green : Colors.grey.shade600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_isBulkMode) ...[
              // Date picker (Single)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  Text('Only showing scheduled delivery days',
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, color: _green, size: 20),
                    const SizedBox(width: 10),
                    Text(DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ]),
                ),
              ),
            ] else ...[
              // Bulk Selection Controls
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quick Range Presets',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                      Text('Auto-filters to your plan days',
                          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _bulkPresetChip('Next 3 Days', () => _applyPresetDays(3)),
                      _bulkPresetChip('Next 7 Days', () => _applyPresetDays(7)),
                      _bulkPresetChip('Next 14 Days', () => _applyPresetDays(14)),
                      _bulkPresetChip('Upcoming Weekend', () => _applyWeekendPreset()),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18, color: _green),
                      label: Text(
                        _bulkDateRange != null
                            ? '${DateFormat('dd MMM').format(_bulkDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_bulkDateRange!.end)}'
                            : 'Select Date Range 📅',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _green),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _green, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickDateRange,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedBulkDates.isNotEmpty
                            ? _green.withValues(alpha: 0.3)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 16,
                                    color: _selectedBulkDates.isNotEmpty ? _green : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Selected Dates (${_selectedBulkDates.length} days)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedBulkDates.isNotEmpty
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedBulkDates.isNotEmpty)
                              InkWell(
                                onTap: _clearBulkDates,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text('Clear All',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedBulkDates.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No dates selected. Pick a date range or choose a preset above.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _selectedBulkDates.map((d) {
                              final dateFormatted = DateFormat('E, dd MMM').format(d);
                              return Chip(
                                label: Text(dateFormatted,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF065F46))),
                                backgroundColor: const Color(0xFFD1FAE5),
                                deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF065F46)),
                                onDeleted: () => _removeBulkDate(d),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // Time selector
            const Text('Select Time Slot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: _times.map((t) => ChoiceChip(
              label: Text(t),
              selected: _selectedTime == t,
              onSelected: (_) => setState(() => _selectedTime = t),
              selectedColor: _green,
              labelStyle: TextStyle(
                color: _selectedTime == t ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w600, fontSize: 12,
              ),
            )).toList()),
            const SizedBox(height: 12),

            // Reason
            const Text('Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Out of station, Guest visiting, Excess milk...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_isBulkMode
                      ? 'Submit Bulk Cancellation (${_selectedBulkDates.length} days)'
                      : 'Submit Cancellation Request (1 day)'),
              onPressed: _submitting ? null : _submit,
            ),
          ]),
        )),
        const SizedBox(height: 16),

        // ── History ──────────────────────────────────────────────────────
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cancellation History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: _green))
            else if (_cancellations.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No cancellations yet', style: TextStyle(color: Colors.grey)),
              ))
            else
              ..._cancellations.map((c) => _cancelCard(c)),
          ]),
        )),
      ],
    );
  }

  Widget _cancelCard(Map<String, dynamic> c) {
    final status = (c['approval_status'] ?? c['status'] ?? 'REQUESTED').toString();
    final dateVal = (c['cancellation_date'] ?? c['cancel_date'] ?? '').toString();
    final color = status == 'APPROVED'
        ? _green
        : (status == 'REJECTED' ? Colors.red : Colors.orange);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(
          status == 'APPROVED'
              ? Icons.check_circle
              : (status == 'REJECTED' ? Icons.cancel : Icons.pending),
          color: color,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(dateVal,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(c['reason'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(status,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

