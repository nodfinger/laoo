import 'package:laoo_shared_core/laoo_shared_core.dart';

class AttendancePeriodRepository {
  AttendancePeriodRepository(this.api);
  final JsonApiClient api;
  static const _path = '/api/time/attendance-periods';

  Future<Map<String, dynamic>> actions(String section) async =>
      Map<String, dynamic>.from(
        await api.get(
              section.isEmpty ? '$_path/actions' : '$_path/$section/actions',
            )
            as Map,
      );
  Future<List<Map<String, dynamic>>> schemes() async {
    final value = Map<String, dynamic>.from(
      await api.get('$_path/schemes') as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> saveScheme(Map<String, dynamic> body, {int? id}) async {
    if (id == null) {
      await api.post('$_path/schemes', body: body);
    } else {
      await api.put('$_path/schemes/$id', body: body);
    }
  }

  Future<void> extendScheme(int id) => api.post('$_path/schemes/$id/extend');
  Future<void> deleteScheme(int id, String rowVersion) =>
      api.delete('$_path/schemes/$id', query: {'rowVersion': rowVersion});
  Future<List<Map<String, dynamic>>> employees({String? search}) async {
    final value = Map<String, dynamic>.from(
      await api.get(
            '$_path/assignment-employees',
            query: {
              if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
            },
          )
          as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> bulkAssign(Map<String, dynamic> body) =>
      api.post('$_path/assignments/bulk', body: body);
  Future<List<Map<String, dynamic>>> periods({String? status}) async {
    final value = Map<String, dynamic>.from(
      await api.get(
            _path,
            query: {if (status?.isNotEmpty == true) 'statusCode': status!},
          )
          as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> review(int id, int branchId, String remark) => api.post(
    '$_path/$id/reviews',
    body: {'branchId': branchId, 'remark': remark},
  );
  Future<List<Map<String, dynamic>>> reviews(int id) async {
    final value = Map<String, dynamic>.from(
      await api.get('$_path/$id/reviews') as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> finalize(int id) => api.post('$_path/$id/finalize');
  Future<void> reopen(int id, String reason) =>
      api.post('$_path/$id/reopen', body: {'reason': reason});
}

String periodDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime periodDateValue(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
