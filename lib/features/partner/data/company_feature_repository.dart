import '../../../core/api/api_client.dart';
import '../models/company_feature.dart';

class CompanyFeatureRepository {
  CompanyFeatureRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<CompanyFeatureState> getSalesManagement(int companyId) async {
    final data = await _api.get(
      '/api/partner/company-features',
      query: {'companyId': '$companyId'},
    );
    final rows = data as List<dynamic>;
    final row = rows.cast<Map<String, dynamic>>().firstWhere(
      (item) => item['featureCode'] == 'SALES_MANAGEMENT',
      orElse: () => <String, dynamic>{
        'featureCode': 'SALES_MANAGEMENT',
        'featureName': 'บริหารงานขาย',
        'isEnabled': false,
        'isTrial': false,
      },
    );
    return CompanyFeatureState.fromJson(row, companyId: companyId);
  }

  Future<CompanyFeatureState> setSalesManagement(
    CompanyFeatureState state, {
    required bool enabled,
  }) async {
    final startDate = enabled
        ? (state.startDate ?? DateTime.now())
        : state.startDate;
    final data = await _api.put(
      '/api/partner/company-features/${state.companyId}/sales-management',
      body: {
        'isEnabled': enabled,
        'isTrial': state.isTrial,
        'startDate': _date(startDate),
        'expireDate': _date(state.expireDate),
        'changeReason': enabled
            ? 'Partner Admin เปิดใช้ระบบบริหารงานขาย'
            : 'Partner Admin ปิดใช้ระบบบริหารงานขาย',
      },
    );
    final row = data as Map<String, dynamic>;
    return state.copyWith(
      isEnabled: row['isEnabled'] == true,
      isTrial: row['isTrial'] == true,
      startDate: DateTime.tryParse('${row['startDate'] ?? ''}') ?? startDate,
      expireDate: DateTime.tryParse('${row['expireDate'] ?? ''}'),
    );
  }

  String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
}
