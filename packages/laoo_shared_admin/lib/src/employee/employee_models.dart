class EmployeeRecord {
  EmployeeRecord._(this._values);

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) =>
      EmployeeRecord._(Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> _values;

  int get employeeId => (_values['employeeId'] as num).toInt();
  int get partnerId => (_values['partnerId'] as num).toInt();
  int? get companyId => (_values['companyId'] as num?)?.toInt();
  String get companyName => (_values['companyName'] ?? '').toString();
  int? get divisionOrgUnitId => (_values['divisionOrgUnitId'] as num?)?.toInt();
  int? get departmentOrgUnitId =>
      (_values['departmentOrgUnitId'] as num?)?.toInt();
  String get divisionName => (_values['divisionName'] ?? '').toString();
  String get departmentName => (_values['departmentName'] ?? '').toString();
  String get employeeCode => (_values['employeeCode'] ?? '').toString();
  String get fullName => (_values['fullName'] ?? '').toString();
  String get nickName => (_values['nickName'] ?? '').toString();
  String get positionCode => (_values['positionCode'] ?? '').toString();
  String get email => (_values['email'] ?? '').toString();
  String get telephone => (_values['telephone'] ?? '').toString();
  bool get notifyByEmail => _asBool(_values['notifyByEmail']);
  bool get notifyInSystem => _asBool(_values['notifyInSystem']);
  String get contName1 => (_values['contName1'] ?? '').toString();
  String get contRelation1 => (_values['contRelation1'] ?? '').toString();
  String get contPhone1 => (_values['contPhone1'] ?? '').toString();
  String get contName2 => (_values['contName2'] ?? '').toString();
  String get contRelation2 => (_values['contRelation2'] ?? '').toString();
  String get contPhone2 => (_values['contPhone2'] ?? '').toString();
  String get carId1 => (_values['carID1'] ?? '').toString();
  String get carColor1 => (_values['carColor1'] ?? '').toString();
  String get carTypeCode1 => (_values['carTypeCode1'] ?? '').toString();
  String get carOilType1 => (_values['carOilType1'] ?? '').toString();
  String get carId2 => (_values['carID2'] ?? '').toString();
  String get carColor2 => (_values['carColor2'] ?? '').toString();
  String get carTypeCode2 => (_values['carTypeCode2'] ?? '').toString();
  String get carOilType2 => (_values['carOilType2'] ?? '').toString();
  DateTime? get startWorkDate {
    final value = _values['startWorkDate'];
    return value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
  }

  bool get isActive => _values['isActive'] != false;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_values);

  Object? operator [](String key) => _values[key];

  static bool _asBool(Object? value) => value is bool
      ? value
      : value is num
      ? value != 0
      : value?.toString().toLowerCase() == 'true';
}

class EmployeeListResult {
  const EmployeeListResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory EmployeeListResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return EmployeeListResult(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      EmployeeRecord.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }

  final List<EmployeeRecord> items;
  final int totalCount;
  final int page;
  final int pageSize;

  Object? operator [](String key) => switch (key) {
    'items' => items.map((item) => item.toJson()).toList(growable: false),
    'totalCount' => totalCount,
    'page' => page,
    'pageSize' => pageSize,
    _ => null,
  };
}

class EmployeeUpsertRequest {
  EmployeeUpsertRequest._(this._values);

  factory EmployeeUpsertRequest.fromJson(Map<String, dynamic> json) =>
      EmployeeUpsertRequest._(Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> _values;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_values);
}

class EmployeeUserRecord {
  const EmployeeUserRecord({required this.username, this.roleGroupId});

  factory EmployeeUserRecord.fromJson(Map<String, dynamic> json) =>
      EmployeeUserRecord(
        username: (json['username'] ?? '').toString(),
        roleGroupId: (json['roleGroupId'] as num?)?.toInt(),
      );

  final String username;
  final int? roleGroupId;

  Object? operator [](String key) => switch (key) {
    'username' => username,
    'roleGroupId' => roleGroupId,
    _ => null,
  };
}
