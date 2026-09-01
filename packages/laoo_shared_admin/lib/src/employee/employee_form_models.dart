import 'dart:typed_data';

import 'employee_models.dart';
import 'employee_repository.dart';

class EmployeeEmergencyContactInput {
  const EmployeeEmergencyContactInput({this.name, this.relation, this.phone});

  final String? name;
  final String? relation;
  final String? phone;
}

class EmployeeVehicleInput {
  const EmployeeVehicleInput({
    this.registration,
    this.color,
    this.typeCode,
    this.oilTypeCode,
  });

  final String? registration;
  final String? color;
  final String? typeCode;
  final String? oilTypeCode;
}

class EmployeeImageInput {
  const EmployeeImageInput({
    required this.bytes,
    required this.fileName,
    this.width = 0,
    this.height = 0,
  });

  final Uint8List bytes;
  final String fileName;
  final int width;
  final int height;
}

class EmployeeFormInput {
  const EmployeeFormInput({
    this.employeeId,
    this.companyId,
    this.divisionOrgUnitId,
    this.departmentOrgUnitId,
    required this.employeeCode,
    required this.fullName,
    this.nickName,
    this.positionCode,
    this.email,
    required this.notifyByEmail,
    required this.notifyInSystem,
    this.telephone,
    this.contact1 = const EmployeeEmergencyContactInput(),
    this.contact2 = const EmployeeEmergencyContactInput(),
    this.vehicle1 = const EmployeeVehicleInput(),
    this.vehicle2 = const EmployeeVehicleInput(),
    this.startWorkDate,
    this.isActive = true,
    this.username,
    this.password,
    this.roleGroupId,
    this.formalImage,
    this.carImage1,
    this.carImage2,
  });

  final int? employeeId;
  final int? companyId;
  final int? divisionOrgUnitId;
  final int? departmentOrgUnitId;
  final String employeeCode;
  final String fullName;
  final String? nickName;
  final String? positionCode;
  final String? email;
  final bool notifyByEmail;
  final bool notifyInSystem;
  final String? telephone;
  final EmployeeEmergencyContactInput contact1;
  final EmployeeEmergencyContactInput contact2;
  final EmployeeVehicleInput vehicle1;
  final EmployeeVehicleInput vehicle2;
  final DateTime? startWorkDate;
  final bool isActive;
  final String? username;
  final String? password;
  final int? roleGroupId;
  final EmployeeImageInput? formalImage;
  final EmployeeImageInput? carImage1;
  final EmployeeImageInput? carImage2;

  bool get editing => employeeId != null;

  String? validate({required int organizationMode}) {
    final normalizedEmail = _text(email);
    final normalizedUsername = _text(username);
    final normalizedPassword = password?.trim() ?? '';
    if (!notifyByEmail && !notifyInSystem) {
      return 'กรุณาเลือกรูปแบบแจ้งเตือนอย่างน้อย 1 รูปแบบ';
    }
    if (notifyByEmail && normalizedEmail == null) {
      return 'กรุณาระบุ Email เมื่อเลือกรับการแจ้งเตือนทาง Email';
    }
    if (normalizedEmail != null &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      return 'รูปแบบ Email ไม่ถูกต้อง';
    }
    if (employeeCode.trim().isEmpty || fullName.trim().isEmpty) {
      return 'กรุณากรอกรหัสพนักงานและชื่อ-นามสกุล';
    }
    if (departmentOrgUnitId == null ||
        (organizationMode == 2 && divisionOrgUnitId == null)) {
      return organizationMode == 2
          ? 'กรุณาเลือกฝ่ายและแผนกก่อนบันทึก'
          : 'กรุณาเลือกแผนกก่อนบันทึก';
    }
    if (normalizedUsername != null && !editing && normalizedPassword.isEmpty) {
      return 'กรุณากรอก Username และ Password ให้ครบ';
    }
    if (normalizedUsername != null && roleGroupId == null) {
      return 'กรุณาเลือกกลุ่มสิทธิ์';
    }
    return null;
  }

  EmployeeUpsertRequest toRequest() => EmployeeUpsertRequest.fromJson({
    'companyId': companyId,
    'divisionOrgUnitId': divisionOrgUnitId,
    'departmentOrgUnitId': departmentOrgUnitId,
    'employeeCode': employeeCode.trim(),
    'fullName': fullName.trim(),
    'nickName': _text(nickName),
    'positionCode': _text(positionCode),
    'email': _text(email),
    'notifyByEmail': notifyByEmail,
    'notifyInSystem': notifyInSystem,
    'telephone': _text(telephone),
    'contName1': _text(contact1.name),
    'contRelation1': _text(contact1.relation),
    'contPhone1': _text(contact1.phone),
    'contName2': _text(contact2.name),
    'contRelation2': _text(contact2.relation),
    'contPhone2': _text(contact2.phone),
    'carID1': _text(vehicle1.registration),
    'carColor1': _text(vehicle1.color),
    'carTypeCode1': _text(vehicle1.typeCode),
    'carOilType1': _text(vehicle1.oilTypeCode),
    'carID2': _text(vehicle2.registration),
    'carColor2': _text(vehicle2.color),
    'carTypeCode2': _text(vehicle2.typeCode),
    'carOilType2': _text(vehicle2.oilTypeCode),
    'startWorkDate': startWorkDate?.toIso8601String().split('T').first,
    'isActive': isActive,
  });

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class EmployeeFormService {
  const EmployeeFormService(this.repository);

  final EmployeeRepository repository;

  Future<int> save(
    EmployeeFormInput input, {
    required int organizationMode,
  }) async {
    final validation = input.validate(organizationMode: organizationMode);
    if (validation != null) throw EmployeeFormValidationException(validation);

    final id = input.editing
        ? await repository.update(input.employeeId!, input.toRequest())
        : await repository.create(input.toRequest());

    if (input.formalImage != null) {
      final image = input.formalImage!;
      await repository.saveFormalImage(
        id,
        image.bytes,
        image.fileName,
        companyId: input.companyId,
        width: image.width,
        height: image.height,
      );
    }
    final carImages = {
      if (input.carImage1 != null) 1: input.carImage1!,
      if (input.carImage2 != null) 2: input.carImage2!,
    };
    for (final entry in carImages.entries) {
      await repository.saveCarImage(
        id,
        entry.key,
        entry.value.bytes,
        entry.value.fileName,
        companyId: input.companyId,
        width: entry.value.width,
        height: entry.value.height,
      );
    }
    final username = input.username?.trim() ?? '';
    if (username.isNotEmpty) {
      final password = input.password?.trim();
      await repository.upsertEmployeeUser(
        id,
        username,
        password == null || password.isEmpty ? null : password,
        companyId: input.companyId,
        roleGroupId: input.roleGroupId,
      );
    }
    return id;
  }
}

class EmployeeFormValidationException implements Exception {
  const EmployeeFormValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
