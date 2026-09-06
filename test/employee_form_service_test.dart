import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

void main() {
  group('EmployeeFormInput validation', () {
    test('requires at least one notification channel', () {
      final input = _validInput(notifyByEmail: false, notifyInSystem: false);

      expect(input.validate(organizationMode: 1), isNotNull);
    });

    test('requires an email when email notification is enabled', () {
      final input = _validInput(notifyByEmail: true, email: null);

      expect(input.validate(organizationMode: 1), contains('Email'));
    });

    test('requires division only for two-level organizations', () {
      final input = _validInput(divisionOrgUnitId: null);

      expect(input.validate(organizationMode: 1), isNull);
      expect(input.validate(organizationMode: 2), isNotNull);
    });
  });

  test('create saves employee, images, and user in order', () async {
    final api = _RecordingApi();
    final service = EmployeeFormService(
      EmployeeRepository(api, scope: EmployeeOwnerScope.company),
    );
    final input = _validInput(
      companyId: 9,
      username: 'employee.one',
      password: 'secret',
      roleGroupId: 4,
      formalImage: EmployeeImageInput(
        bytes: Uint8List.fromList([1, 2]),
        fileName: 'formal.jpg',
        width: 320,
        height: 480,
      ),
      carImage1: EmployeeImageInput(
        bytes: Uint8List.fromList([3, 4]),
        fileName: 'car.jpg',
      ),
    );

    final id = await service.save(input, organizationMode: 1);

    expect(id, 17);
    expect(api.calls.map((call) => call.path), [
      '/api/company/employees',
      '/api/company/employees/17/image',
      '/api/company/employees/17/car-image/1',
      '/api/company/employees/17/user',
    ]);
    expect(api.calls.first.method, 'POST');
    expect(api.calls.first.body?['employeeCode'], 'E001');
    expect(api.calls[1].body?['companyId'], 9);
    expect(api.calls.last.body?['roleGroupId'], 4);
    expect(api.calls.last.body?['password'], 'secret');
  });

  test('edit updates employee and omits an empty password', () async {
    final api = _RecordingApi();
    final service = EmployeeFormService(
      EmployeeRepository(api, scope: EmployeeOwnerScope.partnerCustomer),
    );
    final input = _validInput(
      employeeId: 23,
      companyId: 9,
      username: 'employee.one',
      password: '',
      roleGroupId: 4,
    );

    final id = await service.save(input, organizationMode: 1);

    expect(id, 23);
    expect(api.calls.first.method, 'PUT');
    expect(api.calls.first.path, '/api/partner/customer-employees/23');
    expect(api.calls.last.path, '/api/partner/customer-employees/23/user');
    expect(api.calls.last.body, isNot(contains('password')));
  });
}

EmployeeFormInput _validInput({
  int? employeeId,
  int? companyId,
  int? divisionOrgUnitId = 2,
  bool notifyByEmail = false,
  bool notifyInSystem = true,
  String? email,
  String? username,
  String? password,
  int? roleGroupId,
  EmployeeImageInput? formalImage,
  EmployeeImageInput? carImage1,
}) => EmployeeFormInput(
  employeeId: employeeId,
  companyId: companyId,
  divisionOrgUnitId: divisionOrgUnitId,
  departmentOrgUnitId: 3,
  employeeCode: ' E001 ',
  fullName: ' Employee One ',
  email: email,
  notifyByEmail: notifyByEmail,
  notifyInSystem: notifyInSystem,
  username: username,
  password: password,
  roleGroupId: roleGroupId,
  formalImage: formalImage,
  carImage1: carImage1,
);

class _ApiCall {
  const _ApiCall(this.method, this.path, this.body);

  final String method;
  final String path;
  final Map<String, dynamic>? body;
}

class _RecordingApi implements JsonApiClient {
  final List<_ApiCall> calls = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async => <String, dynamic>{};

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    calls.add(_ApiCall('POST', path, _map(body)));
    return {'employeeId': 17};
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    calls.add(_ApiCall('PUT', path, _map(body)));
    if (RegExp(r'/employees/\d+$').hasMatch(path) ||
        path.contains('/customer-employees/')) {
      return {'employeeId': _employeeId(path)};
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => <String, dynamic>{};

  static Map<String, dynamic>? _map(Object? body) =>
      body is Map ? Map<String, dynamic>.from(body) : null;

  static int _employeeId(String path) =>
      int.parse(RegExp(r'/(\d+)(?:/|$)').firstMatch(path)!.group(1)!);
}
