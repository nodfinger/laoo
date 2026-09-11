class ShiftActions {
  const ShiftActions({
    required this.caption,
    required this.canView,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });
  final String caption;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  factory ShiftActions.fromJson(Map<String, dynamic> j) => ShiftActions(
    caption: j['caption']?.toString() ?? 'Master กะทำงาน',
    canView: j['view'] == true,
    canCreate: j['create'] == true,
    canEdit: j['edit'] == true,
    canDelete: j['delete'] == true,
  );
}

class ShiftSummary {
  const ShiftSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    required this.segmentCount,
    required this.sessionCount,
    required this.rowVersion,
  });
  final int id;
  final String code;
  final String name;
  final bool active;
  final int segmentCount;
  final int sessionCount;
  final String rowVersion;
  factory ShiftSummary.fromJson(Map<String, dynamic> j) => ShiftSummary(
    id: (j['shiftTemplateId'] as num).toInt(),
    code: j['shiftCode']?.toString() ?? '',
    name: j['shiftName']?.toString() ?? '',
    active: j['isActive'] == true,
    segmentCount: (j['segmentCount'] as num?)?.toInt() ?? 0,
    sessionCount: (j['sessionCount'] as num?)?.toInt() ?? 0,
    rowVersion: j['rowVersion']?.toString() ?? '',
  );
}

class ShiftPageResult {
  const ShiftPageResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });
  final int total;
  final int page;
  final int pageSize;
  final List<ShiftSummary> items;
  factory ShiftPageResult.fromJson(Map<String, dynamic> j) => ShiftPageResult(
    total: (j['total'] as num?)?.toInt() ?? 0,
    page: (j['page'] as num?)?.toInt() ?? 1,
    pageSize: (j['pageSize'] as num?)?.toInt() ?? 30,
    items: (j['items'] as List? ?? const [])
        .whereType<Map>()
        .map((x) => ShiftSummary.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );
}

class ShiftSegment {
  ShiftSegment({
    required this.sequenceNo,
    this.type = 'WORK',
    this.startDay = 0,
    this.startTime = '08:00',
    this.endDay = 0,
    this.endTime = '17:00',
  });
  int sequenceNo;
  String type;
  int startDay;
  String startTime;
  int endDay;
  String endTime;
  factory ShiftSegment.fromJson(Map<String, dynamic> j) => ShiftSegment(
    sequenceNo: (j['sequenceNo'] as num).toInt(),
    type: j['segmentTypeCode'].toString(),
    startDay: (j['startDayOffset'] as num).toInt(),
    startTime: _hm(j['startTime']),
    endDay: (j['endDayOffset'] as num).toInt(),
    endTime: _hm(j['endTime']),
  );
  Map<String, dynamic> toJson() => {
    'sequenceNo': sequenceNo,
    'segmentTypeCode': type,
    'startDayOffset': startDay,
    'startTime': '$startTime:00',
    'endDayOffset': endDay,
    'endTime': '$endTime:00',
  };
}

