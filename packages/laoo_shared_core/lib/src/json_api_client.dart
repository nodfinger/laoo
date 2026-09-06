abstract interface class JsonApiClient {
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  });

  Future<dynamic> post(String path, {Object? body, bool authenticated = true});

  Future<dynamic> put(String path, {Object? body, bool authenticated = true});

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  });
}
