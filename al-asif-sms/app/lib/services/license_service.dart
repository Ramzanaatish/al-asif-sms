import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline license-key validation (Universal License Key spec v1.1).
///
/// MUST stay byte-identical in logic with the key generator
/// (`Universal-License-Key-Generator-v1.1-DANIEL-ONLY.html`) — same alphabet,
/// same 125-bit payload layout, same HMAC input bytes, same secret.
///
/// Key: 25 chars Crockford base32 (0123456789ABCDEFGHJKMNPQRSTVWXYZ),
/// shown as 5 groups of 5 joined by '-'. The 125-bit payload is:
///   productField 5 bits | expiry 14 bits (days since 2026-01-01 UTC)
///   | nonce 40 bits | signature 66 bits (top 66 bits of
///   HMAC-SHA256(secret, productField||expiry||nonce as 8 bytes)).
///
/// productField: bit 4 (16) is the device-locked flag; bits 0-3 are the
/// product (0 Universal, 1 Al-Asif, 2 Hotel, 3 Kanta, 4 Grower).
/// A locked key's nonce is the first 40 bits of
/// HMAC-SHA256(secret, 'device:' + deviceId) — so it only validates on
/// that one device. An unbound key's nonce is random (every key unique).
/// Unbound keys from spec v1 (flag clear) still validate unchanged.
///
/// The secret is shared between the generator and this app — that is the
/// lock-and-key mechanism: the generator signs, the app re-computes the
/// signature and accepts only a match. Anyone who extracts the secret from
/// the app could forge keys; a server-side check would be needed to close
/// that gap (same limitation as the hotel license system).
class LicenseService extends ChangeNotifier {
  LicenseService._();

  static final LicenseService instance = LicenseService._();

  /// Shared secret with the generator. Daniel-only: never show in chat,
  /// never ship the generator file to customers.
  static const String _secret = 'a21c1ab7a92501de5767d33c139e15d3';

  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Epoch for the 14-bit expiry field (UTC).
  static final DateTime epoch = DateTime.utc(2026, 1, 1);

  /// This app's product code (see the generator's product list).
  static const int appProduct = 1;

  static const Map<int, String> productNames = {
    0: 'Universal (All Products)',
    1: 'Al-Asif SMS',
    2: 'Hotel POS',
    3: 'Kanta',
    4: 'Grower App',
  };

  /// Renewal contact shown on the license screen (owner's number).
  static const String supportPhone = '0306-6111268';

  /// The license is enforced ONLY in the mobile app (APK/iOS). The
  /// Windows/desktop software runs without a key (owner's decision).
  static bool get isLicenseEnforced => Platform.isAndroid || Platform.isIOS;

  /// Warn when this many days (or fewer) are left on the license.
  static const int warningDays = 3;

  static const String _prefsKey = 'license_key';

  static const String _deviceIdPrefsKey = 'device_id';

  LicenseStatus _status = const LicenseStatus(licensed: false);

  /// Last loaded status (call [load] first, e.g. at boot).
  LicenseStatus get status => _status;

  bool get isLicensed => _status.licensed;

  int? get daysLeft => _status.daysLeft;

  bool get needsWarning =>
      _status.licensed &&
      _status.daysLeft != null &&
      _status.daysLeft! <= warningDays;

