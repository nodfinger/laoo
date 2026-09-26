import '../../core/api/visitor_api_client.dart';

class VisitorInsideRepository {
  VisitorInsideRepository(this.api);

  final VisitorApiClient api;

  Future<VisitorInsideActions> actions() async => VisitorInsideActions.fromJson(
    Map<String, dynamic>.from(
      await api.get('/api/visitor/check-ins/inside/actions') as Map,
    ),
  );

  Future<VisitorInsideList> list({
    String search = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final value = Map<String, dynamic>.from(
      await api.get(
            '/api/visitor/check-ins/inside',
            query: {'search': search, 'page': '$page', 'pageSize': '$pageSize'},
          )
          as Map,
    );
    return VisitorInsideList.fromJson(value);
  }

  Future<void> checkOut(
    int visitId, {
    required String outcomeCode,
    required String reasonCode,
    String? note,
  }) async {
    await api.post(
      '/api/visitor/check-ins/$visitId/check-out',
      body: {
        'visitOutcomeCode': outcomeCode,
        'checkoutReasonCode': reasonCode,
        'checkoutNote': note,
      },
    );
  }

  Future<VisitorVisitDetail> detail(int visitId) async =>
      VisitorVisitDetail.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/check-ins/$visitId') as Map,
        ),
      );

  Future<List<Map<String, dynamic>>> audit(int visitId) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/visitor/check-ins/$visitId/audit') as Map,
    );
    return (value['items'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<int>> imageBytes(int visitId, int imageId) =>
      api.getBytes('/api/visitor/check-ins/$visitId/images/$imageId');

  Future<void> addNote(
    int visitId,
    String text, {
    String stage = 'GENERAL',
  }) async {
    await api.post(
      '/api/visitor/check-ins/$visitId/notes',
      body: {'noteStageCode': stage, 'noteText': text},
    );
  }

  Future<void> retryNotification(int visitId) =>
      api.post('/api/visitor/check-ins/$visitId/notification/retry');

  Future<void> uploadEvidence(
    int visitId, {
    required List<int> bytes,
    required String fileName,
    required String evidenceType,
    required String captureStage,
    String? side,
  }) async {
    await api.upload(
      '/api/visitor/check-ins/$visitId/images',
      bytes: bytes,
      fileName: fileName,
      fields: {
        'evidenceType': evidenceType,
        'captureStage': captureStage,
        'side': ?side,
      },
    );
  }
}

class VisitorInsideActions {
  const VisitorInsideActions({
    required this.caption,
    required this.canView,
    required this.canCreate,
    required this.canEdit,
  });

  factory VisitorInsideActions.fromJson(Map<String, dynamic> json) =>
      VisitorInsideActions(
        caption: json['caption']?.toString() ?? 'ผู้มาติดต่อภายใน',
        canView: json['view'] == true,
        canCreate: json['create'] == true,
        canEdit: json['edit'] == true,
      );

  final String caption;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
}

class VisitorInsideList {
  const VisitorInsideList({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory VisitorInsideList.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List<dynamic>? ?? const [];
    return VisitorInsideList(
      items: rows
          .map(
            (item) =>
                VisitorInside.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? rows.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }

  final List<VisitorInside> items;
  final int total;
  final int page;
  final int pageSize;
}

class VisitorInside {
  const VisitorInside({
    required this.id,
    required this.name,
    required this.host,
    required this.point,
    required this.timeIn,
  });

  factory VisitorInside.fromJson(Map<String, dynamic> json) => VisitorInside(
    id: (json['visitorVisitId'] as num).toInt(),
    name: json['visitorName']?.toString() ?? '',
    host: json['hostName']?.toString() ?? '',
    point: json['contactPointName']?.toString() ?? '',
    timeIn: json['checkedInDate']?.toString() ?? '',
  );

  final int id;
  final String name;
  final String host;
  final String point;
  final String timeIn;
}

class VisitorVisitDetail {
  const VisitorVisitDetail({
    required this.visit,
    required this.images,
    required this.notes,
    required this.notifications,
  });

  factory VisitorVisitDetail.fromJson(Map<String, dynamic> json) =>
      VisitorVisitDetail(
        visit: Map<String, dynamic>.from(json['visit'] as Map? ?? const {}),
        images: (json['images'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(growable: false),
        notes: (json['notes'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(growable: false),
        notifications: (json['notifications'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(growable: false),
      );

  final Map<String, dynamic> visit;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> notifications;
}
