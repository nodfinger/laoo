import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_time/features/employee_schedules/employee_schedule_models.dart';
import 'package:laoo_time/features/employee_schedules/employee_schedule_repository.dart';
import 'package:laoo_time/features/leave_entitlement_policies/leave_entitlement_policy_repository.dart';
import 'package:laoo_time/features/leave_types/leave_type_repository.dart';
import 'package:laoo_time/features/schedule_groups/schedule_group_models.dart';
import 'package:laoo_time/features/schedule_groups/schedule_group_repository.dart';
import 'package:laoo_time/features/shift_templates/shift_template_models.dart';
import 'package:laoo_time/features/shift_templates/shift_template_repository.dart';
import 'package:laoo_time/features/time_reasons/time_reason_repository.dart';
import 'package:laoo_time/features/rotation_patterns/rotation_pattern_models.dart';
import 'package:laoo_time/features/rotation_patterns/rotation_pattern_repository.dart';

void main() {
  test(
    'schedule actions and selected assignment retain login permission context',
    () {
      final denied = ScheduleActions.fromJson({
        'caption': 'จัดตารางพนักงาน',
        'screenType': 1,
        'view': true,
        'edit': false,
        'delete': false,
      });
      expect(denied.screenType, 1);
      expect(denied.edit, isFalse);
      expect(denied.delete, isFalse);

      final selected = EmployeeScheduleRow.fromJson({
        'employeeId': 8,
        'employeeCode': 'E8',
        'fullName': 'ทดสอบ',
        'assignmentId': 19,
        'rowVersion': '0011223344556677',
      });
      expect(selected.assignmentId, 19);
      expect(selected.rowVersion, '0011223344556677');
    },
  );

  test('hard delete APIs use the selected ID and row version', () async {
    final api = _FakeDeleteApi();
    await EmployeeScheduleRepository(
      api,
    ).deleteAssignment(19, '0011223344556677');
    expect(api.path, '/api/time/employee-schedules/assignments/19');
    expect(api.query, {'rowVersion': '0011223344556677'});

    await LeaveEntitlementPolicyRepository(
      api,
    ).delete({'id': 5, 'rowVersion': '8899AABBCCDDEEFF'});
    expect(api.path, '/api/time/leave-entitlement-policies/5');
    expect(api.query, {'rowVersion': '8899AABBCCDDEEFF'});

    await ScheduleGroupRepository(api).delete(
      ScheduleGroup(
        id: 4,
        code: 'G4',
        name: 'กลุ่มทดสอบ',
        rowVersion: '0011223344556677',
      ),
    );
    expect(api.path, '/api/time/schedule-groups/4');
    expect(api.query, {'rowVersion': '0011223344556677'});

    await TimeReasonRepository(
      api,
      '/api/time/on-behalf-reasons',
    ).delete(7, '0011223344556677');
    expect(api.path, '/api/time/on-behalf-reasons/7');
    expect(api.query, {'rowVersion': '0011223344556677'});

    await TimeReasonRepository(
      api,
      '/api/time/adjustment-reasons',
    ).delete(9, '8899AABBCCDDEEFF');
    expect(api.path, '/api/time/adjustment-reasons/9');
    expect(api.query, {'rowVersion': '8899AABBCCDDEEFF'});

    await ShiftTemplateRepository(api).delete(
      const ShiftSummary(
        id: 11,
        code: 'S11',
        name: 'Shift',
        active: true,
        segmentCount: 1,
        sessionCount: 1,
        rowVersion: '0011223344556677',
      ),
    );
    expect(api.path, '/api/time/shift-templates/11');
    expect(api.query, {'rowVersion': '0011223344556677'});

    await RotationPatternRepository(api).delete(
      RotationPattern(
        id: 12,
        code: 'R12',
        name: 'Rotation',
        effectiveFrom: DateTime(2026, 9, 29),
        days: [RotationDay(dayNo: 1, dayOff: true)],
        rowVersion: '8899AABBCCDDEEFF',
      ),
    );
    expect(api.path, '/api/time/rotation-patterns/12');
    expect(api.query, {'rowVersion': '8899AABBCCDDEEFF'});

    await LeaveTypeRepository(api).delete(13, '0011223344556677');
    expect(api.path, '/api/time/leave-types/13');
    expect(api.query, {'rowVersion': '0011223344556677'});
  });

  test('schedule group actions require ScreenType 1 and login flags', () {
    final denied = ScheduleGroupActions.fromJson({
      'caption': 'กลุ่มตารางทำงาน',
      'screenType': 1,
      'view': true,
      'create': false,
      'edit': false,
      'delete': false,
    });
    expect(denied.screenType, 1);
    expect(denied.create, isFalse);
    expect(denied.edit, isFalse);
    expect(denied.delete, isFalse);
  });

  test('shift and rotation actions parse ScreenType and login permissions', () {
    final shift = ShiftActions.fromJson({
      'caption': 'Shift',
      'screenType': 1,
      'view': true,
      'create': true,
      'edit': false,
      'delete': false,
    });
    expect(shift.screenType, 1);
    expect(shift.canEdit, isFalse);
    expect(shift.canDelete, isFalse);

    final rotation = RotationActions.fromJson({
      'caption': 'Rotation',
      'screenType': 1,
      'view': true,
      'create': false,
      'edit': true,
      'delete': false,
    });
    expect(rotation.screenType, 1);
    expect(rotation.edit, isTrue);
    expect(rotation.delete, isFalse);
  });
}

class _FakeDeleteApi implements JsonApiClient {
  String? path;
  Map<String, String>? query;

  @override
  Future<void> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    this.path = path;
    this.query = query;
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();

  @override
  Future<void> post(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();

  @override
  Future<void> put(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();
}
