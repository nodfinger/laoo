import '../network/http_service.dart';

class ApiClient {
  ApiClient({HttpService? httpService}) : _http = httpService ?? HttpService();

  final HttpService _http;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return _http.get(path, query: query, authenticated: authenticated);
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => _http.getBytes(path, query: query, authenticated: authenticated);

  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) {
    return _http.post(path, body: body, authenticated: authenticated);
  }

  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) {
    return _http.put(path, body: body, authenticated: authenticated);
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _http.patch(path, body: body, authenticated: authenticated);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return _http.delete(
      path,
      body: body,
      query: query,
      authenticated: authenticated,
    );
  }

  Future<dynamic> upload(
    String path, {
    required String fileName,
    required List<int> bytes,
    Map<String, String>? fields,
    bool authenticated = true,
  }) {
    return _http.upload(
      path,
      fileName: fileName,
      bytes: bytes,
      fields: fields,
      authenticated: authenticated,
    );
  }

  void dispose() => _http.dispose();
}
