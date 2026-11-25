import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';
import '../services/session_service.dart';
import '../services/language_service.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';

const kGreen = Color(0xFF059669);

class OnboardingScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const OnboardingScreen({super.key, required this.customer});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _loading = false;

  // Server Pricing & Products Config (Fetched dynamically from milk_products & enterprise_settings)
  double _ratePerLiter = 50.0;
  double _bottle1LDeposit = 150.0;
  double _bottle05LDeposit = 50.0;
  String _bottle1LName = 'GLASS BOTTLE 1 Liter (1000ml)';
  String _bottle05LName = 'GLASS BOTTLE 0.5 Liter (500ml)';
  double _iceBoxDepositAmount = 250.0;
  String _milkProductName = 'Raw Fresh Farm Cow Milk';
  String _milkProductDesc = 'Pure A2 Cow Milk collected daily from grass-fed cows.';
  Map<String, dynamic>? _enterprise;

  // Automated bottle calculations for both bottle types (1.0L and 0.5L)
  // Daily milk rotation requires 2 sets of bottles (1 day in delivery, 1 day exchange)
  int get _count1L {
    final qty = _effectiveQuantity;
    if (qty <= 0.5) return 0;
    return (qty.floor() * 2).clamp(2, 50);
  }

  int get _count05L {
    final qty = _effectiveQuantity;
    if (qty <= 0.5) return 2;
    final rem = qty - qty.floor();
    return rem >= 0.25 ? 2 : 0;
  }

  // Onboarding Selections
  double _selectedQuantity = 1.5;
  bool _isCustomQuantity = false;
  final TextEditingController _customQuantityController = TextEditingController();

  String _selectedTimeSlot = '🌅 Morning';
  String _selectedDeliveryDays = 'Daily (Mon - Sun)';
  bool _isCustomDeliveryDays = false;
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> _selectedDaysSet = {'Mon', 'Wed', 'Fri'};
  final TextEditingController _customDeliveryDaysController = TextEditingController(text: 'Mon, Wed, Fri');

  final TextEditingController _customNotesController = TextEditingController();
  final TextEditingController _alternateMobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _iceBoxNeeded = true;
  String _selectedPaymentPeriod = 'weekly'; // 'daily', 'weekly', 'monthly'

  final List<double> _quantityOptions = [0.5, 1.0, 1.5, 2.0, 3.0];
  final List<String> _timeSlotOptions = [
    '🌅 Morning',
    '🌇 Evening',
    '☀️ Both Morning & Evening',
  ];
  final List<String> _deliveryDayOptions = [
    'Daily (Mon - Sun)',
    'Alternate Days',
    'Weekdays Only',
    'Weekends Only',
    'Custom Days (Specify)',
  ];

  @override
  void initState() {
    super.initState();
    _alternateMobileController.text = (widget.customer['alternate_mobile'] ??
            widget.customer['alt_mobile'] ??
            '')
        .toString();
    _emailController.text = (widget.customer['email'] ??
            widget.customer['email_id'] ??
            '')
        .toString();
    _loadServerPricingConfig();
  }

  @override
  void dispose() {
    _customQuantityController.dispose();
    _customDeliveryDaysController.dispose();
    _customNotesController.dispose();
    _alternateMobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadServerPricingConfig() async {
    final config = await SupabaseAPI.fetchPricingConfig();
    final enterprise = await SupabaseAPI.fetchEnterpriseSettings();
    if (mounted) {
      setState(() {
        _enterprise = enterprise;
        _ratePerLiter = double.tryParse((config['rate_per_liter'] ?? 50.0).toString()) ?? 50.0;
        _bottle1LDeposit = double.tryParse((config['bottle_1l_deposit'] ?? 150.0).toString()) ?? 150.0;
        _bottle05LDeposit = double.tryParse((config['bottle_05l_deposit'] ?? 50.0).toString()) ?? 50.0;
        _bottle1LName = (config['bottle_1l_name'] ?? 'GLASS BOTTLE 1 Liter (1000ml)').toString();
        _bottle05LName = (config['bottle_05l_name'] ?? 'GLASS BOTTLE 0.5 Liter (500ml)').toString();
        _iceBoxDepositAmount = double.tryParse((config['ice_box_deposit_amount'] ?? 250.0).toString()) ?? 250.0;
        _milkProductName = (config['milk_product_name'] ?? 'Raw Fresh Farm Cow Milk').toString();
        _milkProductDesc = (config['milk_product_desc'] ?? 'Pure A2 Cow Milk collected daily from grass-fed cows.').toString();
      });
    }
  }

  int get _totalBottleCount => _count1L + _count05L;

  int get _bottleDepositAmount =>
      (_count1L * _bottle1LDeposit + _count05L * _bottle05LDeposit).round();

  int get _iceBoxDepositCalculated =>
      _iceBoxNeeded ? _iceBoxDepositAmount.round() : 0;

  int get _totalDepositCalculated =>
      _bottleDepositAmount + _iceBoxDepositCalculated;

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : kGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  double get _effectiveQuantity {
    if (_isCustomQuantity) {
      final parsed = double.tryParse(_customQuantityController.text.trim());
      return (parsed != null && parsed > 0) ? parsed : 1.5;
    }
    return _selectedQuantity;
  }

  String get _effectiveDeliveryDays {
    if (_isCustomDeliveryDays) {
      final customText = _customDeliveryDaysController.text.trim();
      if (customText.isNotEmpty) return customText;
      if (_selectedDaysSet.isNotEmpty) return _selectedDaysSet.join(', ');
      return 'Custom Days';
    }
    return _selectedDeliveryDays;
  }

  void _startUPIPaymentFlow(int totalDeposit) {
    if (_isCustomDeliveryDays && _effectiveDeliveryDays.isEmpty) {
      _snack('onb_custom_days_required'.tr);
      return;
    }

    if (_isCustomQuantity && (double.tryParse(_customQuantityController.text.trim()) ?? 0) <= 0) {
      _snack('onb_valid_qty_err'.tr);
      return;
    }

    if (_totalBottleCount < 2) {
      _snack('onb_min_bottles_daily_err'.tr);
      return;
    }

    _showUPIPaymentBottomSheet(totalDeposit);
  }

  Future<void> _doCompleteOnboarding() async {
    if (_totalBottleCount < 2) {
      _snack('onb_min_bottles_err'.tr);
      return;
    }

    final currentQty = _effectiveQuantity;
    final currentDays = _effectiveDeliveryDays;
    final estimatedMonthlyRate = (currentQty * 30 * _ratePerLiter).roundToDouble();
    final totalDeposit = _totalDepositCalculated.toDouble();

    setState(() => _loading = true);
    try {
      final onboardingData = {
        'milk_quantity': currentQty,
        'delivery_timing': _selectedTimeSlot,
        'delivery_days': currentDays,
        'payment_period': _selectedPaymentPeriod,
        'billing_cycle': _selectedPaymentPeriod,
        'bottle_count': _totalBottleCount,
        'bottle_1l_count': _count1L,
        'bottle_05l_count': _count05L,
        'bottle_1l_deposit': _bottle1LDeposit,
        'bottle_05l_deposit': _bottle05LDeposit,
        'ice_box_needed': _iceBoxNeeded,
        'ice_box_deposit_amount': _iceBoxDepositAmount,
        'total_deposit': totalDeposit,
        'monthly_rate': estimatedMonthlyRate,
        'custom_notes': _customNotesController.text.trim(),
        'alternate_mobile': _alternateMobileController.text.trim(),
        'alt_mobile': _alternateMobileController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final updatedCustomer = await SupabaseAPI.completeOnboarding(
          widget.customer['id'], onboardingData);

      await UserSession.saveSession(updatedCustomer);
      if (!mounted) return;

      _snack('onb_welcome_success'.tr, error: false);

      // Navigate directly to Dashboard
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => HomeScreen(customer: updatedCustomer)));
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUPIPaymentBottomSheet(int totalDeposit) {
    final upiId = (_enterprise?['upi_id'] ?? 'sriaashikaa@upi').toString().trim();
    final compName = (_enterprise?['upi_payee_name'] ?? _enterprise?['company_name'] ?? 'Sri Aashikaa Milk').toString().trim();
    final upiUrl = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(compName)}&am=$totalDeposit&cu=INR&tn=SecurityDeposit';
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(upiUrl)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
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

                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('onb_upi_title'.tr,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text('onb_upi_subtitle'.tr,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Amount Card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('onb_total_deposit_colon'.tr,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text('₹$totalDeposit',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: kGreen)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined, size: 14, color: kGreen),
                                const SizedBox(width: 4),
                                Text('onb_refundable_100'.tr,
                                    style: const TextStyle(
                                        color: kGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Payee / UPI ID Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(Icons.account_balance_wallet,
                                color: kGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(compName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(tr('onb_upi_id_val', {'upi': upiId}),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: Text('onb_copy_btn'.tr, style: const TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kGreen,
                              side: const BorderSide(color: kGreen),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: upiId));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('onb_upi_copied'.tr),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dynamic QR Code Preview
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.network(
                              qrUrl,
                              width: 160,
                              height: 160,
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: kGreen),
                                  ),
                                );
                              },
                              errorBuilder: (ctx, err, stack) {
                                return Container(
                                  width: 160,
                                  height: 160,
                                  color: Colors.grey.shade100,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_2, size: 64, color: kGreen),
                                      const SizedBox(height: 4),
                                      Text(upiId,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('onb_scan_upi_hint'.tr,
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Launch UPI App Intent Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('onb_open_upi_btn'.tr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGreen,
                        side: const BorderSide(color: kGreen),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(upiUrl);
                        bool launched = false;
                        try {
                          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                        if (!launched) {
                          try {
                            launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                          } catch (_) {}
                        }
                        if (!launched) {
                          Clipboard.setData(ClipboardData(text: upiId));
                          _snack(tr('onb_upi_not_responded', {'upi': upiId}), error: false);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Confirm & Go to Dashboard Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loading
                          ? null
                          : () async {
                              Navigator.of(modalCtx).pop(); // close sheet
                              await _doCompleteOnboarding(); // complete and navigate to dashboard
                            },
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('onb_paid_go_dashboard'.tr,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.customer['name'] ?? 'valued_customer'.tr;

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.languageNotifier,
      builder: (context, _, _) => Scaffold(
      appBar: AppBar(
        title: Text('setup_subscription'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kGreen, Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text(
                      name.toString().characters.first.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 22,
                          color: kGreen,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('onb_welcome_user', {'name': '$name'}),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'onb_configure_subtitle'.tr,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AppLogo(size: 44, compact: true),
                ]),
              ),
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. DAILY MILK NEED ──────────────────────────────────
                      _sectionTitle('onb_sec_1_milk'.tr),
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('🥛', style: TextStyle(fontSize: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _milkProductName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_milkProductDesc • ${tr('onb_rate_per_liter', {'rate': '${_ratePerLiter.toInt()}'})}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kGreen,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text('onb_daily_qty_colon'.tr,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ..._quantityOptions.map((qty) => ChoiceChip(
                                label: Text('$qty L'),
                                selected: !_isCustomQuantity && _selectedQuantity == qty,
                                onSelected: (_) {
                                  setState(() {
                                    _isCustomQuantity = false;
                                    _selectedQuantity = qty;
                                  });
                                },
                                selectedColor: kGreen,
                                labelStyle: TextStyle(
                                  color: (!_isCustomQuantity && _selectedQuantity == qty)
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )),
                          ChoiceChip(
                            label: Text('onb_custom_l'.tr),
                            selected: _isCustomQuantity,
                            onSelected: (_) {
                              setState(() {
                                _isCustomQuantity = true;
                              });
                            },
                            selectedColor: kGreen,
                            labelStyle: TextStyle(
                              color: _isCustomQuantity ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (_isCustomQuantity) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customQuantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'onb_custom_qty_label'.tr,
                            hintText: 'onb_custom_qty_hint'.tr,
                            prefixIcon: const Icon(IconData(0xe39d, fontFamily: 'MaterialIcons')), // local_drink
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ── 2. TIMING & SCHEDULE ─────────────────────────────────
                      _sectionTitle('onb_sec_2_timing'.tr),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTimeSlot,
                        decoration: InputDecoration(
                            labelText: 'onb_delivery_slot_req'.tr,
                            prefixIcon: const Icon(Icons.access_time)),
                        items: _timeSlotOptions
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(LanguageService.slotLabel(t),
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTimeSlot = v!),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDeliveryDays,
                        decoration: InputDecoration(
                            labelText: 'onb_delivery_schedule_req'.tr,
                            prefixIcon: const Icon(Icons.calendar_month_outlined)),
                        items: _deliveryDayOptions
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(LanguageService.planLabel(d),
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedDeliveryDays = v!;
                            _isCustomDeliveryDays = v == 'Custom Days (Specify)';
                          });
                        },
                      ),
                      if (_isCustomDeliveryDays) ...[
                        const SizedBox(height: 12),
                        Text('onb_select_custom_days'.tr,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _weekDays.map((day) {
                            final isSelected = _selectedDaysSet.contains(day);
                            return FilterChip(
                              label: Text(LanguageService.dayShortLabel(day)),
                              selected: isSelected,
                              selectedColor: kGreen,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDaysSet.add(day);
                                  } else {
                                    _selectedDaysSet.remove(day);
                                  }
                                  _customDeliveryDaysController.text =
                                      _selectedDaysSet.join(', ');
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customDeliveryDaysController,
                          decoration: InputDecoration(
                            labelText: 'onb_custom_days_label'.tr,
                            hintText: 'onb_custom_days_hint'.tr,
                            prefixIcon: const Icon(Icons.edit_calendar),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Custom Instructions / Notes Field
                      TextFormField(
                        controller: _customNotesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'onb_custom_notes_label'.tr,
                          hintText: 'onb_custom_notes_hint'.tr,
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── 3. PAYMENT TIME PERIOD ──────────────────────────────
                      _sectionTitle('onb_sec_3_payment'.tr),
                      Text(
                        'onb_choose_settle_bills'.tr,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),

                      _paymentPeriodCard(
                        key: 'daily',
                        title: 'onb_pay_daily_title'.tr,
                        subtitle: 'onb_pay_daily_desc'.tr,
                        tag: 'onb_pay_daily_tag'.tr,
                        icon: Icons.today_outlined,
                      ),
                      const SizedBox(height: 8),

                      _paymentPeriodCard(
                        key: 'weekly',
                        title: 'onb_pay_weekly_title'.tr,
                        subtitle: 'onb_pay_weekly_desc'.tr,
                        tag: 'onb_pay_weekly_tag'.tr,
                        icon: Icons.view_week_outlined,
                      ),
                      const SizedBox(height: 8),

                      _paymentPeriodCard(
                        key: 'monthly',
                        title: 'onb_pay_monthly_title'.tr,
                        subtitle: 'onb_pay_monthly_desc'.tr,
                        tag: 'onb_pay_monthly_tag'.tr,
                        icon: Icons.calendar_month_outlined,
                      ),
                      const SizedBox(height: 16),

                      // ── 4. ALTERNATE CONTACT & EMAIL ID ─────────────────────
                      _sectionTitle('onb_sec_4_contact'.tr),
                      TextFormField(
                        controller: _alternateMobileController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'onb_alt_mobile_opt'.tr,
                          hintText: 'onb_alt_mobile_hint'.tr,
                          prefixIcon: const Icon(Icons.phone_android_outlined),
                          helperText: 'onb_alt_mobile_helper'.tr,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'onb_email_opt'.tr,
                          hintText: 'onb_email_hint'.tr,
                          prefixIcon: const Icon(Icons.email_outlined),
                          helperText: 'onb_email_helper'.tr,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── 5. DEPOSITS & ASSETS ─────────────────────────────────
                      _sectionTitle('onb_sec_5_deposit'.tr),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: kGreen, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr('onb_auto_alloc_banner', {'qty': '$_effectiveQuantity'}),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BOTTLE TYPE 1: 1.0 LITER BOTTLE (1000ml)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _count1L > 0 ? kGreen.withValues(alpha: 0.5) : Colors.grey.shade300,
                            width: _count1L > 0 ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('🥛', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _bottle1LName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87),
                                      ),
                                      Text(
                                        tr('onb_deposit_per_bottle', {'amt': '${_bottle1LDeposit.toInt()}'}),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _count1L > 0 ? Icons.check_circle : Icons.remove_circle_outline,
                                      color: _count1L > 0 ? kGreen : Colors.grey,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _count1L > 0
                                          ? 'onb_auto_alloc_label'.tr
                                          : 'onb_not_needed_qty'.tr,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _count1L > 0
                                        ? kGreen.withValues(alpha: 0.1)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _count1L > 0
                                          ? kGreen
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    '$_count1L ${_count1L == 1 ? 'onb_bottle_singular'.tr : 'onb_bottle_plural'.tr} (₹${(_count1L * _bottle1LDeposit).toInt()})',
                                    style: TextStyle(
                                      color: _count1L > 0 ? kGreen : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // BOTTLE TYPE 2: 0.5 LITER BOTTLE (500ml)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _count05L > 0 ? kGreen.withValues(alpha: 0.5) : Colors.grey.shade300,
                            width: _count05L > 0 ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('🍼', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _bottle05LName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87),
                                      ),
                                      Text(
                                        tr('onb_deposit_per_bottle', {'amt': '${_bottle05LDeposit.toInt()}'}),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _count05L > 0 ? Icons.check_circle : Icons.remove_circle_outline,
                                      color: _count05L > 0 ? kGreen : Colors.grey,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _count05L > 0
                                          ? 'onb_auto_alloc_label'.tr
                                          : 'onb_not_needed_qty'.tr,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _count05L > 0
                                        ? kGreen.withValues(alpha: 0.1)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _count05L > 0
                                          ? kGreen
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    '$_count05L ${_count05L == 1 ? 'onb_bottle_singular'.tr : 'onb_bottle_plural'.tr} (₹${(_count05L * _bottle05LDeposit).toInt()})',
                                    style: TextStyle(
                                      color: _count05L > 0 ? kGreen : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ROTATION STATUS INDICATOR
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: kGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: kGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr('onb_total_bottles_banner', {
                                  'count': '$_totalBottleCount',
                                  'qty': '$_effectiveQuantity',
                                }),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ICE BOX TOGGLE
                      SwitchListTile(
                        value: _iceBoxNeeded,
                        onChanged: (v) => setState(() => _iceBoxNeeded = v),
                        activeThumbColor: kGreen,
                        contentPadding: EdgeInsets.zero,
                        title: Text('onb_ice_box_req'.tr,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            tr('onb_ice_box_deposit', {'amt': '${_iceBoxDepositAmount.toInt()}'}),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                      const SizedBox(height: 16),

                      // ── 6. SUMMARY BREAKDOWN ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('onb_summary_title'.tr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kGreen,
                                    fontSize: 13)),
                            const SizedBox(height: 8),
                            _summaryRow(
                                'onb_billing_freq'.tr,
                                _selectedPaymentPeriod == 'daily'
                                    ? 'onb_pay_daily_title'.tr
                                    : _selectedPaymentPeriod == 'weekly'
                                        ? 'onb_pay_weekly_title'.tr
                                        : 'onb_pay_monthly_title'.tr),
                            if (_count1L > 0)
                              _summaryRow(
                                  tr('onb_bottles_1l_row', {
                                    'count': '$_count1L',
                                    'rate': '${_bottle1LDeposit.toInt()}',
                                  }),
                                  '₹${(_count1L * _bottle1LDeposit).toInt()}'),
                            if (_count05L > 0)
                              _summaryRow(
                                  tr('onb_bottles_05l_row', {
                                    'count': '$_count05L',
                                    'rate': '${_bottle05LDeposit.toInt()}',
                                  }),
                                  '₹${(_count05L * _bottle05LDeposit).toInt()}'),
                            if (_count1L == 0 && _count05L == 0)
                              _summaryRow('onb_bottle_deposit_row'.tr, '₹0'),
                            if (_iceBoxNeeded)
                              _summaryRow(
                                  'onb_ice_box_deposit_row'.tr, '₹${_iceBoxDepositAmount.toInt()}'),
                            const Divider(),
                            _summaryRow(
                                'onb_total_deposit_row'.tr, '₹$_totalDepositCalculated',
                                isBold: true),
                            const SizedBox(height: 6),
                            Text(
                              tr('onb_summary_bullets', {
                                'freq': _selectedPaymentPeriod == 'daily'
                                    ? 'onb_freq_daily_inline'.tr
                                    : _selectedPaymentPeriod == 'weekly'
                                        ? 'onb_freq_weekly_inline'.tr
                                        : 'onb_freq_monthly_inline'.tr,
                              }),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () => _startUPIPaymentFlow(_totalDepositCalculated),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                tr('onb_pay_upi_btn', {'amt': '$_totalDepositCalculated'}),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: kGreen)),
      );

  Widget _summaryRow(String label, String value, {bool isBold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                      fontWeight:
                          isBold ? FontWeight.bold : FontWeight.normal))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: isBold ? kGreen : Colors.black87)),
        ]),
      );

  Widget _paymentPeriodCard({
    required String key,
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentPeriod == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentPeriod = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kGreen : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? kGreen : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? kGreen : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kGreen.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? kGreen : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_off,
              color: isSelected ? kGreen : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
