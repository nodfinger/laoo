import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/access/menu_permission/models/menu_permission_row.dart';
import 'package:laoo/features/access/menu_permission/models/menu_permission_selection.dart';

void main() {
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
}
