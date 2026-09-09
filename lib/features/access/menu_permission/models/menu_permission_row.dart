class MenuPermissionRow {
  const MenuPermissionRow({
    this.projectId,
    this.projectName,
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
  final int? projectId;
  final String? projectName;
  String get groupKey =>
      projectId == null ? menuGroupCode : '$projectId:$menuGroupCode';
  String get groupLabel => projectName == null || projectName!.isEmpty
      ? menuGroupName
      : '$projectName > $menuGroupName';
  final String menuCode, menuName, menuGroupCode, menuGroupName;
  final int screenType;
  final bool canView, canCreate, canEdit, canDelete;
  factory MenuPermissionRow.fromJson(Map<String, dynamic> json) =>
      MenuPermissionRow(
        projectId: (json['projectId'] as num?)?.toInt(),
        projectName: json['projectName'] as String?,
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
    if (projectId != null) 'projectId': projectId,
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
    projectId: projectId,
    projectName: projectName,
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
