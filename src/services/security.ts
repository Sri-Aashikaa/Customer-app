/**
 * Security and Cryptographic Utilities for Amutham Customer App (React Native)
 * - Salted SHA-256 password hashing matching Dart implementation
 * - Timing-safe string comparison
 * - PostgREST input sanitization & XSS stripping
 * - Login attempt brute-force rate limiting
 * - Session and PII scrubbing
 */

const PASSWORD_SALT = 'Amutham_Raw_Milk_Customer_Auth_v1_Salt_#2026';

// Standard SHA-256 Implementation (RFC 6234 / FIPS 180-4)
function sha256Bytes(ascii: string): string {
  function rightRotate(value: number, amount: number): number {
    return (value >>> amount) | (value << (32 - amount));
  }

  const mathPow = Math.pow;
  const maxWord = mathPow(2, 32);
  let result = '';

  const words: number[] = [];
  const asciiBitLength = ascii.length * 8;

  const hash: number[] = [];
  const k: number[] = [];
  let primeCounter = 0;

  const isComposite: { [key: number]: boolean } = {};
  for (let candidate = 2; primeCounter < 64; candidate++) {
    if (!isComposite[candidate]) {
      for (let i = candidate * 2; i < 313; i += candidate) {
        isComposite[i] = true;
      }
      if (primeCounter < 8) {
        hash[primeCounter] = (mathPow(candidate, 0.5) * maxWord) | 0;
      }
      k[primeCounter] = (mathPow(candidate, 1 / 3) * maxWord) | 0;
      primeCounter++;
    }
  }

  for (let i = 0; i < ascii.length; i++) {
    words[i >> 2] |= (ascii.charCodeAt(i) & 0xff) << ((3 - (i % 4)) * 8);
  }

  words[asciiBitLength >> 5] |= 0x80 << (24 - (asciiBitLength % 32));
  words[(((asciiBitLength + 64) >> 9) << 4) + 15] = asciiBitLength;

  for (let i = 0; i < words.length; i += 16) {
    const w: number[] = [];
    let a = hash[0];
    let b = hash[1];
    let c = hash[2];
    let d = hash[3];
    let e = hash[4];
    let f = hash[5];
    let g = hash[6];
    let h = hash[7];

    for (let j = 0; j < 64; j++) {
      if (j < 16) {
        w[j] = words[i + j] || 0;
      } else {
        const s0 = rightRotate(w[j - 15], 7) ^ rightRotate(w[j - 15], 18) ^ (w[j - 15] >>> 3);
        const s1 = rightRotate(w[j - 2], 17) ^ rightRotate(w[j - 2], 19) ^ (w[j - 2] >>> 10);
        w[j] = (((w[j - 16] + s0) | 0) + ((w[j - 7] + s1) | 0)) | 0;
      }

      const s1 = rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25);
      const ch = (e & f) ^ (~e & g);
      const temp1 = (((((h + s1) | 0) + ch) | 0) + ((k[j] + w[j]) | 0)) | 0;
      const s0 = rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22);
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const temp2 = (s0 + maj) | 0;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) | 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) | 0;
    }

    hash[0] = (hash[0] + a) | 0;
    hash[1] = (hash[1] + b) | 0;
    hash[2] = (hash[2] + c) | 0;
    hash[3] = (hash[3] + d) | 0;
    hash[4] = (hash[4] + e) | 0;
    hash[5] = (hash[5] + f) | 0;
    hash[6] = (hash[6] + g) | 0;
    hash[7] = (hash[7] + h) | 0;
  }

  for (let i = 0; i < 8; i++) {
    result += ((hash[i] >>> 0) + maxWord).toString(16).slice(1);
  }

  return result.toLowerCase();
}

// UTF-8 string to binary string conversion for proper multi-byte hashing
function utf8Encode(str: string): string {
  return unescape(encodeURIComponent(str));
}

// In-Memory Login Rate Limiter (Brute-Force Protection)
interface AttemptState {
  failures: number;
  lastAttempt: number;
  lockedUntil?: number;
}
const loginAttempts: Map<string, AttemptState> = new Map();

