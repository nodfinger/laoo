class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5080',
  );

  static const String projectCode = String.fromEnvironment(
    'PROJECT_CODE',
    defaultValue: 'LAOO',
  );
}
