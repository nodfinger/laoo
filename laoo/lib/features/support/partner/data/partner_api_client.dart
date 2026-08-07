abstract class PartnerApiClient {
  Future<dynamic> get(String path, {Map<String, String>? query});

  Future<dynamic> post(String path, {Object? body});

  Future<dynamic> put(String path, {Object? body});
}
