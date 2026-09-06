import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../auth/auth_storage.dart';
import '../config/api_config.dart';

class HttpService {
  HttpService({http.Client? client, AuthStorage? authStorage})
    : _client = client ?? http.Client(),
      _authStorage = authStorage ?? AuthStorage();

  final http.Client _client;
  final AuthStorage _authStorage;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path, query);

    final response = await _client
        .get(uri, headers: await _headers(authenticated: authenticated))
        .timeout(ApiConfig.requestTimeout);

    return _decode(response);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path);

    final response = await _client
        .post(
          uri,
          headers: await _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConfig.requestTimeout);

    return _decode(response);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path);

    final response = await _client
        .put(
          uri,
          headers: await _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConfig.requestTimeout);

    return _decode(response);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path, query);

    final response = await _client
        .delete(
          uri,
          headers: await _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConfig.requestTimeout);

    return _decode(response);
  }

  Future<dynamic> upload(String path, {required List<int> bytes, required String filename}) async {
    final request = http.MultipartRequest('POST', _buildUri(path));
    final token = await _authStorage.readAccessToken();
    if (token == null || token.isEmpty) throw const ApiException(statusCode: 401, message: 'ไม่พบ Access Token กรุณาเข้าสู่ระบบใหม่');
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final response = await http.Response.fromStream(await request.send().timeout(ApiConfig.requestTimeout));
    return _decode(response);
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(ApiConfig.baseUrl);
    final uri = base.resolve(path);

    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await _authStorage.readAccessToken();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'ไม่พบ Access Token กรุณาเข้าสู่ระบบใหม่',
        );
      }

      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);

    dynamic data;
    if (text.trim().isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = text;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String message = 'เกิดข้อผิดพลาดในการเรียก API';

    if (data is Map<String, dynamic>) {
      message =
          data['message']?.toString() ?? data['title']?.toString() ?? message;
      final description = data['description']?.toString();
      if (description != null && description.trim().isNotEmpty) {
        message = '$message: $description';
      }
    } else if (data is String && data.trim().isNotEmpty) {
      message = data;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      details: data,
    );
  }

  void dispose() {
    _client.close();
  }
}
