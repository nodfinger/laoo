abstract final class ApiConfig {
  /// Local development URL for Windows/Web.
  ///
  /// For a physical Android/iOS device, localhost points to the device itself.
  /// Change this value to the API machine's LAN IP when testing on a phone/tablet.
  static const String baseUrl = 'http://localhost:5080';

  static const Duration requestTimeout = Duration(seconds: 30);
}
