class MenuPermissionRow {
  const MenuPermissionRow({
    required this.menuCode,
    required this.menuName,
    required this.menuGroupCode,
    required this.menuGroupName,
    required this.screenType,
    required this.canView,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });
  final String menuCode, menuName, menuGroupCode, menuGroupName;
  final int screenType;
  final bool canView, canCreate, canEdit, canDelete;
  factory MenuPermissionRow.fromJson(Map<String, dynamic> json) =>
      MenuPermissionRow(
        menuCode: json['menuCode'] as String? ?? '',
        menuName: json['menuName'] as String? ?? '',
        menuGroupCode: json['menuGroupCode'] as String? ?? '',
        menuGroupName: json['menuGroupName'] as String? ?? '',
        screenType: (json['screenType'] as num?)?.toInt() ?? 3,
        canView: _bool(json['canView']),
        canCreate: _bool(json['canCreate']),
        canEdit: _bool(json['canEdit']),
        canDelete: _bool(json['canDelete']),
      );
  Map<String, dynamic> toJson() => {
    'menuCode': menuCode,
    'canView': canView,
    'canCreate': canCreate,
    'canEdit': canEdit,
    'canDelete': canDelete,
  };
  MenuPermissionRow copy({
    bool? view,
    bool? create,
    bool? edit,
    bool? delete,
  }) => MenuPermissionRow(
    menuCode: menuCode,
    menuName: menuName,
    menuGroupCode: menuGroupCode,
    menuGroupName: menuGroupName,
    screenType: screenType,
    canView: view ?? canView,
    canCreate: create ?? canCreate,
    canEdit: edit ?? canEdit,
    canDelete: delete ?? canDelete,
  );
}

bool _bool(Object? value) => value is bool
    ? value
    : value is num
    ? value != 0
    : value?.toString().toLowerCase() == 'true' || value == '1';
