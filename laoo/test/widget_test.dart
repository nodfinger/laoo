// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laoo/app/app.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo/app/router/route_paths.dart';
import 'package:laoo/features/auth/presentation/pages/login_page.dart';
import 'package:laoo/features/landing/presentation/pages/landing_page.dart';

void main() {
  tearDown(() {
    appRouter.go(RoutePaths.landing);
  });

  testWidgets('App opens the minimal landing page', (
    WidgetTester tester,
  ) async {
    appRouter.go(RoutePaths.landing);
    await tester.pumpWidget(const ProviderScope(child: LaooApp()));
    await tester.pumpAndSettle();

    expect(find.text('Laoo Solutions'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login route remains reachable', (WidgetTester tester) async {
    appRouter.go(RoutePaths.login);
    await tester.pumpWidget(const ProviderScope(child: LaooApp()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Landing supports a compact viewport and large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: LandingPage(),
        ),
      ),
    );

    expect(find.text('Laoo Solutions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

