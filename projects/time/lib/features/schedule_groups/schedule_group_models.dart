class ScheduleGroupActions {
  const ScheduleGroupActions({
    required this.caption,
    required this.view,
    required this.create,
    required this.edit,
    required this.delete,
  });
  final String caption;
  final bool view, create, edit, delete;
  factory ScheduleGroupActions.fromJson(Map<String, dynamic> j) =>
      ScheduleGroupActions(
        caption: j['caption']?.toString() ?? 'กลุ่มตารางทำงาน',
        view: j['view'] == true,
        create: j['create'] == true,
        edit: j['edit'] == true,
        delete: j['delete'] == true,
      );
}

class ScheduleGroup {
  ScheduleGroup({
    this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.active = true,
    this.members = 0,
    this.rowVersion,
  });
  int? id;
  String code, name, description;
  bool active;
  int members;
  String? rowVersion;
  factory ScheduleGroup.fromJson(Map<String, dynamic> j) => ScheduleGroup(
    id: (j['workScheduleGroupId'] as num).toInt(),
    code: j['groupCode'].toString(),
    name: j['groupName'].toString(),
    description: j['descriptionText']?.toString() ?? '',
    active: j['isActive'] == true,
    members: (j['memberCount'] as num?)?.toInt() ?? 0,
    rowVersion: j['rowVersion']?.toString(),
  );
  Map<String, dynamic> toJson() => {
    'groupCode': code,
    'groupName': name,
    'descriptionText': description,
    'isActive': active,
    'rowVersion': rowVersion,
  };
}

class ScheduleGroupResult {
  const ScheduleGroupResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });
  final int total, page, pageSize;
  final List<ScheduleGroup> items;
  factory ScheduleGroupResult.fromJson(Map<String, dynamic> j) =>
      ScheduleGroupResult(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 30,
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => ScheduleGroup.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );
}
