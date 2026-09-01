import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/support/company_setup/models/company_setup_model.dart';

void main() {
  test('parses partner information returned for a customer setup', () {
    final setup = CompanySetupModel.fromJson({
      'ownerType': 'C',
      'partnerID': 12,
      'partnerNameTh': 'พาร์ตเนอร์ทดสอบ',
      'partnerAddress': 'กรุงเทพมหานคร',
      'partnerTelephone': '02-000-0000',
      'partnerEmail': 'partner@example.com',
      'ownerCode': 'C000001',
      'ownerName': 'ลูกค้าทดสอบ',
      'name': 'ลูกค้าทดสอบ',
      'titleHeader': 'ลูกค้าทดสอบ',
      'rowSTD': 30,
      'rowCardSTD': 30,
      'timeAlert': 5,
      'orgStructureType': 1,
      'passwordPolicyCode': 3,
      'isActive': true,
    });

    expect(setup.partnerId, 12);
    expect(setup.partnerNameTh, 'พาร์ตเนอร์ทดสอบ');
    expect(setup.partnerAddress, 'กรุงเทพมหานคร');
    expect(setup.partnerTelephone, '02-000-0000');
    expect(setup.partnerEmail, 'partner@example.com');
  });
}
