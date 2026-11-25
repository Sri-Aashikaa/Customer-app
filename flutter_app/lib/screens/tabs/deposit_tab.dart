import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/language_service.dart';

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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'dep_raise_refund_title'.tr,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'dep_money_back_guarantee'.tr,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
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
                            Text(
                              'dep_claim_amount'.tr,
                              style: const TextStyle(
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
                          child: Row(
                            children: [
                              const Icon(Icons.shield_outlined,
                                  color: _green, size: 14),
                              const SizedBox(width: 4),
                              Text('dep_100_refundable'.tr,
                                  style: const TextStyle(
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
                  Text('dep_claim_scope'.tr,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
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
                                    Text('dep_full_refund'.tr,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('dep_full_refund_sub'.tr,
                                    style: const TextStyle(
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
                                    Text('dep_partial_refund'.tr,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('dep_partial_refund_sub'.tr,
                                    style: const TextStyle(
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
                          Text('dep_select_assets_return'.tr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          if (count1L > 0)
                            _refundCounterRow(
                              tr('dep_bottle_1l_each',
                                  {'amt': '${_bottle1LDeposit.toInt()}'}),
                              return1L,
                              count1L,
                              (val) => setModalState(() => return1L = val),
                            ),
                          if (count05L > 0) ...[
                            const SizedBox(height: 6),
                            _refundCounterRow(
                              tr('dep_bottle_05l_each',
                                  {'amt': '${_bottle05LDeposit.toInt()}'}),
                              return05L,
                              count05L,
                              (val) => setModalState(() => return05L = val),
                            ),
                          ],
                          if (countIceBox > 0) ...[
                            const SizedBox(height: 6),
                            _refundCounterRow(
                              tr('dep_ice_box_amt',
                                  {'amt': '${_iceBoxDepositAmount.toInt()}'}),
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
                        Row(
                          children: [
                            const Icon(Icons.account_balance, size: 16, color: _green),
                            const SizedBox(width: 6),
                            Text(
                              'dep_payout_bank_title'.tr,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'dep_payout_bank_sub'.tr,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: accountNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'dep_bank_acc_label'.tr,
                            hintText: 'dep_bank_acc_hint'.tr,
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
                            labelText: 'dep_bank_reacc_label'.tr,
                            hintText: 'dep_bank_reacc_hint'.tr,
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
                                  labelText: 'dep_ifsc_label'.tr,
                                  hintText: 'dep_ifsc_hint'.tr,
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
                                  labelText: 'dep_bank_name_label'.tr,
                                  hintText: 'dep_bank_name_hint'.tr,
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
                            labelText: 'dep_acc_holder_label'.tr,
                            hintText: 'dep_acc_holder_hint'.tr,
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
                  Text('dep_handover_date'.tr,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
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
                                LanguageService.formatFullDayDate(handoverDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Text('dep_change_date'.tr,
                              style: const TextStyle(
                                  color: _green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Reason for refund
                  Text('dep_reason_title'.tr,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'Moving out / Relocating',
                          child: Text('dep_reason_relocating'.tr)),
                      DropdownMenuItem(
                          value: 'Discontinuing milk subscription',
                          child: Text('dep_reason_discontinuing'.tr)),
                      DropdownMenuItem(
                          value: 'Returning excess / extra bottles',
                          child: Text('dep_reason_excess'.tr)),
                      DropdownMenuItem(
                          value: 'Ice box no longer required',
                          child: Text('dep_reason_icebox'.tr)),
                      DropdownMenuItem(
                          value: 'Temporary service break',
                          child: Text('dep_reason_break'.tr)),
                      DropdownMenuItem(
                          value: 'Other reason',
                          child: Text('dep_reason_other'.tr)),
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
                      hintText: 'dep_instructions_hint'.tr,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: _green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'dep_collection_info'.tr,
                            style: const TextStyle(
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
                                SnackBar(
                                    content: Text('dep_err_select_asset'.tr)),
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
                                SnackBar(
                                    content: Text('dep_err_acc_empty'.tr)),
                              );
                              return;
                            }
                            if (confirmAccNo != accNo) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('dep_err_acc_mismatch'.tr)),
                              );
                              return;
                            }
                            if (ifsc.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('dep_err_ifsc_empty'.tr)),
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
                                  content: Text(tr('dep_refund_ok', {
                                    'ref': ref,
                                    'amt': '${calculatedRefund.toInt()}',
                                  })),
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
                                      Text(tr('dep_refund_err', {'err': '$e'})),
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
                            tr('dep_submit_refund_btn',
                                {'amt': '${calculatedRefund.toInt()}'}),
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
                          Text(
                            'dep_report_broken_title'.tr,
                            style: const TextStyle(
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
                    'dep_report_broken_desc'.tr,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  Text('dep_select_bottle_type'.tr,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(tr('dep_bottle_1l_chip',
                            {'amt': '${_bottle1LDeposit.toInt()}'})),
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
                        label: Text(tr('dep_bottle_05l_chip',
                            {'amt': '${_bottle05LDeposit.toInt()}'})),
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

                  Text('dep_what_happened'.tr,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'Accidentally slipped / cracked',
                          child: Text('dep_broke_slipped'.tr)),
                      DropdownMenuItem(
                          value: 'Found hairline crack before opening',
                          child: Text('dep_broke_hairline'.tr)),
                      DropdownMenuItem(
                          value: 'Broken during cleaning',
                          child: Text('dep_broke_cleaning'.tr)),
                      DropdownMenuItem(
                          value: 'Cap / Neck chipped',
                          child: Text('dep_broke_chipped'.tr)),
                      DropdownMenuItem(
                          value: 'Other reason',
                          child: Text('dep_reason_other'.tr)),
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
                      hintText: 'dep_broke_notes_hint'.tr,
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
                    label: Text(
                      'dep_report_wa_btn'.tr,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      final note = notesCtrl.text.trim();
                      final message =
                          'Hello Sri Aashikaa Support,\n\nI want to report a broken glass bottle:\n• Customer: $custName (ID: $custId)\n• Bottle Type: $selectedType\n• Reason: $selectedReason${note.isNotEmpty ? '\n• Notes: $note' : ''}\n\nPlease arrange a replacement bottle on the next delivery. Thank you!';
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
                    label: Text(
                        tr('dep_call_hotline_btn', {'phone': supportPhone})),
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
                        Text(
                          'dep_security_deposit_title'.tr,
                          style: const TextStyle(
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
                        child: Row(
                          children: [
                            const Icon(Icons.verified, color: _green, size: 14),
                            const SizedBox(width: 4),
                            Text('dep_100_refundable'.tr,
                                style: const TextStyle(
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
                        Text('dep_total_deposit_bal'.tr,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
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
                      tooltip: 'dep_reload_ledger'.tr,
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
                      _heroDepositItem('dep_1l_bottles'.tr,
                          '₹${bottle1LDepositTotal.toInt()}'),
                      Container(width: 1, height: 22, color: Colors.white24),
                      _heroDepositItem('dep_05l_bottles'.tr,
                          '₹${bottle05LDepositTotal.toInt()}'),
                      Container(width: 1, height: 22, color: Colors.white24),
                      _heroDepositItem(
                          'dep_ice_box'.tr, '₹${iceBoxDepositTotal.toInt()}'),
                      Container(width: 1, height: 22, color: Colors.white24),
                      _heroDepositItem(
                          'dep_refundable'.tr, '₹${pendingRefund.toInt()}'),
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
                            tr('dep_refund_under_review',
                                {'amt': '${pendingRefund.toInt()}'}),
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
                          ? 'dep_view_another_refund_btn'.tr
                          : 'dep_raise_sec_refund_btn'.tr,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('dep_assets_in_hand'.tr,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('dep_assets_in_hand_sub'.tr,
                                  style: const TextStyle(
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
                          tr('dep_total_assets_count',
                              {'count': '${intactBottlesInHand + countIceBox}'}),
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
                    title: 'dep_1l_glass_title'.tr,
                    countText:
                        tr('dep_count_in_hand', {'count': '$count1L'}),
                    rateText: tr('dep_rate_per_unit',
                        {'amt': '${_bottle1LDeposit.toInt()}'}),
                    totalDepositText: tr('dep_amount_held',
                        {'amt': '${bottle1LDepositTotal.toInt()}'}),
                    isActive: count1L > 0,
                    note: 'dep_1l_note'.tr,
                  ),
                  const SizedBox(height: 10),

                  // Asset 2: 0.5L Glass Bottle
                  _inHandAssetTile(
                    icon: Icons.local_drink_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'dep_05l_glass_title'.tr,
                    countText:
                        tr('dep_count_in_hand', {'count': '$count05L'}),
                    rateText: tr('dep_rate_per_unit',
                        {'amt': '${_bottle05LDeposit.toInt()}'}),
                    totalDepositText: tr('dep_amount_held',
                        {'amt': '${bottle05LDepositTotal.toInt()}'}),
                    isActive: count05L > 0,
                    note: 'dep_05l_note'.tr,
                  ),
                  const SizedBox(height: 10),

                  // Asset 3: Insulated Ice Box
                  _inHandAssetTile(
                    icon: Icons.kitchen_outlined,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFF3E8FF),
                    title: 'dep_ice_box_full_title'.tr,
                    countText: countIceBox > 0
                        ? tr('dep_count_in_hand', {'count': '1'})
                        : 'dep_not_opted'.tr,
                    rateText: tr('dep_ice_box_rate_note',
                        {'amt': '${_iceBoxDepositAmount.toInt()}'}),
                    totalDepositText: countIceBox > 0
                        ? tr('dep_amount_held',
                            {'amt': '${iceBoxDepositTotal.toInt()}'})
                        : '₹0',
                    isActive: countIceBox > 0,
                    note: 'dep_ice_box_note'.tr,
                  ),

                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.autorenew, color: _green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'dep_daily_rotation_tip'.tr,
                            style: const TextStyle(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('dep_condition_title'.tr,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('dep_condition_sub'.tr,
                                  style: const TextStyle(
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
                            tr('dep_broken_badge', {'count': '$brokenCount'}),
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
                          label: 'dep_good_intact'.tr,
                          color: _green,
                          bg: const Color(0xFFECFDF5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _conditionMetricTile(
                          icon: Icons.broken_image_outlined,
                          count: '$brokenCount',
                          label: 'dep_broken_damaged'.tr,
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
                          label: 'dep_lost_missing'.tr,
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
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: _green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'dep_all_intact_msg'.tr,
                              style: const TextStyle(
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
                              tr('dep_broken_alert_msg',
                                  {'count': '$brokenCount'}),
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

                  Text('dep_breakage_terms_title'.tr,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  _policyRow(tr('dep_term_1l_break',
                      {'amt': '${_bottle1LDeposit.toInt()}'})),
                  _policyRow(tr('dep_term_05l_break',
                      {'amt': '${_bottle05LDeposit.toInt()}'})),
                  _policyRow('dep_term_notify'.tr),

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
                    label: Text('dep_report_btn'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('dep_ledger_title'.tr,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('dep_ledger_sub'.tr,
                                    style: const TextStyle(
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
                            tr('dep_receipts_count',
                                {'count': '${depositsList.length}'}),
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
                                Text(
                                    tr('dep_date_row',
                                        {'date': date.isEmpty ? '-' : date}),
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
                                  child: Text(
                                      LanguageService.statusLabel(status),
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
                  Text('dep_how_rotation_works'.tr,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stepItem('dep_step1_title'.tr, 'dep_step1_sub'.tr,
                          Icons.local_shipping_outlined),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: Colors.grey),
                      _stepItem('dep_step2_title'.tr, 'dep_step2_sub'.tr,
                          Icons.eco_outlined),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: Colors.grey),
                      _stepItem('dep_step3_title'.tr, 'dep_step3_sub'.tr,
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
                    Text(tr('dep_deposit_prefix', {'amt': totalDepositText}),
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