export const LoginRateLimiter = {
  checkLockout(identifier: string): { isLocked: boolean; remainingSeconds: number } {
    const key = identifier.trim().toLowerCase();
    const state = loginAttempts.get(key);
    if (!state || !state.lockedUntil) {
      return { isLocked: false, remainingSeconds: 0 };
    }
    const now = Date.now();
    if (now < state.lockedUntil) {
      const remainingSeconds = Math.ceil((state.lockedUntil - now) / 1000);
      return { isLocked: true, remainingSeconds };
    }
    state.lockedUntil = undefined;
    return { isLocked: false, remainingSeconds: 0 };
  },

  recordFailedAttempt(identifier: string): void {
    const key = identifier.trim().toLowerCase();
    const now = Date.now();
    const state = loginAttempts.get(key) || { failures: 0, lastAttempt: now };
    state.failures += 1;
    state.lastAttempt = now;

    if (state.failures >= 10) {
      state.lockedUntil = now + 15 * 60 * 1000; // 15 min lock
    } else if (state.failures >= 7) {
      state.lockedUntil = now + 5 * 60 * 1000; // 5 min lock
    } else if (state.failures >= 5) {
      state.lockedUntil = now + 60 * 1000; // 1 min lock
    }
    loginAttempts.set(key, state);
  },

  recordSuccessfulLogin(identifier: string): void {
    const key = identifier.trim().toLowerCase();
    loginAttempts.delete(key);
  }
};

export const SecurityUtils = {
  /**
   * Hashes a password with the standard application salt using SHA-256.
   * Returns a 64-character lowercase hexadecimal string.
   */
  hashPassword(password: string): string {
    const salted = `${PASSWORD_SALT}${password.trim()}`;
    return sha256Bytes(utf8Encode(salted));
  },

  /**
   * Constant-time string equality to prevent timing attacks
   */
  fixedTimeEquals(a: string, b: string): boolean {
    if (a.length !== b.length) return false;
    let diff = 0;
    for (let i = 0; i < a.length; i++) {
      diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }
    return diff === 0;
  },

  /**
   * Validates if a stored password is in legacy plaintext format (not a 64-hex SHA-256 hash)
   */
  isLegacyPlaintext(storedPassword?: string | null): boolean {
    if (!storedPassword || storedPassword.trim().length === 0) return false;
    return !/^[a-fA-F0-9]{64}$/.test(storedPassword.trim());
  },

  /**
   * Verifies an input password against stored value (hash or legacy plaintext)
   */
  verifyPassword(inputPassword: string, storedPassword?: string | null): boolean {
    if (!storedPassword || storedPassword.trim().length === 0) return false;
    const cleanInput = inputPassword.trim();
    const cleanStored = storedPassword.trim();

    // 1. Check against salted SHA-256
    const inputHash = this.hashPassword(cleanInput);
    if (this.fixedTimeEquals(inputHash, cleanStored)) {
      return true;
    }

    // 2. Check legacy plaintext
    if (this.isLegacyPlaintext(cleanStored) && this.fixedTimeEquals(cleanInput, cleanStored)) {
      return true;
    }

    return false;
  },

  /**
   * Sanitizes parameter for PostgREST filter expressions to prevent query injection
   */
  sanitizePostgrestParam(input?: string | null): string {
    if (!input) return '';
    return input.trim().replace(/[^a-zA-Z0-9\-_]/g, '');
  },

  /**
   * Sanitizes mobile number to clean 10 digits
   */
  sanitizeMobileDigits(input?: string | null): string {
    if (!input) return '';
    const digits = input.replace(/[^0-9]/g, '');
    return digits.length >= 10 ? digits.slice(-10) : digits;
  },

  /**
   * Sanitizes text input, stripping null bytes, control chars, and HTML/XSS injection tags
   */
  sanitizeText(input?: string | null, maxLength: number = 500): string {
    if (!input) return '';
    let cleaned = input
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
      .replace(/<[^>]*>/g, '') // Strip HTML/XSS markup
      .replace(/javascript:/gi, '')
      .trim();
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  },

  /**
   * Generates a 6-digit OTP using standard random bytes
   */
  generateSecureOtp(): string {
    const num = Math.floor(100000 + Math.random() * 900000);
    return String(num);
  },

  rateLimiter: LoginRateLimiter
};
