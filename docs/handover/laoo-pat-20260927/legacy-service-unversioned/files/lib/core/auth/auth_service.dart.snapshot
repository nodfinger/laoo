import '../api/api_client.dart';
import '../config/app_config.dart';
import '../constants/api_endpoints.dart';
import 'auth_session.dart';
import 'auth_storage.dart';

class AuthService {
  AuthService({ApiClient? apiClient, AuthStorage? authStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<AuthSession> login({
    required String username,
    required String password,
    bool rememberLogin = true,
  }) async {
    if (rememberLogin) {
      await _authStorage.saveRememberedUsername(username);
    } else {
      await _authStorage.clearRememberedUsername();
    }
    final result = await _apiClient.post(
      ApiEndpoints.login,
      authenticated: false,
      body: {
        'username': username,
        'password': password,
        'projectCode': AppConfig.projectCode,
      },
    );

    final json = result as Map<String, dynamic>;

    final success = json['success'] as bool? ?? false;
    if (!success) {
      throw StateError(json['message']?.toString() ?? 'เข้าสู่ระบบไม่สำเร็จ');
    }

    final token = json['accessToken'] as String?;
    final expiresAtText = json['expiresAt'] as String?;

    if (token == null || token.isEmpty || expiresAtText == null) {
      throw StateError('Login API ไม่ได้คืน Access Token ที่ถูกต้อง');
    }

    final user = json['user'] as Map<String, dynamic>?;

    var session = AuthSession(
      accessToken: token,
      expiresAt: DateTime.parse(expiresAtText),
      userType: user?['userType'] as String?,
      projectCode: user?['projectCode'] as String?,
      username: user?['username'] as String?,
      displayName: user?['displayName'] as String?,
      projectId: _toInt(user?['projectId']),
      partnerUserId: _toInt(user?['partnerUserId']),
      partnerId: _toInt(user?['partnerId']),
      companyId: _toInt(user?['companyId']),
      branchId: _toInt(user?['branchId']),
      userId: _toInt(user?['userId']),
      laooUserId: _toInt(user?['laooUserId']),
    );

    // Save the token first so the next API request can send Bearer auth.
    await _authStorage.save(session, rememberLogin: rememberLogin);

    session = await _refreshContext(session);

    await _authStorage.save(session);
    return session;
  }

  Future<void> requestPasswordReset({required String username}) async {
    await _apiClient.post(
      '/api/auth/forgot-password',
      authenticated: false,
      body: {'username': username.trim(), 'projectCode': AppConfig.projectCode},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/api/auth/reset-password',
      authenticated: false,
      body: {'token': token.trim(), 'newPassword': newPassword},
    );
  }

  Future<AuthSession?> restoreSession() {
    return _authStorage.read();
  }

  Future<void> saveSession(AuthSession session) => _authStorage.save(session);

  Future<AuthSession?> restoreAndRefreshSession() async {
    final restored = await _authStorage.read();

    if (restored == null) {
      return null;
    }

    try {
      final refreshed = await _refreshContext(restored);
      await _authStorage.save(refreshed);
      return refreshed;
    } catch (_) {
      await _authStorage.clear();
      return null;
    }
  }

  Future<void> logout({bool preserveRememberedSession = false}) {
    return _authStorage.clear(
      preserveRememberedSession: preserveRememberedSession,
    );
  }

  Future<AuthSession> _refreshContext(AuthSession session) async {
    final context =
        await _apiClient.get(ApiEndpoints.postLoginContext)
            as Map<String, dynamic>;

    final projects = context['projects'];
    final contextUserType = context['userType'] as String?;
    final contextUserId = _toInt(context['userId']);
    final contextPartnerId = _toInt(context['partnerId']);

    String? projectCode = session.projectCode;
    int? projectId = session.projectId;

    if (projects is List && projects.isNotEmpty) {
      final first = projects.first as Map<String, dynamic>;

      projectCode = first['projectCode'] as String? ?? projectCode;

      projectId = _toInt(first['projectId']) ?? projectId;
    }

    return session.copyWith(
      userType: contextUserType,
      projectCode: projectCode,
      projectId: projectId,
      laooUserId: contextUserType == 'LAOO_SUPPORT'
          ? contextUserId
          : session.laooUserId,
      partnerUserId: contextUserType == 'PARTNER_USER'
          ? contextUserId
          : session.partnerUserId,
      userId: contextUserType == 'COMPANY_USER'
          ? contextUserId
          : session.userId,
      partnerId: contextPartnerId ?? session.partnerId,
    );
  }

  int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }
}
