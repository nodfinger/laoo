import '../../../../core/api/api_client.dart';
import '../models/company_setup_constants.dart';
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

  Future<CompanySetupModel> save(
    CompanySetupUpdateInput input, {
    bool additionalOnly = false,
  }) async {
    final data = await _client.put(
      '/api/company-setup${additionalOnly ? '?additionalOnly=true' : ''}',
      body: input.toJson(),
    );

    if (data is! Map<String, dynamic>) {
      throw StateError('รูปแบบข้อมูล Company Setup หลังบันทึกไม่ถูกต้อง');
    }

    return CompanySetupModel.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> runItemOptions({String? groupCode}) async {
    final data = await _client.get(
      '/api/company-setup/run-item-options',
      query: {
        'groupCode': groupCode ?? CompanySetupConstants.cConstRunItem,
      },
    );
    if (data is! List) return const [];
    return List<Map<String, dynamic>>.from(data);
  }

  void dispose() => _client.dispose();
}
