import 'package:laoo_shared_core/laoo_shared_core.dart';

class VisitorSettingsRepository {
  VisitorSettingsRepository(this.api);
  final JsonApiClient api;

  Future<VisitorSettingsActions> actions() async =>
      VisitorSettingsActions.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/system-settings/actions') as Map,
        ),
      );

  Future<VisitorSettings> get() async => VisitorSettings.fromJson(
    Map<String, dynamic>.from(
      await api.get('/api/visitor/system-settings') as Map,
    ),
  );

  Future<VisitorCompanyContext> context() async =>
      VisitorCompanyContext.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/company-context') as Map,
        ),
      );

  Future<VisitorCheckInContext> checkInContext() async =>
      VisitorCheckInContext.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/check-in-context') as Map,
        ),
      );

  Future<List<VisitorRoomOption>> guarantorRooms({String search = ''}) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/visitor/guarantor-rooms', query: {'search': search})
          as Map,
    );
    return (value['items'] as List<dynamic>? ?? const [])
        .map(
          (item) => VisitorRoomOption.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<VisitorHostOption>> hostOptions(
    String hostType, {
    String search = '',
    int? roomId,
  }) async {
    final value = Map<String, dynamic>.from(
      await api.get(
            '/api/visitor/host-options',
            query: {
              'hostType': hostType,
              'search': search,
              if (roomId != null) 'roomId': roomId.toString(),
            },
          )
          as Map,
    );
    return (value['items'] as List<dynamic>? ?? const [])
        .map(
          (item) => VisitorHostOption.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> update(VisitorSettingsUpdate request) async =>
      api.put('/api/visitor/system-settings', body: request.toJson());
}

class VisitorCompanyContext {
  const VisitorCompanyContext({
    required this.businessTypeCode,
    required this.employeeAllowed,
    required this.residentAllowed,
    required this.serviceCustomerAllowed,
    required this.defaultHostType,
  });
  final String businessTypeCode;
  final bool employeeAllowed;
  final bool residentAllowed;
  final bool serviceCustomerAllowed;
  final String defaultHostType;

  bool get isDormitory => businessTypeCode == 'DORMITORY';

  factory VisitorCompanyContext.fromJson(Map<String, dynamic> json) =>
      VisitorCompanyContext(
        businessTypeCode: json['businessTypeCode']?.toString() ?? 'COMPANY',
        employeeAllowed: json['employeeAllowed'] == true,
        residentAllowed: json['residentAllowed'] == true,
        serviceCustomerAllowed: json['serviceCustomerAllowed'] == true,
        defaultHostType:
            json['defaultHostType']?.toString() ?? 'SERVICE_CUSTOMER',
      );
}

class VisitorCheckInContext {
  const VisitorCheckInContext({
    required this.contactPointId,
    required this.contactPointCode,
    required this.contactPointName,
  });

  final int contactPointId;
  final String contactPointCode;
  final String contactPointName;

  factory VisitorCheckInContext.fromJson(Map<String, dynamic> json) =>
      VisitorCheckInContext(
        contactPointId: (json['contactPointId'] as num).toInt(),
        contactPointCode: json['contactPointCode']?.toString() ?? '',
        contactPointName: json['contactPointName']?.toString() ?? '',
      );
}

class VisitorRoomOption {
  const VisitorRoomOption({
    required this.id,
    required this.code,
    this.name,
    required this.building,
    required this.floor,
  });
  final int id;
  final String code;
  final String? name;
  final String building;
  final String floor;

  factory VisitorRoomOption.fromJson(Map<String, dynamic> json) =>
      VisitorRoomOption(
        id: (json['id'] as num).toInt(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString(),
        building: json['building']?.toString() ?? '',
        floor: json['floor']?.toString() ?? '',
      );
}

class VisitorHostOption {
  const VisitorHostOption({
    required this.id,
    required this.code,
    required this.name,
    this.phone,
    this.room,
    this.building,
    this.floor,
  });
  final int id;
  final String code;
  final String name;
  final String? phone;
  final String? room;
  final String? building;
  final String? floor;

  factory VisitorHostOption.fromJson(Map<String, dynamic> json) =>
      VisitorHostOption(
        id: (json['id'] as num).toInt(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString(),
        room: json['room']?.toString(),
        building: json['building']?.toString(),
        floor: json['floor']?.toString(),
      );
}

class VisitorSettingsActions {
  const VisitorSettingsActions({
    required this.caption,
    required this.canView,
    required this.canEdit,
  });
  final String caption;
  final bool canView;
  final bool canEdit;

  factory VisitorSettingsActions.fromJson(Map<String, dynamic> json) =>
      VisitorSettingsActions(
        caption: json['caption']?.toString() ?? 'กำหนดค่าระบบ Visitor',
        canView: json['view'] == true,
        canEdit: json['edit'] == true,
      );
}

class VisitorSettings {
  const VisitorSettings({
    required this.versionId,
    required this.versionNo,
    required this.effectiveFrom,
    required this.allowManualEntry,
    required this.allowCameraCapture,
    required this.allowNationalIdReader,
    required this.requireVisitorPhone,
    required this.requireHostEmployee,
    required this.requireVisitPurpose,
    required this.requireCardImage,
    required this.requireNationalIdNumber,
    required this.requireNationalIdExpiry,
    required this.requireCheckOut,
    required this.retentionPolicyCode,
    required this.stateToken,
  });

  final int? versionId;
  final int versionNo;
  final DateTime effectiveFrom;
  final bool allowManualEntry;
  final bool allowCameraCapture;
  final bool allowNationalIdReader;
  final bool requireVisitorPhone;
  final bool requireHostEmployee;
  final bool requireVisitPurpose;
  final bool requireCardImage;
  final bool requireNationalIdNumber;
  final bool requireNationalIdExpiry;
  final bool requireCheckOut;
  final String retentionPolicyCode;
  final String stateToken;

  factory VisitorSettings.fromJson(Map<String, dynamic> json) =>
      VisitorSettings(
        versionId: (json['visitorSystemSettingVersionId'] as num?)?.toInt(),
        versionNo: (json['versionNo'] as num?)?.toInt() ?? 0,
        effectiveFrom:
            DateTime.tryParse(json['effectiveFrom']?.toString() ?? '') ??
            DateTime.now(),
        allowManualEntry: json['allowManualEntry'] != false,
        allowCameraCapture: json['allowCameraCapture'] != false,
        allowNationalIdReader: json['allowNationalIdReader'] == true,
        requireVisitorPhone: json['requireVisitorPhone'] == true,
        requireHostEmployee: json['requireHostEmployee'] != false,
        requireVisitPurpose: json['requireVisitPurpose'] != false,
        requireCardImage: json['requireCardImage'] != false,
        requireNationalIdNumber: json['requireNationalIdNumber'] == true,
        requireNationalIdExpiry: json['requireNationalIdExpiry'] == true,
        requireCheckOut: json['requireCheckOut'] != false,
        retentionPolicyCode:
            json['retentionPolicyCode']?.toString() ?? 'COMPANY_POLICY',
        stateToken: json['stateToken']?.toString() ?? '',
      );
}

class VisitorSettingsUpdate {
  const VisitorSettingsUpdate({
    required this.effectiveFrom,
    required this.source,
    required this.reason,
  });
  final DateTime effectiveFrom;
  final VisitorSettings source;
  final String reason;

  Map<String, dynamic> toJson() => {
    'effectiveFrom': _dateOnly(effectiveFrom),
    'allowManualEntry': source.allowManualEntry,
    'allowCameraCapture': source.allowCameraCapture,
    'allowNationalIdReader': false,
    'requireVisitorPhone': source.requireVisitorPhone,
    'requireHostEmployee': source.requireHostEmployee,
    'requireVisitPurpose': source.requireVisitPurpose,
    'requireCardImage': source.requireCardImage,
    'requireNationalIdNumber': source.requireNationalIdNumber,
    'requireNationalIdExpiry': source.requireNationalIdExpiry,
    'requireCheckOut': source.requireCheckOut,
    'retentionPolicyCode': source.retentionPolicyCode,
    'reason': reason.trim(),
    'stateToken': source.stateToken,
  };
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
