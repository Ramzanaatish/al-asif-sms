import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../services/backend_client.dart';
import '../services/local_db.dart';

/// Auth repository with offline login support.
///
/// Online login is unchanged (POST /api/auth/login, server-verified). On a
/// successful online login the credentials' hash + user profile are cached in
/// SQLite; when the device is offline, login falls back to verifying against
/// the cached hash. Online auth is NOT weakened: a 401 still fails, and a
/// wrong password offline still fails.
class AuthRepository {
  final _c = BackendClient.instance;
  final _db = LocalDb.instance;

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await _c.post('/api/auth/login',
          body: {'username': username, 'password': password}, isLogin: true);
      final user =
          (res['user'] as Map).cast<String, dynamic>();
      await _cacheCredentials(username, password, user);
      return (res as Map).cast<String, dynamic>();
    } on NetworkException {
      return _offlineLogin(username, password);
    }
  }

  Future<Map<String, dynamic>> _offlineLogin(
      String username, String password) async {
    final raw = await _db.getMeta('offline_cred:$username');
    if (raw == null) {
      throw Exception(
          'No internet connection and no saved login for "$username". '
          'Connect to the internet once to enable offline login.');
    }
    final saved = jsonDecode(raw) as Map<String, dynamic>;
    final hash = _hash(username, password);
    if (saved['hash'] != hash) {
      throw Exception('Incorrect password.');
    }
    final user = (saved['user'] as Map).cast<String, dynamic>();
    return {
      'access_token': 'offline',
      'token_type': 'bearer',
      'user': user,
      'offline': true,
    };
  }

  /// Profile for boot. Offline: returns the cached profile.
  Future<Map<String, dynamic>> me() async {
    try {
      final res = await _c.get('/api/auth/me');
      return (res as Map).cast<String, dynamic>();
    } on NetworkException {
      final raw = await _db.getMeta('cached_user');
      if (raw == null) rethrow;
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    }
  }

  Future<void> _cacheCredentials(String username, String password,
      Map<String, dynamic> user) async {
    await _db.setMeta(
        'offline_cred:$username',
        jsonEncode({
          'hash': _hash(username, password),
          'user': user,
        }));
  }

  /// Cache the signed-in profile + role context for offline screens.
  Future<void> cacheSession(Map<String, dynamic> user) async {
    await _db.setMeta('cached_user', jsonEncode(user));
    await _db.setMeta('cached_role', user['role']?.toString() ?? '');
    await _db.setMeta(
        'cached_user_id', user['id']?.toString() ?? '');
    if (user['parent_user_id'] != null) {
      await _db.setMeta(
          'cached_parent_user_id', user['parent_user_id'].toString());
    }
    if (user['linked_student_id'] != null) {
      await _db.setMeta(
          'linked_student_id', user['linked_student_id'].toString());
    }
  }

  Future<void> clearSessionCache() async {
    final d = await _db.db;
    await d.delete('meta',
        where: "key IN ('cached_user','cached_role','cached_user_id','cached_parent_user_id','linked_student_id')");
  }

  String _hash(String username, String password) =>
      sha256.convert(utf8.encode('$username:$password')).toString();
}
