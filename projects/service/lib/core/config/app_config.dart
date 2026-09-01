class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5081',
  );

  static const String projectCode = String.fromEnvironment(
    'PROJECT_CODE',
    defaultValue: 'LAOO',
  );
}
