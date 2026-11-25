import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../services/api.dart';
import '../../services/language_service.dart';

const _green = Color(0xFF059669);

class PaymentTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onPaymentDone;
  const PaymentTab(
      {super.key, required this.customer, required this.onPaymentDone});
  @override
  State<PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<PaymentTab> {
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _cancellations = [];
  List<Map<String, dynamic>> _weeklyDeliveries = [];
  Map<String, dynamic>? _enterprise;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _todayDelivery;
  bool _loading = true;
  String _historyFilter = 'ALL'; // 'ALL', 'PAID', 'PENDING'

  double _ratePerLiter = 65.0;
  String _paymentPeriod = 'weekly'; // 'daily', 'weekly', 'monthly'

  List<Map<String, dynamic>> get _filteredPayments {
    if (_historyFilter == 'PAID') {
      return _payments.where((p) {
        final s = (p['payment_status'] ?? p['status'] ?? '').toString().toUpperCase();
        return s == 'PAID' || s == 'COMPLETED';
      }).toList();
    } else if (_historyFilter == 'PENDING') {
      return _payments.where((p) {
        final s = (p['payment_status'] ?? p['status'] ?? '').toString().toUpperCase();
        return s == 'PENDING' || s == 'DUE';
      }).toList();
    }
    return _payments;
  }

  String _periodTitle(String p) {
    switch (p) {
      case 'daily':
        return 'pay_period_daily'.tr;
      case 'monthly':
        return 'pay_period_monthly'.tr;
      case 'weekly':
      default:
        return 'pay_period_weekly'.tr;
    }
  }

  @override
  void initState() {
    super.initState();
    _paymentPeriod = (widget.customer['payment_period'] ??
            widget.customer['billing_cycle'] ??
            'weekly')
        .toString()
        .toLowerCase();
    if (_paymentPeriod != 'daily' &&
        _paymentPeriod != 'weekly' &&
        _paymentPeriod != 'monthly') {
      _paymentPeriod = 'weekly';
    }
    _load();
  }

  // ── Cycle Date Helpers (Daily / Weekly (Saturday) / Monthly (1st)) ─────────

  /// Start date of current cycle
  DateTime get _cycleStartDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_paymentPeriod == 'daily') {
      return today;
    } else if (_paymentPeriod == 'monthly') {
      return DateTime(now.year, now.month, 1);
    } else {
      // Weekly (Saturday closing): Cycle begins previous Sunday
      final daysSinceSunday = today.weekday % 7;
      return today.subtract(Duration(days: daysSinceSunday));
    }
  }

  /// End date of current cycle
  DateTime get _cycleEndDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_paymentPeriod == 'daily') {
      return today;
    } else if (_paymentPeriod == 'monthly') {
      // Last day of current month
      return DateTime(now.year, now.month + 1, 0);
    } else {
      // Weekly closing on Saturday
      return _cycleStartDate.add(const Duration(days: 6));
    }
  }

  /// Next settlement / payment date
  DateTime get _nextPaymentDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_paymentPeriod == 'daily') {
      return today;
    } else if (_paymentPeriod == 'monthly') {
      // 1st of upcoming month
      if (now.month == 12) {
        return DateTime(now.year + 1, 1, 1);
      }
      return DateTime(now.year, now.month + 1, 1);
    } else {
      // Weekly closing on Saturday
      final diff = (DateTime.saturday - today.weekday);
      if (diff < 0) {
        // If today is Sunday (diff = 6 - 7 = -1), upcoming Saturday is in 6 days
        return today.add(const Duration(days: 6));
      }
      return today.add(Duration(days: diff));
    }
  }

  /// Days remaining until the next payment
  int get _daysUntilPayment {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final diff = _nextPaymentDate.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Verifies if the delivered amount for this cycle has been genuinely paid
  bool _checkIfPaid(double deliveredAmount) {
    if (deliveredAmount <= 0) return true;

    final milkPayments = _payments.where((p) {
      final status =
          (p['payment_status'] ?? p['status'] ?? '').toString().toUpperCase();
      if (status != 'PAID' && status != 'COMPLETED') return false;

      final period = (p['billing_period'] ?? '').toString().toLowerCase();
      if (period.contains('security deposit') ||
          period.contains('bottle deposit') ||
          period.contains('asset deposit')) {
        return false; // ignore deposit payments
      }

      final pDateStr =
          (p['payment_date'] ?? p['created_at'] ?? '').toString().split('T').first;
      final pDate = DateTime.tryParse(pDateStr);
      if (pDate == null || pDate.isBefore(_cycleStartDate)) {
        return false;
      }

      final paidAmt = double.tryParse(
              (p['paid_amount'] ?? p['total_amount'] ?? 0).toString()) ??
          0.0;
      return paidAmt >= deliveredAmount;
    }).toList();

    return milkPayments.isNotEmpty;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final custId =
          widget.customer['id'] ?? widget.customer['customer_id'] ?? '';
      final list = await SupabaseAPI.fetchPayments(widget.customer);
      final enterprise = await SupabaseAPI.fetchEnterpriseSettings();
      final config = await SupabaseAPI.fetchPricingConfig();
      final sub = await SupabaseAPI.fetchCustomerSubscription(custId);
      final cancellations = await SupabaseAPI.fetchCancellations(custId);
      final deliveries =
          await SupabaseAPI.fetchDeliveries(widget.customer, 'weekly');
      final todayDel = await SupabaseAPI.fetchTodayDelivery(widget.customer);

      if (mounted) {
        setState(() {
          _payments = list;
          _enterprise = enterprise;
          _subscription = sub;
          _cancellations = cancellations;
          _weeklyDeliveries = deliveries;
          _todayDelivery = todayDel;

          // Dynamically detect rate: from customer, deliveries, or config
          double effectiveRate = 65.0;
          if (widget.customer['rate_per_liter'] != null) {
            effectiveRate = double.tryParse(widget.customer['rate_per_liter'].toString()) ?? 65.0;
          } else if (deliveries.isNotEmpty && deliveries.first['rate_per_liter'] != null) {
            effectiveRate = double.tryParse(deliveries.first['rate_per_liter'].toString()) ?? 65.0;
          } else if (config['rate_per_liter'] != null) {
            final cr = double.tryParse(config['rate_per_liter'].toString()) ?? 65.0;
            if (cr > 0) effectiveRate = cr;
          }
          _ratePerLiter = effectiveRate;

          final savedPeriod = (widget.customer['payment_period'] ??
                  widget.customer['billing_cycle'] ??
                  sub?['billing_cycle'] ??
                  _paymentPeriod)
              .toString()
              .toLowerCase();
          if (savedPeriod == 'daily' ||
              savedPeriod == 'weekly' ||
              savedPeriod == 'monthly') {
            _paymentPeriod = savedPeriod;
          }

          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Update Payment Period Sheet ──────────────────────────────────────────

  void _showUpdatePaymentPeriodBottomSheet() {
    String tempPeriod = _paymentPeriod;
    bool updating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: const EdgeInsets.all(22),
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
                            child: const Icon(Icons.schedule,
                                color: _green, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('pay_update_period_title'.tr,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('pay_choose_cycle_sub'.tr,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
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
                  const Divider(height: 24),

                  // Option 1: Daily
                  _periodSelectionCard(
                    key: 'daily',
                    selectedKey: tempPeriod,
                    title: 'pay_daily_card_title'.tr,
                    subtitle: 'pay_daily_card_sub'.tr,
                    scheduleText: 'pay_daily_card_sched'.tr,
                    icon: Icons.today_outlined,
                    onTap: () => setModalState(() => tempPeriod = 'daily'),
                  ),
                  const SizedBox(height: 10),

                  // Option 2: Weekly (Saturday)
                  _periodSelectionCard(
                    key: 'weekly',
                    selectedKey: tempPeriod,
                    title: 'pay_weekly_card_title'.tr,
                    subtitle: 'pay_weekly_card_sub'.tr,
                    scheduleText: 'pay_weekly_card_sched'.tr,
                    icon: Icons.view_week_outlined,
                    isPopular: true,
                    onTap: () => setModalState(() => tempPeriod = 'weekly'),
                  ),
                  const SizedBox(height: 10),

                  // Option 3: Monthly (1st of Month)
                  _periodSelectionCard(
                    key: 'monthly',
                    selectedKey: tempPeriod,
                    title: 'pay_monthly_card_title'.tr,
                    subtitle: 'pay_monthly_card_sub'.tr,
                    scheduleText: 'pay_monthly_card_sched'.tr,
                    icon: Icons.calendar_month_outlined,
                    onTap: () => setModalState(() => tempPeriod = 'monthly'),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: updating
                        ? null
                        : () async {
                            setModalState(() => updating = true);
                            try {
                              await SupabaseAPI.updatePaymentPeriod(
                                  widget.customer, tempPeriod);

                              setState(() {
                                _paymentPeriod = tempPeriod;
                                widget.customer['payment_period'] = tempPeriod;
                                widget.customer['billing_cycle'] = tempPeriod;
                              });

                              if (modalCtx.mounted) Navigator.pop(modalCtx);
                              await _load();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('pay_period_updated_ok',
                                      {'period': _periodTitle(tempPeriod)})),
                                  backgroundColor: _green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              setModalState(() => updating = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr(
                                      'pay_period_update_err', {'err': '$e'})),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: updating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            tr('pay_save_cycle_btn',
                                {'period': _periodTitle(tempPeriod)}),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _periodSelectionCard({
    required String key,
    required String selectedKey,
    required String title,
    required String subtitle,
    required String scheduleText,
    required IconData icon,
    required VoidCallback onTap,
    bool isPopular = false,
  }) {
    final isSelected = key == selectedKey;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _green : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? _green : Colors.grey.shade200,
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
                          color: isSelected ? _green : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('pay_popular'.tr,
                              style: const TextStyle(
                                  color: _green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(scheduleText,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? _green : Colors.grey.shade700)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_off,
              color: isSelected ? _green : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── UPI Direct Payment Flow ───────────────────────────────────────────────

  Future<void> _recordDirectPayment(
    double amount,
    String periodLabel,
    String upiId,
    String txnRef,
  ) async {
    try {
      final name = widget.customer['name'] ?? 'Customer';
      final phone = widget.customer['phone'] ?? widget.customer['mobile'] ?? '';

      await SupabaseAPI.processPayment(
        widget.customer,
        name,
        phone,
        amount,
        billingPeriod: periodLabel,
        upiId: upiId,
        transactionRef: txnRef,
      );

      widget.onPaymentDone();
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pay_verified_ok', {'amt': '${amount.toInt()}'})),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pay_confirm_err', {'err': '$e'})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _initiateDirectUPIPayment(double amount, String periodLabel) async {
    final upiId = (_enterprise?['upi_id'] ?? 'sriaashikaa@upi').toString().trim().replaceAll(' ', '');
    final payeeName =
        (_enterprise?['upi_payee_name'] ?? _enterprise?['company_name'] ?? 'Sri Aashikaa Milk').toString().trim();
    final custName = (widget.customer['name'] ?? 'Customer').toString();
    final amtStr = amount.toStringAsFixed(2);
    final cleanNote = 'Milk Bill $periodLabel - $custName'.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').trim();
    final safeNote = cleanNote.length > 50 ? cleanNote.substring(0, 50).trim() : cleanNote;
    final txnRef = 'TXN${DateTime.now().millisecondsSinceEpoch}';

    // Standard NPCI UPI URI with pre-filled amount and payee UPI ID directly
    final upiUrl =
        'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amtStr&cu=INR&tn=${Uri.encodeComponent(safeNote)}';
    final uri = Uri.parse(upiUrl);

    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Launch externalApplication error: $e');
    }

    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (e) {
        debugPrint('Launch externalNonBrowserApplication error: $e');
      }
    }

    if (!launched) {
      try {
        launched = await launchUrl(uri);
      } catch (e) {
        debugPrint('Launch default error: $e');
      }
    }

    if (!mounted) return;

    if (launched) {
      // Payment apps opened directly on phone with pre-filled amount!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pay_app_opened_msg', {'amt': '${amount.toInt()}'})),
          backgroundColor: _green,
          duration: const Duration(seconds: 25),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'pay_mark_paid'.tr,
            textColor: Colors.white,
            onPressed: () => _recordDirectPayment(amount, periodLabel, upiId, txnRef),
          ),
        ),
      );
    } else {
      Clipboard.setData(ClipboardData(text: upiId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pay_app_fail_copied', {'upi': upiId})),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Invoice Dialog ────────────────────────────────────────────────────────

  Future<void> _openInvoicePdf(String url, String invNum) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('pay_opening_pdf'.tr),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    bool opened = false;
    try {
      final uri = Uri.parse(url);
      final res = await http.head(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          opened = true;
          return;
        }
      }
    } catch (_) {}

    if (!opened) {
      try {
        final uri = Uri.parse(url);
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            opened = true;
            return;
          }
        }
      } catch (_) {}
    }

    if (!opened && mounted) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('pay_receipt_synced_msg', {'inv': invNum}),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showInvoiceDialog(Map<String, dynamic> p) {
    final rawInv = p['invoice_number'] ?? p['reference_number'] ?? '';
    final String invNum = (rawInv.toString().isNotEmpty && rawInv != 'INV-DUE' && !rawInv.toString().startsWith('INV-DUE'))
        ? (rawInv.toString().startsWith('RCP-')
            ? 'INV-202610-${rawInv.toString().substring(4)}'
            : rawInv.toString())
        : 'INV-202610-${(p['id']?.toString().substring(0, 8) ?? '001').toUpperCase()}';
    final s3InvoiceUrl = p['invoice_url']?.toString().isNotEmpty == true
        ? p['invoice_url'].toString()
        : 'https://eftixvhkmtujlbayrauk.supabase.co/storage/v1/object/public/invoices/$invNum.pdf';
    final amt = p['total_amount'] ?? p['paid_amount'] ?? 0;
    final paidAmt = p['paid_amount'] ?? amt;
    final method = p['payment_method'] ?? 'UPI';
    final status = (p['payment_status'] ?? p['status'] ?? 'PAID')
        .toString()
        .toUpperCase();
    final date = (p['payment_date'] ?? p['created_at'] ?? '')
        .toString()
        .split('T')
        .first;
    final period = p['billing_period'] ?? 'Weekly Milk Delivery';
    final ref = p['reference_number'] ?? p['transaction_ref'] ?? '-';
    final companyName = _enterprise?['company_name'] ?? 'Sri Aashikaa Raw Milk';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: _green, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text('pay_receipt_title'.tr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            _receiptRow('pay_row_inv'.tr, invNum),
            _receiptRow('pay_row_cust'.tr, widget.customer['name'] ?? 'Customer'),
            _receiptRow('pay_row_date'.tr, date.isEmpty ? '-' : date),
            _receiptRow('pay_row_period'.tr, period.toString()),
            _receiptRow('pay_row_method'.tr, method.toString()),
            _receiptRow('pay_row_ref'.tr, ref.toString()),
            const Divider(),
            _receiptRow('pay_row_paid_amt'.tr, '₹$paidAmt', isTotal: true),
            _receiptRow('pay_row_status'.tr, LanguageService.statusLabel(status), isStatus: true),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final receiptText = '''
--- SRI AASHIKAA RAW MILK ---
Official Payment Receipt & Tax Invoice
Invoice No: $invNum
Customer: ${widget.customer['name'] ?? 'Customer'}
Payment Date: ${date.isEmpty ? '-' : date}
Billing Period: $period
Payment Method: $method
Reference No: $ref
Amount Paid: ₹$paidAmt
Payment Status: $status
-----------------------
Support: ${_enterprise?['support_phone'] ?? '+91 98401 23456'}
'''.trim();
              Clipboard.setData(ClipboardData(text: receiptText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('pay_receipt_copied'.tr),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 14, color: _green),
            label: Text('pay_copy_receipt'.tr,
                style: const TextStyle(
                    color: _green, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => _openInvoicePdf(s3InvoiceUrl, invNum),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: Text('pay_download_pdf'.tr,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value,
      {bool isTotal = false, bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (isStatus)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(value,
                  style: const TextStyle(
                      color: _green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            )
          else
            Text(value,
                style: TextStyle(
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                    fontSize: isTotal ? 14 : 12,
                    color: isTotal ? _green : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double dailyQty = double.tryParse(
            (_subscription?['daily_quantity'] ??
                    widget.customer['milk_quantity'] ??
                    1.0)
                .toString()) ??
        1.0;

    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final cycleStart = _cycleStartDate;
    final cycleEnd = _cycleEndDate;

    // Filter cancellations
    final approvedCancelledDates = _cancellations
        .where((c) {
          final status =
              (c['approval_status'] ?? c['status'] ?? '').toString().toUpperCase();
          return status == 'APPROVED' || status == 'REQUESTED';
        })
        .map((c) =>
            (c['cancellation_date'] ?? c['cancel_date'] ?? '').toString())
        .toSet();

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final isCancelledToday = approvedCancelledDates.contains(todayStr);

    final todayDeliveryStatus =
        (_todayDelivery?['delivery_status'] ?? '').toString().toUpperCase();
    final bool isTodayOutForDelivery = !isCancelledToday &&
        (todayDeliveryStatus == 'OUT_FOR_DELIVERY' ||
            todayDeliveryStatus == 'ASSIGNED' ||
            todayDeliveryStatus == 'IN_TRANSIT' ||
            todayDeliveryStatus == 'NEAR_CUSTOMER');
    final bool isTodayDelivered =
        !isCancelledToday && todayDeliveryStatus == 'DELIVERED';
    final bool isTodayActive = isTodayOutForDelivery || isTodayDelivered;

    int deliveredDaysCount = 0;
    double deliveredLiters = 0.0;
    double deliveredAmount = 0.0;
    int totalPossibleCycleDays = 7;
    String cyclePeriodLabel = '';
    String settlementHeading = 'Weekly Settlement';
    String paymentDaySubtitle =
        'Payment Day: Every Saturday • Counted After Delivery';
    int cancelledDaysInCycle = 0;

    int regularDeliveredDays = 0;
    double regularLiters = 0.0;
    double regularAmt = 0.0;
    final List<Map<String, dynamic>> additionalDeliveries = [];
    double additionalLiters = 0.0;
    double additionalAmt = 0.0;

    if (_paymentPeriod == 'daily') {
      settlementHeading = 'pay_settle_daily'.tr;
      totalPossibleCycleDays = 1;
      paymentDaySubtitle = 'pay_sub_daily'.tr;
      cyclePeriodLabel = LanguageService.formatFullDayDate(today);

      if (isCancelledToday) {
        cancelledDaysInCycle = 1;
        deliveredDaysCount = 0;
        deliveredLiters = 0.0;
        deliveredAmount = 0.0;
      } else {
        deliveredDaysCount = 1;
        deliveredLiters = dailyQty;
        deliveredAmount = dailyQty * _ratePerLiter;
        regularDeliveredDays = 1;
        regularLiters = dailyQty;
        regularAmt = deliveredAmount;
      }
    } else if (_paymentPeriod == 'monthly') {
      settlementHeading = 'pay_settle_monthly'.tr;
      totalPossibleCycleDays = cycleEnd.day;
      paymentDaySubtitle = 'pay_sub_monthly'.tr;
      cyclePeriodLabel =
          '01 ${LanguageService.monthShortLabel(today.month)} - ${LanguageService.formatShortDate(cycleEnd)}';

      final daysElapsedInMonth = today.day;
      for (int i = 1; i <= daysElapsedInMonth; i++) {
        final d = DateTime(today.year, today.month, i);
        final dStr = DateFormat('yyyy-MM-dd').format(d);
        if (approvedCancelledDates.contains(dStr)) {
          cancelledDaysInCycle++;
        }
      }

      deliveredDaysCount =
          (daysElapsedInMonth - cancelledDaysInCycle).clamp(0, totalPossibleCycleDays);
      deliveredLiters = deliveredDaysCount * dailyQty;
      deliveredAmount = deliveredLiters * _ratePerLiter;
      regularDeliveredDays = deliveredDaysCount;
      regularLiters = deliveredLiters;
      regularAmt = deliveredAmount;
    } else {
      // Weekly (Saturday)
      settlementHeading = 'pay_settle_weekly'.tr;
      totalPossibleCycleDays = 7;
      paymentDaySubtitle = 'pay_sub_weekly'.tr;
      cyclePeriodLabel =
          '${cycleStart.day.toString().padLeft(2, '0')} ${LanguageService.monthShortLabel(cycleStart.month)} - ${LanguageService.formatShortDate(cycleEnd)}';

      final daysElapsedThisCycle = today.difference(cycleStart).inDays + 1;
      for (int i = 0; i < daysElapsedThisCycle && i < 7; i++) {
        final d = cycleStart.add(Duration(days: i));
        final dStr = DateFormat('yyyy-MM-dd').format(d);
        if (approvedCancelledDates.contains(dStr)) {
          cancelledDaysInCycle++;
        }
      }

      if (_weeklyDeliveries.isNotEmpty) {
        final validDeliveries = _weeklyDeliveries.where((d) {
          final status = (d['delivery_status'] ?? '').toString().toUpperCase();
          final dDate = (d['delivery_date'] ?? d['created_at'] ?? '').toString().split('T').first;
          final pDate = DateTime.tryParse(dDate);
          if (pDate != null && pDate.isBefore(cycleStart)) return false;
          return status != 'CANCELLED';
        }).toList();

        final hasTodayInList = validDeliveries.any((d) {
          final dDate = (d['delivery_date'] ?? d['created_at'] ?? '').toString().split('T').first;
          return dDate == todayStr;
        });

        int extraDays = 0;
        double extraLiters = 0.0;
        double extraAmt = 0.0;
        if (!hasTodayInList && isTodayActive) {
          extraDays = 1;
          extraLiters = dailyQty;
          extraAmt = dailyQty * _ratePerLiter;
        }

        final regularList = validDeliveries.where((d) {
          final plan = (d['subscription_plan'] ?? '').toString();
          return plan != 'Additional Order';
        }).toList();

        final extraList = validDeliveries.where((d) {
          final plan = (d['subscription_plan'] ?? '').toString();
          return plan == 'Additional Order';
        }).toList();

        additionalDeliveries.addAll(extraList);

        regularDeliveredDays = regularList.length + extraDays;
        regularLiters = regularList.fold(
                0.0,
                (acc, d) =>
                    acc +
                    (double.tryParse((d['quantity'] ?? dailyQty).toString()) ??
                        dailyQty)) +
            extraLiters;
        regularAmt = regularList.fold(
                0.0,
                (acc, d) =>
                    acc +
                    (double.tryParse((d['total_amount'] ??
                                (dailyQty * _ratePerLiter))
                            .toString()) ??
                        (dailyQty * _ratePerLiter))) +
            extraAmt;

        additionalLiters = extraList.fold(
            0.0,
            (acc, d) =>
                acc +
                (double.tryParse((d['quantity'] ?? 0).toString()) ?? 0.0));
        additionalAmt = extraList.fold(
            0.0,
            (acc, d) =>
                acc +
                (double.tryParse((d['total_amount'] ?? 0).toString()) ?? 0.0));

        deliveredDaysCount = regularDeliveredDays;
        deliveredLiters = regularLiters + additionalLiters;
        deliveredAmount = regularAmt + additionalAmt;
      } else {
        deliveredDaysCount =
            (daysElapsedThisCycle - cancelledDaysInCycle).clamp(0, 7);
        deliveredLiters = deliveredDaysCount * dailyQty;
        deliveredAmount = deliveredLiters * _ratePerLiter;
        regularDeliveredDays = deliveredDaysCount;
        regularLiters = deliveredLiters;
        regularAmt = deliveredAmount;
      }
    }

    final isCyclePaid = _checkIfPaid(deliveredAmount);

    // Automatically sync pending payment to Supabase database when unbilled
    if (!isCyclePaid && deliveredAmount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SupabaseAPI.syncPendingDeliveryPayment(
            widget.customer, deliveredAmount, cyclePeriodLabel);
      });
    }

    final totalReceivedAllTime = _payments.fold(
        0.0,
        (acc, p) =>
            acc +
            (double.tryParse(
                    (p['paid_amount'] ?? p['total_amount'] ?? 0).toString()) ??
                0.0));

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 0. Active Billing Model & Cycle Bar ──────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_outlined, size: 20, color: _green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'billing_model'.tr,
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              tr('pay_postpaid_suffix', {'period': _periodTitle(_paymentPeriod)}),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.tune, size: 13),
                  label: Text('pay_change_btn'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showUpdatePaymentPeriodBottomSheet,
                ),
              ],
            ),
          ),

          // ── 1. Hero Card: Current Bill & Quick Action ────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCyclePaid
                    ? const [Color(0xFF047857), Color(0xFF10B981)]
                    : const [Color(0xFF065F46), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
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
                          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settlementHeading,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              cyclePeriodLabel,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCyclePaid ? Colors.white : Colors.amber.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCyclePaid
                            ? 'pay_all_settled'.tr
                            : (_daysUntilPayment == 0
                                ? 'pay_due_today'.tr
                                : tr('pay_due_in_days', {'days': '$_daysUntilPayment'})),
                        style: TextStyle(
                          color: isCyclePaid ? _green : const Color(0xFF78350F),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Text('pay_curr_balance_due'.tr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      isCyclePaid ? '₹0' : '₹${deliveredAmount.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCyclePaid
                          ? 'pay_no_dues'.tr
                          : tr('pay_for_liters', {'qty': deliveredLiters.toStringAsFixed(1)}),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isCyclePaid
                      ? 'pay_all_settled_msg'.tr
                      : tr('pay_settlement_date_msg', {
                          'date': LanguageService.formatFullDayDate(_nextPaymentDate),
                          'sub': paymentDaySubtitle,
                        }),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 18),

                // Pay Button (Full Width, UPI Direct Launch)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.payment, size: 20),
                    label: Text(
                      isCyclePaid
                          ? 'pay_advance_btn'.tr
                          : tr('pay_via_upi_btn', {'amt': '${deliveredAmount.toInt()}'}),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      final payAmount = deliveredAmount > 0
                          ? deliveredAmount
                          : (dailyQty * _ratePerLiter * totalPossibleCycleDays);
                      _initiateDirectUPIPayment(payAmount, cyclePeriodLabel);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. Three Metric Highlight Cards ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _deliveryMetricBox(
                  icon: Icons.check_circle_outline,
                  count: '$deliveredDaysCount / $totalPossibleCycleDays',
                  label: 'pay_days_delivered'.tr,
                  color: _green,
                  bg: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _deliveryMetricBox(
                  icon: Icons.water_drop_outlined,
                  count: '${deliveredLiters.toStringAsFixed(1)} L',
                  label: 'pay_liters_delivered'.tr,
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _deliveryMetricBox(
                  icon: Icons.calendar_today_outlined,
                  count:
                      '${_nextPaymentDate.day.toString().padLeft(2, '0')} ${LanguageService.monthShortLabel(_nextPaymentDate.month)}',
                  label: 'pay_next_settlement'.tr,
                  color: const Color(0xFF7C3AED),
                  bg: const Color(0xFFF5F3FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 3. Transparent Bill Calculation Breakdown ────────────────────
          Card(
            elevation: 1.5,
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_outlined, color: _green, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'pay_calc_breakdown'.tr,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text('pay_transparent_acct'.tr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          tr('pay_rate_per_liter_chip', {'rate': '${_ratePerLiter.toInt()}'}),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _billingBreakdownRow(
                          'pay_row_daily_sub'.tr,
                          tr('pay_row_daily_val', {'qty': '$dailyQty', 'rate': '${_ratePerLiter.toInt()}'}),
                          tr('pay_row_per_day', {'amt': '${(dailyQty * _ratePerLiter).toInt()}'}),
                        ),
                        _billingBreakdownRow(
                          'pay_row_reg_del'.tr,
                          tr('pay_row_reg_val', {
                            'days': '$regularDeliveredDays',
                            'qty': regularLiters.toStringAsFixed(1),
                            'rate': '${_ratePerLiter.toInt()}',
                          }),
                          '₹${regularAmt.toInt()}',
                        ),
                        if (additionalDeliveries.isNotEmpty)
                          _billingBreakdownRow(
                            'pay_row_extra_orders'.tr,
                            tr('pay_row_extra_val', {
                              'count': '${additionalDeliveries.length}',
                              'qty': additionalLiters.toStringAsFixed(1),
                            }),
                            '+ ₹${additionalAmt.toInt()}',
                            highlightColor: const Color(0xFF0284C7),
                          ),
                        if (isTodayOutForDelivery)
                          _billingBreakdownRow(
                            'pay_row_today_ofd'.tr,
                            tr('pay_row_today_val', {'qty': '$dailyQty'}),
                            tr('pay_row_included', {'amt': '${(dailyQty * _ratePerLiter).toInt()}'}),
                            highlightColor: const Color(0xFF1D4ED8),
                          ),
                        if (cancelledDaysInCycle > 0)
                          _billingBreakdownRow(
                            'pay_row_paused'.tr,
                            tr('pay_row_paused_val', {'days': '$cancelledDaysInCycle'}),
                            'pay_row_not_charged'.tr,
                            highlightColor: Colors.orange.shade800,
                          ),
                        const Divider(height: 16),
                        _billingBreakdownRow(
                          'pay_row_curr_to_pay'.tr,
                          tr('pay_row_settlement', {'period': _periodTitle(_paymentPeriod)}),
                          '₹${deliveredAmount.toInt()}',
                          isBold: true,
                          highlightColor: isCyclePaid ? _green : Colors.orange.shade800,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_outlined, size: 16, color: _green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'pay_postpaid_notice'.tr,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3),
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

          // ── 4. Subscription Plan & Settings ──────────────────────────────
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'pay_sub_settings_title'.tr,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      InkWell(
                        onTap: _showUpdatePaymentPeriodBottomSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_calendar, size: 12, color: _green),
                              const SizedBox(width: 4),
                              Text('pay_change_cycle'.tr, style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _planDetailTile(
                          icon: Icons.calendar_month,
                          label: 'payment_cycle'.tr,
                          value: _periodTitle(_paymentPeriod),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _planDetailTile(
                          icon: Icons.event,
                          label: 'pay_next_settle_date'.tr,
                          value: LanguageService.formatShortDayDate(_nextPaymentDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _planDetailTile(
                          icon: Icons.water_drop,
                          label: 'pay_per_litre_rate'.tr,
                          value: tr('pay_rate_per_liter_chip', {'rate': '${_ratePerLiter.toInt()}'}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _planDetailTile(
                          icon: Icons.schedule,
                          label: 'pay_daily_milk_rate'.tr,
                          value: tr('pay_daily_rate_val', {
                            'amt': '${(dailyQty * _ratePerLiter).toInt()}',
                            'qty': '$dailyQty',
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // UPI ID with copy action
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 18, color: _green),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('pay_official_upi'.tr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  _enterprise?['upi_id'] ?? 'sriaashikaa@upi',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            final upi = _enterprise?['upi_id'] ?? 'sriaashikaa@upi';
                            Clipboard.setData(ClipboardData(text: upi));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('onb_upi_copied', {'upi': '$upi'})),
                                backgroundColor: _green,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.copy, size: 12, color: _green),
                                const SizedBox(width: 4),
                                Text('onb_copy_btn'.tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
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
          const SizedBox(height: 16),

          // ── 5. Payment History & Official Receipts ────────────────────────
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'pay_history_title'.tr,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            tr('pay_total_received', {'amt': totalReceivedAllTime.toStringAsFixed(0)}),
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr('pay_records_count', {'count': '${_payments.length}'}),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('ALL', tr('pay_filter_all', {'count': '${_payments.length}'})),
                        const SizedBox(width: 8),
                        _filterChip(
                          'PAID',
                          tr('pay_filter_paid', {
                            'count':
                                '${_payments.where((p) => (p['payment_status'] ?? p['status'] ?? '').toString().toUpperCase() == 'PAID').length}',
                          }),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          'PENDING',
                          tr('pay_filter_pending', {
                            'count':
                                '${_payments.where((p) => (p['payment_status'] ?? p['status'] ?? '').toString().toUpperCase() == 'PENDING').length}',
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: _green),
                      ),
                    )
                  else if (_filteredPayments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr('pay_no_records_filter', {
                            'filter': _historyFilter == "ALL" ? "" : LanguageService.statusLabel(_historyFilter),
                          }),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ..._filteredPayments.map(_paymentCard),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSel = _historyFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: _green.withValues(alpha: 0.18),
      checkmarkColor: _green,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSel ? _green : Colors.grey.shade700,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _historyFilter = key);
      },
    );
  }

  Widget _planDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
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
              Icon(icon, size: 14, color: _green),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _deliveryMetricBox({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
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

  Widget _billingBreakdownRow(String title, String subtitle, String amount,
      {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isBold ? 13 : 12,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isBold ? 15 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: highlightColor ?? (isBold ? _green : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> p) {
    final status = (p['payment_status'] ?? p['status'] ?? 'PAID')
        .toString()
        .toUpperCase();
    final isPaid = status == 'PAID' || status == 'COMPLETED';
    final rawInv = p['invoice_number'] ?? p['reference_number'] ?? '';
    final String invNum = (rawInv.toString().isNotEmpty && rawInv != 'INV-DUE')
        ? (rawInv.toString().startsWith('RCP-')
            ? 'INV-202610-${rawInv.toString().substring(4)}'
            : rawInv.toString())
        : 'INV-${(p['id']?.toString().substring(0, 8) ?? '001').toUpperCase()}';
    final amt = p['total_amount'] ?? p['paid_amount'] ?? 0;
    final mode = p['payment_method'] ?? 'UPI';
    final period = p['billing_period'] ?? 'Weekly Milk Delivery';
    final date = (p['payment_date'] ?? p['created_at'] ?? '')
        .toString()
        .split('T')
        .first;

    return InkWell(
      onTap: () => _showInvoiceDialog(p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isPaid ? _green : Colors.orange).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isPaid ? _green : Colors.orange).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isPaid ? _green : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPaid ? Icons.check_circle_outline : Icons.pending_actions,
                color: isPaid ? _green : Colors.orange.shade800,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invNum.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.isEmpty ? '-' : date} • $period',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('pay_method_line', {'mode': '$mode'}),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$amt',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPaid ? _green : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'pay_badge_paid'.tr : 'pay_badge_pending'.tr,
                    style: TextStyle(
                      color: isPaid ? _green : Colors.orange.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
