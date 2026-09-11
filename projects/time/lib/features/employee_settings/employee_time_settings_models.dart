class EmployeeTimeActions {
  const EmployeeTimeActions({
    required this.menuCode,
    required this.caption,
    required this.screenType,
    required this.canView,
    required this.canEdit,
  });

  final String menuCode;
  final String caption;
  final int screenType;
  final bool canView;
  final bool canEdit;

  factory EmployeeTimeActions.fromJson(Map<String, dynamic> json) =>
      EmployeeTimeActions(
        menuCode: json['menuCode']?.toString() ?? '28001',
        caption: json['caption']?.toString() ?? 'พนักงาน–ลงเวลาทำงาน',
        screenType: (json['screenType'] as num?)?.toInt() ?? 2,
        canView: json['view'] == true,
        canEdit: json['edit'] == true,
      );
}

class EmployeeTimeSettingRecord {
  const EmployeeTimeSettingRecord({
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    required this.nickName,
    required this.isActive,
    required this.requiresAttendance,
    required this.requirementEffectiveFrom,
    required this.requirementEffectiveTo,
    required this.requirementReason,
    required this.requirementRowVersion,
    required this.deviceCode,
    required this.deviceCodeEffectiveFrom,
    required this.deviceCodeRowVersion,
    required this.hasActiveLogin,
  });

  final int employeeId;
  final String employeeCode;
  final String fullName;
  final String? nickName;
  final bool isActive;
  final bool requiresAttendance;
  final DateTime? requirementEffectiveFrom;
  final DateTime? requirementEffectiveTo;
  final String? requirementReason;
  final String? requirementRowVersion;
  final String? deviceCode;
  final DateTime? deviceCodeEffectiveFrom;
  final String? deviceCodeRowVersion;
  final bool hasActiveLogin;

  factory EmployeeTimeSettingRecord.fromJson(Map<String, dynamic> json) =>
      EmployeeTimeSettingRecord(
        employeeId: (json['employeeId'] as num).toInt(),
        employeeCode: json['employeeCode']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        nickName: _text(json['nickName']),
        isActive: json['isActive'] == true,
        requiresAttendance: json['requiresAttendance'] != false,
        requirementEffectiveFrom: _date(json['requirementEffectiveFrom']),
        requirementEffectiveTo: _date(json['requirementEffectiveTo']),
        requirementReason: _text(json['requirementReason']),
        requirementRowVersion: _text(json['requirementRowVersion']),
        deviceCode: _text(json['deviceCode']),
        deviceCodeEffectiveFrom: _date(json['deviceCodeEffectiveFrom']),
        deviceCodeRowVersion: _text(json['deviceCodeRowVersion']),
        hasActiveLogin: json['hasActiveLogin'] == true,
      );
}

class EmployeeTimeSettingsResult {
  const EmployeeTimeSettingsResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });

  final int total;
  final int page;
  final int pageSize;
  final List<EmployeeTimeSettingRecord> items;

  factory EmployeeTimeSettingsResult.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];
    return EmployeeTimeSettingsResult(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 30,
      items: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => EmployeeTimeSettingRecord.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class EmployeeTimeSettingsUpdate {
  const EmployeeTimeSettingsUpdate({
    required this.requiresAttendance,
    required this.deviceCode,
    required this.effectiveFrom,
    required this.reason,
    required this.requirementRowVersion,
    required this.deviceCodeRowVersion,
  });

  final bool requiresAttendance;
  final String? deviceCode;
  final DateTime effectiveFrom;
  final String reason;
  final String? requirementRowVersion;
  final String? deviceCodeRowVersion;

  Map<String, dynamic> toJson() => {
    'requiresAttendance': requiresAttendance,
    'deviceCode': _text(deviceCode),
    'effectiveFrom': _dateOnly(effectiveFrom),
    'reason': reason.trim(),
    'requirementRowVersion': requirementRowVersion,
    'deviceCodeRowVersion': deviceCodeRowVersion,
  };
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? _date(dynamic value) {
  final text = _text(value);
  return text == null ? null : DateTime.tryParse(text);
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
