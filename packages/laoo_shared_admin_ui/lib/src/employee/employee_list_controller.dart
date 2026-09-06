import 'package:flutter/foundation.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

class EmployeeListController extends ChangeNotifier {
  EmployeeListController({
    required this.repository,
    required this.pageSize,
    required this.screenType,
  }) : assert(pageSize > 0);

  final EmployeeRepository repository;
  final int pageSize;
  final int screenType;

  List<EmployeeRecord> items = const [];
  int totalCount = 0;
  int page = 1;
  bool loading = false;
  bool canCreate = false;
  bool canEdit = false;
  bool canDelete = false;
  Object? error;

  String search = '';
  int? divisionId;
  int? departmentId;
  int? companyId;
  bool? isActive;
  bool _disposed = false;

  int get totalPages =>
      totalCount == 0 ? 1 : (totalCount + pageSize - 1) ~/ pageSize;
  int get firstRow => totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
  int get lastRow =>
      totalCount == 0 ? 0 : (firstRow + pageSize - 1).clamp(0, totalCount);

  Future<void> initialize() async {
    Map<String, bool> actions = const {};
    try {
      actions = await repository.actions();
    } catch (_) {
      // Permission loading is fail-closed.
    }
    canCreate = screenType == 1 && actions['create'] == true;
    canEdit = (screenType == 1 || screenType == 2) && actions['edit'] == true;
    canDelete = screenType == 1 && actions['delete'] == true;
    await load();
  }

  Future<void> load({int? targetPage}) async {
    if (targetPage != null) {
      page = targetPage.clamp(1, totalPages);
    }
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.list(
        search: search,
        divisionId: divisionId,
        departmentId: departmentId,
        isActive: isActive,
        companyId: companyId,
        page: page,
        pageSize: pageSize,
      );
      items = result.items;
      totalCount = result.totalCount;
      page = result.page.clamp(1, totalPages);
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> applyFilters({
    required String searchText,
    int? division,
    int? department,
    int? company,
    bool? active,
  }) {
    search = searchText.trim();
    divisionId = division;
    departmentId = department;
    companyId = company;
    isActive = active;
    page = 1;
    return load();
  }

  Future<void> clearFilters() => applyFilters(searchText: '');

  Future<void> previousPage() =>
      page > 1 ? load(targetPage: page - 1) : Future<void>.value();

  Future<void> nextPage() =>
      page < totalPages ? load(targetPage: page + 1) : Future<void>.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
