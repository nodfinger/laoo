import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'auth_session.dart';

enum AppAuthStatus { checking, unauthenticated, authenticated }

class AppAuthController extends ChangeNotifier {
  AppAuthController({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  AppAuthStatus _status = AppAuthStatus.checking;
  AuthSession? _session;
  String? _lastError;

  AppAuthStatus get status => _status;
  AuthSession? get session => _session;
  String? get lastError => _lastError;

  bool get isChecking => _status == AppAuthStatus.checking;

  bool get isAuthenticated => _status == AppAuthStatus.authenticated;

  bool get isLaooSupport => _session?.userType == 'LAOO_SUPPORT';

  Future<void> initialize() async {
    _status = AppAuthStatus.checking;
    _lastError = null;
    notifyListeners();

    try {
      final restored = await _authService.restoreAndRefreshSession();

      if (restored == null) {
        _session = null;
        _status = AppAuthStatus.unauthenticated;
      } else {
        _session = restored;
        _status = AppAuthStatus.authenticated;
      }
    } catch (_) {
      await _authService.logout();
      _session = null;
      _status = AppAuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    String projectCode = 'LAOO',
  }) async {
    _lastError = null;

    try {
      final session = await _authService.login(
        username: username,
        password: password,
        projectCode: projectCode,
      );

      _session = session;
      _status = AppAuthStatus.authenticated;
      notifyListeners();

      return session;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();

    _session = null;
    _status = AppAuthStatus.unauthenticated;
    _lastError = null;

    notifyListeners();
  }
}

final AppAuthController appAuthController = AppAuthController();
