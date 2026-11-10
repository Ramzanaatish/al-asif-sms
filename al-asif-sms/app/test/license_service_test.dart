import 'package:alasif_sms/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the offline license-key algorithm against the key generator
/// (`Universal-License-Key-Generator-v1.1-DANIEL-ONLY.html`).
///
/// The test vectors below were produced by the generator itself in headless
/// Chrome (fixed device ids and nonces, so the keys are deterministic) and
/// verified valid there first. If the generator and this service ever drift
/// apart, these tests fail — that is the point. Dates are asserted as
/// absolute expiry dates; days-left is always computed from today, never
/// hard-coded.
void main() {
  const alasifKey = '10NE7-5YK4D-18HSV-4YT4W-BRPCQ';
  const universalKey = '00QBS-FMS3S-WND55-RE9CG-DPTJR';
  const hotelKey = '20NF0-ASP44-E6743-01A13-QZEME';
  const expiredKey = '10JY6-EYQM0-WFCVT-HHA90-5KFVZ';

  /// Device-locked Al-Asif key for device TEST-DEVICE-0001, expiry
  /// 2026-12-10 (generator v1.1, deterministic nonce).
  const lockedKeyA = 'H0NEE-PH479-WWPPN-78WAF-CRV7Z';

  const deviceA = 'TEST-DEVICE-0001';
  const deviceB = 'TEST-DEVICE-0002';

  test('generator key for Al-Asif validates (product 1, expiry 2026-12-10)',
      () {
    final r = LicenseService.validateKey(alasifKey);
    expect(r.valid, isTrue);
    expect(r.product, 1);
    expect(r.expiryDate, DateTime.utc(2026, 12, 10));
    expect(r.daysLeft, 343 - LicenseService.todayDays());
  });

  test('universal key validates for this product (product 0)', () {
    final r = LicenseService.validateKey(universalKey);
    expect(r.valid, isTrue);
    expect(r.product, 0);
    expect(r.expiryDate, DateTime.utc(2027, 1, 9));
  });

  test('key for another product is rejected', () {
    final r = LicenseService.validateKey(hotelKey);
    expect(r.valid, isFalse);
    expect(r.product, 2);
    expect(r.expiryDate, DateTime.utc(2026, 12, 10));
  });

  test('expired key is rejected', () {
    final r = LicenseService.validateKey(expiredKey);
    expect(r.valid, isFalse);
    expect(r.product, 1);
    expect(r.expiryDate, DateTime.utc(2026, 10, 31));
  });

  test('one changed character breaks the signature', () {
    // Last char Q -> A: same format, different signature bits.
    final tampered = '${alasifKey.substring(0, alasifKey.length - 1)}A';
    final r = LicenseService.validateKey(tampered);
    expect(r.valid, isFalse);
  });

  test('malformed keys are rejected', () {
    expect(LicenseService.validateKey('SHORT').valid, isFalse);
    expect(LicenseService.validateKey('').valid, isFalse);
    // 'I' is outside the Crockford alphabet.
    expect(
      LicenseService.validateKey('I0NE7-5YK4D-18HSV-4YT4W-BRPCQ').valid,
      isFalse,
    );
  });

  test('dashes and case do not matter', () {
    final r = LicenseService.validateKey('10ne75yk4d18hsv4yt4wbrpcq');
    expect(r.valid, isTrue);
    expect(r.product, 1);
    expect(r.expiryDate, DateTime.utc(2026, 12, 10));
  });

  test('device nonce matches the generator for both test devices', () {
    expect(
      LicenseService.deviceNonceFor(deviceA),
      BigInt.parse('252616758222'),
    );
    expect(
      LicenseService.deviceNonceFor(deviceB),
      BigInt.parse('677970304928'),
    );
  });

  test('device-locked key validates on its own device only', () {
    final right = LicenseService.validateKey(
      lockedKeyA,
      expectedDeviceNonce: LicenseService.deviceNonceFor(deviceA),
    );
    expect(right.valid, isTrue);
    expect(right.deviceLocked, isTrue);
    expect(right.product, 1);
    expect(right.expiryDate, DateTime.utc(2026, 12, 10));

    final wrong = LicenseService.validateKey(
      lockedKeyA,
      expectedDeviceNonce: LicenseService.deviceNonceFor(deviceB),
    );
    expect(wrong.valid, isFalse);
    expect(wrong.deviceLocked, isTrue);
  });

  test('the same device-locked key is deterministic (same device = same key)',
      () {
    // A locked key re-issued for the same device is identical — the nonce
    // is derived from the device id, not random. That is by design.
    expect(
      LicenseService.deviceNonceFor(deviceA),
      LicenseService.deviceNonceFor(deviceA),
    );
  });

  test('an unbound key still works on any device (spec v1 compat)', () {
    final r = LicenseService.validateKey(
      alasifKey,
      expectedDeviceNonce: LicenseService.deviceNonceFor(deviceA),
    );
    expect(r.valid, isTrue);
    expect(r.deviceLocked, isFalse);
  });

  test('license is enforced only in the mobile app, not desktop', () {
    // Tests run on the Linux host (desktop), where the license gate is
    // off by design: only the APK (Android/iOS) is key-based.
    expect(LicenseService.isLicenseEnforced, isFalse);
  });

  test('activate stores a valid key; an invalid key is never stored',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = LicenseService.instance;
    await service.clear();

    final bad = await service.activate('SHORT');
    expect(bad.valid, isFalse);
    await service.load();
    expect(service.isLicensed, isFalse);

    final good = await service.activate(alasifKey);
    expect(good.valid, isTrue);
    await service.load();
    expect(service.isLicensed, isTrue);
    expect(service.daysLeft, 343 - LicenseService.todayDays());
    expect(service.status.key, alasifKey);

    await service.clear();
    await service.load();
    expect(service.isLicensed, isFalse);
  });
}
