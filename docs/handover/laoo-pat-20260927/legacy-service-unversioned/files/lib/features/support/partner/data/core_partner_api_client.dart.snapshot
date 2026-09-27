import '../../../../core/api/api_client.dart';
import '../data/partner_api_client.dart';

class CorePartnerApiClient implements PartnerApiClient {
  CorePartnerApiClient({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _apiClient.get(path, query: query);
  }

  @override
  Future<dynamic> post(String path, {Object? body}) {
    return _apiClient.post(path, body: body);
  }

  @override
  Future<dynamic> put(String path, {Object? body}) {
    return _apiClient.put(path, body: body);
  }

  @override
  Future<dynamic> delete(String path, {Object? body}) {
    return _apiClient.delete(path, body: body);
  }
}
