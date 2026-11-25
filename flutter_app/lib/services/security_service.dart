import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Comprehensive Security Service for Amutham Raw Milk Application
/// Implements OWASP Mobile Top 10 defenses:
/// - Cryptographic password hashing (Salted SHA-256)
/// - Safe legacy plaintext password migration
/// - Cryptographically secure OTP generation (Random.secure)
/// - OTP brute-force protection, replay protection, and 5-minute TTL
/// - Login attempt rate limiting and lockout protection
/// - PostgREST query injection prevention and input sanitization (XSS safe)
/// - PII & credential scrubbing for sessions
class SecurityService {
  /// Salt prefix for password hashing
  static const String _kPasswordSalt = 'Amutham_Raw_Milk_Customer_Auth_v1_Salt_#2026';

  /// Hashes a plaintext password using Salted SHA-256.
  /// Returns a 64-character lowercase hexadecimal hash.
  static String hashPassword(String password) {
    final cleanPass = password.trim();
    final saltedBytes = utf8.encode('$_kPasswordSalt$cleanPass');
    final digest = sha256.convert(saltedBytes);
    return digest.toString();
  }

  /// Timing-safe constant-time string comparison to prevent side-channel timing attacks
  static bool fixedTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Verifies an input password against stored database value.
  /// Seamlessly supports:
  /// 1. Salted SHA-256 hashed password (64-char hex)
  /// 2. Legacy plaintext password (for backward compatibility during migration)
  static bool verifyPassword(String inputPassword, String? storedPassword) {
    if (storedPassword == null || storedPassword.trim().isEmpty) {
      return false;
    }
    final cleanInput = inputPassword.trim();
    final cleanStored = storedPassword.trim();

    // 1. Check against salted SHA-256 hash
    final inputHash = hashPassword(cleanInput);
    if (fixedTimeEquals(inputHash, cleanStored)) {
      return true;
    }

    // 2. Fallback check for legacy plaintext stored password
    if (isLegacyPlaintext(cleanStored) && fixedTimeEquals(cleanInput, cleanStored)) {
      return true;
    }

    return false;
  }

  /// Determines if a stored password is legacy plaintext (not a 64-character hex hash)
  static bool isLegacyPlaintext(String? storedPassword) {
    if (storedPassword == null || storedPassword.trim().isEmpty) return false;
    final regex = RegExp(r'^[a-fA-F0-9]{64}$');
    return !regex.hasMatch(storedPassword.trim());
  }

  /// Generates a cryptographically strong 6-digit OTP using Random.secure()
  static String generateSecureOtp() {
    final rng = Random.secure();
    final code = (100000 + rng.nextInt(900000)).toString();
    return code;
  }

  /// In-memory OTP Session Manager with Rate Limiting and Expiration
  static final OtpSessionManager otpManager = OtpSessionManager();

  /// In-memory Login Rate Limiter for Brute-Force Defense
  static final LoginRateLimiter loginRateLimiter = LoginRateLimiter();

  /// Sanitizes an input parameter for PostgREST filter expressions.
  /// Strips commas, parentheses, quotes, spaces, and operator characters to prevent injection.
  static String sanitizePostgrestParam(String? input) {
    if (input == null) return '';
    return input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
  }

