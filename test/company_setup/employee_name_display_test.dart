import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/company_setup/company_setup_context.dart';
import 'package:laoo/features/support/company_setup/models/company_setup_constants.dart';
import 'package:laoo/features/support/company_setup/models/company_setup_model.dart';

void main() {
  test('company name display defaults safely to full name', () {
    expect(CompanySetupContext.fromJson({}).employeeNameDisplay, 'FULL');
    expect(CompanySetupModel.fromJson({}).employeeNameDisplay, 'FULL');
  });

  test('three supported values survive settings and runtime parsing', () {
    for (final mode in CompanySetupConstants.employeeNameOptions) {
      expect(
        CompanySetupContext.fromJson({
          'employeeNameDisplay': mode,
        }).employeeNameDisplay,
        mode,
      );
      expect(
        CompanySetupModel.fromJson({
          'employeeNameDisplay': mode,
        }).employeeNameDisplay,
        mode,
      );
    }
  });
}
