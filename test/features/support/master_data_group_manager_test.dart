import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/workspace_theme_presets.dart';
import 'package:laoo/core/widgets/pinned_data_table.dart';
import 'package:laoo/features/support/master_data/data/master_data_api.dart';
import 'package:laoo/features/support/master_data/pages/master_data_page.dart';
import 'package:laoo/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  testWidgets('table viewport uses available card height for long lists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeMasterApi(rowCount: 30);
    await tester.pumpWidget(
      MaterialApp(
        theme: workspaceThemeController.value.toThemeData(),
        home: Scaffold(
          body: MasterDataPage(
            menuScope: WorkspaceMenuScope.company,
            embedded: true,
            masterGroupCode: '008',
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final table = find.byType(PinnedDataTable);
    final card = find.ancestor(of: table, matching: find.byType(Card)).first;
    final vertical = find.descendant(
      of: table,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.vertical,
      ),
    );
    expect(
      tester.getSize(vertical).height,
      closeTo(tester.getSize(card).height - 56, 1),
    );
    await tester.drag(vertical, const Offset(0, -300));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: vertical,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });
  for (final code in ['008', '009', '010']) {
    testWidgets('master manager loads only group $code', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _FakeMasterApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: workspaceThemeController.value.toThemeData(),
          home: Scaffold(
            body: MasterDataPage(
              key: ValueKey(code),
              menuScope: WorkspaceMenuScope.company,
              embedded: true,
              masterGroupCode: code,
              api: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.loadedGroups, [code]);
      expect(find.text('รายการ $code'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'เพิ่ม'), findsOneWidget);
      final addButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'เพิ่ม'),
      );
      expect(
        addButton.style?.backgroundColor?.resolve({}),
        workspaceThemeController.value.primary,
      );
      expect(find.byTooltip('แก้ไข'), findsNothing);
      expect(find.byTooltip('ลบ'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unknown group does not fall back to another group', (
    tester,
  ) async {
    final api = _FakeMasterApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasterDataPage(
            menuScope: WorkspaceMenuScope.company,
            embedded: true,
            masterGroupCode: '999',
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.loadedGroups, isEmpty);
    expect(
      find.textContaining('ไม่สามารถโหลดกลุ่มข้อมูลที่เลือกได้'),
      findsOneWidget,
    );
  });

  testWidgets('master lookup selects from table and card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasterDataPage(
            menuScope: WorkspaceMenuScope.company,
            embedded: true,
            masterGroupCode: '008',
            api: _FakeMasterApi(masterView: false),
            onSelected: (code) => selected = code,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายการ 008').last);
    await tester.pump();
    expect(selected, '00001');
    selected = null;
    await tester.tap(find.byTooltip('แสดงแบบการ์ด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายการ 008').last);
    await tester.pump();
    expect(selected, '00001');
  });

  testWidgets('position lookup without master access is read only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeMasterApi(masterView: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasterDataPage(
            menuScope: WorkspaceMenuScope.company,
            embedded: true,
            masterGroupCode: '008',
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('รายการ 008'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'เพิ่ม'), findsNothing);
    expect(find.byTooltip('ไม่มีสิทธิ์แก้ไข'), findsWidgets);
    expect(find.byTooltip('ไม่มีสิทธิ์ลบ'), findsWidgets);
  });
}

class _FakeMasterApi extends MasterDataApi {
  _FakeMasterApi({this.rowCount = 1, this.masterView = true});
  final int rowCount;
  final bool masterView;
  final List<String> loadedGroups = [];

  @override
  Future<Map<String, bool>> actions() async => {
    'view': masterView,
    'create': true,
    'edit': false,
    'delete': false,
  };

  @override
  Future<List<Map<String, dynamic>>> groups() async => [
    {'code': '008', 'name': 'ตำแหน่งงาน'},
    {'code': '009', 'name': 'ประเภทรถ'},
    {'code': '010', 'name': 'ประเภทเชื้อเพลิง'},
  ];

  @override
  Future<List<Map<String, dynamic>>> list(
    String groupCode, {
    String? search,
  }) async {
    loadedGroups.add(groupCode);
    return List.generate(
      rowCount,
      (index) => {
        'code': '${index + 1}'.padLeft(5, '0'),
        'name': rowCount == 1 ? 'รายการ $groupCode' : 'รายการ ${index + 1}',
        'seq': index + 1,
        'shortCode': '',
      },
    );
  }

  @override
  void dispose() {}
}
