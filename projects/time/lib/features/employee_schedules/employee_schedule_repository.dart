import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'employee_schedule_models.dart';

class EmployeeScheduleRepository {
  EmployeeScheduleRepository(this.api);
  final JsonApiClient api;
  static const path = '/api/time/employee-schedules';
  Future<ScheduleActions> actions() async => ScheduleActions.fromJson(
    Map<String, dynamic>.from(await api.get('$path/actions') as Map),
  );
  Future<ScheduleLookups> lookups() async => ScheduleLookups.fromJson(
    Map<String, dynamic>.from(await api.get('$path/lookups') as Map),
  );
  Future<EmployeeScheduleResult> list({
    String? search,
    int page = 1,
    int pageSize = 30,
  }) async => EmployeeScheduleResult.fromJson(
    Map<String, dynamic>.from(
      await api.get(
            path,
            query: {
              'page': '$page',
              'pageSize': '$pageSize',
              if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
            },
          )
          as Map,
    ),
  );
  Future<void> assign({
    required int employeeId,
    required int groupId,
    required DateTime date,
    required String reason,
  }) => api.post(
    '$path/assignments',
    body: {
      'employeeId': employeeId,
      'workScheduleGroupId': groupId,
      'effectiveFrom': scheduleDate(date),
      'reason': reason,
    },
  );
  Future<void> rotate({
    required int groupId,
    required int patternId,
    required DateTime date,
    required String reason,
  }) => api.post(
    '$path/group-rotations',
    body: {
      'workScheduleGroupId': groupId,
      'rotationPatternId': patternId,
      'anchorDate': scheduleDate(date),
      'effectiveFrom': scheduleDate(date),
      'reason': reason,
    },
  );
  Future<void> override({
    required int employeeId,
    required DateTime date,
    required bool dayOff,
    int? shiftId,
    required String reason,
  }) => api.post(
    '$path/overrides',
    body: {
      'employeeId': employeeId,
      'workDate': scheduleDate(date),
      'isDayOff': dayOff,
      'shiftTemplateId': dayOff ? null : shiftId,
      'reason': reason,
    },
  );
}
