import '../../../core/api/api_client.dart';

class EmployeeBorrowApi {
  EmployeeBorrowApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  static const _root = '/api/company/employee-borrow';

  Future<Map<String, bool>> actions(String menuCode) async =>
      Map<String, bool>.from(
        await _client.get('$_root/actions/$menuCode') as Map,
      );

  Future<Map<String, dynamic>> lookup() async =>
      Map<String, dynamic>.from(await _client.get('$_root/lookup') as Map);

  Future<List<Map<String, dynamic>>> requests(
    String menuCode, {
    String? status,
  }) async => List<Map<String, dynamic>>.from(
    await _client.get(
          '$_root/requests',
          query: {
            'menuCode': menuCode,
            if (status != null && status.isNotEmpty) 'status': status,
          },
        )
        as List,
  );

  Future<Map<String, dynamic>> detail(int id) async =>
      Map<String, dynamic>.from(
        await _client.get('$_root/requests/$id') as Map,
      );

  Future<List<int>> photo(int photoID) =>
      _client.getBytes('$_root/photos/$photoID');

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('$_root/requests', body: body) as Map,
      );

  Future<Map<String, dynamic>> approve(int id) async =>
      Map<String, dynamic>.from(
        await _client.post('$_root/requests/$id/approve') as Map,
      );

  Future<Map<String, dynamic>> reject(int id, String reason) async =>
      Map<String, dynamic>.from(
        await _client.post(
              '$_root/requests/$id/reject',
              body: {'reason': reason},
            )
            as Map,
      );

  Future<Map<String, dynamic>> cancel(int id) async =>
      Map<String, dynamic>.from(
        await _client.post('$_root/requests/$id/cancel') as Map,
      );

  Future<Map<String, dynamic>> transfer({
    required int requestID,
    required int lineID,
    required bool returning,
    required String fileName,
    required List<int> bytes,
    required num quantity,
    int? instanceID,
    String? conditionNote,
  }) async => Map<String, dynamic>.from(
    await _client.upload(
          '$_root/requests/$requestID/lines/$lineID/${returning ? 'return' : 'issue'}',
          fileName: fileName,
          bytes: bytes,
          fields: {
            'quantity': '$quantity',
            if (instanceID != null) 'itemInstanceID': '$instanceID',
            if (conditionNote != null) 'conditionNote': conditionNote,
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> itemPolicy(int itemID) async =>
      Map<String, dynamic>.from(
        await _client.get('$_root/item-policy/$itemID') as Map,
      );

  Future<void> saveItemPolicy(int itemID, Map<String, dynamic> body) async =>
      _client.put('$_root/item-policy/$itemID', body: body);

  Future<List<Map<String, dynamic>>> routes() async =>
      List<Map<String, dynamic>>.from(
        await _client.get('$_root/routes') as List,
      );

  Future<List<Map<String, dynamic>>> approvers() async =>
      List<Map<String, dynamic>>.from(
        await _client.get('$_root/approvers') as List,
      );

  Future<void> addRoute(Map<String, dynamic> body) async =>
      _client.post('$_root/routes', body: body);

  void dispose() => _client.dispose();
}
