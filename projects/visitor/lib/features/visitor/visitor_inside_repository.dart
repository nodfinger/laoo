import 'package:laoo_shared_core/laoo_shared_core.dart';

class VisitorInsideRepository {
  VisitorInsideRepository(this.api);

  final JsonApiClient api;

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
        query: {
          'search': search,
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ) as Map,
    );
    return VisitorInsideList.fromJson(value);
  }

  Future<void> checkOut(int visitId) async {
    await api.post('/api/visitor/check-ins/$visitId/check-out');
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
          .map((item) => VisitorInside.fromJson(Map<String, dynamic>.from(item as Map)))
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
