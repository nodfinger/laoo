import '../../core/api/visitor_api_client.dart';
import 'visitor_inside_repository.dart';

class VisitorHistoryRepository {
  VisitorHistoryRepository(this.api);

  final VisitorApiClient api;

  Future<VisitorHistoryActions> actions() async =>
      VisitorHistoryActions.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/check-ins/history/actions') as Map,
        ),
      );

  Future<VisitorHistoryList> list({
    String search = '',
    String? outcomeCode,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
      if (outcomeCode != null && outcomeCode.isNotEmpty)
        'outcomeCode': outcomeCode,
      if (dateFrom != null) 'dateFrom': _date(dateFrom),
      if (dateTo != null) 'dateTo': _date(dateTo),
    };
    return VisitorHistoryList.fromJson(
      Map<String, dynamic>.from(
        await api.get('/api/visitor/check-ins/history', query: query) as Map,
      ),
    );
  }

  Future<VisitorVisitDetail> detail(int visitId) =>
      VisitorInsideRepository(api).detail(visitId);

  Future<List<int>> imageBytes(int visitId, int imageId) =>
      VisitorInsideRepository(api).imageBytes(visitId, imageId);

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class VisitorHistoryActions {
  const VisitorHistoryActions({required this.caption, required this.canView});

  factory VisitorHistoryActions.fromJson(Map<String, dynamic> json) =>
      VisitorHistoryActions(
        caption: json['caption']?.toString() ?? 'ประวัติผู้มาติดต่อ',
        canView: json['view'] == true,
      );

  final String caption;
  final bool canView;
}

class VisitorHistoryList {
  const VisitorHistoryList({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory VisitorHistoryList.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List<dynamic>? ?? const [];
    return VisitorHistoryList(
      items: rows
          .map(
            (value) => VisitorHistoryItem.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? rows.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }

  final List<VisitorHistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
}

class VisitorHistoryItem {
  const VisitorHistoryItem({
    required this.id,
    required this.visitorName,
    required this.hostName,
    required this.contactPointName,
    required this.visitPurpose,
    required this.checkedInDate,
    required this.checkedOutDate,
    required this.outcomeCode,
    required this.reasonCode,
  });

  factory VisitorHistoryItem.fromJson(Map<String, dynamic> json) =>
      VisitorHistoryItem(
        id: (json['visitorVisitId'] as num).toInt(),
        visitorName: json['visitorName']?.toString() ?? '',
        hostName: json['hostName']?.toString() ?? '-',
        contactPointName: json['contactPointName']?.toString() ?? '-',
        visitPurpose: json['visitPurpose']?.toString() ?? '-',
        checkedInDate: json['checkedInDate']?.toString() ?? '',
        checkedOutDate: json['checkedOutDate']?.toString() ?? '',
        outcomeCode: json['visitOutcomeCode']?.toString() ?? '',
        reasonCode: json['checkoutReasonCode']?.toString() ?? '',
      );

  final int id;
  final String visitorName;
  final String hostName;
  final String contactPointName;
  final String visitPurpose;
  final String checkedInDate;
  final String checkedOutDate;
  final String outcomeCode;
  final String reasonCode;

  String get outcomeLabel => switch (outcomeCode) {
    'MET' => 'เข้าพบสำเร็จ',
    'NOT_MET' => 'ไม่ได้เข้าพบ',
    'CANCELLED' => 'ยกเลิกการเข้าพบ',
    _ => outcomeCode.isEmpty ? '-' : outcomeCode,
  };

  String get reasonLabel => switch (reasonCode) {
    'NORMAL' => 'ออกตามปกติ',
    'HOST_ABSENT' => 'ไม่พบผู้รับรอง',
    'VISITOR_LEFT' => 'ผู้มาติดต่อออกก่อนเข้าพบ',
    'FORGOT_MEETING_CONFIRMATION' => 'เข้าพบแล้วแต่ลืมยืนยัน',
    'OTHER' => 'อื่น ๆ',
    _ => reasonCode.isEmpty ? '-' : reasonCode,
  };
}
