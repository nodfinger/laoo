import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_storage.dart';
import '../../../../core/auth/auth_session.dart';
import '../models/company_context.dart';

class CompanyContextService {
  CompanyContextService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _api = apiClient ?? ApiClient(),
        _storage = authStorage ?? AuthStorage();

  final ApiClient _api;
  final AuthStorage _storage;

  Future<List<CompanyContextItem>> loadCompanies() async {
    final result = await _api.get('/api/company-context/companies');

    if (result is! List) {
      throw StateError('รูปแบบรายการ Company ไม่ถูกต้อง');
    }

    return result
        .whereType<Map<String, dynamic>>()
        .map(CompanyContextItem.fromJson)
        .toList();
  }

  Future<CompanyContextItem> selectCompany(int companyId) async {
    final result = await _api.put(
      '/api/company-context',
      body: {'companyID': companyId},
    );

    if (result is! Map<String, dynamic>) {
      throw StateError('รูปแบบ Company Context ไม่ถูกต้อง');
    }

    final token = result['accessToken']?.toString();
    final expiresAtText = result['expiresAt']?.toString();

    if (token == null ||
        token.isEmpty ||
        expiresAtText == null ||
        expiresAtText.isEmpty) {
      throw StateError('API ไม่ได้คืน Access Token ใหม่');
    }

    final current = await _storage.read();
    if (current == null) {
      throw StateError('ไม่พบ Login Session ในเครื่อง');
    }

    final selected = CompanyContextItem.fromJson(result);
    final expiresAt = DateTime.parse(expiresAtText);

    final updatedSession = AuthSession(
      accessToken: token,
      expiresAt: expiresAt,
      projectCode: current.projectCode,
      projectId: current.projectId,
      companyId: selected.companyId,
      branchId: current.branchId,
      userId: current.userId,
      laooUserId: current.laooUserId,
      userType: current.userType,
      username: current.username,
      displayName: current.displayName,
    );

    await _storage.save(updatedSession);

    return selected;
  }

  void dispose() => _api.dispose();
}
