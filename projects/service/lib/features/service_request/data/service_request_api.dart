import '../../../core/api/api_client.dart';

class ServiceRequestApi {
  ServiceRequestApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Map<String, String> _menuCodeQuery(String? menuCode) =>
      menuCode == null ? const {} : {'menuCode': menuCode};

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/service/requests/actions') as Map,
  );

  Future<List<Map<String, dynamic>>> priorities() async =>
      (await _client.get('/api/service/requests/priority-options') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<List<Map<String, dynamic>>> subjectOptions({
    required bool selfService,
  }) async =>
      (await _client.get(
                '/api/service/requests/subject-options',
                query: {'self': '$selfService'},
              )
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<Map<String, dynamic>> filteredList({
    required String search,
    required String status,
    required bool selfService,
    required int page,
    required String menuCode,
    required String priority,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests',
          query: {
            'search': search,
            'status': status,
            'self': '$selfService',
            'page': '$page',
            'pageSize': '20',
            'menuCode': menuCode,
            'priority': priority,
          },
        )
        as Map,
  );

  Future<List<Map<String, dynamic>>> equipmentOptions({
    required bool selfService,
    String search = '',
  }) async =>
      (await _client.get(
                '/api/service/requests/equipment-options',
                query: {'self': '$selfService', 'search': search},
              )
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<void> editEquipment(
    int id, {
    required bool selfService,
    required String subject,
    required String detail,
    required String rowVersion,
    required String priorityCode,
    required int? equipmentItemId,
    String? equipmentSerial,
    bool updateSerial = false,
  }) => _client.put(
    selfService
        ? '/api/service/requests/self/$id'
        : '/api/service/requests/$id',
    body: {
      'subject': subject,
      'detail': detail,
      'rowVersion': rowVersion,
      'priorityCode': priorityCode,
      'equipmentItemId': equipmentItemId,
      'updateEquipment': true,
      'equipmentSerial': equipmentSerial,
      'updateSerial': updateSerial,
    },
  );

  Future<Map<String, dynamic>> lookup({
    String search = '',
    bool selfService = false,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests/lookup',
          query: {'search': search, 'self': '$selfService'},
        )
        as Map,
  );

  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    bool selfService = false,
    int page = 1,
    String? menuCode,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests',
          query: {
            'search': search,
            'status': status,
            'self': '$selfService',
            'page': '$page',
            'pageSize': '20',
            ..._menuCodeQuery(menuCode),
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> dispatchList({
    String search = '',
    int page = 1,
    bool? queueJump,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests',
          query: {
            'search': search,
            'status': 'NEW',
            'page': '$page',
            'pageSize': '20',
            'menuCode': '17001',
            if (queueJump != null) 'queueJump': '$queueJump',
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> repairHistory({
    String search = '',
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests/repair-history',
          query: {'search': search, 'page': '$page', 'pageSize': '20'},
        )
        as Map,
  );

  Future<Map<String, dynamic>> create({
    required bool selfService,
    int? requesterId,
    String? requesterType,
    required int? equipmentItemId,
    required String subject,
    required String detail,
    String? qrToken,
    String priorityCode = '0',
    String? equipmentSerial,
  }) async => Map<String, dynamic>.from(
    await _client.post(
          selfService ? '/api/service/requests/self' : '/api/service/requests',
          body: {
            'requesterId': requesterId,
            'requesterType': requesterType,
            'equipmentItemId': equipmentItemId,
            'subject': subject,
            'detail': detail,
            'qrToken': qrToken,
            'priorityCode': priorityCode,
            'equipmentSerial': equipmentSerial,
          },
        )
        as Map,
  );

  Future<void> edit(
    int id, {
    required bool selfService,
    required String subject,
    required String detail,
    required String rowVersion,
    String? priorityCode,
  }) => _client.put(
    selfService
        ? '/api/service/requests/self/$id'
        : '/api/service/requests/$id',
    body: {
      'subject': subject,
      'detail': detail,
      'rowVersion': rowVersion,
      'priorityCode': ?priorityCode,
    },
  );

  Future<void> delete(int id, String rowVersion, {required bool selfService}) =>
      _client.delete(
        selfService
            ? '/api/service/requests/self/$id'
            : '/api/service/requests/$id',
        query: {'rowVersion': rowVersion},
      );

  Future<List<Map<String, dynamic>>> attachments(
    int requestId, {
    String? menuCode,
  }) async {
    final value =
        await _client.get(
              '/api/service/requests/$requestId/attachments',
              query: _menuCodeQuery(menuCode),
            )
            as Map;
    return ((value['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> uploadAttachment(
    int requestId, {
    required String fileName,
    required List<int> bytes,
    bool editSelf = false,
    bool editNew = false,
  }) async => Map<String, dynamic>.from(
    await _client.upload(
          '/api/service/requests/$requestId/attachments${editSelf
              ? '?editSelf=true'
              : editNew
              ? '?editNew=true'
              : ''}',
          fileName: fileName,
          bytes: bytes,
        )
        as Map,
  );

  Future<void> deleteAttachment(
    int requestId,
    int attachmentId, {
    bool editSelf = false,
    bool editNew = false,
  }) async {
    await _client.delete(
      '/api/service/requests/$requestId/attachments/$attachmentId',
      query: editSelf
          ? {'editSelf': 'true'}
          : editNew
          ? {'editNew': 'true'}
          : const {},
    );
  }

  Future<List<int>> downloadAttachment(
    int requestId,
    int attachmentId, {
    String? menuCode,
  }) => _client.getBytes(
    '/api/service/requests/$requestId/attachments/$attachmentId',
    query: _menuCodeQuery(menuCode),
  );

  Future<Map<String, dynamic>> detail(int id, {String? menuCode}) async =>
      Map<String, dynamic>.from(
        await _client.get(
              '/api/service/requests/$id',
              query: _menuCodeQuery(menuCode),
            )
            as Map,
      );

  Future<List<Map<String, dynamic>>> technicians() async {
    final value = await _client.get('/api/service/requests/technicians') as Map;
    return ((value['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> evaluationTemplates() async =>
      Map<String, dynamic>.from(
        await _client.get('/api/service/requests/evaluation-templates') as Map,
      );

  Future<void> receive(
    int id,
    int employeeId, {
    int? evaluationTemplateId,
  }) async {
    await _client.post(
      '/api/service/requests/$id/receive',
      body: {
        'assignedEmployeeId': employeeId,
        'evaluationTemplateId': evaluationTemplateId,
      },
    );
  }

  Future<void> start(int id) async {
    await _client.post('/api/service/requests/$id/start', body: {});
  }

  Future<Map<String, dynamic>> partsLookup() async => Map<String, dynamic>.from(
    await _client.get('/api/service/requests/parts/lookup') as Map,
  );
  Future<void> complete(
    int id,
    String resolutionDetail, {
    List<Map<String, dynamic>> parts = const [],
  }) async {
    await _client.post(
      '/api/service/requests/$id/complete',
      body: {'resolutionDetail': resolutionDetail, 'parts': parts},
    );
  }

  Future<void> cancel(int id, String reason) async {
    await _client.post(
      '/api/service/requests/$id/cancel',
      body: {'cancellationReason': reason},
    );
  }
}
