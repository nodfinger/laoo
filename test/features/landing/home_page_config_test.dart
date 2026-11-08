import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laoo/features/landing/data/home_page_config.dart';
import 'package:laoo/features/landing/presentation/pages/home_page_entry.dart';
import 'package:laoo/features/auth/presentation/pages/login_page.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads all four modes', () {
    for (final mode in [1, 2, 3, 4]) {
      final config = HomePageConfig.fromJson({
        'defaultMode': mode,
        'externalUrl': 'https://example.com',
      });
      expect(config.mode, mode);
    }
  });

  test('normalizes domains and refuses unsafe or malformed URLs', () {
    expect(
      HomePageConfig.fromJson({
        'defaultMode': 2,
        'externalUrl': 'www.example.com',
      }).externalUrl.toString(),
      'https://www.example.com',
    );
    for (final url in [
      '',
      'javascript:alert(1)',
      'file:///secret',
      'ftp://example.com',
      'https://user@example.com',
      'https://exa mple.com',
    ]) {
      final result = HomePageConfig.fromJson({
        'defaultMode': 2,
        'externalUrl': url,
      });
      expect(result.mode, 3, reason: url);
      expect(result.message, isNotNull, reason: url);
    }
    expect(HomePageConfig.fromJson({'defaultMode': 9}).mode, 3);
  });

  test('login return URL is optional, validated and cached', () async {
    expect(HomePageConfig.fromJson({'defaultMode': 1}).loginReturnUrl, isNull);
    expect(
      HomePageConfig.fromJson({
        'defaultMode': 1,
        'loginReturnUrl': 'javascript:alert(1)',
      }).loginReturnUrl,
      isNull,
    );
    final config = await HomePageConfigService(
      fetch: () async => {'defaultMode': 1, 'loginReturnUrl': 'example.com'},
    ).load();
    expect(config.loginReturnUrl.toString(), 'https://example.com');
    final offline = await HomePageConfigService(
      fetch: () async => throw Exception('offline'),
    ).load();
    expect(offline.loginReturnUrl.toString(), 'https://example.com');
  });

  testWidgets('login return button is hidden without a configured URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageEntry(
          service: HomePageConfigService(fetch: () async => {'defaultMode': 1}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u0e01\u0e25\u0e31\u0e1a\u0e2b\u0e19\u0e49\u0e32\u0e2b\u0e25\u0e31\u0e01',
      ),
      findsNothing,
    );
  });

  testWidgets('login return button opens the configured URL', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageEntry(
          service: HomePageConfigService(
            fetch: () async => {
              'defaultMode': 1,
              'loginReturnUrl': 'example.com',
            },
          ),
          openUrl: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.arrow_back_rounded));
    await tester.tap(
      find.text(
        '\u0e01\u0e25\u0e31\u0e1a\u0e2b\u0e19\u0e49\u0e32\u0e2b\u0e25\u0e31\u0e01',
      ),
    );
    await tester.pumpAndSettle();
    expect(opened.toString(), 'https://example.com');
  });

  test('uses last valid configuration on API failure', () async {
    final initial = HomePageConfigService(
      fetch: () async => {'defaultMode': 4},
    );
    expect((await initial.load()).mode, 4);
    final offline = HomePageConfigService(
      fetch: () async => throw Exception('offline'),
    );
    expect((await offline.load()).mode, 4);
    SharedPreferences.setMockInitialValues({});
    expect((await offline.load()).mode, 3);
  });

  test('external login button setting is retained in offline cache', () async {
    final online = HomePageConfigService(
      fetch: () async => {
        'defaultMode': 2,
        'externalUrl': 'https://example.com',
        'showLoginButton': true,
      },
    );
    expect((await online.load()).showLoginButton, isTrue);
    final offline = HomePageConfigService(
      fetch: () async => throw Exception('offline'),
    );
    final restored = await offline.load();
    expect(restored.mode, 2);
    expect(restored.showLoginButton, isTrue);
    expect(
      HomePageConfig.fromJson({
        'defaultMode': 2,
        'externalUrl': 'https://example.com',
      }).showLoginButton,
      isFalse,
    );
  });

  test(
    'invalid server configuration does not overwrite last valid configuration',
    () async {
      await HomePageConfigService(fetch: () async => {'defaultMode': 1}).load();
      final invalid = await HomePageConfigService(
        fetch: () async => {'defaultMode': 2, 'externalUrl': ''},
      ).load();
      expect(invalid.mode, 3);
      expect(invalid.message, isNotNull);
      expect(
        (await HomePageConfigService(
          fetch: () async => throw Exception(),
        ).load()).mode,
        1,
      );
    },
  );

  testWidgets('intranet home is public and renders placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageEntry(
          service: HomePageConfigService(fetch: () async => {'defaultMode': 4}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Intranet'), findsOneWidget);
  });

  testWidgets('login mode renders login page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageEntry(
          service: HomePageConfigService(fetch: () async => {'defaultMode': 1}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('external mode opens configured address', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageEntry(
          service: HomePageConfigService(
            fetch: () async => {'defaultMode': 2, 'externalUrl': 'example.com'},
          ),
          openUrl: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened.toString(), 'https://example.com');
  });

  testWidgets('external mode can show login button without redirect', (
    tester,
  ) async {
    var redirected = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HomePageEntry(
            service: HomePageConfigService(
              fetch: () async => {
                'defaultMode': 2,
                'externalUrl': 'https://example.com',
                'showLoginButton': true,
              },
            ),
            openUrl: (_) async {
              redirected = true;
              return true;
            },
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(redirected, isFalse);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('เปิดเว็บไซต์'), findsOneWidget);
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('login destination'), findsOneWidget);
  });
}
