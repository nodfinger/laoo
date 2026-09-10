import '../../../../core/api/api_client.dart';

class MeetingSetupLookupRepository {
  final _api = ApiClient();

  Future<Map<String, dynamic>> get(String screenCode) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/company/meeting-setup-lookups/$screenCode') as Map,
      );
}
