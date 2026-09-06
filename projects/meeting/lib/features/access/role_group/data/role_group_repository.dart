import '../../../../core/api/api_client.dart';
import '../models/role_group.dart';

class RoleGroupRepository {
  RoleGroupRepository({ApiClient? client}):_client=client??ApiClient();
  final ApiClient _client;
  Future<List<RoleGroup>> list(String scope,{String? search}) async { final data=await _client.get('/api/role-groups',query:{'scope':scope,if(search!=null&&search.trim().isNotEmpty)'search':search.trim()}); if (data is! List) return const []; return data.whereType<Map<String,dynamic>>().map(RoleGroup.fromJson).toList(); }
  Future<Map<String, bool>> actions(String scope) async { final data = await _client.get('/api/role-groups/actions', query: {'scope': scope}); if (data is! Map) return const {}; return Map<String, bool>.fromEntries(data.entries.map((entry) => MapEntry('${entry.key}', entry.value == true))); }
  Future<void> create(String scope,RoleGroup group) async { await _client.post('/api/role-groups?scope=$scope',body:group.toJson()); }
  Future<void> update(String scope,RoleGroup group) async { await _client.put('/api/role-groups/${group.id}?scope=$scope',body:group.toJson()); }
  Future<void> delete(String scope,int id) async { await _client.delete('/api/role-groups/$id',query:{'scope':scope}); }
}
