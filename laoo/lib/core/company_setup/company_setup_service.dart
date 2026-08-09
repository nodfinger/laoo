import '../api/api_client.dart';
import 'company_setup_context.dart';

class CompanySetupService {
  CompanySetupService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<CompanySetupContext> loadRuntime() async {
    final result = await _apiClient.get('/api/company-setup');

    if (result is! Map<String, dynamic>) {
      throw StateError('Company Setup API ไม่ได้คืนข้อมูลในรูปแบบที่ถูกต้อง');
    }

    return CompanySetupContext.fromJson(result);
  }
}
