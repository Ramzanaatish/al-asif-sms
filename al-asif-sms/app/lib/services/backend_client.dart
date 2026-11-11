import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Thrown when the device cannot reach the server (offline, timeout, DNS...).
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown for non-2xx HTTP responses (other than 401, which auto-logs-out).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Singleton HTTP client for the FastAPI backend.
///
/// Endpoint paths come straight from API_CONTRACT.md. A 401 response clears
/// the stored JWT and fires [onUnauthorized] so the UI can drop to login.
class BackendClient {
  BackendClient._internal();
  static final BackendClient instance = BackendClient._internal();

  /// Set by AuthProvider; invoked on 401.
  static VoidCallback? onUnauthorized;

  /// Per-request timeout for the LAN sync server. A local PC server
  /// answers in well under a second; the old 25s value let one stalled
  /// request hold the whole sync (and the "Syncing..." banner) for minutes
  /// when the server was slow or black-holing. 5s fails fast and the sync
  /// retry picks the run up again.
  static const Duration syncTimeout = Duration(seconds: 5);

  String? _token;
  SharedPreferences? _prefs;

  /// True once the user has saved a server address in Settings. The
  /// compile-time default (http://10.0.2.2:8000, the Android emulator
  /// address) is NOT a configured server: on Windows/desktop it is
  /// unreachable, so auto-sync and login must never wait on it.
  bool _hasServerConfigured = false;
  bool get hasServerConfigured => _hasServerConfigured;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _token = _prefs!.getString('jwt_token');
    final savedUrl = _prefs!.getString('api_base_url');
    _hasServerConfigured = savedUrl != null && savedUrl.isNotEmpty;
    if (_hasServerConfigured) {
      AppConfig.apiBaseUrl = savedUrl!;
    }
  }

  /// The server address currently in use (from Settings / login, or the
  /// built-in default when none was saved).
  String get baseUrl => AppConfig.apiBaseUrl;

  /// Persist a new server address (e.g. http://192.168.1.50:8000).
  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    if (u.isEmpty) return;
    AppConfig.apiBaseUrl = u;
    _hasServerConfigured = true;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('api_base_url', u);
  }

  bool get hasToken => _token != null;

  /// Current token (exposed so AuthProvider can detect offline sessions).
  String? get token => _token;

  Future<void> setToken(String token) async {
    _token = token;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('jwt_token', token);
  }

  Future<void> saveUserJson(Map<String, dynamic> json) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('user_json', jsonEncode(json));
  }

  Future<void> clearToken() async {
    _token = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('jwt_token');
    await _prefs!.remove('user_json');
  }

  Map<String, String> _headers() {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token != 'offline') {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.isNotEmpty) q[k] = v;
    });
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> _send(Future<http.Response> Function() call,
      {bool isLogin = false}) async {
    // An offline-login session has no real JWT. Never send the fake token:
    // the server would answer 401 and force-logout the user mid-sync.
    if (!isLogin && _token == 'offline') {
      throw NetworkException(
          'Offline session. Log in again while online to sync.');
    }
    late http.Response res;
    try {
      res = await call().timeout(syncTimeout);
    } on TimeoutException {
      throw NetworkException('Request timed out. Check your connection.');
    } on SocketException {
      throw NetworkException('No network connection to the server.');
    } on http.ClientException {
      throw NetworkException('Could not reach the server.');
    }
    if (res.statusCode == 401 && isLogin) {
      var m = 'Invalid username or password';
      try {
        final b = jsonDecode(res.body);
        if (b is Map && b['detail'] != null) m = b['detail'].toString();
      } catch (_) {}
      throw ApiException(401, m);
    }
    if (res.statusCode == 401) {
      await clearToken();
      onUnauthorized?.call();
      throw ApiException(401, 'Session expired. Please log in again.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(res.body);
    }
    var msg = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        msg = body['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, {Object? body, bool isLogin = false}) =>
      _send(
          () => http.post(
                _uri(path),
                headers: _headers(),
                body: body == null ? null : jsonEncode(body),
              ),
          isLogin: isLogin);

  Future<dynamic> put(String path, {Object? body}) => _send(() => http.put(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ));

  Future<dynamic> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers()));
}
