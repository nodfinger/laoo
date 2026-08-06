class AppConfig {
  const AppConfig._();

  /// Development API endpoint.
  ///
  /// Windows desktop:
  ///   http://localhost:5080
  ///
  /// Android Emulator ในอนาคต:
  ///   http://10.0.2.2:5080
  static const String apiBaseUrl = 'http://localhost:5080';

  static const String projectCode = 'LAOO';
}
