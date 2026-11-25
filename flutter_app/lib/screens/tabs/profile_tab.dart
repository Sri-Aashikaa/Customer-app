import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/session_service.dart';
import '../../services/language_service.dart';
import '../../widgets/location_picker_dialog.dart';
import '../../widgets/app_logo.dart';
import '../auth_screen.dart';
import '../change_password_screen.dart';
import '../deactivate_account_screen.dart';

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
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr('prof_up_to_date_toast', {'ver': SupabaseAPI.currentAppVersion})),
                  ),
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
              content: Text(tr('prof_update_check_err', {'err': '$e'})),
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
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('prof_updating_toast'.tr)),
              ],
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
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
            content: Text(tr('prof_update_failed', {'err': '$e'})),
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
                  Text('prof_new_update_title'.tr,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(tr('prof_ver_ready', {'ver': '$latestVer'}),
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
                      Text(
                        'prof_release_highlights'.tr,
                        style: const TextStyle(
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
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'prof_required_update'.tr,
                      style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
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
              child: Text('prof_later'.tr, style: const TextStyle(color: Colors.grey)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(kIsWeb ? 'prof_update_refresh'.tr : 'update_now_btn'.tr),
            onPressed: () {
              Navigator.pop(ctx);
              _performAppUpdate(info);
            },
          ),
        ],
      ),
    );
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
                      Text(
                        'prof_update_profile_title'.tr,
                        style: const TextStyle(
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
                    decoration: InputDecoration(
                      labelText: 'prof_full_name_req'.tr,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'prof_street_addr_req'.tr,
                      prefixIcon: const Icon(Icons.home_outlined),
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
                              if (nameCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('prof_err_name'.tr),
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
                                    SnackBar(
                                      content: Text('prof_profile_updated_ok'.tr),
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
                          : Text(
                              'prof_save_profile_btn'.tr,
                              style: const TextStyle(
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
                      Text(
                        'prof_update_mobile_title'.tr,
                        style: const TextStyle(
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
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'prof_mobile_auth_notice'.tr,
                            style: const TextStyle(
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
                    decoration: InputDecoration(
                      labelText: 'prof_new_mobile_req'.tr,
                      hintText: 'prof_mobile_10_hint'.tr,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'prof_acc_pass_auth'.tr,
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
                                  SnackBar(
                                    content: Text('prof_err_mobile_10'.tr),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (pass.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('prof_err_pass_auth'.tr),
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
                                      SnackBar(
                                        content: Text('prof_err_wrong_pass'.tr),
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
                                    SnackBar(
                                      content: Text('prof_mobile_updated_ok'.tr),
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
                          : Text(
                              'prof_auth_update_mobile_btn'.tr,
                              style: const TextStyle(
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
                      Text(
                        'prof_update_acc_loc_title'.tr,
                        style: const TextStyle(
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
                    decoration: InputDecoration(
                      labelText: 'prof_area_neighborhood'.tr,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'city'.tr,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: pincodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'pincode'.tr,
                      prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: altMobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'prof_alt_mobile'.tr,
                      hintText: 'prof_alt_mobile_hint'.tr,
                      prefixIcon: const Icon(Icons.phone_android_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'prof_email_id_label'.tr,
                      hintText: 'e.g. customer@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'prof_del_loc_addr'.tr,
                      prefixIcon: const Icon(Icons.map_outlined),
                      border: const OutlineInputBorder(),
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
                                    ? tr('prof_map_pin', {
                                        'loc': areaCtrl.text.isNotEmpty
                                            ? areaCtrl.text
                                            : 'prof_map_selected'.tr
                                      })
                                    : 'prof_pick_del_loc'.tr,
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
                                label: Text('pick_on_map'.tr,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                label: Text('prof_my_gps'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                  'latitude': lat,
                                  'longitude': lng,
                                };
                                final custId = widget.customer['id'] ??
                                    widget.customer['customer_id'] ??
                                    '';
                                await SupabaseAPI.updateProfile(custId, updates);

                                final newPin = pincodeCtrl.text.trim();
                                final isServiceable = await SupabaseAPI.isPincodeServiceable(newPin);
                                if (!isServiceable) {
                                  await SupabaseAPI.recordUnserviceableLocationRequest(
                                    pincode: newPin.isNotEmpty ? newPin : 'Unspecified',
                                    areaName: areaCtrl.text.trim(),
                                    city: cityCtrl.text.trim(),
                                    customerName: (widget.customer['name'] ?? 'Customer').toString(),
                                    customerMobile: (widget.customer['mobile'] ?? widget.customer['phone'] ?? '').toString(),
                                    fullAddress: locationCtrl.text.trim(),
                                    latitude: lat,
                                    longitude: lng,
                                    notes: 'Customer updated profile address with unserviceable pincode',
                                  );
                                }

                                final updatedCust = {
                                  ...widget.customer,
                                  ...updates
                                };
                                await UserSession.saveSession(updatedCust);
                                widget.onUpdated(updatedCust);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (!isServiceable) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.location_off_outlined, color: Colors.orange),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text('prof_loc_notice_title'.tr,
                                                  style: const TextStyle(fontSize: 16)),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          tr('prof_loc_notice_body', {'pin': newPin}),
                                          style: const TextStyle(fontSize: 13, height: 1.4),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text('ok'.tr,
                                                style: const TextStyle(
                                                    color: _green, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('prof_loc_updated_ok'.tr),
                                        backgroundColor: _green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
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
                          : Text(
                              'prof_save_loc_btn'.tr,
                              style: const TextStyle(
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

  void _openLanguageSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String tempLang = LanguageService.currentLanguage;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isTa = tempLang == 'ta';
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.translate_rounded, color: _green, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTa ? 'மொழி விருப்பம்' : 'Language Preference',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isTa ? 'செயலியின் மொழியைத் தேர்ந்தெடுக்கவும்' : 'Select app language',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Option 1: Tamil
                    InkWell(
                      onTap: () {
                        setModalState(() => tempLang = 'ta');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tempLang == 'ta' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tempLang == 'ta' ? _green : const Color(0xFFE2E8F0),
                            width: tempLang == 'ta' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: tempLang == 'ta' ? _green : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'த',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: tempLang == 'ta' ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'தமிழ் (Tamil)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'பயன்பாட்டை முழுமையாக தமிழில் பயன்படுத்தவும்',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            if (tempLang == 'ta')
                              const Icon(Icons.check_circle, color: _green, size: 22)
                            else
                              const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Option 2: English
                    InkWell(
                      onTap: () {
                        setModalState(() => tempLang = 'en');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tempLang == 'en' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tempLang == 'en' ? _green : const Color(0xFFE2E8F0),
                            width: tempLang == 'en' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: tempLang == 'en' ? _green : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'EN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: tempLang == 'en' ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'English',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Use the entire app in English',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            if (tempLang == 'en')
                              const Icon(Icons.check_circle, color: _green, size: 22)
                            else
                              const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (tempLang != LanguageService.currentLanguage) {
                          await LanguageService.setLanguage(tempLang);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      tempLang == 'ta'
                                          ? 'மொழி வெற்றிகரமாக தமிழாக மாற்றப்பட்டது'
                                          : 'Language successfully changed to English',
                                    ),
                                  ],
                                ),
                                backgroundColor: _green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        isTa ? 'சேமிக்க (Save)' : 'Save Language (சேமிக்க)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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
          SnackBar(content: Text(tr('prof_err_link', {'err': '$e'})), backgroundColor: Colors.red),
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

    final localizedPlan = LanguageService.planLabel(planName);
    final badgeLabel = planName.toLowerCase().contains('plan') ||
            planName.toLowerCase().contains('subscription')
        ? localizedPlan
        : tr('prof_plan_badge', {'plan': localizedPlan});

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
                      Text('prof_details_title'.tr,
                          style: const TextStyle(
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
                        label: Text('prof_update_btn'.tr,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openUpdateProfileModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(Icons.badge_outlined, 'prof_customer_id'.tr,
                      (c['customer_id'] ?? c['id'] ?? '').toString()),
                  _detailRow(Icons.person_outline, 'full_name'.tr,
                      (c['name'] ?? 'pay_row_cust'.tr).toString()),
                  _detailRow(Icons.home_outlined, 'prof_delivery_address'.tr,
                      _formatFullAddress(c)),
                  
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 4),

                  // Mobile Row with Separate Security Authorization Update Button
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: _green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('prof_mobile_label'.tr,
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                        label: Text('prof_change_btn'.tr,
                            style: const TextStyle(
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
                      Text('account_details'.tr,
                          style: const TextStyle(
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
                        label: Text('update_location_btn'.tr,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openUpdateAccountDetailsModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(Icons.phone_outlined, 'primary_mobile'.tr,
                      _safeDisplay(c['mobile'] ?? c['phone'])),
                  _detailRow(Icons.phone_android_outlined, 'alternate_mobile_label'.tr,
                      _safeDisplay(c['alternate_mobile'] ?? c['alt_mobile'], 'prof_not_provided'.tr)),
                  _detailRow(Icons.email_outlined, 'email_label'.tr,
                      _safeDisplay(c['email'] ?? c['email_id'], 'prof_not_provided'.tr)),
                  _detailRow(Icons.payments_outlined, 'payment_plan_label'.tr,
                      LanguageService.periodLabel((c['payment_period'] ?? c['billing_cycle'] ?? 'weekly').toString()).toUpperCase()),
                  _detailRow(Icons.location_city_outlined, 'area_label'.tr,
                      _safeDisplay(c['area'] ?? c['location'], 'Anna Nagar')),
                  _detailRow(Icons.location_on_outlined, 'city_label'.tr,
                      _safeDisplay(c['city'], 'Salem')),
                  _detailRow(Icons.markunread_mailbox_outlined, 'pincode_label'.tr,
                      _safeDisplay(c['pincode'], '636004')),
                  _detailRow(Icons.map_outlined, 'full_address_label'.tr,
                      _formatFullAddress(c)),
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
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, color: _green),
                      const SizedBox(width: 8),
                      Text('security_password_title'.tr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('security_password_desc'.tr,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                    label: Text('change_password_btn'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

        // ── Language Preference Card ──────────────────────────────────────
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
                      child: const Icon(Icons.translate_rounded, color: _green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'language_preference'.tr,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'language_preference_desc'.tr,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'current_language'.tr,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          LanguageService.isTamil ? 'தமிழ் (Tamil)' : 'English',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(
                    'change_language'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _openLanguageSelectionModal,
                ),
              ],
            ),
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
                    const AppLogo(size: 42, compact: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _enterprise?['company_name'] ?? 'Sri Aashikaa Raw Milk',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'enterprise_details_subtitle'.tr,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _detailRow(Icons.receipt_outlined, 'gst_number'.tr,
                    _enterprise?['gst_number'] ?? '33AAAAA0000A1Z5'),
                _detailRow(Icons.location_city_outlined, 'head_office'.tr,
                    _enterprise?['head_office_address'] ?? 'Plot 42, Dairy Tech Park, Salem'),
                _detailRow(Icons.storefront_outlined, 'central_hub'.tr,
                    _enterprise?['branch_address'] ?? 'Salem Central Hub, Meyyanur Bypass, Salem - 636004'),
                Builder(builder: (_) {
                  final lat = _enterprise?['office_latitude'] ?? 11.664325;
                  final lng = _enterprise?['office_longitude'] ?? 78.146014;
                  final mapUrl = _enterprise?['google_maps_url']?.toString() ?? 'https://maps.google.com/?q=$lat,$lng';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => _launchURL(mapUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: _green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'View Office on Google Maps / Directions',
                                style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            Icon(Icons.directions_outlined, size: 16, color: Colors.blue.shade800),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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
                          Expanded(
                            child: Text('official_website'.tr,
                                style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                Row(
                  children: [
                    const Icon(Icons.headset_mic_outlined, color: _green),
                    const SizedBox(width: 8),
                    Text('customer_support_title'.tr,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'customer_support_desc'.tr,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),

                // WhatsApp Help Desk Button
                Builder(builder: (_) {
                  final rawPhone = _enterprise?['support_phone'] ?? _enterprise?['secondary_phone'] ?? '919876543210';
                  final cleanDigits = rawPhone.toString().replaceAll(RegExp(r'[^0-9]'), '');
                  final compName = _enterprise?['company_name'] ?? 'Sri Aashikaa Raw Milk';
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
                                Text('whatsapp_helpdesk'.tr,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                        fontSize: 13)),
                                Text(tr('prof_instant_chat', {'phone': '$rawPhone'}),
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
                                Text('call_support'.tr,
                                    style: const TextStyle(
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



                // Email Support Button
                Builder(builder: (_) {
                  final email = _enterprise?['support_email'] ?? 'contact@sriaashikaamilk.com';
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
                                Text('email_support'.tr,
                                    style: const TextStyle(
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

        // ── 6. App Updates & Version Management (Google Play Store) ──────
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
                          Text(
                            'app_version_title'.tr,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _updateInfo?['has_update'] == true
                                ? tr('prof_new_ver_avail', {'ver': '${_updateInfo!['latest_version']}'})
                                : tr('prof_app_up_to_date_ver', {'ver': SupabaseAPI.currentAppVersion}),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.new_releases_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              'prof_update_badge'.tr,
                              style: const TextStyle(
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
                          Row(
                            children: [
                              const Icon(Icons.smartphone_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('installed_version'.tr, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${SupabaseAPI.currentAppVersion}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_done_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('latest_version'.tr, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                              _updateInfo == null
                                  ? 'checking'.tr
                                  : (_updateInfo?['latest_version'] != null
                                      ? 'v${_updateInfo!['latest_version']}'
                                      : 'prof_ps_unavailable'.tr),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'auto_update_app'.tr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'auto_update_desc'.tr,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
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
                        label: Text(_checkingUpdate ? 'checking'.tr : 'check_updates_btn'.tr),
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
                          label: Text(_isUpdating
                              ? 'prof_updating_btn'.tr
                              : (kIsWeb ? 'prof_update_refresh'.tr : 'update_now_btn'.tr)),
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

        // ── 7. Logout Account ──────────────────────────────────────────────
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
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
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'prof_acc_session'.tr,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'prof_acc_session_desc'.tr,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      'logout_btn'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _confirmLogout(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 8. Danger Zone: Deactivate Account ─────────────────────────────
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
                      child: const Icon(Icons.no_accounts_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'deactivate_account_title'.tr,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                          Text(
                            'deactivate_account_desc'.tr,
                            style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 11),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'prof_deactivate_tap_info'.tr,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
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
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: Text(
                      '${'deactivate_account_btn'.tr} ➔',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeactivateAccountScreen(customer: widget.customer),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _safeDisplay(dynamic value, [String? fallback]) {
    final effectiveFallback = fallback ?? 'prof_not_set'.tr;
    if (value == null) return effectiveFallback;
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null' || str == 'undefined' || str == '-') {
      return effectiveFallback;
    }
    return str;
  }

  String _formatFullAddress(Map<String, dynamic> c) {
    final parts = <String>[];
    void addIfValid(dynamic val) {
      if (val == null) return;
      final str = val.toString().trim();
      if (str.isNotEmpty && str.toLowerCase() != 'null' && str != '-' && str != 'undefined') {
        if (!parts.any((p) => p.toLowerCase() == str.toLowerCase())) {
          parts.add(str);
        }
      }
    }

    addIfValid(c['address']);
    addIfValid(c['location']);
    addIfValid(c['area']);
    addIfValid(c['city']);

    final pin = c['pincode']?.toString().trim();
    String addr = parts.join(', ');
    if (pin != null && pin.isNotEmpty && pin.toLowerCase() != 'null' && pin != '-') {
      if (addr.isNotEmpty) {
        addr = '$addr - $pin';
      } else {
        addr = pin;
      }
    }
    return addr.isNotEmpty ? addr : 'prof_not_set'.tr;
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _green),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Text('logout_confirm_title'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'logout_confirm_msg'.tr,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await UserSession.clearSession();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: Text('yes_logout'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
