import 'package:alasif_sms/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('older, equal and newer versions compare correctly', () {
      expect(UpdateService.compareVersions('1.0.0', '1.1.0'), lessThan(0));
      expect(UpdateService.compareVersions('1.1.0', '1.1.0'), 0);
      expect(UpdateService.compareVersions('1.2.0', '1.1.0'), greaterThan(0));
    });

    test('missing parts count as zero', () {
      expect(UpdateService.compareVersions('1.1', '1.1.0'), 0);
      expect(UpdateService.compareVersions('1.1.0', '1.1'), 0);
    });

    test('leading v and build metadata are ignored', () {
      expect(UpdateService.compareVersions('v1.1.0', '1.1.0'), 0);
      expect(UpdateService.compareVersions('1.1.0+2', '1.1.0'), 0);
      expect(UpdateService.compareVersions('1.1.0', 'v1.1.0+9'), 0);
    });

    test('numeric comparison is not lexicographic', () {
      expect(UpdateService.compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(UpdateService.compareVersions('1.9.0', '1.10.0'), lessThan(0));
    });
  });
}
