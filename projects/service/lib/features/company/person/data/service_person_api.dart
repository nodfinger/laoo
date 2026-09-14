import '../../../../core/api/api_client.dart';

class ServicePersonApi {
  ServicePersonApi({ApiClient? client, this.path = '/api/service/persons'})
    : _client = client ?? ApiClient();
  final ApiClient _client;
  final String path;

  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _client.get('$path/actions') as Map).entries.map(
      (entry) => MapEntry('${entry.key}', entry.value == true),
    ),
  );

  Future<Map<String, dynamic>> list({
    String search = '',
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          path,
          query: {
            'search': search,
            'page': '$page',
            'pageSize': '$pageSize',
            if (isActive != null) 'isActive': '$isActive',
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> lookup({int? personId, int? roomId}) async =>
      Map<String, dynamic>.from(
        await _client.get(
              '$path/lookup',
              query: {
                if (personId != null) 'includePersonId': '$personId',
                if (roomId != null) 'includeRoomId': '$roomId',
              },
            )
            as Map,
      );

  Future<void> save(Map<String, dynamic> body, {int? personId}) async {
    if (personId == null) {
      await _client.post(path, body: body);
    } else {
      await _client.put('$path/$personId', body: body);
    }
  }

  void dispose() => _client.dispose();
}
