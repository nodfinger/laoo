import 'menu_permission_row.dart';

class MenuPermissionSelection {
  const MenuPermissionSelection._();

  static bool isActionVisible(int screenType, String action) =>
      action == 'VIEW' ||
      ({1, 4}.contains(screenType) &&
          {'CREATE', 'EDIT', 'DELETE'}.contains(action)) ||
      (screenType == 2 && action == 'EDIT');

  static bool supports(MenuPermissionRow row, String action) =>
      switch (action) {
        'PRINT' => row.allowPrint,
        'EXPORT' => row.allowExport,
        _ => isActionVisible(row.screenType, action),
      };

  static List<MenuPermissionRow> grantAll(Iterable<MenuPermissionRow> rows) =>
      rows
          .map(
            (row) => row.copy(
              view: true,
              create: isActionVisible(row.screenType, 'CREATE'),
              edit: isActionVisible(row.screenType, 'EDIT'),
              delete: isActionVisible(row.screenType, 'DELETE'),
              print: row.allowPrint,
              export: row.allowExport,
            ),
          )
          .toList();

  static bool samePermissions(
    Iterable<MenuPermissionRow> first,
    Iterable<MenuPermissionRow> second,
  ) {
    final left = {
      for (final row in first) '${row.projectId}:${row.menuCode}': row,
    };
    final right = {
      for (final row in second) '${row.projectId}:${row.menuCode}': row,
    };
    if (left.length != right.length) return false;
    return left.entries.every((entry) {
      final other = right[entry.key];
      final row = entry.value;
      return other != null &&
          row.screenType == other.screenType &&
          row.canView == other.canView &&
          row.canCreate == other.canCreate &&
          row.canEdit == other.canEdit &&
          row.canDelete == other.canDelete &&
          row.canPrint == other.canPrint &&
          row.canExport == other.canExport;
    });
  }

  static MenuPermissionRow applyToRow(
    MenuPermissionRow row,
    String action,
    bool value,
  ) {
    if (!supports(row, action)) return row;
    if (action == 'VIEW' && !value) {
      return row.copy(
        view: false,
        create: false,
        edit: false,
        delete: false,
        print: false,
        export: false,
      );
    }
    return row.copy(
      view: action == 'VIEW' ? value : (value ? true : null),
      create: action == 'CREATE' ? value : null,
      edit: action == 'EDIT' ? value : null,
      delete: action == 'DELETE' ? value : null,
      print: action == 'PRINT' ? value : null,
      export: action == 'EXPORT' ? value : null,
    );
  }

  static List<MenuPermissionRow> applyToGroup(
    List<MenuPermissionRow> rows,
    String menuGroupCode,
    String action,
    bool value,
  ) => rows
      .map(
        (row) => row.groupKey == menuGroupCode
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
        .where((row) => row.groupKey == menuGroupCode && supports(row, action))
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
  ) =>
      rows.any((row) => row.groupKey == menuGroupCode && supports(row, action));

  static bool valueOf(MenuPermissionRow row, String action) => switch (action) {
    'VIEW' => row.canView,
    'CREATE' => row.canCreate,
    'EDIT' => row.canEdit,
    'DELETE' => row.canDelete,
    'PRINT' => row.canPrint,
    'EXPORT' => row.canExport,
    _ => false,
  };
}
