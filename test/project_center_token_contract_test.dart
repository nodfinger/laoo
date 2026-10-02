import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project API accepts center token before checking menu permission', () {
    final source = File(
      'projects/project/packages/dotnet/Laoo.Project.Module/Controllers/'
      'ProjectManagementController.cs',
    ).readAsStringSync();

    final scopeStart = source.indexOf('bool Scope(out long c,out long u)');
    final scopeEnd = source.indexOf(
      'async Task<SqlConnection> Open',
      scopeStart,
    );
    expect(scopeStart, greaterThanOrEqualTo(0));
    expect(scopeEnd, greaterThan(scopeStart));

    final scope = source.substring(scopeStart, scopeEnd);
    expect(scope, contains('User.FindFirstValue("user_type")=="COMPANY_USER"'));
    expect(scope, contains('User.FindFirstValue("company_id")'));
    expect(scope, contains('User.FindFirstValue("user_id")'));
    expect(scope, isNot(contains('User.FindFirstValue("project_code")')));
    expect(source, contains('CompanyMenuAccess.IsAllowedAsync'));

    final permissionSource = File(
      'packages/dotnet/Laoo.Shared.Contracts/CompanyMenuAccess.cs',
    ).readAsStringSync();
    expect(permissionSource, contains('C.CompanyID=@CompanyID'));
    expect(permissionSource, contains('C.PartnerID=@PartnerID'));
    expect(permissionSource, contains('TDADCompanyProject CP'));
    expect(permissionSource, contains('TDADUserProject UP'));
    expect(permissionSource, contains('PM.MenuCode=@MenuCode'));
    expect(permissionSource, contains('P.ActionCode=@Action'));
  });
}
