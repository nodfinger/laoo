import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/login_models.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.expiresAt,
  });

  final String accessToken;
  final DateTime? expiresAt;
  final LoginUser user;
}

class AuthSessionService {
  static const String _tokenKey = 'auth_access_token';
  static const String _expiresAtKey = 'auth_expires_at';
  static const String _userKey = 'auth_user';

  Future<void> save(LoginResult result) async {
    final token = result.accessToken;
    final user = result.user;

    if (token == null || token.isEmpty || user == null) {
      throw StateError('Login result ไม่มี Token หรือ User');
    }

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_tokenKey, token);
    await preferences.setString(
      _expiresAtKey,
      result.expiresAt?.toIso8601String() ?? '',
    );
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<AuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();

    final token = preferences.getString(_tokenKey);
    final userText = preferences.getString(_userKey);
    final expiresAtText = preferences.getString(_expiresAtKey);

    if (token == null ||
        token.isEmpty ||
        userText == null ||
        userText.isEmpty) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtText ?? '');

    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      await clear();
      return null;
    }

    final decoded = jsonDecode(userText);

    if (decoded is! Map) {
      await clear();
      return null;
    }

    final user = LoginUser.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );

    return AuthSession(accessToken: token, expiresAt: expiresAt, user: user);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_tokenKey);
    await preferences.remove(_expiresAtKey);
    await preferences.remove(_userKey);
  }
}
