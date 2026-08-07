import '../api/api_client.dart';
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
    String projectCode = 'LAOO',
  }) async {
    final result = await _apiClient.post(
      ApiEndpoints.login,
      authenticated: false,
      body: {
        'username': username,
        'password': password,
        'projectCode': projectCode,
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
      projectCode: user?['projectCode'] as String?,
      projectId: _toInt(user?['projectId']),
      companyId: _toInt(user?['companyId']),
      branchId: _toInt(user?['branchId']),
      userId: _toInt(user?['userId']),
      laooUserId: _toInt(user?['laooUserId']),
    );

    // Save the token first so the next API request can send Bearer auth.
    await _authStorage.save(session);

    session = await _refreshContext(session);

    await _authStorage.save(session);
    return session;
  }

  Future<AuthSession?> restoreSession() {
    return _authStorage.read();
  }

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

  Future<void> logout() {
    return _authStorage.clear();
  }

  Future<AuthSession> _refreshContext(AuthSession session) async {
    final context =
        await _apiClient.get(ApiEndpoints.postLoginContext)
            as Map<String, dynamic>;

    final projects = context['projects'];

    String? projectCode = session.projectCode;
    int? projectId = session.projectId;

    if (projects is List && projects.isNotEmpty) {
      final first = projects.first as Map<String, dynamic>;

      projectCode = first['projectCode'] as String? ?? projectCode;

      projectId = _toInt(first['projectId']) ?? projectId;
    }

    return session.copyWith(
      userType: context['userType'] as String?,
      projectCode: projectCode,
      projectId: projectId,
    );
  }

  int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }
}
