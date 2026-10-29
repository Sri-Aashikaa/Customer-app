import 'package:flutter/material.dart';
import '../../services/api.dart';

const _green = Color(0xFF059669);

class TimingTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Function(Map<String, dynamic>)? onUpdated;
  const TimingTab({super.key, required this.customer, this.onUpdated});

  @override
  State<TimingTab> createState() => _TimingTabState();
}

class _TimingTabState extends State<TimingTab> {
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _orderTimings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
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

  Future<void> _loadSubscription() async {
    final custId = widget.customer['id'] ?? widget.customer['customer_id'] ?? '';
    var sub = await SupabaseAPI.fetchCustomerSubscription(custId);
    final timings = await SupabaseAPI.fetchOrderTimingsConfig();

    // If no subscription record exists in customer_subscriptions table yet, seed it now
    if (sub == null && custId.toString().isNotEmpty) {
      final initialSlot = widget.customer['delivery_timing'] ??
          widget.customer['delivery_slot'] ??
          'Morning (5:00 AM - 9:30 AM)';
      final initialQty = widget.customer['milk_quantity'] != null
          ? double.tryParse(widget.customer['milk_quantity'].toString()) ?? 1.5
          : 1.5;

      try {
        await SupabaseAPI.updateSubscription(
          custId,
          dailyQuantity: initialQty,
          timingSlot: initialSlot,
          deliveryDays: 'Monday-Sunday',
        );
        sub = await SupabaseAPI.fetchCustomerSubscription(custId);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _subscription = sub;
        _orderTimings = timings;
        _loading = false;
      });
    }
  }

  void _openUpdateBottomSheet(
      String currentSlot, double currentQty, String currentDays) {
    String selectedSlot = 'Morning';
    final lowerSlot = currentSlot.toLowerCase();
    if (lowerSlot.contains('both') || (lowerSlot.contains('morning') && lowerSlot.contains('evening'))) {
      selectedSlot = 'Both';
    } else if (lowerSlot.contains('evening')) {
      selectedSlot = 'Evening';
    } else {
      selectedSlot = 'Morning';
    }
    double selectedQty = currentQty;

    final standardPlans = [
      'Daily',
      'Monday-Saturday',
      'Weekdays (Mon-Fri)',
      'Alternate Days',
    ];

    String normalizedDays = currentDays == 'Monday-Sunday' ? 'Daily' : currentDays;
    bool isCustom = !standardPlans.contains(normalizedDays);
    String activePlanOption = isCustom ? 'Custom Days' : normalizedDays;

    final allDaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final Set<String> selectedCustomDays = {};

    if (isCustom) {
      for (final d in allDaysShort) {
        if (currentDays.contains(d)) selectedCustomDays.add(d);
      }
    }
    if (selectedCustomDays.isEmpty) {
      selectedCustomDays.addAll({'Mon', 'Wed', 'Fri'});
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Update Delivery Schedule',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // 1. Delivery Slot
                  const Text('Delivery Slot',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('🌅 Morning',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          selected: selectedSlot == 'Morning',
                          selectedColor: _green.withValues(alpha: 0.2),
                          checkmarkColor: _green,
                          labelStyle: TextStyle(
                            color: selectedSlot == 'Morning'
                                ? _green
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(() {
                                selectedSlot = 'Morning';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('🌇 Evening',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          selected: selectedSlot == 'Evening',
                          selectedColor: _green.withValues(alpha: 0.2),
                          checkmarkColor: _green,
                          labelStyle: TextStyle(
                            color: selectedSlot == 'Evening'
                                ? _green
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(() {
                                selectedSlot = 'Evening';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('🔄 Both',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          selected: selectedSlot == 'Both',
                          selectedColor: _green.withValues(alpha: 0.2),
                          checkmarkColor: _green,
                          labelStyle: TextStyle(
                            color: selectedSlot == 'Both'
                                ? _green
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(() {
                                selectedSlot = 'Both';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Daily Quantity
                  const Text('Daily Milk Quantity',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.outlined(
                        icon: const Icon(Icons.remove),
                        onPressed: selectedQty > 0.5
                            ? () {
                                setModalState(() {
                                  selectedQty = (selectedQty - 0.5);
                                });
                              }
                            : null,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${selectedQty.toStringAsFixed(1)} Liters',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _green),
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.add),
                        onPressed: selectedQty < 10.0
                            ? () {
                                setModalState(() {
                                  selectedQty = (selectedQty + 0.5);
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [0.5, 1.0, 1.5, 2.0, 3.0].map((qty) {
                      final isSel = selectedQty == qty;
                      return ChoiceChip(
                        label: Text('$qty L'),
                        selected: isSel,
                        selectedColor: _green.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSel ? _green : Colors.black87,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (sel) {
                          if (sel) {
                            setModalState(() => selectedQty = qty);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // 3. Delivery Days
                  const Text('Subscription Days Plan',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Daily',
                      'Monday-Saturday',
                      'Weekdays (Mon-Fri)',
                      'Alternate Days',
                      'Custom Days',
                    ].map((daysOption) {
                      final isSel = activePlanOption == daysOption;
                      return ChoiceChip(
                        label: Text(daysOption),
                        selected: isSel,
                        selectedColor: _green.withValues(alpha: 0.2),
                        checkmarkColor: _green,
                        labelStyle: TextStyle(
                          color: isSel ? _green : Colors.black87,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (sel) {
                          if (sel) {
                            setModalState(() => activePlanOption = daysOption);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  // Custom Days Selector Wrap
                  if (activePlanOption == 'Custom Days') ...[
                    const SizedBox(height: 12),
                    const Text('Select Delivery Days:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                          .map((day) {
                        final isSelected = selectedCustomDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          selectedColor: _green,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (sel) {
                            setModalState(() {
                              if (sel) {
                                selectedCustomDays.add(day);
                              } else {
                                if (selectedCustomDays.length > 1) {
                                  selectedCustomDays.remove(day);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              final custId = widget.customer['id'] ??
                                  widget.customer['customer_id'] ??
                                  '';
                               final String finalSlotText;
                               if (selectedSlot == 'Evening') {
                                 finalSlotText = 'Evening';
                               } else if (selectedSlot == 'Both') {
                                 finalSlotText = 'Both (Morning & Evening)';
                               } else {
                                 finalSlotText = 'Morning';
                               }

                              String finalDaysText = activePlanOption;
                              if (activePlanOption == 'Custom Days') {
                                final orderedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                    .where((d) => selectedCustomDays.contains(d))
                                    .join(', ');
                                finalDaysText = 'Custom ($orderedDays)';
                              }

                              try {
                                await SupabaseAPI.updateSubscription(
                                  custId,
                                  dailyQuantity: selectedQty,
                                  timingSlot: finalSlotText,
                                  deliveryDays: finalDaysText,
                                );

                                final updatedCust =
                                    Map<String, dynamic>.from(widget.customer);
                                updatedCust['milk_quantity'] = selectedQty;
                                updatedCust['delivery_timing'] = finalSlotText;
                                updatedCust['delivery_days'] = finalDaysText;

                                widget.onUpdated?.call(updatedCust);

                                if (mounted) {
                                  setState(() {
                                    _subscription = {
                                      ...?_subscription,
                                      'daily_quantity': selectedQty,
                                      'timing_slot': finalSlotText,
                                      'delivery_days': finalDaysText,
                                    };
                                  });
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                              'Delivery schedule updated successfully!'),
                                        ],
                                      ),
                                      backgroundColor: _green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Schedule Changes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
    final custPincode = (widget.customer['pincode'] ?? '').toString().trim();
    if (custPincode.isNotEmpty) {
      final serviceable = await SupabaseAPI.isPincodeServiceable(custPincode);
      if (!serviceable) {
        if (!mounted) return;
        _showUnserviceableDialog(custPincode);
        return;
      }
    }
    _openAdditionalOrderBottomSheet();
  }

  void _openAdditionalOrderBottomSheet() {
    final now = DateTime.now();
    final timings = _orderTimings ?? const {};
    final morningCutoffStr = (timings['morning_cutoff_time'] ?? '09:00 AM').toString();
    final eveningCutoffStr = (timings['evening_cutoff_time'] ?? '05:00 PM').toString();
    final morningStart = (timings['morning_slot_start'] ?? '5:00 AM').toString();
    final morningEnd = (timings['morning_slot_end'] ?? '9:30 AM').toString();
    final eveningStart = (timings['evening_slot_start'] ?? '5:00 PM').toString();
    final eveningEnd = (timings['evening_slot_end'] ?? '8:00 PM').toString();

    final morningSlotLabel = (timings['morning_slot_label'] ?? 'Morning ($morningStart - $morningEnd)').toString();
    final eveningSlotLabel = (timings['evening_slot_label'] ?? 'Evening ($eveningStart - $eveningEnd)').toString();

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
    final custSlot = (widget.customer['delivery_timing'] ?? widget.customer['delivery_slot'] ?? '').toString().toLowerCase();
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
    final double rate = 65.0;

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
                            label: Center(
                              child: Text('🌅 Morning\n$morningStart - $morningEnd',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            selected: selectedSlot.contains('Morning'),
                            selectedColor: _green.withValues(alpha: 0.18),
                            checkmarkColor: _green,
                            labelStyle: TextStyle(
                              color: selectedSlot.contains('Morning') ? _green : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (sel) {
                              if (sel) setModalState(() => selectedSlot = morningSlotLabel);
                            },
                          ),
                        ),
                      if (canSelectMorning && canSelectEvening) const SizedBox(width: 8),
                      if (canSelectEvening)
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text('🌇 Evening\n$eveningStart - $eveningEnd',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            selected: selectedSlot.contains('Evening'),
                            selectedColor: _green.withValues(alpha: 0.18),
                            checkmarkColor: _green,
                            labelStyle: TextStyle(
                              color: selectedSlot.contains('Evening') ? _green : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (sel) {
                              if (sel) setModalState(() => selectedSlot = eveningSlotLabel);
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
                              '${selectedQty.toStringAsFixed(1)} L (${widget.customer['milk_type'] ?? 'Raw Cow Milk'})',
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
                                customer: widget.customer,
                                deliveryDate: selectedDate,
                                deliverySlot: selectedSlot,
                                quantity: selectedQty,
                                ratePerLiter: rate,
                                milkProductId: widget.customer['milk_product_id'],
                                milkProductName: widget.customer['milk_type'] ?? 'Raw cow milk',
                                notes: notesController.text.trim(),
                              );

                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }
                              await _loadSubscription();

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

  @override
  Widget build(BuildContext context) {
    final slot = _subscription?['timing_slot'] ??
        widget.customer['delivery_timing'] ??
        widget.customer['delivery_slot'] ??
        'Morning';

    final dailyQty = _subscription?['daily_quantity'] != null
        ? double.tryParse(_subscription!['daily_quantity'].toString()) ?? 1.5
        : (widget.customer['milk_quantity'] != null
            ? double.tryParse(widget.customer['milk_quantity'].toString()) ?? 1.5
            : 1.5);

    final deliveryDays =
        _subscription?['delivery_days'] ?? 'Monday-Sunday';

    final String displaySlot = _formatSlotOnly(slot.toString());
    final nextDate = DateTime.now().add(const Duration(days: 1));
    final nextDateStr = 'Tomorrow (${nextDate.day}/${nextDate.month}/${nextDate.year})';

    bool isDayScheduled(String day, String plan) {
      final cleanPlan = plan.trim();
      final dayShort = day.substring(0, 3);

      if (cleanPlan.startsWith('Custom') || cleanPlan.contains(',')) {
        return cleanPlan.contains(dayShort) || cleanPlan.contains(day);
      } else if (cleanPlan == 'Monday-Saturday') {
        return day != 'Sunday';
      } else if (cleanPlan.contains('Weekdays') || cleanPlan == 'Monday-Friday') {
        return day != 'Saturday' && day != 'Sunday';
      } else if (cleanPlan.contains('Alternate')) {
        return day == 'Monday' || day == 'Wednesday' || day == 'Friday' || day == 'Sunday';
      }
      return true; // Monday-Sunday (All Days)
    }

    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final schedule = daysOfWeek
        .map((day) {
          final scheduled = isDayScheduled(day, deliveryDays);
          return {
            'day': day,
            'time': displaySlot,
            'qty': '$dailyQty L',
            'isScheduled': scheduled,
          };
        })
        .where((s) => s['isScheduled'] == true)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        Card(
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
                        const Text('Delivery Schedule',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_loading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _green)),
                        ]
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Update',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _openUpdateBottomSheet(
                          displaySlot, dailyQty, deliveryDays),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _infoRow(Icons.schedule, 'Assigned Delivery Slot', displaySlot),
                _infoRow(Icons.event, 'Next Delivery Date', nextDateStr),
                _infoRow(Icons.calendar_today, 'Subscription Plan', deliveryDays),
                _infoRow(Icons.local_drink_outlined, 'Daily Quantity', '$dailyQty Liters'),
                _infoRow(Icons.location_on_outlined, 'Delivery Area',
                    widget.customer['area'] ?? widget.customer['location'] ?? 'Anna Nagar'),
                _infoRow(Icons.info_outline, 'Cutoff to Cancel',
                    displaySlot.toLowerCase().contains('evening')
                        ? 'Before ${_orderTimings?['evening_pause_cutoff'] ?? '2:00 PM'} (same day)'
                        : 'Before ${_orderTimings?['morning_pause_cutoff'] ?? '8:00 PM'} (previous night)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Order Additional Milk Action Card
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🥛', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
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
                                  fontSize: 15,
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
                          const SizedBox(height: 2),
                          const Text(
                            'Need more milk on a specific day? Tap to schedule extra milk',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Color(0xFF047857), size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Next 7 Days Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weekly Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Upcoming 7 days delivery plan synced with Supabase',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                if (schedule.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No active delivery days selected for this week.',
                        style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                else
                  ...schedule.map((s) => _scheduleRow(s)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        // Timing notice
        Card(
          color: const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.notifications_active_outlined,
                  color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Notification',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706))),
                    Text(
                        'You will receive a notification 10 minutes before delivery at $displaySlot.',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 18, color: _green),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _scheduleRow(Map<String, dynamic> s) {
    final bool isScheduled = s['isScheduled'] == true;
    final dotColor = isScheduled ? _green : Colors.grey.shade400;
    final timeColor = isScheduled ? Colors.grey.shade600 : Colors.grey.shade400;
    final qtyColor = isScheduled ? _green : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isScheduled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isScheduled ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(s['day']!,
                style: TextStyle(
                    fontWeight: isScheduled ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                    color: isScheduled ? const Color(0xFF0F172A) : Colors.grey.shade500))),
        Text(s['time']!,
            style: TextStyle(color: timeColor, fontSize: 12)),
        const SizedBox(width: 12),
        Text(s['qty']!,
            style: TextStyle(
                color: qtyColor,
                fontWeight: isScheduled ? FontWeight.bold : FontWeight.normal,
                fontSize: 12)),
      ]),
    );
  }
}

