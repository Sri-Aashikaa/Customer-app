import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/session_service.dart';
import '../../widgets/location_picker_dialog.dart';
import '../auth_screen.dart';
import '../change_password_screen.dart';

const _green = Color(0xFF059669);

class ProfileTab extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Function(Map<String, dynamic>) onUpdated;
  final Function(int tabIndex)? onNavigateToTab;
  const ProfileTab({
    super.key,
    required this.customer,
    required this.onUpdated,
    this.onNavigateToTab,
  });
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _enterprise;

  // App Update State
  Map<String, dynamic>? _updateInfo;
  bool _checkingUpdate = false;
  bool _autoUpdateEnabled = true;
  bool _isUpdating = false;

  // Account Deletion State
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
    _loadEnterpriseSettings();
    _loadAutoUpdatePreference();
    _checkAppUpdate(silent: true);
  }

  @override
  void didUpdateWidget(ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSubscription();
    _loadEnterpriseSettings();
  }

  Future<void> _loadAutoUpdatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_update_enabled') ?? true;
      if (mounted) setState(() => _autoUpdateEnabled = enabled);
    } catch (_) {}
  }

  Future<void> _toggleAutoUpdate(bool val) async {
    setState(() => _autoUpdateEnabled = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_update_enabled', val);
    } catch (_) {}
    if (val && _updateInfo?['has_update'] == true) {
      _showUpdateDialog(_updateInfo!);
    }
  }

  Future<void> _checkAppUpdate({bool silent = false}) async {
    if (!silent) setState(() => _checkingUpdate = true);
    try {
      final info = await SupabaseAPI.checkAppUpdate();
      if (mounted) {
        setState(() {
          _updateInfo = info;
          _checkingUpdate = false;
        });

        if (info['has_update'] == true) {
          if (!silent || _autoUpdateEnabled) {
            _showUpdateDialog(info);
          }
        } else if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('App is up to date! (v${SupabaseAPI.currentAppVersion})'),
                ],
              ),
              backgroundColor: _green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingUpdate = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check for updates: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _performAppUpdate(Map<String, dynamic> info) async {
    setState(() => _isUpdating = true);
    final urlStr = info['update_url']?.toString() ?? '';

    try {
      if (kIsWeb) {
        // Cache-busting refresh on web
        final currentUri = Uri.base;
        final reloadUri = currentUri.replace(
          queryParameters: {
            ...currentUri.queryParameters,
            'v': info['latest_version'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Updating app to latest version...'),
              ],
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 700));
        await launchUrl(reloadUri, webOnlyWindowName: '_self');
      } else {
        if (urlStr.isNotEmpty) {
          final uri = Uri.parse(urlStr);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw 'Cannot launch update URL: $urlStr';
          }
        } else {
          throw 'Update URL not specified in server settings';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> info) {
    final latestVer = info['latest_version'] ?? 'Latest';
    final releaseNotes = info['release_notes'] ?? 'General enhancements and bug fixes.';
    final isForced = info['force_update'] == true;

    showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: _green, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Update Available!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Version $latestVer is ready',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
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
                      const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      const Text(
                        'Release Highlights:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v$latestVer',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold, color: _green),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    releaseNotes,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                  ),
                ],
              ),
            ),
            if (isForced) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This is a required update for uninterrupted service.',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (!isForced)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(kIsWeb ? 'Update & Refresh' : 'Update Now'),
            onPressed: () {
              Navigator.pop(ctx);
              _performAppUpdate(info);
            },
          ),
        ],
      ),
    );
  }

  // ─── ACCOUNT DELETION FLOW (Pending Dues -> Agreement -> OTP -> Purge) ───

  Future<void> _startAccountDeletionFlow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.redAccent),
                SizedBox(width: 16),
                Text('Checking account balance & dues...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    final duesInfo = await SupabaseAPI.checkCustomerPendingDues(widget.customer);
    if (!mounted) return;
    Navigator.pop(context); // close progress dialog

    final hasPending = duesInfo['has_pending_dues'] == true;
    final pendingAmt = (duesInfo['pending_amount'] as num?)?.toDouble() ?? 0.0;

    if (hasPending && pendingAmt > 0) {
      _showPendingDuesDialog(pendingAmt);
    } else {
      _showDeletionAgreementDialog();
    }
  }

  void _showPendingDuesDialog(double pendingAmt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending Dues Detected',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Clear balance before deleting',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                children: [
                  const Text('Outstanding Balance to Settle:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                  const SizedBox(height: 6),
                  Text('₹${pendingAmt.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your account has pending milk delivery dues or unpaid invoices. As per company policy, all pending dues must be paid before account deletion and permanent record purge can be completed.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.payment, size: 18),
            label: Text('Pay Pending ₹${pendingAmt.toStringAsFixed(0)} Now'),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onNavigateToTab != null) {
                widget.onNavigateToTab!(4); // Switch to Payment Tab
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please navigate to the Payment tab to clear pending dues.'),
                    backgroundColor: _green,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeletionAgreementDialog() {
    bool agreed = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delete Account & Data',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    SizedBox(height: 2),
                    Text('Permanent Data Removal Agreement',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('The following will be deleted & revoked permanently:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text('All daily milk subscriptions and schedules will stop immediately.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text('Glass bottle & ice box allocations will be de-allocated and closed.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text('Past delivery history, invoices, and receipts will be purged.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text('Your mobile number and account credentials will be blocked from logging in again.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setDialogState(() => agreed = !agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: agreed,
                      activeColor: Colors.red,
                      onChanged: (val) => setDialogState(() => agreed = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'I agree to delete all my data and deactivate my account permanently.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: agreed ? Colors.red : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Proceed to OTP Authentication'),
              onPressed: agreed
                  ? () {
                      Navigator.pop(ctx);
                      _showDeletionOtpDialog();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletionOtpDialog() {
    final generatedOtp = (100000 + Random().nextInt(900000)).toString();
    final phone = widget.customer['mobile'] ?? widget.customer['phone'] ?? 'Registered Mobile';
    final otpCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sms_rounded, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OTP Authentication',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    SizedBox(height: 2),
                    Text('Security verification required',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 6-digit authentication code sent to $phone to confirm permanent account deletion:',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),

              // Simulated SMS Alert Banner for Instant Usability
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SMS OTP Verification Code',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          Text('Your 6-digit code is: $generatedOtp',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setModalState(() {
                          otpCtrl.text = generatedOtp;
                          errorText = null;
                        });
                      },
                      child: const Text('Auto-Fill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • • • •',
                  hintStyle: const TextStyle(letterSpacing: 4, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) setModalState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Confirm & Delete Account'),
              onPressed: () {
                final entered = otpCtrl.text.trim();
                if (entered != generatedOtp) {
                  setModalState(() => errorText = 'Invalid OTP. Please enter $generatedOtp');
                  return;
                }
                Navigator.pop(ctx);
                _executeAccountDeletion();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeAccountDeletion() async {
    setState(() => _isDeletingAccount = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(width: 18),
                Text('Permanently deleting account & data...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await SupabaseAPI.deleteCustomerAccount(widget.customer);
      await UserSession.clearSession();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show confirmation dialog before redirect
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _green, size: 28),
              SizedBox(width: 10),
              Text('Account Deleted', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your account and all associated subscriptions have been permanently deleted and deactivated. You will not be able to log in with these credentials again.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK, Go to Login'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadEnterpriseSettings() async {
    final ent = await SupabaseAPI.fetchEnterpriseSettings();
    if (mounted && ent != null) {
      setState(() => _enterprise = ent);
    }
  }

  Future<void> _loadSubscription() async {
    final custId = widget.customer['id'] ?? widget.customer['customer_id'] ?? '';
    if (custId.isEmpty) return;
    final sub = await SupabaseAPI.fetchCustomerSubscription(custId);
    if (mounted && sub != null) {
      setState(() => _subscription = sub);
    }
  }

  void _openUpdateProfileModal() {
    final nameCtrl = TextEditingController(text: widget.customer['name'] ?? '');
    final addressCtrl = TextEditingController(text: widget.customer['address'] ?? '');
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
                        'Update Profile Details',
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

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Street Address *',
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              if (nameCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your full name'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              try {
                                final updates = {
                                  'name': nameCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                };
                                final custId = widget.customer['id'] ??
                                    widget.customer['customer_id'] ??
                                    '';
                                await SupabaseAPI.updateProfile(custId, updates);

                                final updatedCust = {
                                  ...widget.customer,
                                  ...updates
                                };
                                widget.onUpdated(updatedCust);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '✅ Profile details updated successfully!'),
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
                                      content: Text('Error: $e'),
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
                              'Save Profile Changes',
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

  void _openChangeMobileModal() {
    final mobileCtrl = TextEditingController(
        text: widget.customer['mobile'] ?? widget.customer['phone'] ?? '');
    final passCtrl = TextEditingController();
    bool obscurePass = true;
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
                        'Update Mobile Number',
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 18, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Security Authorization Required: Enter your account password to verify your identity before changing your login mobile number.',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF78350F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'New Mobile Number *',
                      hintText: '10-digit mobile number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Account Password for Authorization *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setModalState(() => obscurePass = !obscurePass),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              final newMobile = mobileCtrl.text.trim();
                              final pass = passCtrl.text.trim();

                              if (newMobile.length < 10) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please enter a valid 10-digit mobile number'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (pass.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please enter your password for security authorization'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);
                              try {
                                final custId = widget.customer['id'] ??
                                    widget.customer['customer_id'] ??
                                    '';

                                final isAuthOk =
                                    await SupabaseAPI.verifyCurrentPassword(
                                        custId, pass);

                                if (!isAuthOk) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '🔒 Incorrect password authorization! Mobile number not changed.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final updates = {
                                  'mobile': newMobile,
                                  'phone': newMobile,
                                };
                                await SupabaseAPI.updateProfile(
                                    custId, updates);

                                final updatedCust = {
                                  ...widget.customer,
                                  ...updates
                                };
                                widget.onUpdated(updatedCust);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '📱 Mobile number updated securely!'),
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
                                      content: Text('Error: $e'),
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
                              'Authorize & Update Mobile Number',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
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

  void _openUpdateAccountDetailsModal() {
    final areaCtrl = TextEditingController(text: widget.customer['area'] ?? 'Anna Nagar');
    final cityCtrl = TextEditingController(text: widget.customer['city'] ?? 'Chennai');
    final pincodeCtrl = TextEditingController(text: widget.customer['pincode'] ?? '600040');
    final locationCtrl = TextEditingController(
        text: widget.customer['location'] ??
            '${widget.customer['area'] ?? 'Anna Nagar'}, ${widget.customer['city'] ?? 'Chennai'}');
    final altMobileCtrl = TextEditingController(
        text: (widget.customer['alternate_mobile'] ?? widget.customer['alt_mobile'] ?? '').toString());
    final emailCtrl = TextEditingController(
        text: (widget.customer['email'] ?? widget.customer['email_id'] ?? '').toString());

    double? lat = double.tryParse((widget.customer['latitude'] ?? '11.695006').toString());
    double? lng = double.tryParse((widget.customer['longitude'] ?? '77.974743').toString());

    bool isUpdating = false;
    bool isFetchingGps = false;

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
                        'Update Account & Location Details',
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

                  TextField(
                    controller: areaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Area / Neighborhood',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: pincodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pincode',
                      prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: altMobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Alternate Mobile Number',
                      hintText: 'Secondary or emergency contact number',
                      prefixIcon: Icon(Icons.phone_android_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address / ID',
                      hintText: 'e.g. customer@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Location Address',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Interactive Map Location Picker
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, color: _green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lat != null && lng != null
                                    ? 'Map Pin: ${areaCtrl.text.isNotEmpty ? areaCtrl.text : 'Selected'}'
                                    : 'Pick delivery location on the map',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.pin_drop, size: 16),
                                label: const Text('Pick / Modify on Map 🗺️',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final result = await LocationPickerDialog.show(
                                    context,
                                    initialLat: lat ?? 13.0827,
                                    initialLng: lng ?? 80.2707,
                                    initialArea: areaCtrl.text,
                                    initialCity: cityCtrl.text,
                                    initialPincode: pincodeCtrl.text,
                                    initialAddress: locationCtrl.text,
                                  );
                                  if (result != null) {
                                    setModalState(() {
                                      lat = result['latitude'];
                                      lng = result['longitude'];
                                      if (result['area'] != null && result['area'].toString().isNotEmpty) {
                                        areaCtrl.text = result['area'];
                                      }
                                      if (result['city'] != null && result['city'].toString().isNotEmpty) {
                                        cityCtrl.text = result['city'];
                                      }
                                      if (result['pincode'] != null && result['pincode'].toString().isNotEmpty) {
                                        pincodeCtrl.text = result['pincode'];
                                      }
                                      if (result['location'] != null && result['location'].toString().isNotEmpty) {
                                        locationCtrl.text = result['location'];
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _green,
                                  side: const BorderSide(color: _green),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: isFetchingGps
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                                    : const Icon(Icons.my_location, size: 15),
                                label: const Text('My GPS 📍', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: isFetchingGps
                                    ? null
                                    : () async {
                                        setModalState(() => isFetchingGps = true);
                                        try {
                                          final pos = await Geolocator.getCurrentPosition(
                                            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                                          );
                                          setModalState(() {
                                            lat = pos.latitude;
                                            lng = pos.longitude;
                                          });
                                        } catch (_) {}
                                        setModalState(() => isFetchingGps = false);
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

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
                      onPressed: isUpdating
                          ? null
                          : () async {
                              setModalState(() => isUpdating = true);
                              try {
                                final updates = {
                                  'area': areaCtrl.text.trim(),
                                  'city': cityCtrl.text.trim(),
                                  'pincode': pincodeCtrl.text.trim(),
                                  'location': locationCtrl.text.trim(),
                                  'alternate_mobile': altMobileCtrl.text.trim(),
                                  'alt_mobile': altMobileCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'latitude': ?lat,
                                  'longitude': ?lng,
                                };
                                final custId = widget.customer['id'] ??
                                    widget.customer['customer_id'] ??
                                    '';
                                await SupabaseAPI.updateProfile(custId, updates);

                                final updatedCust = {
                                  ...widget.customer,
                                  ...updates
                                };
                                await UserSession.saveSession(updatedCust);
                                widget.onUpdated(updatedCust);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '✅ Location and account details updated successfully!'),
                                      backgroundColor: _green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isUpdating = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Location & Account Details',
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

  Future<void> _launchURL(String urlStr) async {
    final Uri uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch link: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    String planName = _subscription?['delivery_days'] ??
        c['delivery_days'] ??
        c['subscription_type'] ??
        'Daily';

    if (planName == 'Monday-Sunday') {
      planName = 'Daily';
    }

    final badgeLabel = planName.toLowerCase().contains('plan') ||
            planName.toLowerCase().contains('subscription')
        ? planName
        : '$planName Plan';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Profile Header ───────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFECFDF5),
                child: Text(
                  (c['name'] ?? 'C').toString().characters.first.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 30, color: _green, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text(c['name'] ?? 'Customer',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(c['customer_id'] ?? c['id'] ?? '',
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeLabel,
                    style: const TextStyle(
                        color: _green, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── 1. Profile Details Card ───────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profile Details',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
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
                        label: const Text('Update Profile',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openUpdateProfileModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(Icons.badge_outlined, 'Customer ID',
                      c['customer_id'] ?? c['id'] ?? ''),
                  _detailRow(Icons.person_outline, 'Full Name',
                      c['name'] ?? 'Customer'),
                  _detailRow(Icons.home_outlined, 'Street Address',
                      c['address'] ?? 'Not set'),
                  
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 4),

                  // Mobile Row with Separate Security Authorization Update Button
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: _green),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Mobile Number',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                      Text(
                        c['mobile'] ?? c['phone'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: _green),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.lock_person_outlined, size: 12),
                        label: const Text('Change',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openChangeMobileModal,
                      ),
                    ],
                  ),
                ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── 2. Account Details Card with Update & Location Option ───────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Account Details',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
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
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 14),
                        label: const Text('Update Location',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openUpdateAccountDetailsModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(Icons.phone_outlined, 'Primary Mobile',
                      (c['mobile'] ?? c['phone'] ?? '-').toString()),
                  _detailRow(Icons.phone_android_outlined, 'Alternate Mobile',
                      (c['alternate_mobile'] ?? c['alt_mobile'] ?? 'Not set').toString().isNotEmpty
                          ? (c['alternate_mobile'] ?? c['alt_mobile']).toString()
                          : 'Not set'),
                  _detailRow(Icons.email_outlined, 'Email Address',
                      (c['email'] ?? c['email_id'] ?? 'Not set').toString().isNotEmpty
                          ? (c['email'] ?? c['email_id']).toString()
                          : 'Not set'),
                  _detailRow(Icons.payments_outlined, 'Payment Plan',
                      (c['payment_period'] ?? c['billing_cycle'] ?? 'Weekly').toString().toUpperCase()),
                  _detailRow(Icons.location_city_outlined, 'Area',
                      c['area'] ?? 'Anna Nagar'),
                  _detailRow(Icons.location_on_outlined, 'City',
                      c['city'] ?? 'Chennai'),
                  _detailRow(Icons.markunread_mailbox_outlined, 'Pincode',
                      c['pincode'] ?? '600040'),
                  _detailRow(Icons.map_outlined, 'Location',
                      c['location'] ?? '${c['area'] ?? 'Anna Nagar'}, ${c['city'] ?? 'Chennai'}'),
                ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── 3. Password Change Card ───────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, color: _green),
                      SizedBox(width: 8),
                      Text('Security & Password',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Verify your current password and update to a new password',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Change Password',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePasswordScreen(customer: widget.customer),
                        ),
                      );
                    },
                  ),
                ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── 4. Company & Enterprise Details (enterprise_settings table) ─────
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.business_outlined, color: Colors.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _enterprise?['company_name'] ?? 'Amudham / Milk ERP Enterprises',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Official Enterprise Details (Server Settings)',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _detailRow(Icons.receipt_outlined, 'GST Number',
                    _enterprise?['gst_number'] ?? '33AAAAA0000A1Z5'),
                _detailRow(Icons.location_city_outlined, 'Head Office',
                    _enterprise?['head_office_address'] ?? 'Plot 42, Dairy Tech Park, Salem'),
                _detailRow(Icons.storefront_outlined, 'Central Hub',
                    _enterprise?['branch_address'] ?? 'Salem Central Hub, Meyyanur Bypass, Salem - 636004'),
                _detailRow(Icons.schedule_outlined, 'Operating Shift',
                    _enterprise?['default_shift'] ?? 'Morning Shift (05:00 AM - 07:30 AM)'),
                _detailRow(Icons.payments_outlined, 'Payee UPI ID',
                    _enterprise?['upi_id'] ?? 'amudhamdairy@upi'),
                if (_enterprise?['website_url'] != null) ...[
                  const Divider(height: 16),
                  InkWell(
                    onTap: () => _launchURL(_enterprise!['website_url'].toString()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.language_outlined, size: 18, color: Colors.blue),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Official Website',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ),
                          Text(
                            _enterprise!['website_url'].toString(),
                            style: const TextStyle(
                                color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new, size: 14, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 5. Contact Customer Care Support (enterprise_settings table) ─────
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.headset_mic_outlined, color: _green),
                    SizedBox(width: 8),
                    Text('Customer Care Support',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                    'Have questions or need assistance with your daily delivery? Contact our team anytime.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),

                // WhatsApp Help Desk Button
                Builder(builder: (_) {
                  final rawPhone = _enterprise?['support_phone'] ?? _enterprise?['secondary_phone'] ?? '919876543210';
                  final cleanDigits = rawPhone.toString().replaceAll(RegExp(r'[^0-9]'), '');
                  final compName = _enterprise?['company_name'] ?? 'Amudham Milk';
                  final waUrl = 'https://wa.me/$cleanDigits?text=Hello%20${Uri.encodeComponent(compName)}%20Support';

                  return InkWell(
                    onTap: () => _launchURL(waUrl),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Color(0xFF15803D)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('WhatsApp Help Desk',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                        fontSize: 13)),
                                Text('Instant chat assistance • $rawPhone',
                                    style: const TextStyle(
                                        color: Color(0xFF166534), fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF15803D)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),

                // Phone Call Button
                Builder(builder: (_) {
                  final phone = _enterprise?['support_phone'] ?? '+91 98765 43210';
                  final shift = _enterprise?['default_shift'] ?? 'Available 6:00 AM - 9:00 PM';
                  final callDigits = phone.toString().replaceAll(RegExp(r'[^0-9+]'), '');

                  return InkWell(
                    onTap: () => _launchURL('tel:$callDigits'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, color: _green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Call Support Desk',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        fontSize: 13)),
                                Text('$phone ($shift)',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),

                // Secondary Helpline if available
                if (_enterprise?['secondary_phone'] != null) ...[
                  Builder(builder: (_) {
                    final secPhone = _enterprise!['secondary_phone'].toString();
                    final secDigits = secPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                    return InkWell(
                      onTap: () => _launchURL('tel:$secDigits'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_forwarded_outlined, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Secondary Helpline Desk',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          fontSize: 13)),
                                  Text(secPhone,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // Email Support Button
                Builder(builder: (_) {
                  final email = _enterprise?['support_email'] ?? 'contact@amudhammilk.com';
                  return InkWell(
                    onTap: () => _launchURL('mailto:$email'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: _green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Email Customer Support',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        fontSize: 13)),
                                Text(email,
                                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 6. App Updates & Version Management (enterprise_settings table) ──
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: _green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App Version & Updates',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _updateInfo?['has_update'] == true
                                ? 'New version v${_updateInfo!['latest_version']} available!'
                                : 'App is up to date (v${SupabaseAPI.currentAppVersion})',
                            style: TextStyle(
                              color: _updateInfo?['has_update'] == true
                                  ? const Color(0xFFD97706)
                                  : Colors.grey,
                              fontSize: 11,
                              fontWeight: _updateInfo?['has_update'] == true
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_updateInfo?['has_update'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.new_releases_rounded, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 4),
                            Text(
                              'UPDATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Version detail container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.smartphone_rounded, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Installed Version', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${SupabaseAPI.currentAppVersion} (Build ${SupabaseAPI.currentBuildNumber})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_done_rounded, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Latest Server Version', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _updateInfo?['has_update'] == true
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${_updateInfo?['latest_version'] ?? SupabaseAPI.currentAppVersion}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _updateInfo?['has_update'] == true ? _green : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_updateInfo?['has_update'] == true &&
                          (_updateInfo?['release_notes']?.toString().isNotEmpty ?? false)) ...[
                        const Divider(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.description_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _updateInfo!['release_notes'].toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Auto-Update Switch Tile
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.autorenew_rounded, color: _green, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Update App',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Automatically check releases and notify',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoUpdateEnabled,
                        activeThumbColor: _green,
                        onChanged: _toggleAutoUpdate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: _green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _checkingUpdate
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(_checkingUpdate ? 'Checking...' : 'Check for Updates'),
                        onPressed: _checkingUpdate ? null : () => _checkAppUpdate(silent: false),
                      ),
                    ),
                    if (_updateInfo?['has_update'] == true) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_rounded, size: 18),
                          label: Text(_isUpdating ? 'Updating...' : (kIsWeb ? 'Update & Refresh' : 'Update Now')),
                          onPressed: _isUpdating ? null : () => _performAppUpdate(_updateInfo!),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 7. Danger Zone: Delete Account & Data ───────────────────────────
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
          ),
          color: const Color(0xFFFFF5F5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Danger Zone: Delete Account',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                          Text(
                            'Permanently delete your account, milk deliveries, and personal data',
                            style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Once deleted, your active subscriptions are cancelled and you will no longer be able to log in. Any outstanding balance must be cleared prior to deletion.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isDeletingAccount
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(_isDeletingAccount ? 'Processing Deletion...' : 'Delete Account & Erase Data'),
                    onPressed: _isDeletingAccount ? null : _startAccountDeletionFlow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: _green),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.right)),
      ]),
    );
  }
}
