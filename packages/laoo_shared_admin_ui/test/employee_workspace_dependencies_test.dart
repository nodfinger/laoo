import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  test('employee dependencies preserve project-specific adapters', () async {
    var savedCardMode = false;
    final dependencies = EmployeeWorkspaceDependencies(
      loadCompanies: () async => const [
        EmployeeCompanyOption(id: 7, name: 'Customer A'),
      ],
      loadRoleGroups: () async => const [
        EmployeeRoleGroupOption(id: 3, name: 'Supervisor'),
      ],
      loadMaster: (groupCode) async => [
        EmployeeMasterOption(code: groupCode, name: 'Master'),
      ],
      loadCardMode: () async => true,
      saveCardMode: (value) async => savedCardMode = value,
      formatDate: (value) => value.toIso8601String().split('T').first,
      errorText: (error) => error.toString(),
    );

    expect((await dependencies.loadCompanies()).single.id, 7);
    expect((await dependencies.loadRoleGroups()).single.id, 3);
    expect((await dependencies.loadMaster('CAR')).single.code, 'CAR');
    expect(await dependencies.loadCardMode(), isTrue);
    await dependencies.saveCardMode(true);
    expect(savedCardMode, isTrue);
    expect(dependencies.formatDate(DateTime(2026, 9)), '2026-09-01');
  });
}
