import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/session_service.dart';
import 'auth_screen.dart';

class DeactivateAccountScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const DeactivateAccountScreen({super.key, required this.customer});

  @override
  State<DeactivateAccountScreen> createState() => _DeactivateAccountScreenState();
}

class _DeactivateAccountScreenState extends State<DeactivateAccountScreen> {
  bool _agreed = false;
  bool _isLoading = false;
  Map<String, dynamic>? _duesInfo;

  @override
  void initState() {
    super.initState();
    _checkPendingDues();
  }

  Future<void> _checkPendingDues() async {
    try {
      final info = await SupabaseAPI.checkCustomerPendingDues(widget.customer);
      if (mounted) {
        setState(() {
          _duesInfo = info;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Confirm Deactivation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently deactivate your account? All daily milk subscriptions will be cancelled immediately and your login access will be revoked.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Deactivate', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseAPI.deleteCustomerAccount(widget.customer);
      await UserSession.clearSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deactivated successfully.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deactivating account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double pendingAmt = (_duesInfo?['pending_amount'] as num?)?.toDouble() ?? 0.0;
    final bool hasDues = pendingAmt > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deactivate Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Deactivation & Removal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Please review all terms, conditions, and consequences before confirming deactivation.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pending Dues alert if any
              if (hasDues) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Outstanding Balance: ₹${pendingAmt.toStringAsFixed(2)}. Our support team will coordinate final bill settlement upon deactivation.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Terms & Details Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terms & Conditions of Deactivation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _termItem(
                        icon: Icons.cancel_schedule_send_rounded,
                        title: '1. Immediate Delivery Cancellation',
                        description:
                            'All ongoing recurring milk deliveries (morning & evening schedules) will be cancelled immediately from tomorrow onwards.',
                      ),
                      const Divider(height: 20),
                      _termItem(
                        icon: Icons.inventory_2_outlined,
                        title: '2. Asset Collection & Bottle Deposits',
                        description:
                            'Any glass bottles or delivery crates in your possession must be returned to the delivery partner. Any refundable security deposits will be credited to your bank account after physical inspection.',
                      ),
                      const Divider(height: 20),
                      _termItem(
                        icon: Icons.receipt_long_outlined,
                        title: '3. Bill Settlement',
                        description:
                            'Any unpaid dues up to your last delivery date will remain payable. An itemized closing statement will be generated.',
                      ),
                      const Divider(height: 20),
                      _termItem(
                        icon: Icons.no_accounts_rounded,
                        title: '4. Login Access Revocation',
                        description:
                            'You will be immediately logged out of this device. Your account credentials will be blocked from logging into the Amudham Customer App.',
                      ),
                      const Divider(height: 20),
                      _termItem(
                        icon: Icons.support_agent_rounded,
                        title: '5. Reactivation Request',
                        description:
                            'If you wish to resume milk delivery services in the future, you must contact the Amudham Dairy customer helpline desk.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tick Box (Checkbox)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _agreed ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                    width: _agreed ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreed,
                          activeColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => setState(() => _agreed = v ?? false),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'I have read, understood, and accept all the terms and conditions above. I confirm that I want to deactivate my account and permanently cancel all milk deliveries.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Delete / Deactivate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF64748B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: _agreed ? 2 : 0,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Processing Deactivation...' : 'Delete & Deactivate Account',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: (_agreed && !_isLoading) ? _handleDeactivate : null,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFDC2626), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
