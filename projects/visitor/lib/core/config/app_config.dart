class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5082',
  );

  static const String projectCode = String.fromEnvironment(
    'PROJECT_CODE',
    defaultValue: 'LAOO_VISITOR',
  );
}
