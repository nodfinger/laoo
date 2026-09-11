class TimeSystemActions {
  const TimeSystemActions({
    required this.menuCode,
    required this.caption,
    required this.screenType,
    required this.canView,
    required this.canEdit,
    required this.canManageApprovalProfile,
  });

  final String menuCode;
  final String caption;
  final int screenType;
  final bool canView;
  final bool canEdit;
  final bool canManageApprovalProfile;

  factory TimeSystemActions.fromJson(Map<String, dynamic> json) =>
      TimeSystemActions(
        menuCode: json['menuCode']?.toString() ?? '28002',
        caption: json['caption']?.toString() ?? 'กำหนดค่าระบบเวลา',
        screenType: (json['screenType'] as num?)?.toInt() ?? 2,
        canView: json['view'] == true,
        canEdit: json['edit'] == true,
        canManageApprovalProfile: json['manageApprovalProfile'] == true,
      );
}

class TimeSystemSettings {
  const TimeSystemSettings({
    required this.effectiveDate,
    required this.defaultProfileCode,
    required this.processProfiles,
    required this.requestPolicies,
    required this.activeEmployeeCount,
    required this.employeeWithoutLoginCount,
    required this.selfServiceReady,
    required this.stateToken,
  });

  final DateTime effectiveDate;
  final String defaultProfileCode;
  final Map<String, String> processProfiles;
  final Map<String, String> requestPolicies;
  final int activeEmployeeCount;
  final int employeeWithoutLoginCount;
  final bool selfServiceReady;
  final String stateToken;

  factory TimeSystemSettings.fromJson(Map<String, dynamic> json) =>
      TimeSystemSettings(
        effectiveDate:
            DateTime.tryParse(json['effectiveDate']?.toString() ?? '') ??
            DateTime.now(),
        defaultProfileCode:
            json['defaultProfileCode']?.toString() ?? 'OWNER_OPERATED',
        processProfiles: _stringMap(json['processProfiles']),
        requestPolicies: _stringMap(json['requestPolicies']),
        activeEmployeeCount:
            (json['activeEmployeeCount'] as num?)?.toInt() ?? 0,
        employeeWithoutLoginCount:
            (json['employeeWithoutLoginCount'] as num?)?.toInt() ?? 0,
        selfServiceReady: json['selfServiceReady'] == true,
        stateToken: json['stateToken']?.toString() ?? '',
      );
}

class TimeSystemSettingsUpdate {
  const TimeSystemSettingsUpdate({
    required this.effectiveFrom,
    required this.defaultProfileCode,
    required this.processProfiles,
    required this.requestPolicies,
    required this.reason,
    required this.stateToken,
  });

  final DateTime effectiveFrom;
  final String defaultProfileCode;
  final Map<String, String> processProfiles;
  final Map<String, String> requestPolicies;
  final String reason;
  final String stateToken;

  Map<String, dynamic> toJson() => {
    'effectiveFrom': _dateOnly(effectiveFrom),
    'defaultProfileCode': defaultProfileCode,
    'processProfiles': processProfiles,
    'requestPolicies': requestPolicies,
    'reason': reason.trim(),
    'stateToken': stateToken,
  };
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item.toString()));
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
