class RotationActions {
  const RotationActions({
    required this.caption,
    required this.view,
    required this.create,
    required this.edit,
    required this.delete,
  });
  final String caption;
  final bool view, create, edit, delete;
  factory RotationActions.fromJson(Map<String, dynamic> j) => RotationActions(
    caption: j['caption']?.toString() ?? 'รูปแบบหมุนกะ',
    view: j['view'] == true,
    create: j['create'] == true,
    edit: j['edit'] == true,
    delete: j['delete'] == true,
  );
}

class ShiftOption {
  const ShiftOption(this.id, this.code, this.name);
  final int id;
  final String code, name;
  factory ShiftOption.fromJson(Map<String, dynamic> j) => ShiftOption(
    (j['id'] as num).toInt(),
    j['code'].toString(),
    j['name'].toString(),
  );
}

class RotationDay {
  RotationDay({required this.dayNo, this.dayOff = false, this.shiftId});
  int dayNo;
  bool dayOff;
  int? shiftId;
  factory RotationDay.fromJson(Map<String, dynamic> j) => RotationDay(
    dayNo: (j['dayNo'] as num).toInt(),
    dayOff: j['isDayOff'] == true,
    shiftId: (j['shiftTemplateId'] as num?)?.toInt(),
  );
  Map<String, dynamic> toJson() => {
    'dayNo': dayNo,
    'isDayOff': dayOff,
    'shiftTemplateId': dayOff ? null : shiftId,
  };
}

class RotationPattern {
  RotationPattern({
    this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.active = true,
    required this.effectiveFrom,
    this.cycleDays = 1,
    required this.days,
    this.rowVersion,
  });
  int? id;
  String code, name, description;
  bool active;
  DateTime effectiveFrom;
  int cycleDays;
  List<RotationDay> days;
  String? rowVersion;
  factory RotationPattern.empty() => RotationPattern(
    code: '',
    name: '',
    effectiveFrom: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
    days: [RotationDay(dayNo: 1)],
  );
  factory RotationPattern.fromJson(Map<String, dynamic> j) => RotationPattern(
    id: (j['rotationPatternId'] as num).toInt(),
    code: j['patternCode'].toString(),
    name: j['patternName'].toString(),
    description: j['descriptionText']?.toString() ?? '',
    active: j['isActive'] == true,
    effectiveFrom: _editableDate(j['effectiveFrom']),
    cycleDays: (j['cycleDays'] as num).toInt(),
    days: (j['days'] as List)
        .whereType<Map>()
        .map((x) => RotationDay.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    rowVersion: j['rowVersion']?.toString(),
  );
  Map<String, dynamic> toJson() => {
    'patternCode': code,
    'patternName': name,
    'descriptionText': description,
    'isActive': active,
    'effectiveFrom':
        '${effectiveFrom.year.toString().padLeft(4, '0')}-${effectiveFrom.month.toString().padLeft(2, '0')}-${effectiveFrom.day.toString().padLeft(2, '0')}',
    'cycleDays': cycleDays,
    'days': days.map((x) => x.toJson()).toList(),
    'rowVersion': rowVersion,
  };
}

class RotationResult {
  const RotationResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });
  final int total, page, pageSize;
  final List<RotationPattern> items;
  factory RotationResult.fromJson(Map<String, dynamic> j) => RotationResult(
    total: (j['total'] as num?)?.toInt() ?? 0,
    page: (j['page'] as num?)?.toInt() ?? 1,
    pageSize: (j['pageSize'] as num?)?.toInt() ?? 30,
    items: (j['items'] as List? ?? const []).whereType<Map>().map((x) {
      final m = Map<String, dynamic>.from(x);
      return RotationPattern(
        id: (m['rotationPatternId'] as num).toInt(),
        code: m['patternCode'].toString(),
        name: m['patternName'].toString(),
        description: m['descriptionText']?.toString() ?? '',
        active: m['isActive'] == true,
        effectiveFrom:
            DateTime.tryParse(m['effectiveFrom']?.toString() ?? '') ??
            DateTime.now(),
        cycleDays: (m['cycleDays'] as num?)?.toInt() ?? 0,
        days: [],
        rowVersion: m['rowVersion']?.toString(),
      );
    }).toList(),
  );
}

DateTime _editableDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return parsed == null || parsed.isBefore(today) ? today : parsed;
}
