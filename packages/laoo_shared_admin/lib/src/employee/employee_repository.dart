import 'dart:convert';
import 'dart:typed_data';

import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'employee_models.dart';
import 'employee_screen_contracts.dart';

class EmployeeRepository {
  EmployeeRepository(this._api, {required this.scope});

  final JsonApiClient _api;
  final EmployeeOwnerScope scope;

  ScreenContract get contract => EmployeeScreenContracts.forScope(scope);

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('${contract.apiPath}/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry(entry.key.toString(), entry.value == true),
      ),
    );
  }

  Future<EmployeeListResult> list({
    String? search,
    int? divisionId,
    int? departmentId,
    bool? isActive,
    int? companyId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get(
      contract.apiPath,
      query: {
        'search': search ?? '',
        if (divisionId != null) 'divisionId': '$divisionId',
        if (departmentId != null) 'departmentId': '$departmentId',
        if (isActive != null) 'isActive': isActive ? 'true' : 'false',
        if (companyId != null) 'companyId': '$companyId',
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    return EmployeeListResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<int> create(Object request) async {
    final body = request is EmployeeUpsertRequest ? request.toJson() : request;
    final result = await _api.post(contract.apiPath, body: body);
    return ((result as Map)['employeeId'] as num).toInt();
  }

  Future<int> update(int id, Object request) async {
    final body = request is EmployeeUpsertRequest ? request.toJson() : request;
    final result = await _api.put('${contract.apiPath}/$id', body: body);
    return ((result as Map)['employeeId'] as num).toInt();
  }

  Future<void> delete(int id, {int? companyId}) async {
    await _api.delete(
      '${contract.apiPath}/$id',
      query: {if (companyId != null) 'companyId': '$companyId'},
    );
  }

  Future<void> saveFormalImage(
    int id,
    Uint8List bytes,
    String fileName, {
    int? companyId,
    int width = 0,
    int height = 0,
  }) async {
    await _api.put(
      '${contract.apiPath}/$id/image',
      body: {
        'imageType': 'FORMAL',
        'companyId': companyId,
        'contentType': 'image/jpeg',
        'fileName': fileName,
        'imageDataBase64': base64Encode(bytes),
        'imageWidth': width,
        'imageHeight': height,
      },
    );
  }

  Future<void> saveCarImage(
    int id,
    int carNo,
    Uint8List bytes,
    String fileName, {
    int? companyId,
    int width = 0,
    int height = 0,
  }) async {
    await _api.put(
      '${contract.apiPath}/$id/car-image/$carNo',
      body: {
        'carNo': carNo,
        'companyId': companyId,
        'contentType': 'image/jpeg',
        'fileName': fileName,
        'imageDataBase64': base64Encode(bytes),
        'imageWidth': width,
        'imageHeight': height,
      },
    );
  }

  Future<Map<String, dynamic>?> getFormalImage(int id, {int? companyId}) =>
      _getOptionalMap('${contract.apiPath}/$id/image', companyId);

  Future<Map<String, dynamic>?> getCarImage(
    int id,
    int carNo, {
    int? companyId,
  }) => _getOptionalMap('${contract.apiPath}/$id/car-image/$carNo', companyId);

  Future<void> deleteCarImage(int id, int carNo, {int? companyId}) async {
    await _api.delete(
      '${contract.apiPath}/$id/car-image/$carNo',
      query: {if (companyId != null) 'companyId': '$companyId'},
    );
  }

  Future<void> createEmployeeUser(
    int id,
    String username,
    String password, {
    int? companyId,
  }) async {
    await _api.post(
      '${contract.apiPath}/$id/user',
      body: {
        'username': username,
        'password': password,
        'companyId': companyId,
      },
    );
  }

  Future<EmployeeUserRecord> getEmployeeUser(int id, {int? companyId}) async {
    final data = await _api.get(
      '${contract.apiPath}/$id/user',
      query: {if (companyId != null) 'companyId': '$companyId'},
    );
    return EmployeeUserRecord.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> upsertEmployeeUser(
    int id,
    String username,
    String? password, {
    int? companyId,
    int? roleGroupId,
  }) async {
    await _api.put(
      '${contract.apiPath}/$id/user',
      body: {
        'username': username,
        if (password != null && password.isNotEmpty) 'password': password,
        'companyId': companyId,
        'roleGroupId': roleGroupId,
      },
    );
  }

  Future<Map<String, dynamic>?> _getOptionalMap(
    String path,
    int? companyId,
  ) async {
    try {
      return Map<String, dynamic>.from(
        await _api.get(
              path,
              query: {if (companyId != null) 'companyId': '$companyId'},
            )
            as Map,
      );
    } catch (_) {
      return null;
    }
  }
}
