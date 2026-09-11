class ScheduleActions {
  const ScheduleActions({
    required this.caption,
    required this.view,
    required this.edit,
  });
  final String caption;
  final bool view, edit;
  factory ScheduleActions.fromJson(Map<String, dynamic> j) => ScheduleActions(
    caption: j['caption']?.toString() ?? 'จัดตารางพนักงาน',
    view: j['view'] == true,
    edit: j['edit'] == true,
  );
}

class ScheduleOption {
  const ScheduleOption(this.id, this.code, this.name);
  final int id;
  final String code, name;
  factory ScheduleOption.fromJson(Map<String, dynamic> j) => ScheduleOption(
    (j['id'] as num).toInt(),
    j['code'].toString(),
    j['name'].toString(),
  );
}

class ScheduleLookups {
  const ScheduleLookups({
    required this.employees,
    required this.groups,
    required this.patterns,
    required this.shifts,
  });
  final List<ScheduleOption> employees, groups, patterns, shifts;
  factory ScheduleLookups.fromJson(Map<String, dynamic> j) {
    List<ScheduleOption> read(String k) => (j[k] as List? ?? const [])
        .whereType<Map>()
        .map((x) => ScheduleOption.fromJson(Map<String, dynamic>.from(x)))
        .toList();
    return ScheduleLookups(
      employees: read('employees'),
      groups: read('groups'),
      patterns: read('patterns'),
      shifts: read('shifts'),
    );
  }
}

class EmployeeScheduleRow {
  const EmployeeScheduleRow({
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    this.groupId,
    this.groupCode,
    this.groupName,
  });
  final int employeeId;
  final String employeeCode, fullName;
  final int? groupId;
  final String? groupCode, groupName;
  factory EmployeeScheduleRow.fromJson(Map<String, dynamic> j) =>
      EmployeeScheduleRow(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'].toString(),
        fullName: j['fullName'].toString(),
        groupId: (j['workScheduleGroupId'] as num?)?.toInt(),
        groupCode: j['groupCode']?.toString(),
        groupName: j['groupName']?.toString(),
      );
}

class EmployeeScheduleResult {
  const EmployeeScheduleResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });
  final int total, page, pageSize;
  final List<EmployeeScheduleRow> items;
  factory EmployeeScheduleResult.fromJson(Map<String, dynamic> j) =>
      EmployeeScheduleResult(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 30,
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (x) => EmployeeScheduleRow.fromJson(Map<String, dynamic>.from(x)),
            )
            .toList(),
      );
}

String scheduleDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
