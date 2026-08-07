import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

class AuthStorage {
  static const _accessTokenKey = 'auth.accessToken';
  static const _expiresAtKey = 'auth.expiresAt';
  static const _userTypeKey = 'auth.userType';
  static const _projectCodeKey = 'auth.projectCode';
  static const _projectIdKey = 'auth.projectId';
  static const _companyIdKey = 'auth.companyId';
  static const _branchIdKey = 'auth.branchId';
  static const _userIdKey = 'auth.userId';
  static const _laooUserIdKey = 'auth.laooUserId';

  Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_accessTokenKey, session.accessToken);
    await prefs.setString(
      _expiresAtKey,
      session.expiresAt.toUtc().toIso8601String(),
    );

    await _setNullableString(prefs, _userTypeKey, session.userType);
    await _setNullableString(prefs, _projectCodeKey, session.projectCode);

    await _setNullableInt(prefs, _projectIdKey, session.projectId);
    await _setNullableInt(prefs, _companyIdKey, session.companyId);
    await _setNullableInt(prefs, _branchIdKey, session.branchId);
    await _setNullableInt(prefs, _userIdKey, session.userId);
    await _setNullableInt(prefs, _laooUserIdKey, session.laooUserId);
  }

  Future<AuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(_accessTokenKey);
    final expiresAtText = prefs.getString(_expiresAtKey);

    if (token == null || token.isEmpty || expiresAtText == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null) {
      await clear();
      return null;
    }

    final session = AuthSession(
      accessToken: token,
      expiresAt: expiresAt,
      userType: prefs.getString(_userTypeKey),
      projectCode: prefs.getString(_projectCodeKey),
      projectId: prefs.getInt(_projectIdKey),
      companyId: prefs.getInt(_companyIdKey),
      branchId: prefs.getInt(_branchIdKey),
      userId: prefs.getInt(_userIdKey),
      laooUserId: prefs.getInt(_laooUserIdKey),
    );

    if (session.isExpired) {
      await clear();
      return null;
    }

    return session;
  }

  Future<String?> readAccessToken() async {
    final session = await read();
    return session?.accessToken;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in [
      _accessTokenKey,
      _expiresAtKey,
      _userTypeKey,
      _projectCodeKey,
      _projectIdKey,
      _companyIdKey,
      _branchIdKey,
      _userIdKey,
      _laooUserIdKey,
    ]) {
      await prefs.remove(key);
    }
  }

  Future<void> _setNullableString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  Future<void> _setNullableInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, value);
    }
  }
}
