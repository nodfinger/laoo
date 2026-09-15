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
      data.entries.map(
        (entry) => MapEntry('${entry.key}', entry.value == true),
      ),
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
      query: {'groupCode': groupCode ?? CompanySetupConstants.cConstRunItem},
    );
    if (data is! List) return const [];
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> businessTypeOptions() async {
    final data = await _client.get('/api/company-setup/business-type-options');
    if (data is! List) return const [];
    return List<Map<String, dynamic>>.from(data);
  }

  void dispose() => _client.dispose();
}

class MeetingEquipmentRequestSettingsApi {
  MeetingEquipmentRequestSettingsApi({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;
  static const _path = '/api/company/meeting-equipment-requests/settings';

  Future<bool> load() async {
    final data = await _client.get(_path);
    return data is Map && data['requireEquipmentRequestReview'] == true;
  }

  Future<void> save(bool requireReview) => _client.put(
    _path,
    body: {'requireEquipmentRequestReview': requireReview},
  );

  void dispose() => _client.dispose();
}

/// Read-only bootstrap contract. Training settings are added by the Training
/// module later; this endpoint only confirms the Company entitlement now.
class TrainingSettingsApi {
  TrainingSettingsApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const _path = '/api/company/training/settings';

  Future<bool> load() async {
    final data = await _client.get(_path);
    return data is Map && data['trainingEnabled'] == true;
  }

  void dispose() => _client.dispose();
}
