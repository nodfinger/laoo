import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_survey/survey_feature.dart';

void main() {
  test('Survey has seven placeholder route contracts', () {
    expect(SurveyProject.code, 'LAOO_SURVEY');
    expect(SurveyRoutes.all, hasLength(7));
    expect(
      SurveyRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '40001',
        '40002',
        '40003',
        '40004',
        '40005',
        '40006',
        '40007',
      ]),
    );
    expect(SurveyRoutes.implemented, isEmpty);
    final previewRoutes = buildSurveyFeatureRoutes();
    expect(previewRoutes, hasLength(SurveyRoutes.all.length));
    for (final route in SurveyRoutes.all) {
      expect(
        previewRoutes.where(
          (preview) =>
              preview.name == route.routeName &&
              preview.path == route.routePath,
        ),
        hasLength(1),
      );
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });

  testWidgets('every Survey route opens a readable preview page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: SurveyRoutes.all.first.routePath,
      routes: buildSurveyFeatureRoutes(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    for (final route in SurveyRoutes.all) {
      router.go(route.routePath);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, route.routePath);
      expect(find.text('กำลังเตรียมหน้าจอระบบแบบสอบถาม'), findsOneWidget);
    }
  });
}
