import 'app_config.dart';

abstract final class ApiConfig {
  static const String baseUrl = AppConfig.apiBaseUrl;

  static const Duration requestTimeout = Duration(seconds: 30);
}