  /// Checks whether a string is a valid RFC-4122 UUID before filtering UUID columns
  static bool isUuid(String? input) {
    if (input == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(input.trim());
  }

  /// Sanitizes mobile numbers down to clean digits (returns last 10 digits for Indian standard)
  static String sanitizeMobileDigits(String? input) {
    if (input == null) return '';
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Sanitizes general text input, removing null bytes, control characters, and HTML/XSS markup
  static String sanitizeText(String? input, {int maxLength = 500}) {
    if (input == null) return '';
    var cleaned = input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '') // Strip HTML tags to prevent stored XSS
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .trim();
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Removes sensitive security fields (e.g. password, tokens) from a customer map
  static Map<String, dynamic> sanitizeCustomerData(Map<String, dynamic> customer) {
    final copy = Map<String, dynamic>.from(customer);
    copy.remove('password');
    copy.remove('raw_password');
    copy.remove('token');
    copy.remove('access_token');
    return copy;
  }
}

/// In-memory Login Rate Limiter (Brute-Force Protection)
class LoginRateLimiter {
  static final Map<String, _LoginAttemptState> _attempts = {};

  static const int maxFreeAttempts = 5;

  RateLimitResult checkLockout(String identifier) {
    final cleanId = SecurityService.sanitizePostgrestParam(identifier).toLowerCase();
    if (cleanId.isEmpty) return const RateLimitResult(isLocked: false, remainingSeconds: 0);

    final state = _attempts[cleanId];
    if (state == null) return const RateLimitResult(isLocked: false, remainingSeconds: 0);

    if (state.lockedUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(state.lockedUntil!)) {
        final remaining = state.lockedUntil!.difference(now).inSeconds;
        return RateLimitResult(isLocked: true, remainingSeconds: remaining);
      } else {
        state.lockedUntil = null;
      }
    }
    return const RateLimitResult(isLocked: false, remainingSeconds: 0);
  }

  void recordFailedAttempt(String identifier) {
    final cleanId = SecurityService.sanitizePostgrestParam(identifier).toLowerCase();
    if (cleanId.isEmpty) return;

    final now = DateTime.now();
    final state = _attempts.putIfAbsent(cleanId, () => _LoginAttemptState());
    state.failureCount++;
    state.lastAttempt = now;

    if (state.failureCount >= 10) {
      state.lockedUntil = now.add(const Duration(minutes: 15));
    } else if (state.failureCount >= 7) {
      state.lockedUntil = now.add(const Duration(minutes: 5));
    } else if (state.failureCount >= maxFreeAttempts) {
      state.lockedUntil = now.add(const Duration(minutes: 1));
    }
  }

  void recordSuccessfulLogin(String identifier) {
    final cleanId = SecurityService.sanitizePostgrestParam(identifier).toLowerCase();
    _attempts.remove(cleanId);
  }
}

class _LoginAttemptState {
  int failureCount = 0;
  DateTime? lastAttempt;
  DateTime? lockedUntil;
}

class RateLimitResult {
  final bool isLocked;
  final int remainingSeconds;

  const RateLimitResult({required this.isLocked, required this.remainingSeconds});
}

/// In-memory OTP Challenge & Verification State
class OtpSessionManager {
  String? _targetMobile;
  String? _activeOtpHash;
  DateTime? _expiresAt;
  int _failedAttempts = 0;

  static const int maxAttempts = 5;
  static const Duration validityDuration = Duration(minutes: 5);

  /// Issues a new OTP challenge tied to a specific mobile number
  void issueOtp(String mobile, String plainOtp) {
    final cleanMobile = SecurityService.sanitizeMobileDigits(mobile);
    _targetMobile = cleanMobile;
    _activeOtpHash = SecurityService.hashPassword(plainOtp);
    _expiresAt = DateTime.now().add(validityDuration);
    _failedAttempts = 0;
  }

  /// Validates an entered OTP against the active challenge
  OtpVerificationResult verifyOtp(String mobile, String enteredOtp) {
    final cleanMobile = SecurityService.sanitizeMobileDigits(mobile);

    if (_activeOtpHash == null || _targetMobile == null || _expiresAt == null) {
      return OtpVerificationResult(
        isValid: false,
        message: 'No active OTP request found. Please request a new OTP.',
      );
    }

    if (DateTime.now().isAfter(_expiresAt!)) {
      clear();
      return OtpVerificationResult(
        isValid: false,
        message: 'OTP has expired (valid for 5 minutes). Please request a new OTP.',
      );
    }

    if (_failedAttempts >= maxAttempts) {
      clear();
      return OtpVerificationResult(
        isValid: false,
        message: 'Too many incorrect attempts. For security, please request a new OTP.',
      );
    }

    if (_targetMobile != cleanMobile) {
      return OtpVerificationResult(
        isValid: false,
        message: 'Mobile number mismatch. Please enter the OTP for the requested number.',
      );
    }

    final enteredHash = SecurityService.hashPassword(enteredOtp.trim());
    if (SecurityService.fixedTimeEquals(enteredHash, _activeOtpHash!)) {
      // Successful verification: consume challenge immediately (single-use / anti-replay)
      clear();
      return OtpVerificationResult(isValid: true, message: 'OTP verified successfully.');
    } else {
      _failedAttempts++;
      final remaining = maxAttempts - _failedAttempts;
      if (remaining <= 0) {
        clear();
        return OtpVerificationResult(
          isValid: false,
          message: 'Incorrect OTP. Maximum attempts exceeded. Please request a new OTP.',
        );
      }
      return OtpVerificationResult(
        isValid: false,
        message: 'Incorrect OTP. $remaining attempts remaining.',
      );
    }
  }

  /// Clears active OTP session
  void clear() {
    _targetMobile = null;
    _activeOtpHash = null;
    _expiresAt = null;
    _failedAttempts = 0;
  }
}

class OtpVerificationResult {
  final bool isValid;
  final String message;

  const OtpVerificationResult({required this.isValid, required this.message});
}
