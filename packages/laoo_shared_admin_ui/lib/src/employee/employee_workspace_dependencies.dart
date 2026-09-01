import '../shared/shared_admin_ui_tokens.dart';

class EmployeeCompanyOption {
  const EmployeeCompanyOption({required this.id, required this.name});

  final int id;
  final String name;
}

class EmployeeRoleGroupOption {
  const EmployeeRoleGroupOption({required this.id, required this.name});

  final int id;
  final String name;
}

class EmployeeMasterOption {
  const EmployeeMasterOption({required this.code, required this.name});

  final String code;
  final String name;
}

typedef EmployeeCompanyLoader = Future<List<EmployeeCompanyOption>> Function();
typedef EmployeeRoleGroupLoader =
    Future<List<EmployeeRoleGroupOption>> Function();
typedef EmployeeMasterLoader =
    Future<List<EmployeeMasterOption>> Function(String masterGroupCode);
typedef EmployeeViewModeLoader = Future<bool> Function();
typedef EmployeeViewModeSaver = Future<void> Function(bool cardMode);
typedef EmployeeDateText = String Function(DateTime value);

class EmployeeWorkspaceDependencies {
  const EmployeeWorkspaceDependencies({
    required this.loadCompanies,
    required this.loadRoleGroups,
    required this.loadMaster,
    required this.loadCardMode,
    required this.saveCardMode,
    required this.formatDate,
    required this.errorText,
  });

  final EmployeeCompanyLoader loadCompanies;
  final EmployeeRoleGroupLoader loadRoleGroups;
  final EmployeeMasterLoader loadMaster;
  final EmployeeViewModeLoader loadCardMode;
  final EmployeeViewModeSaver saveCardMode;
  final EmployeeDateText formatDate;
  final SharedAdminErrorText errorText;
}
