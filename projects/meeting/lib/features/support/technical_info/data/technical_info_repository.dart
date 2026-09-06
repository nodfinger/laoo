import '../../../../core/api/api_client.dart';

class TechnicalInfoRepository {
  TechnicalInfoRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<TechnicalInfoResult> search(String query) async {
    final data = await _api.get('/api/technical-info/search', query: {'q': query});
    return TechnicalInfoResult.fromJson(data as Map<String, dynamic>);
  }

  Future<TechnicalFileContent> readFile(String path) async {
    final data = await _api.get('/api/technical-info/file-content', query: {'path': path});
    final json = data as Map<String, dynamic>;
    return TechnicalFileContent(
      path: '${json['path'] ?? path}',
      content: '${json['content'] ?? ''}',
    );
  }
}

class TechnicalFileContent {
  const TechnicalFileContent({required this.path, required this.content});
  final String path;
  final String content;
}

class TechnicalInfoResult {
  const TechnicalInfoResult({required this.menus, required this.dartFiles, required this.mds, required this.tables});
  final List<Map<String, dynamic>> menus;
  final List<Map<String, dynamic>> dartFiles;
  final List<Map<String, dynamic>> mds;
  final List<Map<String, dynamic>> tables;
  factory TechnicalInfoResult.fromJson(Map<String, dynamic> json) => TechnicalInfoResult(
    menus: List<Map<String, dynamic>>.from(json['menus'] as List? ?? const []),
    dartFiles: List<Map<String, dynamic>>.from(json['dartFiles'] as List? ?? const []),
    mds: List<Map<String, dynamic>>.from(json['mds'] as List? ?? const []),
    tables: List<Map<String, dynamic>>.from(json['tables'] as List? ?? const []),
  );
}
