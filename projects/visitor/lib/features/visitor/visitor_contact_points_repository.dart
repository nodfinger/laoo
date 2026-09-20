import 'package:laoo_shared_core/laoo_shared_core.dart';

class VisitorContactPointsRepository {
  VisitorContactPointsRepository(this.api);
  final JsonApiClient api;

  Future<VisitorContactPointActions> actions() async =>
      VisitorContactPointActions.fromJson(
        Map<String, dynamic>.from(
          await api.get('/api/visitor/contact-points/actions') as Map,
        ),
      );

  Future<VisitorContactPointList> list({
    String search = '',
    int page = 1,
  }) async => VisitorContactPointList.fromJson(
    Map<String, dynamic>.from(
      await api.get(
            '/api/visitor/contact-points',
            query: {'search': search, 'page': '$page', 'pageSize': '30'},
          )
          as Map,
    ),
  );

  Future<VisitorContactPointLookups> lookups({
    String employeeSearch = '',
    int? contactPointId,
  }) async => VisitorContactPointLookups.fromJson(
    Map<String, dynamic>.from(
      await api.get(
            '/api/visitor/contact-points/lookups',
            query: {
              'employeeSearch': employeeSearch,
              if (contactPointId != null) 'contactPointId': '$contactPointId',
            },
          )
          as Map,
    ),
  );

  Future<VisitorContactPoint> get(int id) async => VisitorContactPoint.fromJson(
    Map<String, dynamic>.from(
      await api.get('/api/visitor/contact-points/$id') as Map,
    ),
  );

  Future<void> save(VisitorContactPoint value) async {
    if (value.id == null) {
      await api.post('/api/visitor/contact-points', body: value.toJson());
    } else {
      await api.put(
        '/api/visitor/contact-points/${value.id}',
        body: value.toJson(),
      );
    }
  }

  Future<void> delete(int id) => api.delete('/api/visitor/contact-points/$id');
}

class VisitorContactPointActions {
  const VisitorContactPointActions({
    required this.caption,
    required this.view,
    required this.create,
    required this.edit,
    required this.delete,
  });
  final String caption;
  final bool view, create, edit, delete;
  factory VisitorContactPointActions.fromJson(Map<String, dynamic> json) =>
      VisitorContactPointActions(
        caption: json['caption']?.toString() ?? '33001',
        view: json['view'] == true,
        create: json['create'] == true,
        edit: json['edit'] == true,
        delete: json['delete'] == true,
      );
}

class VisitorContactPointList {
  const VisitorContactPointList({
    required this.items,
    required this.total,
    required this.page,
  });
  final List<VisitorContactPoint> items;
  final int total, page;
  factory VisitorContactPointList.fromJson(Map<String, dynamic> json) =>
      VisitorContactPointList(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (e) => VisitorContactPoint.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
      );
}

class VisitorContactPoint {
  const VisitorContactPoint({
    this.id,
    this.code = '',
    this.name = '',
    this.branchId,
    this.branchCode,
    this.branchName,
    this.isActive = true,
    this.employeeCount = 0,
    this.employeeIds = const [],
  });
  final int? id, branchId;
  final String code, name;
  final String? branchCode, branchName;
  final bool isActive;
  final int employeeCount;
  final List<int> employeeIds;
  factory VisitorContactPoint.fromJson(Map<String, dynamic> json) =>
      VisitorContactPoint(
        id: (json['id'] as num?)?.toInt(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        branchId: (json['branchId'] as num?)?.toInt(),
        branchCode: json['branchCode']?.toString(),
        branchName: json['branchName']?.toString(),
        isActive: json['isActive'] != false,
        employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
        employeeIds: (json['employeeIds'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'contactPointCode': code,
    'contactPointName': name,
    'branchId': branchId,
    'isActive': isActive,
    'employeeIds': employeeIds,
  };
  VisitorContactPoint copyWith({
    int? branchId,
    String? code,
    String? name,
    bool? isActive,
    List<int>? employeeIds,
  }) => VisitorContactPoint(
    id: id,
    branchId: branchId ?? this.branchId,
    code: code ?? this.code,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
    employeeIds: employeeIds ?? this.employeeIds,
  );
}

class VisitorContactPointLookups {
  const VisitorContactPointLookups({
    required this.branches,
    required this.employees,
  });
  final List<VisitorLookup> branches, employees;
  factory VisitorContactPointLookups.fromJson(
    Map<String, dynamic> json,
  ) => VisitorContactPointLookups(
    branches: (json['branches'] as List<dynamic>? ?? const [])
        .map((e) => VisitorLookup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    employees: (json['employees'] as List<dynamic>? ?? const [])
        .map((e) => VisitorLookup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class VisitorLookup {
  const VisitorLookup({
    required this.id,
    required this.code,
    required this.name,
    this.available = true,
  });
  final int id;
  final String code, name;
  final bool available;
  factory VisitorLookup.fromJson(Map<String, dynamic> json) => VisitorLookup(
    id: (json['id'] as num).toInt(),
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    available: json['available'] != false,
  );
}
