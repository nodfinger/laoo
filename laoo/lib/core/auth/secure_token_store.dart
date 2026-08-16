import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureTokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class PlatformSecureTokenStore implements SecureTokenStore {
  PlatformSecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth.accessToken';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
