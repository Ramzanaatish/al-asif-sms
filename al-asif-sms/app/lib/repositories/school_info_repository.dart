import 'dart:convert';

import '../services/local_db.dart';

/// School information (the HTML's S.schoolInfo + showPrincipalSign),
/// stored in the meta table. Defaults match the HTML's seed values.
/// Used by Settings (School Info & Login popup) and by Reports (the
/// Benazir slip's address / tehsil / type / shift).
class SchoolInfo {
  final String emis;
  final String address;
  final String tehsil;
  final String type; // Govt | Private | Semi Private | Community
  final String shift; // Morning | Evening
  final bool showPrincipalSign;

  const SchoolInfo({
    this.emis = '',
    this.address = 'Basti Shaikhan, Zafar Abad, Tehsil Liaquatpur',
    this.tehsil = 'Liaquatpur',
    this.type = 'Private',
    this.shift = 'Morning',
    this.showPrincipalSign = true,
  });

  Map<String, dynamic> toJson() => {
        'emis': emis,
        'address': address,
        'tehsil': tehsil,
        'type': type,
        'shift': shift,
        'show_principal_sign': showPrincipalSign,
      };

  factory SchoolInfo.fromJson(Map<String, dynamic> j) => SchoolInfo(
        emis: j['emis']?.toString() ?? '',
        address: j['address']?.toString() ??
            'Basti Shaikhan, Zafar Abad, Tehsil Liaquatpur',
        tehsil: j['tehsil']?.toString() ?? 'Liaquatpur',
        type: j['type']?.toString() ?? 'Private',
        shift: j['shift']?.toString() ?? 'Morning',
        showPrincipalSign: j['show_principal_sign'] as bool? ?? true,
      );
}

class SchoolInfoRepository {
  static const _key = 'school_info';
  final _db = LocalDb.instance;

  Future<SchoolInfo> get() async {
    final j = await _db.getMetaJson(_key);
    return j == null ? const SchoolInfo() : SchoolInfo.fromJson(j);
  }

  Future<void> save(SchoolInfo info) async {
    await _db.setMetaJson(_key, info.toJson());
  }
}
