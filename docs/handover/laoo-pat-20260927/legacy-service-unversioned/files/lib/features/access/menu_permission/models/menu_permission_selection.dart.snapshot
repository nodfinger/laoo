import 'menu_permission_row.dart';

class MenuPermissionSelection {
  const MenuPermissionSelection._();

  static bool isActionVisible(int screenType, String action) =>
      action == 'VIEW' ||
      ({1, 4}.contains(screenType) &&
          {'CREATE', 'EDIT', 'DELETE'}.contains(action)) ||
      (screenType == 2 && action == 'EDIT');

  static MenuPermissionRow applyToRow(
    MenuPermissionRow row,
    String action,
    bool value,
  ) {
    if (!isActionVisible(row.screenType, action)) return row;
    if (action == 'VIEW' && !value) {
      return row.copy(view: false, create: false, edit: false, delete: false);
    }
    return row.copy(
      view: action == 'VIEW' ? value : (value ? true : null),
      create: action == 'CREATE' ? value : null,
      edit: action == 'EDIT' ? value : null,
      delete: action == 'DELETE' ? value : null,
    );
  }

  static List<MenuPermissionRow> applyToGroup(
    List<MenuPermissionRow> rows,
    String menuGroupCode,
    String action,
    bool value,
  ) => rows
      .map(
        (row) => row.menuGroupCode == menuGroupCode
            ? applyToRow(row, action, value)
            : row,
      )
      .toList();

  static bool? groupValue(
    Iterable<MenuPermissionRow> rows,
    String menuGroupCode,
    String action,
  ) {
    final applicable = rows
        .where(
          (row) =>
              row.menuGroupCode == menuGroupCode &&
              isActionVisible(row.screenType, action),
        )
        .toList();
    if (applicable.isEmpty) return false;
    final selected = applicable.where((row) => valueOf(row, action)).length;
    if (selected == 0) return false;
    if (selected == applicable.length) return true;
    return null;
  }

  static bool hasAction(
    Iterable<MenuPermissionRow> rows,
    String menuGroupCode,
    String action,
  ) => rows.any(
    (row) =>
        row.menuGroupCode == menuGroupCode &&
        isActionVisible(row.screenType, action),
  );

  static bool valueOf(MenuPermissionRow row, String action) => switch (action) {
    'VIEW' => row.canView,
    'CREATE' => row.canCreate,
    'EDIT' => row.canEdit,
    'DELETE' => row.canDelete,
    _ => false,
  };
}
