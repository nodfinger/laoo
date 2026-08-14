import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/api/api_client.dart';

class EmployeeRepository {
  EmployeeRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, dynamic>> list({String? search, int? divisionId, int? departmentId, bool? isActive, int? companyId, bool customer = false, bool company = false, int page = 1, int pageSize = 20}) async =>
      Map<String, dynamic>.from(await _api.get(company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees', query: {
        'search': search ?? '',
        if (divisionId != null) 'divisionId': '$divisionId',
        if (departmentId != null) 'departmentId': '$departmentId',
        if (isActive != null) 'isActive': isActive ? 'true' : 'false',
        if (companyId != null) 'companyId': '$companyId',
        'page': '$page',
        'pageSize': '$pageSize',
      }) as Map);

  Future<int> create(Map<String, dynamic> body, {bool customer = false, bool company = false}) async {
    final result = await _api.post(company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees', body: body) as Map;
    return (result['employeeId'] as num).toInt();
  }
  Future<int> update(int id, Map<String, dynamic> body, {bool customer = false, bool company = false}) async {
    final result = await _api.put('${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id', body: body) as Map;
    return (result['employeeId'] as num).toInt();
  }
  Future<void> delete(int id, {int? companyId, bool customer = false, bool company = false}) async => _api.delete('${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id', query: {
    if (companyId != null) 'companyId': '$companyId',
  });

  Future<void> saveFormalImage(int id, Uint8List bytes, String fileName, {int? companyId, int width = 0, int height = 0, bool customer = false, bool company = false}) async {
    final path = '${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id/image';
    await _api.put(path, body: {
      'imageType': 'FORMAL',
      if (companyId != null) 'companyId': companyId,
      'contentType': 'image/jpeg',
      'fileName': fileName,
      'imageDataBase64': base64Encode(bytes),
      'imageWidth': width,
      'imageHeight': height,
    });
  }

  Future<void> saveCarImage(int id, int carNo, Uint8List bytes, String fileName, {int? companyId, int width = 0, int height = 0, bool customer = false, bool company = false}) async {
    final path = '${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id/car-image/$carNo';
    await _api.put(path, body: {
      'carNo': carNo,
      if (companyId != null) 'companyId': companyId,
      'contentType': 'image/jpeg',
      'fileName': fileName,
      'imageDataBase64': base64Encode(bytes),
      'imageWidth': width,
      'imageHeight': height,
    });
  }

  Future<Map<String, dynamic>?> getFormalImage(int id, {int? companyId, bool customer = false, bool company = false}) async {
    final path = '${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id/image';
    try {
      return Map<String, dynamic>.from(await _api.get(path, query: {if (companyId != null) 'companyId': '$companyId'}) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCarImage(int id, int carNo, {int? companyId, bool customer = false, bool company = false}) async {
    final path = '${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id/car-image/$carNo';
    try {
      return Map<String, dynamic>.from(await _api.get(path, query: {if (companyId != null) 'companyId': '$companyId'}) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCarImage(int id, int carNo, {int? companyId, bool customer = false, bool company = false}) async => _api.delete(
    '${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id/car-image/$carNo',
    query: {if (companyId != null) 'companyId': '$companyId'},
  );
}
