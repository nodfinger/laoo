import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/service_settings/data/service_settings_api.dart';
import 'package:laoo_service/features/service_settings/pages/service_settings_page.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  setUpAll(() {
    configureServiceWorkspaceShell(
      ({
        required String pageTitle,
        required String activeMenu,
        required Widget child,
      }) => Scaffold(body: child),
    );
  });

  testWidgets('18001 error retry keeps VIEW-only controls read-only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _SettingsApi(canEdit: false, failFirst: true);
    await tester.pumpWidget(MaterialApp(home: ServiceSettingsPage(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ไม่สามารถโหลดตั้งค่าระบบบริการได้'),
      findsOneWidget,
    );
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.getCalls, 2);
    expect(find.text('เปิดใช้งานระบบบริการ'), findsOneWidget);
    expect(find.text('บันทึก'), findsNothing);
    for (final widget in tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    )) {
      expect(widget.onChanged, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('18001 EDIT allows changing and saving in card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _SettingsApi(canEdit: true);
    await tester.pumpWidget(MaterialApp(home: ServiceSettingsPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('บันทึก'), findsOneWidget);
    expect(find.byType(Card), findsAtLeastNWidgets(4));
    await tester.ensureVisible(find.text('บันทึก'));
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.updateCalls, 1);
    expect(api.getCalls, 2);
    expect(api.lastBody?['serviceEnabled'], true);
    expect(tester.takeException(), isNull);
  });
}

class _SettingsApi extends ServiceSettingsApi {
  _SettingsApi({required this.canEdit, this.failFirst = false});
  final bool canEdit;
  final bool failFirst;
  int getCalls = 0;
  int updateCalls = 0;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> get() async {
    getCalls++;
    if (failFirst && getCalls == 1) throw StateError('simulated failure');
    return {
      'canEdit': canEdit,
      'serviceEnabled': true,
      'allowWalkIn': true,
      'requireEquipment': true,
      'attachmentRequired': false,
      'workflowEnabled': true,
      'attachmentMaxBytes': 1048576,
    };
  }

  @override
  Future<void> update(Map<String, dynamic> settings) async {
    updateCalls++;
    lastBody = settings;
  }
}
