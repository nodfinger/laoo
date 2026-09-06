import '../../../core/network/http_service.dart';

class UserProfileRepository {
  UserProfileRepository({HttpService? client})
    : _client = client ?? HttpService();
  final HttpService _client;

  Future<Map<String, dynamic>> get() async =>
      Map<String, dynamic>.from(await _client.get('/api/user-profile') as Map);

  Future<Map<String, dynamic>> save(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.put('/api/user-profile', body: body) as Map,
      );

  Future<void> saveTheme(String themeCode) async {
    await _client.put(
      '/api/user-profile/theme',
      body: {'themeCode': themeCode},
    );
  }
}
