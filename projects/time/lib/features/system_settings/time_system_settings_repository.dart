import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'time_system_settings_models.dart';

class TimeSystemSettingsRepository {
  TimeSystemSettingsRepository(this.api);

  static const path = '/api/time/system-settings';
  final JsonApiClient api;

  Future<TimeSystemActions> actions() async {
    final json = await api.get('$path/actions');
    return TimeSystemActions.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<TimeSystemSettings> get({DateTime? effectiveDate}) async {
    final query = effectiveDate == null
        ? null
        : <String, String>{'effectiveDate': _dateOnly(effectiveDate)};
    final json = await api.get(path, query: query);
    return TimeSystemSettings.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> update(TimeSystemSettingsUpdate request) async {
    await api.put(path, body: request.toJson());
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
