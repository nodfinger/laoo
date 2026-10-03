import '../../../../core/api/api_client.dart';

class ProjectPackageSummary {
  const ProjectPackageSummary({
    required this.projectId,
    required this.projectCode,
    required this.projectName,
    this.packageId,
    this.packageCode,
    this.packageName,
    this.tierCode,
    this.billingCycle,
    this.price = 0,
    this.trialDays = 0,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ProjectPackageSummary.fromJson(Map<String, dynamic> json) =>
      ProjectPackageSummary(
        projectId: json['projectId'] as int,
        projectCode: '${json['projectCode'] ?? ''}',
        projectName: '${json['projectNameTh'] ?? ''}',
        packageId: json['packageId'] as int?,
        packageCode: json['packageCode'] as String?,
        packageName: json['packageNameTh'] as String?,
        tierCode: json['tierCode'] as String?,
        billingCycle: json['billingCycle'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        trialDays: json['trialDays'] as int? ?? 0,
        sortOrder: json['sortOrder'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );

  final int projectId;
  final String projectCode;
  final String projectName;
  final int? packageId;
  final String? packageCode;
  final String? packageName;
  final String? tierCode;
  final String? billingCycle;
  final double price;
  final int trialDays;
  final int sortOrder;
  final bool isActive;
}

class ProjectPackageRepository {
  ProjectPackageRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<List<ProjectPackageSummary>> getPackages() async {
    final data = await _api.get('/api/support/project-packages');
    return (data as List)
        .map((x) => ProjectPackageSummary.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getDetail(int packageId) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/support/project-packages/$packageId') as Map,
      );

  Future<List<Map<String, dynamic>>> getFeatureOptions(int projectId) async {
    final data = await _api.get(
      '/api/support/project-packages/options/$projectId',
    );
    return (data as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  Future<void> save(Map<String, dynamic> body, {int? packageId}) async {
    if (packageId == null) {
      await _api.post('/api/support/project-packages', body: body);
    } else {
      await _api.put('/api/support/project-packages/$packageId', body: body);
    }
  }
}
