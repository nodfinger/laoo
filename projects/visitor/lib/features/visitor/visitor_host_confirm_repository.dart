import '../../core/api/visitor_api_client.dart';

class VisitorHostConfirmRepository {
  VisitorHostConfirmRepository(this._api);
  final VisitorApiClient _api;

  Future<HostConfirmActions> actions() async => HostConfirmActions.fromJson(
    Map<String, dynamic>.from(
      await _api.get('/api/visitor/host-confirm/actions') as Map,
    ),
  );

  Future<List<HostConfirmVisit>> pending() async {
    final value = Map<String, dynamic>.from(
      await _api.get('/api/visitor/host-confirm/pending') as Map,
    );
    return (value['items'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              HostConfirmVisit.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<HostConfirmDetail> detail(int id) async => HostConfirmDetail.fromJson(
    Map<String, dynamic>.from(
      await _api.get('/api/visitor/host-confirm/visits/$id') as Map,
    ),
  );

  Future<List<int>> imageBytes(int visitId, int imageId) => _api.getBytes(
    '/api/visitor/host-confirm/visits/$visitId/images/$imageId',
  );

  Future<void> confirm(int id, String result, String? note) => _api.post(
    '/api/visitor/host-confirm/visits/$id',
    body: {'confirmationResultCode': result, 'confirmationNote': note},
  );
}

class HostConfirmActions {
  const HostConfirmActions({
    required this.caption,
    required this.canView,
    required this.canEdit,
  });
  factory HostConfirmActions.fromJson(Map<String, dynamic> json) =>
      HostConfirmActions(
        caption: json['caption']?.toString() ?? 'ยืนยันการเข้าพบ',
        canView: json['view'] == true,
        canEdit: json['edit'] == true,
      );
  final String caption;
  final bool canView;
  final bool canEdit;
}

class HostConfirmVisit {
  const HostConfirmVisit({
    required this.id,
    required this.visitorName,
    required this.hostName,
    required this.contactPointName,
    required this.purpose,
    required this.checkedInDate,
  });
  factory HostConfirmVisit.fromJson(Map<String, dynamic> json) =>
      HostConfirmVisit(
        id: (json['visitorVisitId'] as num).toInt(),
        visitorName: json['visitorName']?.toString() ?? '',
        hostName: json['hostName']?.toString() ?? '',
        contactPointName: json['contactPointName']?.toString() ?? '',
        purpose: json['visitPurpose']?.toString() ?? '',
        checkedInDate: json['checkedInDate']?.toString() ?? '',
      );
  final int id;
  final String visitorName;
  final String hostName;
  final String contactPointName;
  final String purpose;
  final String checkedInDate;
}

class HostConfirmDetail {
  const HostConfirmDetail({required this.visit, required this.images});
  factory HostConfirmDetail.fromJson(Map<String, dynamic> json) =>
      HostConfirmDetail(
        visit: Map<String, dynamic>.from(json['visit'] as Map? ?? const {}),
        images: (json['images'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false),
      );
  final Map<String, dynamic> visit;
  final List<Map<String, dynamic>> images;
}
