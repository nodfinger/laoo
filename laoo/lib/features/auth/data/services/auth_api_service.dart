import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../models/login_models.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/auth/login');

    final request = LoginRequest(
      username: username.trim(),
      password: password,
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: const {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeBody(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return LoginResult.fromJson(body);
      }

      final result = LoginResult.fromJson(body);
      throw AuthApiException(result.message);
    } on TimeoutException {
      throw const AuthApiException('เชื่อมต่อ API ไม่สำเร็จภายในเวลาที่กำหนด');
    } on SocketException {
      throw const AuthApiException(
        'ไม่สามารถเชื่อมต่อ Laoo API ได้ กรุณาตรวจสอบว่า API กำลังทำงาน',
      );
    } on FormatException {
      throw const AuthApiException('ข้อมูลตอบกลับจาก API ไม่ถูกต้อง');
    } on http.ClientException {
      throw const AuthApiException('เกิดข้อผิดพลาดในการเชื่อมต่อ API');
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      throw const FormatException('Empty response body');
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map) {
      throw const FormatException('Response is not an object');
    }

    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  void dispose() {
    _client.close();
  }
}
