import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/auth/auth_session.dart';
import 'package:laoo/core/auth/auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout clears auth session while preserving remembered credentials', () async {
    SharedPreferences.setMockInitialValues(const {});
    final storage = AuthStorage();
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
    await storage.saveRememberedPassword('secret');

    await storage.clear(preserveRememberedSession: true);

    expect(await storage.read(), isNull);
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRememberedUsername(), 't');
    expect(await storage.readRememberedPassword(), 'secret');
  });
}