class ShiftSessionRule {
  ShiftSessionRule({
    required this.sequenceNo,
    this.name = 'รอบปกติ',
    this.inDay = 0,
    this.inTime = '08:00',
    this.outDay = 0,
    this.outTime = '17:00',
    this.inStartDay = 0,
    this.inStart = '05:00',
    this.inEndDay = 0,
    this.inEnd = '10:00',
    this.outStartDay = 0,
    this.outStart = '15:00',
    this.outEndDay = 0,
    this.outEnd = '23:00',
    this.late,
    this.early,
  });
  int sequenceNo;
  String name;
  int inDay;
  String inTime;
  int outDay;
  String outTime;
  int inStartDay;
  String inStart;
  int inEndDay;
  String inEnd;
  int outStartDay;
  String outStart;
  int outEndDay;
  String outEnd;
  int? late;
  int? early;
  factory ShiftSessionRule.fromJson(Map<String, dynamic> j) => ShiftSessionRule(
    sequenceNo: (j['sequenceNo'] as num).toInt(),
    name: j['ruleName'].toString(),
    inDay: (j['scheduledInDayOffset'] as num).toInt(),
    inTime: _hm(j['scheduledInTime']),
    outDay: (j['scheduledOutDayOffset'] as num).toInt(),
    outTime: _hm(j['scheduledOutTime']),
    inStartDay: (j['inWindowStartDayOffset'] as num).toInt(),
    inStart: _hm(j['inWindowStartTime']),
    inEndDay: (j['inWindowEndDayOffset'] as num).toInt(),
    inEnd: _hm(j['inWindowEndTime']),
    outStartDay: (j['outWindowStartDayOffset'] as num).toInt(),
    outStart: _hm(j['outWindowStartTime']),
    outEndDay: (j['outWindowEndDayOffset'] as num).toInt(),
    outEnd: _hm(j['outWindowEndTime']),
    late: (j['lateToleranceMinutes'] as num?)?.toInt(),
    early: (j['earlyToleranceMinutes'] as num?)?.toInt(),
  );
  Map<String, dynamic> toJson() => {
    'sequenceNo': sequenceNo,
    'ruleName': name.trim(),
    'scheduledInDayOffset': inDay,
    'scheduledInTime': '$inTime:00',
    'scheduledOutDayOffset': outDay,
    'scheduledOutTime': '$outTime:00',
    'inWindowStartDayOffset': inStartDay,
    'inWindowStartTime': '$inStart:00',
    'inWindowEndDayOffset': inEndDay,
    'inWindowEndTime': '$inEnd:00',
    'outWindowStartDayOffset': outStartDay,
    'outWindowStartTime': '$outStart:00',
    'outWindowEndDayOffset': outEndDay,
    'outWindowEndTime': '$outEnd:00',
    'lateToleranceMinutes': late,
    'earlyToleranceMinutes': early,
  };
}

class ShiftDetail {
  ShiftDetail({
    this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.active = true,
    required this.effectiveFrom,
    this.late = 0,
    this.early = 0,
    required this.segments,
    required this.rules,
    this.rowVersion,
  });
  int? id;
  String code;
  String name;
  String description;
  bool active;
  DateTime effectiveFrom;
  int late;
  int early;
  List<ShiftSegment> segments;
  List<ShiftSessionRule> rules;
  String? rowVersion;
  factory ShiftDetail.empty() => ShiftDetail(
    code: '',
    name: '',
    effectiveFrom: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
    segments: [ShiftSegment(sequenceNo: 1)],
    rules: [ShiftSessionRule(sequenceNo: 1)],
  );
  factory ShiftDetail.fromJson(Map<String, dynamic> j) => ShiftDetail(
    id: (j['shiftTemplateId'] as num).toInt(),
    code: j['shiftCode'].toString(),
    name: j['shiftName'].toString(),
    description: j['descriptionText']?.toString() ?? '',
    active: j['isActive'] == true,
    effectiveFrom: _editableDate(j['effectiveFrom']),
    late: (j['lateToleranceMinutes'] as num?)?.toInt() ?? 0,
    early: (j['earlyToleranceMinutes'] as num?)?.toInt() ?? 0,
    segments: (j['segments'] as List)
        .whereType<Map>()
        .map((x) => ShiftSegment.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    rules: (j['sessionRules'] as List)
        .whereType<Map>()
        .map((x) => ShiftSessionRule.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    rowVersion: j['rowVersion']?.toString(),
  );
  Map<String, dynamic> toJson() => {
    'shiftCode': code.trim(),
    'shiftName': name.trim(),
    'descriptionText': description.trim(),
    'isActive': active,
    'effectiveFrom': _date(effectiveFrom),
    'lateToleranceMinutes': late,
    'earlyToleranceMinutes': early,
    'segments': segments.map((x) => x.toJson()).toList(),
    'sessionRules': rules.map((x) => x.toJson()).toList(),
    'rowVersion': rowVersion,
  };
}

String _hm(dynamic value) {
  final s = value?.toString() ?? '';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _editableDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return parsed == null || parsed.isBefore(today) ? today : parsed;
}
