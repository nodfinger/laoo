import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class VisitorApiException implements Exception {
  const VisitorApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class VisitorApiClient implements JsonApiClient {
  VisitorApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _storage = FlutterSecureStorage();

  @override
  Future<dynamic> get(String path, {Map<String, String>? query, bool authenticated = true}) async {
    return _decode(await _client.get(_uri(path, query), headers: await _headers(authenticated)));
  }

  @override
  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) async {
    return _decode(await _client.post(_uri(path), headers: await _headers(authenticated), body: _body(body)));
  }

  @override
  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) async {
    return _decode(await _client.put(_uri(path), headers: await _headers(authenticated), body: _body(body)));
  }

  @override
  Future<dynamic> delete(String path, {Object? body, Map<String, String>? query, bool authenticated = true}) async {
    return _decode(await _client.delete(_uri(path, query), headers: await _headers(authenticated), body: _body(body)));
  }

  Future<dynamic> upload(String path, {required List<int> bytes, required String fileName, required Map<String, String> fields}) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(await _headers(true));
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    return _decode(await http.Response.fromStream(await request.send()));
  }

  void dispose() => _client.close();

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse(AppConfig.apiBaseUrl).resolve(path);
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  String? _body(Object? body) => body == null ? null : jsonEncode(body);

  Future<Map<String, String>> _headers(bool authenticated) async {
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (authenticated) {
      final prefs = await SharedPreferences.getInstance();
      final token = await _storage.read(key: 'auth.accessToken') ?? prefs.getString('auth.accessToken');
      if (token == null || token.isEmpty) throw const VisitorApiException(401, 'ไม่พบ Access Token กรุณาเข้าสู่ระบบใหม่');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    dynamic value;
    final text = utf8.decode(response.bodyBytes);
    try {
      value = text.trim().isEmpty ? null : jsonDecode(text);
    } catch (_) {
      value = text;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return value;
    var message = 'ไม่สามารถดำเนินการกับระบบ Visitor ได้';
    if (value is Map) {
      message = value['message']?.toString() ?? value['title']?.toString() ?? message;
      final detail = value['description']?.toString() ?? value['detail']?.toString();
      if (detail != null && detail.isNotEmpty) message = '$message\nรายละเอียดเพิ่มเติม: $detail';
    }
    throw VisitorApiException(response.statusCode, message);
  }
}
