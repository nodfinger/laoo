import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/api_config.dart';

class HomePageConfig {
  const HomePageConfig({
    required this.mode,
    this.externalUrl,
    this.loginReturnUrl,
    this.message,
    this.showLoginButton = false,
  });
  final int mode;
  final Uri? externalUrl;
  final Uri? loginReturnUrl;
  final String? message;
  final bool showLoginButton;

  static const fallback = HomePageConfig(mode: 3);

  factory HomePageConfig.fromJson(Map<String, dynamic> json) {
    final value = json['defaultMode'];
    final mode = value is num ? value.toInt() : int.tryParse('$value');
    if (mode == null || mode < 1 || mode > 4) {
      return const HomePageConfig(
        mode: 3,
        message: 'ตั้งค่าหน้าแรกไม่ถูกต้อง จึงแสดงหน้าค้นหาช่าง',
      );
    }
    if (mode == 1) {
      return HomePageConfig(
        mode: 1,
        loginReturnUrl: _safeUrl(json['loginReturnUrl']),
      );
    }
    if (mode != 2) return HomePageConfig(mode: mode);
    final uri = _safeUrl(json['externalUrl']);
    if (uri == null) {
      return const HomePageConfig(
        mode: 3,
        message: 'URL หน้าแรกไม่ถูกต้อง จึงแสดงหน้าค้นหาช่าง',
      );
    }
    return HomePageConfig(
      mode: 2,
      externalUrl: uri,
      showLoginButton: json['showLoginButton'] == true,
    );
  }

  static Uri? _safeUrl(Object? value) {
    final raw = value is String ? value.trim() : '';
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(raw);
    final forbiddenScheme = RegExp(
      r'^(javascript|data|file):',
      caseSensitive: false,
    ).hasMatch(raw);
    final uri = Uri.tryParse(hasScheme ? raw : 'https://$raw');
    if (raw.isEmpty ||
        forbiddenScheme ||
        uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        raw.contains(RegExp(r'\s'))) {
      return null;
    }
    return uri;
  }

  Map<String, dynamic> toJson() => {
    'defaultMode': mode,
    'externalUrl': externalUrl?.toString() ?? '',
    'loginReturnUrl': loginReturnUrl?.toString() ?? '',
    'showLoginButton': showLoginButton,
  };
}

class HomePageConfigService {
  HomePageConfigService({Future<Map<String, dynamic>> Function()? fetch})
    : _fetch = fetch ?? _fetchFromApi;
  final Future<Map<String, dynamic>> Function() _fetch;
  static String get _cacheKey => 'home_page_config_v1:${ApiConfig.baseUrl}';

  static Future<Map<String, dynamic>> _fetchFromApi() async {
    final api = ApiClient();
    try {
      final response = await api
          .get('/api/public/home-page', authenticated: false)
          .timeout(const Duration(seconds: 5));
      if (response is! Map) {
        throw const FormatException('Invalid home page configuration');
      }
      return Map<String, dynamic>.from(response);
    } finally {
      api.dispose();
    }
  }

  Future<HomePageConfig> load() async {
    try {
      final config = HomePageConfig.fromJson(await _fetch());
      if (config.message == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
        } catch (_) {
          // Storage may be unavailable; the freshly fetched value still works.
        }
      }
      return config;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          final decoded = jsonDecode(cached);
          if (decoded is Map) {
            return HomePageConfig.fromJson(Map<String, dynamic>.from(decoded));
          }
        }
      } catch (_) {
        // Invalid or unavailable cached data falls back to the current landing page.
      }
      return HomePageConfig.fallback;
    }
  }
}