  /// Stable id of this device, created once and kept in SharedPreferences.
  /// Survives app updates; a fresh install (uninstall first) gets a new
  /// id, so a device-locked key then needs re-issue from the owner.
  /// Shown on the license screen so the customer can send it to the owner.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdPrefsKey);
    if (id == null || id.isEmpty) {
      id = _newDeviceId();
      await prefs.setString(_deviceIdPrefsKey, id);
    }
    return id;
  }

  static String _newDeviceId() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final hex = rnd.toRadixString(16).padLeft(12, '0');
    final parts = <String>[];
    for (var i = 0; i < hex.length; i += 4) {
      parts.add(hex.substring(i, i + 4 > hex.length ? hex.length : i + 4));
    }
    return parts.join('-').toUpperCase();
  }

  static int daysSinceEpoch(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    return d.difference(epoch).inDays;
  }

  static DateTime dateFromDays(int days) =>
      epoch.add(Duration(days: days));

  static int todayDays() {
    final now = DateTime.now().toUtc();
    return daysSinceEpoch(now);
  }

  /// First 40 bits of HMAC-SHA256(secret, 'device:' + deviceId).
  /// A device-locked key's nonce is exactly this value.
  static BigInt deviceNonceFor(String deviceId) {
    final digest = Hmac(sha256, utf8.encode(_secret))
        .convert(utf8.encode('device:$deviceId'))
        .bytes;
    var v = BigInt.zero;
    for (var i = 0; i < 5; i++) {
      v = (v << 8) | BigInt.from(digest[i]);
    }
    return v;
  }

  static BigInt _hmacTop66(int productField, int expiryDays, BigInt nonce) {
    final header = Uint8List(8);
    header[0] = productField;
    header[1] = (expiryDays >> 8) & 0xff;
    header[2] = expiryDays & 0xff;
    var n = nonce;
    for (var i = 7; i >= 3; i--) {
      header[i] = (n & BigInt.from(0xff)).toInt();
      n >>= 8;
    }
    final digest = Hmac(sha256, utf8.encode(_secret)).convert(header).bytes;
    var v = BigInt.zero;
    for (final b in digest) {
      v = (v << 8) | BigInt.from(b);
    }
    return v >> 190;
  }

  /// Pure offline validation of a key string. Never touches storage.
  ///
  /// Pass [expectedDeviceNonce] (from [deviceNonceFor] of this device's
  /// id) to enforce device binding on locked keys; without it, a locked
  /// key's signature still validates but its binding is not checked.
  static LicenseValidation validateKey(
    String rawKey, {
    BigInt? expectedDeviceNonce,
  }) {
    final clean =
        rawKey.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (clean.length != 25) {
      return const LicenseValidation(
        valid: false,
        reason: 'Key ka format ghalat hai — 25 harf honay chahiye.',
      );
    }
    var payload = BigInt.zero;
    for (var i = 0; i < 25; i++) {
      final idx = alphabet.indexOf(clean[i]);
      if (idx < 0) {
        return const LicenseValidation(
          valid: false,
          reason: 'Key mein ghalat harf hai.',
        );
      }
      payload = (payload << 5) | BigInt.from(idx);
    }
    final productField = ((payload >> 120) & BigInt.from(31)).toInt();
    final deviceLocked = (productField & 16) != 0;
    final product = productField & 15;
    final expiryDays = ((payload >> 106) & BigInt.from(16383)).toInt();
    final nonce =
        (payload >> 66) & ((BigInt.one << 40) - BigInt.one);
    final signature = payload & ((BigInt.one << 66) - BigInt.one);
    if (_hmacTop66(productField, expiryDays, nonce) != signature) {
      return const LicenseValidation(
        valid: false,
        reason: 'Key asli nahi hai — signature match nahi hui.',
      );
    }
    final expiryDate = dateFromDays(expiryDays);
    if (product != 0 && product != appProduct) {
      return LicenseValidation(
        valid: false,
        reason: 'Ye key is product ke liye nahi hai.',
        product: product,
        expiryDate: expiryDate,
        deviceLocked: deviceLocked,
      );
    }
    final today = todayDays();
    if (expiryDays < today) {
      return LicenseValidation(
        valid: false,
        reason: 'Key ki expiry guzar gayi hai.',
        product: product,
        expiryDate: expiryDate,
        deviceLocked: deviceLocked,
      );
    }
    if (deviceLocked &&
        expectedDeviceNonce != null &&
        nonce != expectedDeviceNonce) {
      return LicenseValidation(
        valid: false,
        reason: 'Ye key is device ke liye nahi hai.',
        product: product,
        expiryDate: expiryDate,
        deviceLocked: true,
      );
    }
    return LicenseValidation(
      valid: true,
      product: product,
      expiryDate: expiryDate,
      daysLeft: expiryDays - today,
      deviceLocked: deviceLocked,
    );
  }

  /// Loads the stored key and validates it. Call once at boot.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final deviceNonce = deviceNonceFor(await getDeviceId());
    _status = _statusFor(stored, deviceNonce);
    notifyListeners();
  }

  /// Validates [rawKey]; if valid, stores it and returns the validation.
  /// An invalid key is never stored.
  Future<LicenseValidation> activate(String rawKey) async {
    final deviceNonce = deviceNonceFor(await getDeviceId());
    final result = validateKey(
      rawKey,
      expectedDeviceNonce: deviceNonce,
    );
    if (!result.valid) return result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _normalise(rawKey));
    _status = _statusFor(_normalise(rawKey), deviceNonce);
    notifyListeners();
    return result;
  }

  /// Removes the stored key (used only for testing / re-issue).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _status = const LicenseStatus(licensed: false);
    notifyListeners();
  }

  static String _normalise(String rawKey) {
    final clean =
        rawKey.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final groups = <String>[];
    for (var i = 0; i < clean.length; i += 5) {
      groups.add(clean.substring(
          i, i + 5 > clean.length ? clean.length : i + 5));
    }
    return groups.join('-');
  }

  LicenseStatus _statusFor(String? stored, BigInt deviceNonce) {
    if (stored == null || stored.isEmpty) {
      return const LicenseStatus(licensed: false);
    }
    final result = validateKey(
      stored,
      expectedDeviceNonce: deviceNonce,
    );
    if (!result.valid) {
      return LicenseStatus(
        licensed: false,
        key: _normalise(stored),
        product: result.product,
        expiryDate: result.expiryDate,
        message: result.reason,
        deviceLocked: result.deviceLocked,
      );
    }
    return LicenseStatus(
      licensed: true,
      key: _normalise(stored),
      product: result.product,
      expiryDate: result.expiryDate,
      daysLeft: result.daysLeft,
      deviceLocked: result.deviceLocked,
    );
  }
}

/// Result of a pure key validation (no storage involved).
class LicenseValidation {
  const LicenseValidation({
    required this.valid,
    this.product,
    this.expiryDate,
    this.reason,
    this.daysLeft,
    this.deviceLocked = false,
  });

  final bool valid;
  final int? product;
  final DateTime? expiryDate;
  final String? reason;
  final int? daysLeft;

  /// True when the key is device-locked (only valid on one device).
  final bool deviceLocked;
}

/// Stored-license state surfaced to the UI.
class LicenseStatus {
  const LicenseStatus({
    required this.licensed,
    this.key,
    this.product,
    this.expiryDate,
    this.daysLeft,
    this.message,
    this.deviceLocked = false,
  });

  final bool licensed;
  final String? key;
  final int? product;
  final DateTime? expiryDate;
  final int? daysLeft;
  final String? message;

  /// True when the stored key is device-locked.
  final bool deviceLocked;

  /// Key with the middle groups masked, e.g. AB12C-•••-•••-•••-XYZ99.
  String get maskedKey {
    final k = key;
    if (k == null || k.isEmpty) return '-';
    final parts = k.split('-');
    if (parts.length != 5) return k;
    return '${parts.first}-•••••-•••••-•••••-${parts.last}';
  }
}
