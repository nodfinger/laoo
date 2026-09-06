import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/auth/auth_session.dart';
import 'package:laoo/core/auth/auth_storage.dart';
import 'package:laoo/core/auth/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'logout clears auth session while preserving remembered username',
    () async {
      SharedPreferences.setMockInitialValues(const {});
      final storage = AuthStorage(secureTokenStore: _MemorySecureTokenStore());
      final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 1));

      await storage.save(
        AuthSession(
          accessToken: 'token',
          expiresAt: expiresAt,
          userType: 'LAOO_SUPPORT',
          username: 't',
          companyId: 10,
        ),
        rememberLogin: true,
      );
      await storage.saveRememberedUsername('t');

      await storage.clear(preserveRememberedSession: true);

      expect(await storage.read(), isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRememberedUsername(), 't');
    },
  );

  test('persists the complete partner identity and owner scope', () async {
    SharedPreferences.setMockInitialValues(const {});
    final storage = AuthStorage(secureTokenStore: _MemorySecureTokenStore());

    await storage.save(
      AuthSession(
        accessToken: 'partner-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        userType: 'PARTNER_USER',
        username: 'l',
        projectId: 7,
        partnerUserId: 11,
        partnerId: 22,
      ),
    );

    final restored = await storage.read();
    expect(restored?.userType, 'PARTNER_USER');
    expect(restored?.projectId, 7);
    expect(restored?.partnerUserId, 11);
    expect(restored?.partnerId, 22);
  });
}

class _MemorySecureTokenStore implements SecureTokenStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
