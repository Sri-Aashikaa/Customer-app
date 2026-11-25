import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api.dart';
import '../services/session_service.dart';
import '../services/security_service.dart';
import '../services/whatsapp_service.dart';
import '../services/language_service.dart';
import '../widgets/location_picker_dialog.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

const kGreen = Color(0xFF059669);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureReg = true;

  // Login controllers
  final _loginMobileCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  String? _loginMobileError;
  String? _loginPassError;

  // Register controllers
  final _regNameCtrl = TextEditingController();
  final _regMobileCtrl = TextEditingController();
  final _regAddressCtrl = TextEditingController();
  final _regAreaCtrl = TextEditingController(text: 'Anna Nagar');
  final _regCityCtrl = TextEditingController(text: 'Chennai');
  final _regPincodeCtrl = TextEditingController(text: '600040');
  final _regPassCtrl = TextEditingController();
  final _latCtrl = TextEditingController(text: '13.0827');
  final _lngCtrl = TextEditingController(text: '80.2707');
  final _otpCtrl = TextEditingController();

  // Register Field Error Messages
  String? _regNameError;
  String? _regMobileError;
  bool _isDuplicateMobileError = false;
  String? _regPassError;
  String? _regAddressError;

  // OTP Registration State
  // Step 0 = fill form, Step 1 = OTP sent (verify), Step 2 = verified & registering
  int _regStep = 0;
  bool _otpVerified = false;
  bool _sendingOtp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginMobileCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regMobileCtrl.dispose();
    _regAddressCtrl.dispose();
    _regAreaCtrl.dispose();
    _regCityCtrl.dispose();
    _regPincodeCtrl.dispose();
    _regPassCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : kGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('auth_loc_perm_settings'.tr);
        return;
      }
      if (!mounted) return;
      setState(() => _loading = true);
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        _loading = false;
      });
      _snack('auth_loc_captured'.tr, error: false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(tr('auth_loc_error', {'err': '$e'}));
    }
  }

  Future<void> _openMapPicker() async {
    final curLat = double.tryParse(_latCtrl.text) ?? 13.0827;
    final curLng = double.tryParse(_lngCtrl.text) ?? 80.2707;

    final result = await LocationPickerDialog.show(
      context,
      initialLat: curLat,
      initialLng: curLng,
      initialArea: _regAreaCtrl.text.isNotEmpty ? _regAreaCtrl.text : 'Anna Nagar',
      initialCity: _regCityCtrl.text.isNotEmpty ? _regCityCtrl.text : 'Chennai',
      initialPincode: _regPincodeCtrl.text.isNotEmpty ? _regPincodeCtrl.text : '600040',
      initialAddress: _regAddressCtrl.text,
    );

    if (result != null && mounted) {
      setState(() {
        _latCtrl.text = (result['latitude'] ?? curLat).toString();
        _lngCtrl.text = (result['longitude'] ?? curLng).toString();
        if (result['area'] != null && result['area'].toString().isNotEmpty) {
          _regAreaCtrl.text = result['area'].toString();
        }
        if (result['city'] != null && result['city'].toString().isNotEmpty) {
          _regCityCtrl.text = result['city'].toString();
        }
        if (result['pincode'] != null && result['pincode'].toString().isNotEmpty) {
          _regPincodeCtrl.text = result['pincode'].toString();
        }
        if (result['address'] != null &&
            result['address'].toString().isNotEmpty &&
            _regAddressCtrl.text.trim().isEmpty) {
          _regAddressCtrl.text = result['address'].toString();
        }
      });
      _snack('auth_loc_confirmed_map'.tr, error: false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1: Validate form with Field Error Highlights & send OTP via WhatsApp
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendRegisterOtp() async {
    final name = _regNameCtrl.text.trim();
    final mobile = _regMobileCtrl.text.trim();
    final cleanMobile = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final pass = _regPassCtrl.text.trim();
    final address = _regAddressCtrl.text.trim();

    // 1. Validate fields & highlight exact missing inputs in red
    setState(() {
      _isDuplicateMobileError = false;
      _regNameError = name.isEmpty ? 'auth_name_required'.tr : null;

      if (cleanMobile.isEmpty) {
        _regMobileError = 'auth_mobile_empty'.tr;
      } else if (cleanMobile.length < 10) {
        _regMobileError = 'auth_mobile_digits'.tr;
      } else {
        _regMobileError = null;
      }

      if (pass.isEmpty) {
        _regPassError = 'auth_pass_required'.tr;
      } else if (pass.length < 6) {
        _regPassError = 'auth_pass_min'.tr;
      } else {
        _regPassError = null;
      }

      _regAddressError =
          address.isEmpty ? 'auth_address_required'.tr : null;
    });

    if (_regNameError != null ||
        _regMobileError != null ||
        _regPassError != null ||
        _regAddressError != null) {
      _snack('auth_fill_required'.tr);
      return;
    }

    setState(() => _sendingOtp = true);
    try {
      // 2. Check Pincode Serviceability
      final pincode = _regPincodeCtrl.text.trim();
      final isServiceable = await SupabaseAPI.isPincodeServiceable(pincode);
      if (!isServiceable) {
        setState(() => _sendingOtp = false);
        await SupabaseAPI.recordUnserviceableLocationRequest(
          pincode: pincode.isNotEmpty ? pincode : 'Unspecified',
          areaName: _regAreaCtrl.text.trim(),
          city: _regCityCtrl.text.trim(),
          customerName: name,
          customerMobile: cleanMobile,
          fullAddress: address,
          latitude: double.tryParse(_latCtrl.text),
          longitude: double.tryParse(_lngCtrl.text),
          notes: 'Customer attempted signup from unserviceable pincode',
        );
        _showUnserviceableDialog(pincode.isNotEmpty ? pincode : 'auth_your_area'.tr);
        return;
      }

      // 3. Strict Duplicate Mobile Check on Server (BEFORE sending OTP)
      final isDuplicate =
          await SupabaseAPI.isMobileAlreadyRegistered(cleanMobile);
      if (isDuplicate) {
        setState(() {
          _isDuplicateMobileError = true;
          _regMobileError = tr('auth_mobile_registered', {'mobile': cleanMobile});
          _sendingOtp = false;
        });
        _snack('❌ ${tr('auth_mobile_registered', {'mobile': cleanMobile})}');
        return;
      }

      final otp = SecurityService.generateSecureOtp();
      SecurityService.otpManager.issueOtp(cleanMobile, otp);

      final sent =
          await WhatsAppService.sendAuthenticationOtp(cleanMobile, otp);

      if (!mounted) return;

      if (sent) {
        setState(() {
          _regStep = 1;
          _otpCtrl.clear();
        });
        _snack(tr('auth_otp_sent', {'mobile': cleanMobile}), error: false);
      } else {
        _snack('auth_otp_send_fail'.tr);
      }
    } catch (e) {
      _snack(tr('auth_otp_send_err', {'err': '$e'}));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2: Verify OTP entered by user
  // ─────────────────────────────────────────────────────────────────────────
  void _verifyOtp() {
    final entered = _otpCtrl.text.trim();
    final cleanMobile = SecurityService.sanitizeMobileDigits(_regMobileCtrl.text);

    if (entered.length != 6) {
      _snack('auth_enter_6_otp'.tr);
      return;
    }

    final verification = SecurityService.otpManager.verifyOtp(cleanMobile, entered);
    if (!verification.isValid) {
      _snack('❌ ${verification.message}');
      return;
    }

    setState(() {
      _otpVerified = true;
      _regStep = 2;
    });
    _snack('auth_mobile_verified'.tr, error: false);
    _doRegister();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3: Create account on Supabase after OTP verified
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _doRegister() async {
    if (!_otpVerified) return;

    final name = _regNameCtrl.text.trim();
    final mobile = _regMobileCtrl.text.trim();
    final cleanMobile = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final pass = _regPassCtrl.text.trim();
    final address = _regAddressCtrl.text.trim();

    if (cleanMobile.isEmpty || cleanMobile.length < 10) {
      _snack('❌ Registration failed: Mobile number is required (10 digits).');
      return;
    }

    final suffix = cleanMobile.length >= 4
        ? cleanMobile.substring(cleanMobile.length - 4)
        : '0000';
    final generatedCustId =
        'CUST-$suffix-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

    setState(() => _loading = true);
    try {
      final payload = {
        'customer_id': generatedCustId,
        'name': name,
        'mobile': cleanMobile,
        'phone': cleanMobile,
        'password': pass,
        'address': address,
        'area': _regAreaCtrl.text.trim(),
        'city': _regCityCtrl.text.trim(),
        'pincode': _regPincodeCtrl.text.trim(),
        'latitude': double.tryParse(_latCtrl.text) ?? 13.0827,
        'longitude': double.tryParse(_lngCtrl.text) ?? 80.2707,
      };

      final user = await SupabaseAPI.registerCustomer(payload);
      await UserSession.saveSession(user);
      if (!mounted) return;

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => OnboardingScreen(customer: user)));
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
      SecurityService.otpManager.clear();
      setState(() {
        _regStep = 0;
        _otpVerified = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Login with Field Error Highlights
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _doLogin() async {
    final inputMobile = _loginMobileCtrl.text.trim();
    final inputPass = _loginPassCtrl.text.trim();

    setState(() {
      _loginMobileError = inputMobile.isEmpty ? 'auth_mobile_required'.tr : null;
      _loginPassError = inputPass.isEmpty ? 'auth_pass_required'.tr : null;
    });

    if (_loginMobileError != null || _loginPassError != null) {
      _snack('auth_enter_login_creds'.tr);
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await SupabaseAPI.loginCustomer(inputMobile, inputPass);
      await UserSession.saveSession(user);
      if (!mounted) return;

      if (user['account_status'] == 'INACTIVE' ||
          user['milk_quantity'] == null) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => OnboardingScreen(customer: user)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(customer: user)));
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Unserviceable Location Notice Dialog
  // ─────────────────────────────────────────────────────────────────────────
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.location_off_outlined, color: Color(0xFFD97706), size: 34),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'delivery_notice'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
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
                      '${'pincode'.tr}: $pincode',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'unserviceable_notice'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
              Text(
                'unserviceable_info'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('understood_thanks'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Forgot Password Dialog
  // ─────────────────────────────────────────────────────────────────────────
  void _showPasswordResetDialog() {
    final mobileCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool otpSent = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool sendingOtp = false;
    bool resetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.lock_reset, color: kGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('reset_password'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('auth_otp_via_wa'.tr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ])),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: mobileCtrl,
                    keyboardType: TextInputType.phone,
                    enabled: !otpSent,
                    decoration: InputDecoration(
                      labelText: 'auth_reg_mobile_req'.tr,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: otpSent ? const Icon(Icons.check_circle, color: kGreen) : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!otpSent)
                    ElevatedButton.icon(
                      icon: sendingOtp
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, size: 16),
                      label: Text(sendingOtp ? 'auth_sending_otp'.tr : 'auth_send_otp_wa_btn'.tr),
                      onPressed: sendingOtp ? null : () async {
                        final mobile = mobileCtrl.text.trim();
                        final cleanMobile = SecurityService.sanitizeMobileDigits(mobile);
                        if (cleanMobile.length < 10) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('auth_valid_mobile_err'.tr), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                          return;
                        }
                        setStateDialog(() => sendingOtp = true);
                        final otp = SecurityService.generateSecureOtp();
                        SecurityService.otpManager.issueOtp(cleanMobile, otp);
                        final sent = await WhatsAppService.sendAuthenticationOtp(cleanMobile, otp);
                        if (!ctx.mounted) return;
                        setStateDialog(() { sendingOtp = false; if (sent) otpSent = true; });
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(sent ? tr('auth_otp_sent', {'mobile': cleanMobile}) : 'auth_otp_send_fail'.tr),
                          backgroundColor: sent ? kGreen : Colors.red, behavior: SnackBarBehavior.floating,
                        ));
                      },
                    ),
                  if (otpSent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: kGreen, size: 16), const SizedBox(width: 8),
                        Expanded(child: Text('auth_otp_valid_5min'.tr, style: const TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                    TextField(controller: otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
                        decoration: InputDecoration(labelText: 'auth_enter_6_otp_req'.tr, prefixIcon: const Icon(Icons.pin_outlined), counterText: '')),
                    const SizedBox(height: 10),
                    StatefulBuilder(builder: (_, setP) => TextField(controller: newPassCtrl, obscureText: obscureNew,
                        decoration: InputDecoration(labelText: 'auth_new_pass_req'.tr, prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: () => setP(() => obscureNew = !obscureNew))))),
                    const SizedBox(height: 10),
                    StatefulBuilder(builder: (_, setP) => TextField(controller: confirmPassCtrl, obscureText: obscureConfirm,
                        decoration: InputDecoration(labelText: 'auth_confirm_new_pass_req'.tr, prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: () => setP(() => obscureConfirm = !obscureConfirm))))),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: resetting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.lock_reset, size: 16),
                      label: Text(resetting ? 'auth_resetting'.tr : 'reset_password'.tr),
                      onPressed: resetting ? null : () async {
                        final enteredOtp = otpCtrl.text.trim();
                        final newPass = newPassCtrl.text.trim();
                        final confirmPass = confirmPassCtrl.text.trim();
                        final mobile = mobileCtrl.text.trim();
                        final cleanMobile = SecurityService.sanitizeMobileDigits(mobile);

                        final verification = SecurityService.otpManager.verifyOtp(cleanMobile, enteredOtp);
                        if (!verification.isValid) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('❌ ${verification.message}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                          return;
                        }
                        if (newPass.isEmpty || newPass.length < 6) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('auth_pass_min_6'.tr), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                          return;
                        }
                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('auth_pass_mismatch'.tr), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                          return;
                        }
                        setStateDialog(() => resetting = true);
                        try {
                          await SupabaseAPI.resetCustomerPassword(cleanMobile, newPass);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _snack('auth_pass_reset_ok'.tr, error: false);
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                        } finally {
                          if (ctx.mounted) setStateDialog(() => resetting = false);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 14),
                      label: Text('resend_otp'.tr, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setStateDialog(() => otpSent = false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 60),
                const AppLogo(
                  size: 76,
                ),
                InkWell(
                  onTap: () async {
                    final next = LanguageService.isTamil ? 'en' : 'ta';
                    await LanguageService.setLanguage(next);
                    if (mounted) setState(() {});
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate_rounded, size: 14, color: kGreen),
                        const SizedBox(width: 4),
                        Text(
                          LanguageService.isTamil ? 'English' : 'தமிழ்',
                          style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('app_title'.tr,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text('app_tagline'.tr,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
              child: Text('live_server_connected'.tr,
                  style: const TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [Tab(text: 'login'.tr), Tab(text: 'register'.tr)],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 880,
              child: TabBarView(
                controller: _tabController,
                children: [_loginForm(), _registerForm()],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── LOGIN FORM ───────────────────────────────────────────────────────────
  Widget _loginForm() {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('customer_login'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('login_subtitle'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          TextField(
            controller: _loginMobileCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) {
              if (_loginMobileError != null) setState(() => _loginMobileError = null);
            },
            decoration: InputDecoration(
              labelText: 'mobile_number'.tr,
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _loginMobileError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginPassCtrl,
            obscureText: _obscure,
            onChanged: (_) {
              if (_loginPassError != null) setState(() => _loginPassError = null);
            },
            decoration: InputDecoration(
              labelText: 'password'.tr,
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _loginPassError,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.lock_reset_outlined, size: 15, color: kGreen),
              label: Text('forgot_password'.tr, style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: _showPasswordResetDialog,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _doLogin,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('login_button'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add_outlined, size: 16, color: kGreen),
            label: Text('new_customer_reg'.tr, style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w600)),
            onPressed: () => _tabController.animateTo(1),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: kGreen), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
      ),
    );
  }

  // ─── REGISTER FORM WITH FIELD ERROR HIGHLIGHTS ────────────────────────────
  Widget _registerForm() {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Progress Steps Indicator ─────────────────────────────────────
          Row(children: [
            _stepBadge(1, 'step_details'.tr, _regStep >= 0),
            Expanded(child: Divider(color: _regStep >= 1 ? kGreen : Colors.grey.shade300, thickness: 2)),
            _stepBadge(2, 'step_verify_otp'.tr, _regStep >= 1),
            Expanded(child: Divider(color: _regStep >= 2 ? kGreen : Colors.grey.shade300, thickness: 2)),
            _stepBadge(3, 'step_done'.tr, _regStep >= 2),
          ]),
          const SizedBox(height: 16),

          // ─── STEP 0: Fill Account Details ───────────────────────────────
          if (_regStep == 0) ...[
            Text('create_account'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('register_subtitle'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),

            _sectionTitle('personal_details_sec'.tr),
            TextField(
              controller: _regNameCtrl,
              enabled: _regStep == 0,
              onChanged: (_) {
                if (_regNameError != null) setState(() => _regNameError = null);
              },
              decoration: InputDecoration(
                labelText: 'full_name'.tr,
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _regNameError,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _regMobileCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              enabled: _regStep == 0,
              onChanged: (_) {
                if (_regMobileError != null || _isDuplicateMobileError) {
                  setState(() {
                    _regMobileError = null;
                    _isDuplicateMobileError = false;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: 'mobile_whatsapp'.tr,
                hintText: 'mobile_hint'.tr,
                prefixText: '+91 ',
                prefixIcon: const Icon(Icons.phone_outlined),
                errorText: _regMobileError,
              ),
            ),
            if (_isDuplicateMobileError) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: kGreen,
                  ),
                  icon: const Icon(Icons.login, size: 14),
                  label: Text('already_registered_switch'.tr,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _loginMobileCtrl.text = _regMobileCtrl.text.trim();
                    _tabController.animateTo(0);
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _regPassCtrl,
              obscureText: _obscureReg,
              enabled: _regStep == 0,
              onChanged: (_) {
                if (_regPassError != null) setState(() => _regPassError = null);
              },
              decoration: InputDecoration(
                labelText: 'password'.tr,
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _regPassError,
                suffixIcon: IconButton(
                  icon: Icon(_obscureReg ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureReg = !_obscureReg),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle('delivery_address_sec'.tr),
            TextField(
              controller: _regAddressCtrl,
              enabled: _regStep == 0,
              onChanged: (_) {
                if (_regAddressError != null) setState(() => _regAddressError = null);
              },
              decoration: InputDecoration(
                labelText: 'house_flat_address'.tr,
                prefixIcon: const Icon(Icons.home_outlined),
                errorText: _regAddressError,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _regAreaCtrl, enabled: _regStep == 0,
                  decoration: InputDecoration(labelText: 'area'.tr))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _regCityCtrl, enabled: _regStep == 0,
                  decoration: InputDecoration(labelText: 'city'.tr))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _regPincodeCtrl, keyboardType: TextInputType.number, enabled: _regStep == 0,
                decoration: InputDecoration(labelText: 'pincode'.tr, prefixIcon: const Icon(Icons.pin_drop_outlined))),
            const SizedBox(height: 8),
            const SizedBox(height: 10),
            // Map Location Picker & GPS Selection (Replaces raw Latitude & Longitude)
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.map_outlined, color: kGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'pinpoint_map_title'.tr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              _latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty
                                  ? '${'selected_location'.tr}: ${_regAreaCtrl.text.isNotEmpty ? _regAreaCtrl.text : 'auth_pin_placed'.tr}'
                                  : 'pinpoint_map_desc'.tr,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
                          icon: const Icon(Icons.pin_drop, size: 16),
                          label: Text(
                            'pick_on_map'.tr,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _regStep != 0 ? null : _openMapPicker,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.my_location, size: 15),
                          label: Text(
                            'auth_gps_btn'.tr,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kGreen,
                            side: const BorderSide(color: kGreen),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: (_loading || _regStep != 0) ? null : _getLocation,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: _sendingOtp
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_to_mobile, size: 18),
              label: Text(_sendingOtp ? 'please_wait'.tr : 'send_whatsapp_otp'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _sendingOtp ? null : _sendRegisterOtp,
            ),
          ],

          // ─── STEP 1: Enter & Verify OTP ─────────────────────────────────
          if (_regStep == 1) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGreen, Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                const Icon(Icons.mark_chat_unread_outlined, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text('auth_otp_sent_wa_title'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(tr('auth_check_wa_for', {'mobile': _regMobileCtrl.text.trim()}),
                    style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
              ]),
            ),
            const SizedBox(height: 20),

            Text('enter_otp'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('auth_enter_otp_wa_desc'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),

            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: '------',
                hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 28, letterSpacing: 10),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 2)),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(_loading ? 'please_wait'.tr : 'verify_and_create'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _loading ? null : _verifyOtp,
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('auth_didnt_receive'.tr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14, color: kGreen),
                label: Text('resend_otp'.tr, style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: _sendingOtp ? null : () {
                  setState(() => _regStep = 0);
                  _sendRegisterOtp();
                },
              ),
            ]),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                SecurityService.otpManager.clear();
                setState(() => _regStep = 0);
              },
              child: Text('auth_edit_details'.tr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ],

          // ─── STEP 2: Registering in progress ────────────────────────────
          if (_regStep == 2) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator(color: kGreen, strokeWidth: 3)),
            const SizedBox(height: 20),
            Center(child: Text('auth_otp_verified_title'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kGreen))),
            const SizedBox(height: 8),
            Center(child: Text('auth_creating_account'.tr, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          ],
        ]),
      ),
    );
  }

  Widget _stepBadge(int step, String label, bool active) {
    return Column(children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: active ? kGreen : Colors.grey.shade300,
        child: Text('$step', style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: active ? kGreen : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kGreen)),
  );
}
