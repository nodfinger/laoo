import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';
import 'secure_token_store.dart';

class AuthStorage {
  AuthStorage({SecureTokenStore? secureTokenStore})
    : _secureTokenStore = secureTokenStore ?? PlatformSecureTokenStore();

  final SecureTokenStore _secureTokenStore;
  static const _accessTokenKey = 'auth.accessToken';
  static const _expiresAtKey = 'auth.expiresAt';
  static const _userTypeKey = 'auth.userType';
  static const _usernameKey = 'auth.username';
  static const _displayNameKey = 'auth.displayName';
  static const _projectCodeKey = 'auth.projectCode';
  static const _projectIdKey = 'auth.projectId';
  static const _partnerIdKey = 'auth.partnerId';
  static const _companyIdKey = 'auth.companyId';
  static const _branchIdKey = 'auth.branchId';
  static const _userIdKey = 'auth.userId';
  static const _laooUserIdKey = 'auth.laooUserId';
  static const _rememberLoginKey = 'auth.rememberLogin';
  static const _rememberedUsernameKey = 'auth.rememberedUsername';

  Future<void> save(AuthSession session, {bool? rememberLogin}) async {
    final prefs = await SharedPreferences.getInstance();

    final shouldRemember =
        rememberLogin ?? prefs.getBool(_rememberLoginKey) ?? true;
    await prefs.setBool(_rememberLoginKey, shouldRemember);

    await _secureTokenStore.write(session.accessToken);
    await prefs.remove(_accessTokenKey);
    await prefs.setString(
      _expiresAtKey,
      session.expiresAt.toUtc().toIso8601String(),
    );

    await _setNullableString(prefs, _userTypeKey, session.userType);
    await _setNullableString(prefs, _usernameKey, session.username);
    await _setNullableString(prefs, _displayNameKey, session.displayName);
    await _setNullableString(prefs, _projectCodeKey, session.projectCode);

    await _setNullableInt(prefs, _projectIdKey, session.projectId);
    await _setNullableInt(prefs, _partnerIdKey, session.partnerId);
    await _setNullableInt(prefs, _companyIdKey, session.companyId);
    await _setNullableInt(prefs, _branchIdKey, session.branchId);
    await _setNullableInt(prefs, _userIdKey, session.userId);
    await _setNullableInt(prefs, _laooUserIdKey, session.laooUserId);
  }

  Future<AuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_rememberLoginKey) == false) {
      await _clearSessionKeys(prefs);
      return null;
    }

    final token = await _readAndMigrateToken(prefs);
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
      username: prefs.getString(_usernameKey),
      displayName: prefs.getString(_displayNameKey),
      projectCode: prefs.getString(_projectCodeKey),
      projectId: prefs.getInt(_projectIdKey),
      partnerId: prefs.getInt(_partnerIdKey),
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
    final prefs = await SharedPreferences.getInstance();
    final token = await _readAndMigrateToken(prefs);
    final expiresAtText = prefs.getString(_expiresAtKey);

    if (token == null || token.isEmpty || expiresAtText == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      await _clearSessionKeys(prefs);
      return null;
    }

    return token;
  }

  Future<void> saveRememberedUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedUsernameKey, username.trim());
  }

  Future<String?> readRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedUsernameKey);
  }

  Future<void> clearRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedUsernameKey);
  }

  Future<void> clear({bool preserveRememberedSession = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final preserveRememberedCredentials =
        preserveRememberedSession && prefs.getBool(_rememberLoginKey) == true;
    await _clearSessionKeys(prefs);

    if (preserveRememberedCredentials) {
      return;
    }

    await prefs.remove(_rememberLoginKey);
    await prefs.remove(_rememberedUsernameKey);
  }

  Future<void> _clearSessionKeys(SharedPreferences prefs) async {
    await _secureTokenStore.delete();
    for (final key in [
      _accessTokenKey,
      _expiresAtKey,
      _userTypeKey,
      _usernameKey,
      _displayNameKey,
      _projectCodeKey,
      _projectIdKey,
      _partnerIdKey,
      _companyIdKey,
      _branchIdKey,
      _userIdKey,
      _laooUserIdKey,
    ]) {
      await prefs.remove(key);
    }
  }

  Future<String?> _readAndMigrateToken(SharedPreferences prefs) async {
    final secureToken = await _secureTokenStore.read();
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    final legacyToken = prefs.getString(_accessTokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return null;

    await _secureTokenStore.write(legacyToken);
    await prefs.remove(_accessTokenKey);
    return legacyToken;
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
