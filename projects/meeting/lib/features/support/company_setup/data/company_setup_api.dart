import '../../../../core/api/api_client.dart';
import '../models/company_setup_model.dart';

class CompanySetupApi {
  CompanySetupApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, bool>> actions() async {
    final data = await _client.get('/api/company-setup/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map((entry) => MapEntry('${entry.key}', entry.value == true)),
    );
  }

  Future<CompanySetupModel> load() async {
    final data = await _client.get('/api/company-setup');

    if (data is! Map<String, dynamic>) {
      throw StateError('รูปแบบข้อมูล Company Setup ไม่ถูกต้อง');
    }

    return CompanySetupModel.fromJson(data);
  }

  Future<CompanySetupModel> save(CompanySetupUpdateInput input) async {
    final data = await _client.put(
      '/api/company-setup',
      body: input.toJson(),
    );

    if (data is! Map<String, dynamic>) {
      throw StateError('รูปแบบข้อมูล Company Setup หลังบันทึกไม่ถูกต้อง');
    }

    return CompanySetupModel.fromJson(data);
  }

  void dispose() => _client.dispose();
}
