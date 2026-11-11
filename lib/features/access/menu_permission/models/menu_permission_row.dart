class MenuPermissionRow {
  const MenuPermissionRow({
    this.projectId,
    this.projectName,
    this.configuredMenuGroupCount,
    required this.menuCode,
    required this.menuName,
    required this.menuGroupCode,
    required this.menuGroupName,
    required this.screenType,
    required this.canView,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    this.allowPrint = false,
    this.allowExport = false,
    this.canPrint = false,
    this.canExport = false,
  });
  final int? projectId;
  final String? projectName;
  final int? configuredMenuGroupCount;
  String get groupKey =>
      projectId == null ? menuGroupCode : '$projectId:$menuGroupCode';
  String get groupLabel => projectName == null || projectName!.isEmpty
      ? menuGroupName
      : '$projectName > $menuGroupName';
  final String menuCode, menuName, menuGroupCode, menuGroupName;
  final int screenType;
  final bool canView, canCreate, canEdit, canDelete;
  final bool allowPrint, allowExport, canPrint, canExport;
  factory MenuPermissionRow.fromJson(Map<String, dynamic> json) =>
      MenuPermissionRow(
        projectId: (json['projectId'] as num?)?.toInt(),
        projectName: json['projectName'] as String?,
        configuredMenuGroupCount: (json['configuredMenuGroupCount'] as num?)
            ?.toInt(),
        menuCode: json['menuCode'] as String? ?? '',
        menuName: json['menuName'] as String? ?? '',
        menuGroupCode: json['menuGroupCode'] as String? ?? '',
        menuGroupName: json['menuGroupName'] as String? ?? '',
        screenType: (json['screenType'] as num?)?.toInt() ?? 3,
        canView: _bool(json['canView']),
        canCreate: _bool(json['canCreate']),
        canEdit: _bool(json['canEdit']),
        canDelete: _bool(json['canDelete']),
        allowPrint: _bool(json['allowPrint']),
        allowExport: _bool(json['allowExport']),
        canPrint: _bool(json['canPrint']),
        canExport: _bool(json['canExport']),
      );
  Map<String, dynamic> toJson() => {
    if (projectId != null) 'projectId': projectId,
    'menuCode': menuCode,
    'canView': canView,
    'canCreate': canCreate,
    'canEdit': canEdit,
    'canDelete': canDelete,
    'canPrint': canPrint,
    'canExport': canExport,
  };
  MenuPermissionRow copy({
    bool? view,
    bool? create,
    bool? edit,
    bool? delete,
    bool? print,
    bool? export,
  }) => MenuPermissionRow(
    projectId: projectId,
    projectName: projectName,
    configuredMenuGroupCount: configuredMenuGroupCount,
    menuCode: menuCode,
    menuName: menuName,
    menuGroupCode: menuGroupCode,
    menuGroupName: menuGroupName,
    screenType: screenType,
    canView: view ?? canView,
    canCreate: create ?? canCreate,
    canEdit: edit ?? canEdit,
    canDelete: delete ?? canDelete,
    allowPrint: allowPrint,
    allowExport: allowExport,
    canPrint: print ?? canPrint,
    canExport: export ?? canExport,
  );
}

bool _bool(Object? value) => value is bool
    ? value
    : value is num
    ? value != 0
    : value?.toString().toLowerCase() == 'true' || value == '1';
