import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';

const _green = Color(0xFF059669);

class DepositTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  const DepositTab({super.key, required this.customer});

  @override
  State<DepositTab> createState() => _DepositTabState();
}

class _DepositTabState extends State<DepositTab> {
  List<Map<String, dynamic>> _deposits = [];
  Map<String, dynamic> _assets = {};
  Map<String, dynamic>? _enterprise;
  bool _loading = true;

  // Server Pricing Config
  double _bottle1LDeposit = 150.0;
  double _bottle05LDeposit = 50.0;
  double _iceBoxDepositAmount = 250.0;

  @override
  void initState() {
    super.initState();
    _loadServerData();
  }

  Future<void> _loadServerData() async {
    setState(() => _loading = true);
    try {
      final config = await SupabaseAPI.fetchPricingConfig();
      final deposits = await SupabaseAPI.fetchDeposits(widget.customer);
      final assets = await SupabaseAPI.fetchAssetSummary(widget.customer);
      final enterprise = await SupabaseAPI.fetchEnterpriseSettings();

      if (mounted) {
        setState(() {
          _bottle1LDeposit =
              double.tryParse((config['bottle_1l_deposit'] ?? 150.0).toString()) ?? 150.0;
          _bottle05LDeposit =
              double.tryParse((config['bottle_05l_deposit'] ?? 50.0).toString()) ?? 50.0;
          _iceBoxDepositAmount =
              double.tryParse((config['ice_box_deposit_amount'] ?? 250.0).toString()) ?? 250.0;
          _deposits = deposits;
          _assets = assets;
          _enterprise = enterprise;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWhatsApp(String phone, String text) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final number = clean.length == 10 ? '91$clean' : clean;
    final msg = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/$number?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Widget _refundCounterRow(
      String label, int current, int max, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  size: 20, color: Colors.grey),
              onPressed: current > 0 ? () => onChanged(current - 1) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$current',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  size: 20, color: _green),
              onPressed: current < max ? () => onChanged(current + 1) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  void _showRaiseRefundDialog({
    required double pendingRefund,
    required double totalDeposit,
    required int count1L,
    required int count05L,
    required int countIceBox,
  }) {
    final custName = widget.customer['name'] ?? 'Customer';

    String refundType = 'FULL'; // 'FULL' or 'PARTIAL'
    const String payoutMethod = 'BANK'; // Direct Bank Account Transfer only

    int return1L = count1L;
    int return05L = count05L;
    int returnIceBox = countIceBox;

    final accountHolderCtrl = TextEditingController(text: custName);
    final accountNumberCtrl = TextEditingController();
    final confirmAccountNumberCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final bankNameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    DateTime handoverDate = DateTime.now().add(const Duration(days: 1));
    String selectedReason = 'Moving out / Relocating';
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final double calculatedRefund = refundType == 'FULL'
              ? (pendingRefund > 0 ? pendingRefund : totalDeposit)
              : ((return1L * _bottle1LDeposit) +
                  (return05L * _bottle05LDeposit) +
                  (returnIceBox * _iceBoxDepositAmount));

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.currency_exchange,
                                color: _green, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Raise Deposit Refund',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '100% money-back guarantee on bottle return',
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
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
                  const Divider(height: 20),

                  // Amount Highlight Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF047857), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Refund Claim Amount',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${calculatedRefund.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  color: _green, size: 14),
                              SizedBox(width: 4),
                              Text('100% Refundable',
                                  style: TextStyle(
                                      color: _green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Refund Type Switcher
                  const Text('Refund Claim Scope',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setModalState(() => refundType = 'FULL'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: refundType == 'FULL'
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: refundType == 'FULL'
                                    ? _green
                                    : const Color(0xFFE2E8F0),
                                width: refundType == 'FULL' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      refundType == 'FULL'
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: refundType == 'FULL'
                                          ? _green
                                          : Colors.grey,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Full Refund',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text('Return all bottles & ice box',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setModalState(() => refundType = 'PARTIAL'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: refundType == 'PARTIAL'
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: refundType == 'PARTIAL'
                                    ? _green
                                    : const Color(0xFFE2E8F0),
                                width: refundType == 'PARTIAL' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      refundType == 'PARTIAL'
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: refundType == 'PARTIAL'
                                          ? _green
                                          : Colors.grey,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Partial Refund',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text('Return surplus assets only',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // If Partial, show asset return counters
                  if (refundType == 'PARTIAL') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Assets Being Returned:',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          if (count1L > 0)
                            _refundCounterRow(
                              '1.0L Bottle (₹${_bottle1LDeposit.toInt()} each)',
                              return1L,
                              count1L,
                              (val) => setModalState(() => return1L = val),
                            ),
                          if (count05L > 0) ...[
                            const SizedBox(height: 6),
                            _refundCounterRow(
                              '0.5L Bottle (₹${_bottle05LDeposit.toInt()} each)',
                              return05L,
                              count05L,
                              (val) => setModalState(() => return05L = val),
                            ),
                          ],
                          if (countIceBox > 0) ...[
                            const SizedBox(height: 6),
                            _refundCounterRow(
                              'Ice Box (₹${_iceBoxDepositAmount.toInt()})',
                              returnIceBox,
                              countIceBox,
                              (val) =>
                                  setModalState(() => returnIceBox = val),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Bank Account Refund Details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance, size: 16, color: _green),
                            SizedBox(width: 6),
                            Text(
                              'Refund Payout Bank Account',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Direct bank deposit upon bottle inspection & collection',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: accountNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Bank Account Number *',
                            hintText: 'Enter bank account number',
                            prefixIcon: const Icon(Icons.numbers,
                                color: _green, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: confirmAccountNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Re-Enter Bank Account Number *',
                            hintText: 'Re-enter to confirm',
                            prefixIcon: const Icon(Icons.check_circle_outline,
                                color: _green, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ifscCtrl,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'IFSC Code *',
                                  hintText: 'e.g. SBIN0001234',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: bankNameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Bank Name',
                                  hintText: 'e.g. SBI, HDFC',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: accountHolderCtrl,
                          decoration: InputDecoration(
                            labelText: 'Account Holder Name',
                            hintText: 'Name as per bank records',
                            prefixIcon: const Icon(Icons.person_outline,
                                color: _green, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Handover Date Selector
                  const Text('Asset Handover Date to Delivery Partner',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: modalCtx,
                        initialDate: handoverDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: _green,
                              onPrimary: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => handoverDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: _green, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('EEEE, dd MMMM yyyy')
                                    .format(handoverDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const Text('Change 📅',
                              style: TextStyle(
                                  color: _green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Reason for refund
                  const Text('Reason for Refund Request',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Moving out / Relocating',
                          child: Text('Moving out / Relocating')),
                      DropdownMenuItem(
                          value: 'Discontinuing milk subscription',
                          child: Text('Discontinuing milk subscription')),
                      DropdownMenuItem(
                          value: 'Returning excess / extra bottles',
                          child: Text('Returning excess / extra bottles')),
                      DropdownMenuItem(
                          value: 'Ice box no longer required',
                          child: Text('Ice box no longer required')),
                      DropdownMenuItem(
                          value: 'Temporary service break',
                          child: Text('Temporary service break')),
                      DropdownMenuItem(
                          value: 'Other reason', child: Text('Other reason')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedReason = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Special instructions for delivery partner (optional)...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info Disclaimer Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: _green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your delivery partner will collect clean, intact glass bottles on the handover date. Refund amount will be credited to your account within 24 hours of collection.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Primary Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            if (calculatedRefund <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please select at least 1 asset to refund.')),
                              );
                              return;
                            }
                            final accNo = accountNumberCtrl.text.trim();
                            final confirmAccNo = confirmAccountNumberCtrl.text.trim();
                            final ifsc = ifscCtrl.text.trim().toUpperCase();
                            final holder = accountHolderCtrl.text.trim();
                            final bank = bankNameCtrl.text.trim();

                            if (accNo.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please enter your Bank Account Number.')),
                              );
                              return;
                            }
                            if (confirmAccNo != accNo) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Account numbers do not match. Please verify.')),
                              );
                              return;
                            }
                            if (ifsc.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please enter your Bank IFSC Code.')),
                              );
                              return;
                            }

                            final payoutStr = '${bank.isNotEmpty ? "$bank - " : ""}A/C: $accNo IFSC: $ifsc${holder.isNotEmpty ? " - $holder" : ""}';

                            setModalState(() => submitting = true);
                            try {
                              final ref =
                                  await SupabaseAPI.submitRefundRequest(
                                customerOrId: widget.customer,
                                refundAmount: calculatedRefund,
                                refundType: refundType,
                                payoutMethod: payoutMethod,
                                payoutDetails: payoutStr,
                                handoverDate: DateFormat('yyyy-MM-dd')
                                    .format(handoverDate),
                                reason: selectedReason,
                                notes: notesCtrl.text.trim(),
                              );

                              if (modalCtx.mounted) Navigator.pop(modalCtx);
                              await _loadServerData();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '✅ Security Deposit Refund Request Raised!\nReference: $ref\nAmount: ₹${calculatedRefund.toInt()}'),
                                  backgroundColor: _green,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } catch (e) {
                              if (modalCtx.mounted) {
                                setModalState(() => submitting = false);
                              }
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed to raise refund: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Submit Refund Request (₹${calculatedRefund.toInt()}) ➔',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
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

  void _showReportBrokenBottleDialog() {
    final supportPhone = (_enterprise?['support_phone'] ??
            _enterprise?['secondary_phone'] ??
            '+91 98765 43210')
        .toString();
    final custName = widget.customer['name'] ?? 'Customer';
    final custId = widget.customer['customer_id'] ?? widget.customer['id'] ?? '';

    String selectedType = '1.0 Liter Glass Bottle';
    String selectedReason = 'Accidentally slipped / cracked';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.red, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Report Broken Bottle',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Let us know if a glass bottle broke so your delivery partner brings a replacement bottle on the next delivery.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  const Text('Select Bottle Type',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('1.0L Bottle (₹${_bottle1LDeposit.toInt()})'),
                        selected: selectedType == '1.0 Liter Glass Bottle',
                        onSelected: (sel) {
                          if (sel) {
                            setModalState(
                                () => selectedType = '1.0 Liter Glass Bottle');
                          }
                        },
                        selectedColor: _green.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: selectedType == '1.0 Liter Glass Bottle'
                              ? _green
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      ChoiceChip(
                        label: Text('0.5L Bottle (₹${_bottle05LDeposit.toInt()})'),
                        selected: selectedType == '0.5 Liter Glass Bottle',
                        onSelected: (sel) {
                          if (sel) {
                            setModalState(
                                () => selectedType = '0.5 Liter Glass Bottle');
                          }
                        },
                        selectedColor: _green.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: selectedType == '0.5 Liter Glass Bottle'
                              ? _green
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text('What happened?',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Accidentally slipped / cracked',
                          child: Text('Accidentally slipped / cracked')),
                      DropdownMenuItem(
                          value: 'Found hairline crack before opening',
                          child: Text('Found hairline crack before opening')),
                      DropdownMenuItem(
                          value: 'Broken during cleaning',
                          child: Text('Broken during cleaning')),
                      DropdownMenuItem(
                          value: 'Cap / Neck chipped',
                          child: Text('Cap / Neck chipped')),
                      DropdownMenuItem(
                          value: 'Other reason', child: Text('Other reason')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedReason = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Additional notes or remarks (optional)...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text(
                      'Report via WhatsApp Support ➔',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      final note = notesCtrl.text.trim();
                      final message =
                          'Hello Amudham Dairy Support,\n\nI want to report a broken glass bottle:\n• Customer: $custName (ID: $custId)\n• Bottle Type: $selectedType\n• Reason: $selectedReason${note.isNotEmpty ? '\n• Notes: $note' : ''}\n\nPlease arrange a replacement bottle on the next delivery. Thank you!';
                      _openWhatsApp(supportPhone, message);
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text('Call Support Hotline ($supportPhone)'),
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      _makeCall(supportPhone);
                    },
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
    final depositsList =
        List<Map<String, dynamic>>.from(_assets['deposits_list'] ?? _deposits);
    final bottlesList =
        List<Map<String, dynamic>>.from(_assets['bottles_list'] ?? []);
    final iceBoxesList =
        List<Map<String, dynamic>>.from(_assets['ice_boxes_list'] ?? []);
    final bottleAlloc = _assets['bottle_alloc'] as Map<String, dynamic>?;

    // ── Calculate Deposit Totals ──
    double totalDepositPaid = 0.0;
    double totalRefundProcessed = 0.0;
    double pendingRefund = 0.0;

    double bottle1LDepositTotal = 0.0;
    double bottle05LDepositTotal = 0.0;
    double iceBoxDepositTotal = 0.0;

    int count1L = 0;
    int count05L = 0;
    int countIceBox = 0;

    if (depositsList.isNotEmpty) {
      for (var d in depositsList) {
        final type = (d['asset_type'] ?? '').toString();
        final paid =
            double.tryParse((d['deposit_paid'] ?? d['total_deposit'] ?? 0).toString()) ?? 0.0;
        final refund =
            double.tryParse((d['deposit_refund'] ?? 0).toString()) ?? 0.0;

        totalDepositPaid += paid;
        totalRefundProcessed += refund;

        if (type.contains('1.0') || type.contains('1L') || type.contains('1000')) {
          bottle1LDepositTotal += paid;
        } else if (type.contains('0.5') || type.contains('500')) {
          bottle05LDepositTotal += paid;
        } else if (type.toLowerCase().contains('ice')) {
          iceBoxDepositTotal += paid;
        } else {
          bottle1LDepositTotal += paid;
        }
      }
      pendingRefund = totalDepositPaid - totalRefundProcessed;

      count1L = (bottle1LDepositTotal / _bottle1LDeposit).round();
      count05L = (bottle05LDepositTotal / _bottle05LDeposit).round();
      countIceBox = iceBoxDepositTotal > 0
          ? 1
          : (iceBoxesList.isNotEmpty ? iceBoxesList.length : 0);
    } else {
      // Fallback calculation from customer milk quantity or standard rotation
      final double milkQty =
          double.tryParse((widget.customer['milk_quantity'] ?? 1.0).toString()) ?? 1.0;
      if (milkQty <= 0.5) {
        count05L = 2;
        count1L = 0;
      } else {
        count1L = (milkQty.ceil() * 2).clamp(2, 6);
        count05L = 0;
      }

      final iceOpted = widget.customer['ice_box_needed'] == true ||
          widget.customer['has_ice_box'] == true ||
          iceBoxesList.isNotEmpty;
      countIceBox = iceOpted ? 1 : 0;

      bottle1LDepositTotal = count1L * _bottle1LDeposit;
      bottle05LDepositTotal = count05L * _bottle05LDeposit;
      iceBoxDepositTotal = countIceBox * _iceBoxDepositAmount;

      totalDepositPaid =
          bottle1LDepositTotal + bottle05LDepositTotal + iceBoxDepositTotal;
      pendingRefund = totalDepositPaid;
    }

    final bool hasPendingRefundRequest = depositsList.any((d) {
      final stat = (d['deposit_status'] ?? '').toString().toUpperCase();
      return stat == 'REFUND_REQUESTED' || stat == 'PENDING_REFUND';
    });

    // ── Calculate Bottle Condition & Breakage Counts ──
    int brokenCount = 0;
    int lostCount = 0;

    if (bottlesList.isNotEmpty) {
      brokenCount = bottlesList.where((b) {
        final cond = (b['condition'] ?? '').toString().toUpperCase();
        final stat = (b['status'] ?? '').toString().toUpperCase();
        return cond == 'DAMAGED' || cond == 'BROKEN' || stat == 'DAMAGED';
      }).length;

      lostCount = bottlesList.where((b) {
        final cond = (b['condition'] ?? '').toString().toUpperCase();
        final stat = (b['status'] ?? '').toString().toUpperCase();
        return cond == 'LOST' || stat == 'LOST';
      }).length;
    } else if (bottleAlloc != null) {
      brokenCount =
          int.tryParse((bottleAlloc['damaged_count'] ?? 0).toString()) ?? 0;
      lostCount =
          int.tryParse((bottleAlloc['lost_count'] ?? 0).toString()) ?? 0;
    }

    final totalBottlesIssued = count1L + count05L;
    final int intactBottlesInHand =
        (totalBottlesIssued - brokenCount - lostCount).clamp(0, 99);

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadServerData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Hero Card: Security Deposit Ledger ─────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Security Deposit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        if (_loading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                    InkWell(
                      onTap: () => _showRaiseRefundDialog(
                        pendingRefund: pendingRefund,
                        totalDeposit: totalDepositPaid,
                        count1L: count1L,
                        count05L: count05L,
                        countIceBox: countIceBox,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: _green, size: 14),
                            SizedBox(width: 4),
                            Text('100% Refundable',
                                style: TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Deposit Balance',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalDepositPaid.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 18),
                      tooltip: 'Reload Live Ledger',
                      onPressed: _loadServerData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _heroDepositItem(
                          '1.0L Bottles', '₹${bottle1LDepositTotal.toInt()}'),
                      Container(width: 1, height: 22, color: Colors.white24),
                      _heroDepositItem(
                          '0.5L Bottles', '₹${bottle05LDepositTotal.toInt()}'),
                      Container(width: 1, height: 22, color: Colors.white24),
                      _heroDepositItem(
                          'Ice Box', '₹${iceBoxDepositTotal.toInt()}'),
                      Container(width: 1, height: 22, color: Colors.white24),
                      _heroDepositItem(
                          'Refundable', '₹${pendingRefund.toInt()}'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Status banner if refund already requested ──
                if (hasPendingRefundRequest) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Refund Request Under Review • ₹${pendingRefund.toInt()} will be credited after bottle handover.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Raise Refund Action Button ──
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF047857),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.currency_exchange,
                        size: 18, color: Color(0xFF047857)),
                    label: Text(
                      hasPendingRefundRequest
                          ? 'View / Raise Another Refund Request ➔'
                          : 'Raise Security Deposit Refund ➔',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    onPressed: () => _showRaiseRefundDialog(
                      pendingRefund: pendingRefund,
                      totalDeposit: totalDepositPaid,
                      count1L: count1L,
                      count05L: count05L,
                      countIceBox: countIceBox,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. What Assets You Now Have (Easy View Model) ──────────────────
          Card(
            elevation: 1.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: _green, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Assets in Hand',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Reusable delivery assets currently with you',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${intactBottlesInHand + countIceBox} Total Assets',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Asset 1: 1.0L Glass Bottle
                  _inHandAssetTile(
                    icon: Icons.liquor,
                    iconColor: _green,
                    iconBg: const Color(0xFFDCFCE7),
                    title: '1.0 Liter Glass Bottle (1000ml)',
                    countText: '$count1L in hand',
                    rateText: '₹${_bottle1LDeposit.toInt()} deposit / unit',
                    totalDepositText: '₹${bottle1LDepositTotal.toInt()} held',
                    isActive: count1L > 0,
                    note: 'Pure glass container for fresh cow milk',
                  ),
                  const SizedBox(height: 10),

                  // Asset 2: 0.5L Glass Bottle
                  _inHandAssetTile(
                    icon: Icons.local_drink_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                    title: '0.5 Liter Glass Bottle (500ml)',
                    countText: '$count05L in hand',
                    rateText: '₹${_bottle05LDeposit.toInt()} deposit / unit',
                    totalDepositText: '₹${bottle05LDepositTotal.toInt()} held',
                    isActive: count05L > 0,
                    note: 'Compact dairy glass bottle for half-liter deliveries',
                  ),
                  const SizedBox(height: 10),

                  // Asset 3: Insulated Ice Box
                  _inHandAssetTile(
                    icon: Icons.kitchen_outlined,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFF3E8FF),
                    title: 'Insulated Cold-Chain Ice Box',
                    countText: countIceBox > 0 ? '1 in hand' : 'Not Opted',
                    rateText:
                        '₹${_iceBoxDepositAmount.toInt()} refundable deposit',
                    totalDepositText: countIceBox > 0
                        ? '₹${iceBoxDepositTotal.toInt()} held'
                        : '₹0',
                    isActive: countIceBox > 0,
                    note:
                        'Preserves milk temperature and freshness at doorstep',
                  ),

                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.autorenew, color: _green, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Daily Rotation: Please keep empty rinsed glass bottles outside every morning for delivery partner exchange.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF334155),
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Broken Bottle & Condition Tracker (Easy View Model) ─────────
          Card(
            elevation: 1.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: brokenCount > 0
                                  ? Colors.red.shade50
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              brokenCount > 0
                                  ? Icons.broken_image_outlined
                                  : Icons.verified_user_outlined,
                              color: brokenCount > 0 ? Colors.red : _green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bottle Condition & Breakage',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Breakage tracking & damage count',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      if (brokenCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$brokenCount Broken',
                            style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // High-clarity 3-Card Condition Dashboard
                  Row(
                    children: [
                      Expanded(
                        child: _conditionMetricTile(
                          icon: Icons.check_circle_outline,
                          count: '$intactBottlesInHand',
                          label: 'Good / Intact',
                          color: _green,
                          bg: const Color(0xFFECFDF5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _conditionMetricTile(
                          icon: Icons.broken_image_outlined,
                          count: '$brokenCount',
                          label: 'Broken / Damaged',
                          color: brokenCount > 0 ? Colors.red : Colors.grey.shade600,
                          bg: brokenCount > 0
                              ? Colors.red.shade50
                              : const Color(0xFFF8FAFC),
                          isAlert: brokenCount > 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _conditionMetricTile(
                          icon: Icons.help_outline,
                          count: '$lostCount',
                          label: 'Lost / Missing',
                          color: lostCount > 0 ? Colors.amber.shade800 : Colors.grey.shade600,
                          bg: lostCount > 0
                              ? Colors.amber.shade50
                              : const Color(0xFFF8FAFC),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Condition status highlight
                  if (brokenCount == 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: _green, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'All bottles in good intact condition. No breakage or damage reported.',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF065F46)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$brokenCount broken bottle(s) recorded on your account. Replacement fee will be adjusted per dairy policy.',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),

                  const Text('Breakage & Replacement Terms',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  _policyRow(
                      '1.0L Bottle breakage deduction / replacement: ₹${_bottle1LDeposit.toInt()}'),
                  _policyRow(
                      '0.5L Bottle breakage deduction / replacement: ₹${_bottle05LDeposit.toInt()}'),
                  _policyRow(
                      'Notify immediately if a bottle arrives cracked so we can replace it promptly.'),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.report_problem_outlined, size: 16),
                    label: const Text('Report Broken Bottle to Dairy Desk',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _showReportBrokenBottleDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 4. Live Server Deposits Ledger (Official Receipts) ─────────────
          if (depositsList.isNotEmpty) ...[
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long_outlined,
                                  color: _green, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deposits Ledger',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('Official Supabase security deposit receipts',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${depositsList.length} Receipts',
                            style: const TextStyle(
                                color: _green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...depositsList.map((d) {
                      final assetType = d['asset_type'] ?? 'Asset Deposit';
                      final total = d['total_deposit'] ?? d['deposit_paid'] ?? 0;
                      final status =
                          (d['deposit_status'] ?? 'ACTIVE').toString();
                      final date = (d['transaction_date'] ??
                              d['created_at'] ??
                              '')
                          .toString()
                          .split('T')
                          .first;
                      final isHeld = status == 'ACTIVE' || status == 'HELD';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assetType.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text('Date: ${date.isEmpty ? '-' : date}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹$total',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _green,
                                        fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isHeld ? _green : Colors.orange)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(status,
                                      style: TextStyle(
                                          color:
                                              isHeld ? _green : Colors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 5. Bottle Return & Delivery Cycle ──────────────────────────────
          Card(
            elevation: 1.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How Bottle Rotation Works',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stepItem('1. Delivery', 'Partner delivers full glass bottles',
                          Icons.local_shipping_outlined),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: Colors.grey),
                      _stepItem('2. Fresh Milk', 'Rinse empty bottles after use',
                          Icons.eco_outlined),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: Colors.grey),
                      _stepItem('3. Return', 'Hand over empty bottles next morning',
                          Icons.autorenew),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _heroDepositItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _inHandAssetTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String countText,
    required String rateText,
    required String totalDepositText,
    required bool isActive,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _green.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          width: isActive ? 1.2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFDCFCE7)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        countText,
                        style: TextStyle(
                          color: isActive ? _green : Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(note,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(rateText,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                    Text('Deposit: $totalDepositText',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive ? _green : Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionMetricTile({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
    required Color bg,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? Colors.red.shade300 : color.withValues(alpha: 0.25),
          width: isAlert ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _stepItem(String step, String desc, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: _green),
          const SizedBox(height: 4),
          Text(step,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 2),
          Text(desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _policyRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
