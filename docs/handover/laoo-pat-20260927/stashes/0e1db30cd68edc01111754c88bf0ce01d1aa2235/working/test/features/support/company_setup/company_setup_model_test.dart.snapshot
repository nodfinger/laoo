import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/support/company_setup/models/company_setup_model.dart';

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

  test('parses business type and requester context from the API', () {
    final setup = CompanySetupModel.fromJson({
      'ownerType': 'C',
      'ownerCode': 'C000001',
      'ownerName': 'Demo',
      'name': 'Demo',
      'titleHeader': 'Demo',
      'rowSTD': 30,
      'rowCardSTD': 12,
      'timeAlert': 30,
      'orgStructureType': 1,
      'passwordPolicyCode': 3,
      'businessTypeCode': 'DORMITORY',
      'requesterMode': 'RESIDENT',
      'requesterCaption': 'ผู้พักอาศัยผู้แจ้งซ่อม',
      'isBusinessTypeLocked': true,
      'isActive': true,
    });

    expect(setup.businessTypeCode, 'DORMITORY');
    expect(setup.requesterMode, 'RESIDENT');
    expect(setup.requesterCaption, 'ผู้พักอาศัยผู้แจ้งซ่อม');
    expect(setup.isBusinessTypeLocked, isTrue);
  });
}
