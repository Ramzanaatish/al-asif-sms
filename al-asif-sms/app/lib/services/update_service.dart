import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Checks GitHub Releases for a newer Al-Asif SMS build.
///
/// The app never downloads or installs anything itself. The check only
/// reports that a newer release exists and where to get it; the user
/// downloads the new APK or Windows zip and installs it over the old one.
/// The database lives outside the install folder, so installing over the
/// old version keeps every record.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _releasesUrl =
      'https://api.github.com/repos/aidiscoverywire-dotcom/al-asif-sms/releases/latest';

  /// Current version from the installed package (for example "1.1.0").
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Compare two dotted version strings ("1.1.0" vs "1.2.0").
  ///
  /// Returns a negative number when [a] is older than [b], zero when they
  /// are equal, and a positive number when [a] is newer. Non-numeric parts
  /// compare as equal; missing parts count as zero ("1.1" equals "1.1.0").
  /// Leading "v" and build metadata ("+2") are ignored.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) {
      final clean = v.trim().replaceFirst(RegExp(r'^v'), '').split('+').first;
      return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }

    final pa = parts(a);
    final pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Ask GitHub for the latest release. Returns null when offline, when
  /// GitHub cannot be reached, or when no release exists yet.
  Future<UpdateInfo?> checkForUpdate() async {
    final current = await currentVersion();
    final res = await http.get(
      Uri.parse(_releasesUrl),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?) ?? '';
    if (tag.isEmpty) return null;
    final latest = tag.replaceFirst(RegExp(r'^v'), '');
    return UpdateInfo(
      currentVersion: current,
      latestVersion: latest,
      updateAvailable: compareVersions(current, latest) < 0,
      releaseUrl: (json['html_url'] as String?) ?? '',
      releaseNotes: (json['body'] as String?) ?? '',
    );
  }
}

/// The result of one update check.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;

  /// GitHub release page, where the new APK and Windows zip are downloaded.
  final String releaseUrl;

  /// Release notes, as written on the release.
  final String releaseNotes;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.releaseUrl,
    required this.releaseNotes,
  });
}
