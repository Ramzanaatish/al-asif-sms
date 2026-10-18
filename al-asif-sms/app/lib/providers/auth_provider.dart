import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/backend_client.dart';

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  AppUser? _user;
  bool _checking = true;
  bool _offlineMode = false;

  AppUser? get user => _user;
  String? get role => _user?.role;
  bool get isLoggedIn => _user != null;
  bool get isChecking => _checking;

  /// True when the current session was established without internet
  /// (cached credentials). Drives the "Offline mode" banner.
  bool get offlineMode => _offlineMode;
  bool get isParent => _user?.isParent ?? false;

  AuthProvider() {
    BackendClient.onUnauthorized = () {
      _user = null;
      _offlineMode = false;
      notifyListeners();
    };
    _boot();
  }

  Future<void> _boot() async {
    await BackendClient.instance.init();
    // Password login off (default): straight in as principal, no questions.
    if (!await _repo.isPasswordLoginEnabled()) {
      final res = await _repo.autoLogin();
      final userJson = (res['user'] as Map).cast<String, dynamic>();
      _user = AppUser.fromJson(userJson);
      _offlineMode = true;
      _checking = false;
      notifyListeners();
      return;
    }
    if (BackendClient.instance.hasToken) {
      try {
        final me = await _repo.me();
        _user = AppUser.fromJson(me);
        await _repo.cacheSession(me);
        _offlineMode =
            BackendClient.instance.token == 'offline';
      } catch (_) {
        await BackendClient.instance.clearToken();
      }
    }
    _checking = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final res = await _repo.login(username, password);
    await BackendClient.instance
        .setToken(res['access_token']?.toString() ?? '');
    final userJson = (res['user'] as Map).cast<String, dynamic>();
    await BackendClient.instance.saveUserJson(userJson);
    await _repo.cacheSession(userJson);
    _user = AppUser.fromJson(userJson);
    _offlineMode = res['offline'] == true;
    notifyListeners();
  }

  Future<void> logout() async {
    await BackendClient.instance.clearToken();
    await _repo.clearSessionCache();
    _user = null;
    _offlineMode = false;
    notifyListeners();
  }

  Future<bool> isPasswordLoginEnabled() =>
      _repo.isPasswordLoginEnabled();

  /// Turn password login on/off from Settings.
  /// Turning it off logs straight back in as principal.
  Future<void> setPasswordLoginEnabled(bool enabled) async {
    await _repo.setPasswordLoginEnabled(enabled);
    if (!enabled) {
      final res = await _repo.autoLogin();
      final userJson = (res['user'] as Map).cast<String, dynamic>();
      _user = AppUser.fromJson(userJson);
      _offlineMode = true;
    } else {
      _user = null;
      _offlineMode = false;
      await BackendClient.instance.clearToken();
    }
    notifyListeners();
  }

  Future<void> changePassword(String username, String newPassword) =>
      _repo.changePassword(username, newPassword);
}
