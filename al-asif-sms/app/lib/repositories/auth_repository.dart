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
      // No cached login yet: fall back to built-in seed users so the app
      // works out of the box with no server configured.
      final seed = _seedUsers[username];
      if (seed != null && _hash(username, password) == seed['hash']) {
        final user = {
          'id': seed['id'],
          'username': username,
          'full_name': seed['full_name'],
          'role': seed['role'],
        };
        await _cacheCredentials(username, password, user);
        await cacheSession(user);
        return {
          'access_token': 'offline',
          'token_type': 'bearer',
          'user': user,
          'offline': true,
        };
      }
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

  /// Built-in users. Only principal + teacher exist; no parents/admin/accounts.
  /// Password for both is "alasif123" (changeable in Settings).
  /// Hashes are SHA-256("username:alasif123").
  static const _seedUsers = {
    'principal': {
      'id': 1,
      'full_name': 'Mrs. Hajra Iqbal',
      'role': 'principal',
      'hash':
          '903450da05a8af527fa7d3c1c718fe0073f887080d1d4deb509f912baa8f9c3d',
    },
    'teacher': {
      'id': 3,
      'full_name': 'Teacher',
      'role': 'teacher',
      'hash':
          'd8f569441d80799df556418fae0e84d77dd60fa29df4f41f3bcc0957806a9ca3',
    },
  };

  /// Password-login gate. Off by default: first launch goes straight in.
  Future<bool> isPasswordLoginEnabled() async {
    final v = await _db.getMeta('password_login_enabled');
    return v == '1';
  }

  Future<void> setPasswordLoginEnabled(bool enabled) async {
    await _db.setMeta('password_login_enabled', enabled ? '1' : '0');
  }

  /// Change a seed user's password (stored as new offline hash).
  Future<void> changePassword(String username, String newPassword) async {
    final user = _seedUsers[username];
    if (user == null) throw Exception('Unknown user.');
    await _db.setMeta(
        'offline_cred:$username',
        jsonEncode({
          'hash': _hash(username, newPassword),
          'user': {
            'id': user['id'],
            'username': username,
            'full_name': user['full_name'],
            'role': user['role'],
          },
        }));
  }

  /// Direct entry when password login is off: principal, no questions asked.
  Future<Map<String, dynamic>> autoLogin() async {
    const username = 'principal';
    final user = {
      'id': 1,
      'username': username,
      'full_name': 'Mrs. Hajra Iqbal',
      'role': 'principal',
    };
    await cacheSession(user);
    return {
      'access_token': 'offline',
      'token_type': 'bearer',
      'user': user,
      'offline': true,
    };
  }
}
