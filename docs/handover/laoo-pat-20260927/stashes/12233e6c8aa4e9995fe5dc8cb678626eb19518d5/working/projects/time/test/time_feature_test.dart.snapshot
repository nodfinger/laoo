import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_time/core/config/app_config.dart';
import 'package:laoo_time/time_feature.dart';

void main() {
  test('Time reserves the approved project and screen contracts', () {
    expect(AppConfig.projectCode, 'LAOO_TIME');
    expect(AppConfig.apiBaseUrl, 'http://localhost:5080');
    expect(TimeMenuGroups.setup, '28');
    expect(TimeRoutes.all, hasLength(2));
    expect(TimeRoutes.employeeSettings.menuCode, '28001');
    expect(TimeRoutes.employeeSettings.screenType, 2);
    expect(TimeRoutes.systemSettings.menuCode, '28002');
    expect(TimeRoutes.systemSettings.screenType, 2);
    expect(TimeRoutes.implemented, isEmpty);
    expect(buildTimeFeatureRoutes(), isEmpty);
  });

  testWidgets('Time delegates workspace composition to the Center host', (
    tester,
  ) async {
    configureTimeFeatureHost(({
      required pageTitle,
      required activeMenu,
      required child,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [Text('$pageTitle:$activeMenu'), child]),
      );
    });

    await tester.pumpWidget(
      buildTimeWorkspaceShell(
        pageTitle: 'Time',
        activeMenu: 'timeSystemSettings',
        child: const Text('content'),
      ),
    );

    expect(find.text('Time:timeSystemSettings'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });
}
