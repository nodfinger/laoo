import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/access/menu_permission/models/menu_permission_row.dart';
import 'package:laoo/features/access/menu_permission/models/menu_permission_selection.dart';

void main() {
  test(
    'permission changes preserve group metadata without sending it to save API',
    () {
      final source = MenuPermissionRow.fromJson({
        'projectId': 10,
        'projectName': 'Sales',
        'configuredMenuGroupCount': 1,
        'menuCode': '09001',
        'menuName': 'Customers',
        'menuGroupCode': '09',
        'menuGroupName': 'Sales',
        'screenType': 1,
      });
      final changed = MenuPermissionSelection.applyToRow(
        source,
        'CREATE',
        true,
      );
      expect(changed.configuredMenuGroupCount, 1);
      expect(changed.canView, isTrue);
      expect(changed.canCreate, isTrue);
      expect(changed.toJson().containsKey('configuredMenuGroupCount'), isFalse);
    },
  );
  MenuPermissionRow row(String code, int screenType) => MenuPermissionRow(
    menuCode: code,
    menuName: code,
    menuGroupCode: '01',
    menuGroupName: 'กลุ่มทดสอบ',
    screenType: screenType,
    canView: false,
    canCreate: false,
    canEdit: false,
    canDelete: false,
  );

  test('grant all gives only actions supported by each screen type', () {
    final source = [
      row('CRUD', 1),
      row('UPDATE', 2),
      row('SHOW', 3),
      row('DOC', 4),
    ];
    final granted = MenuPermissionSelection.grantAll(source);
    expect(
      granted.map(
        (item) => [item.canView, item.canCreate, item.canEdit, item.canDelete],
      ),
      [
        [true, true, true, true],
        [true, false, true, false],
        [true, false, false, false],
        [true, true, true, true],
      ],
    );
    expect(source.every((item) => !item.canView), isTrue);
  });

  test(
    'permission comparison detects unsaved edits and changed menu scope',
    () {
      final original = [row('A', 1), row('B', 2)];
      expect(
        MenuPermissionSelection.samePermissions(original, original.reversed),
        isTrue,
      );
      expect(
        MenuPermissionSelection.samePermissions(original, [
          row('A', 1).copy(view: true),
          row('B', 2),
        ]),
        isFalse,
      );
      expect(
        MenuPermissionSelection.samePermissions(original, [row('A', 1)]),
        isFalse,
      );
      expect(
        MenuPermissionSelection.samePermissions(original, [
          row('A', 3),
          row('B', 2),
        ]),
        isFalse,
      );
    },
  );

  test('group CREATE selects only supported child menus and enables VIEW', () {
    final updated = MenuPermissionSelection.applyToGroup(
      [row('CRUD', 1), row('UPDATE', 2), row('SHOW', 3), row('DOC', 4)],
      '01',
      'CREATE',
      true,
    );

    expect(updated[0].canCreate, isTrue);
    expect(updated[0].canView, isTrue);
    expect(updated[1].canCreate, isFalse);
    expect(updated[2].canCreate, isFalse);
    expect(updated[3].canCreate, isTrue);
    expect(updated[3].canView, isTrue);
  });

  test('turning group VIEW off clears every child action', () {
    final selected = row(
      'CRUD',
      1,
    ).copy(view: true, create: true, edit: true, delete: true);
    final updated = MenuPermissionSelection.applyToGroup(
      [selected],
      '01',
      'VIEW',
      false,
    ).single;

    expect(updated.canView, isFalse);
    expect(updated.canCreate, isFalse);
    expect(updated.canEdit, isFalse);
    expect(updated.canDelete, isFalse);
  });

  test('group value is null when child selection is partial', () {
    final rows = [row('A', 1).copy(view: true), row('B', 1)];

    expect(MenuPermissionSelection.groupValue(rows, '01', 'VIEW'), isNull);
  });

  test('same menu group code in different projects stays separate', () {
    final core = MenuPermissionRow(
      projectId: 1,
      projectName: 'Core',
      menuCode: 'CORE',
      menuName: 'Core menu',
      menuGroupCode: '01',
      menuGroupName: 'Shared code',
      screenType: 1,
      canView: false,
      canCreate: false,
      canEdit: false,
      canDelete: false,
    );
    final service = MenuPermissionRow(
      projectId: 4,
      projectName: 'Service',
      menuCode: 'SERVICE',
      menuName: 'Service menu',
      menuGroupCode: '01',
      menuGroupName: 'Shared code',
      screenType: 1,
      canView: false,
      canCreate: false,
      canEdit: false,
      canDelete: false,
    );

    final updated = MenuPermissionSelection.applyToGroup(
      [core, service],
      core.groupKey,
      'VIEW',
      true,
    );

    expect(updated[0].canView, isTrue);
    expect(updated[1].canView, isFalse);
  });
}
