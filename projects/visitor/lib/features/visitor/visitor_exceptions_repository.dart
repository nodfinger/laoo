import '../../core/api/visitor_api_client.dart';
import 'visitor_inside_repository.dart';

class VisitorExceptionsRepository {
  VisitorExceptionsRepository(this.api);

  final VisitorApiClient api;

  Future<VisitorExceptionsActions> actions() async =>
      VisitorExceptionsActions.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/exceptions/actions') as Map,
        ),
      );

  Future<VisitorExceptionsList> list({
    String search = '',
    String? exceptionType,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
      if (exceptionType != null && exceptionType.isNotEmpty)
        'exceptionType': exceptionType,
      if (dateFrom != null) 'dateFrom': _date(dateFrom),
      if (dateTo != null) 'dateTo': _date(dateTo),
    };
    return VisitorExceptionsList.fromJson(
      Map<String, dynamic>.from(
        await api.get('/api/visitor/exceptions', query: query) as Map,
      ),
    );
  }

  Future<VisitorVisitDetail> detail(int visitId) =>
      VisitorInsideRepository(api).detail(visitId);

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class VisitorExceptionsActions {
  const VisitorExceptionsActions({
    required this.caption,
    required this.canView,
  });

  factory VisitorExceptionsActions.fromJson(Map<String, dynamic> json) =>
      VisitorExceptionsActions(
        caption: json['caption']?.toString() ?? '',
        canView: json['view'] == true,
      );

  final String caption;
  final bool canView;
}

class VisitorExceptionsList {
  const VisitorExceptionsList({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory VisitorExceptionsList.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List<dynamic>? ?? const [];
    return VisitorExceptionsList(
      items: rows
          .map(
            (value) => VisitorExceptionItem.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? rows.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }

  final List<VisitorExceptionItem> items;
  final int total;
  final int page;
  final int pageSize;
}

class VisitorExceptionItem {
  const VisitorExceptionItem({
    required this.visitId,
    required this.visitorName,
    required this.hostName,
    required this.contactPointName,
    required this.occurredDate,
    required this.exceptionType,
    required this.description,
  });

  factory VisitorExceptionItem.fromJson(Map<String, dynamic> json) =>
      VisitorExceptionItem(
        visitId: (json['visitorVisitId'] as num).toInt(),
        visitorName: json['visitorName']?.toString() ?? '-',
        hostName: json['hostName']?.toString() ?? '-',
        contactPointName: json['contactPointName']?.toString() ?? '-',
        occurredDate: json['occurredDate']?.toString() ?? '',
        exceptionType: json['exceptionType']?.toString() ?? '',
        description: json['exceptionDescription']?.toString() ?? '-',
      );

  final int visitId;
  final String visitorName;
  final String hostName;
  final String contactPointName;
  final String occurredDate;
  final String exceptionType;
  final String description;

  String get typeLabel => switch (exceptionType) {
    'HOST_CONFIRMATION_PENDING' => '?????????????????',
    'CHECKOUT_OTHER' => 'Check-out ?????????? ?',
    'NOTIFICATION_FAILED' => '?????????????????????',
    'NOTIFICATION_NO_CHANNEL' => '?????????????????????',
    'CHECKOUT_RULE_MISMATCH' => '?????????????????????????',
    _ => exceptionType,
  };
}
