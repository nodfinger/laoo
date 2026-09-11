import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'time_system_settings_models.dart';
import 'time_system_settings_repository.dart';

class TimeSystemSettingsPage extends StatefulWidget {
  const TimeSystemSettingsPage({super.key});

  @override
  State<TimeSystemSettingsPage> createState() =>
      _TimeSystemSettingsPageState();
}

class _TimeSystemSettingsPageState extends State<TimeSystemSettingsPage> {
  static const _approvalProcesses = <String, String>{
    'LEAVE': 'การลา',
    'TIME': 'การปรับเวลา',
    'OT': 'ล่วงเวลา (OT)',
    'ENTITLEMENT': 'สิทธิ์การลา',
    'PERIOD': 'งวดเวลา',
  };
  static const _requestProcesses = <String, String>{
    'LEAVE_REQUEST': 'คำขอลา',
    'LEAVE_CANCELLATION': 'ยกเลิกการลา',
    'TIME_CORRECTION': 'ขอปรับเวลา',
    'RECONFIRMATION': 'ยืนยันเวลาใหม่',
  };
  static const _profiles = <String, String>{
    'OWNER_OPERATED': 'เจ้าของดำเนินการเอง',
    'SEGREGATED_WORKFLOW': 'แยกผู้ทำและผู้อนุมัติ',
  };
  static const _processProfiles = <String, String>{
    'DEFAULT': 'ใช้ค่าหลักของบริษัท',
    ..._profiles,
  };
  static const _requestPolicies = <String, String>{
    'SELF_SERVICE_AND_PROXY': 'พนักงานทำเองและผู้ดูแลทำแทนได้',
    'PROXY_ONLY': 'ผู้ดูแลทำแทนเท่านั้น',
    'SELF_SERVICE_ONLY': 'พนักงานต้องทำเอง',
  };

  final _reason = TextEditingController();
  late final JsonApiClient _api;
  late final TimeSystemSettingsRepository _repository;
  TimeSystemActions? _actions;
  TimeSystemSettings? _source;
  late DateTime _effectiveFrom;
  String _defaultProfile = 'OWNER_OPERATED';
  Map<String, String> _selectedProfiles = {};
  Map<String, String> _selectedPolicies = {};
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _messageError = false;

  bool get _canEdit =>
      _actions?.canEdit == true &&
      _actions?.canManageApprovalProfile == true;

  @override
  void initState() {
    super.initState();
    _effectiveFrom = _today();
    _api = createTimeApiClient();
    _repository = TimeSystemSettingsRepository(_api);
    _initialize();
  }

  @override
  void dispose() {
    _reason.dispose();
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final actions = await _repository.actions();
      if (!actions.canView) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      if (!mounted) return;
      setState(() => _actions = actions);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _show(timeErrorText(error), error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.get(effectiveDate: _effectiveFrom);
      if (!mounted) return;
      setState(() {
        _source = data;
        _defaultProfile = data.defaultProfileCode;
        _selectedProfiles = {
          for (final key in _approvalProcesses.keys)
            key: data.processProfiles[key] ?? 'DEFAULT',
        };
        _selectedPolicies = {
          for (final key in _requestProcesses.keys)
            key: data.requestPolicies[key] ?? 'SELF_SERVICE_AND_PROXY',
        };
        _reason.clear();
      });
    } catch (error) {
      if (mounted) _show(timeErrorText(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageError = error;
    });
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: _today(),
      lastDate: DateTime(_today().year + 5, 12, 31),
    );
    if (value == null || value == _effectiveFrom) return;
    setState(() => _effectiveFrom = value);
    await _load();
  }

  Future<void> _save() async {
    final source = _source;
    if (!_canEdit || source == null || _saving) return;
    if (_reason.text.trim().isEmpty) {
      _show('กรุณาระบุเหตุผลในการแก้ไข', error: true);
      return;
    }
    final selfServiceOnly = _selectedPolicies.values.contains(
      'SELF_SERVICE_ONLY',
    );
    if (selfServiceOnly && !source.selfServiceReady) {
      _show(
        'ยังเปิดพนักงานทำเองเท่านั้นไม่ได้ เพราะมีพนักงานไม่มี Login '
        '${source.employeeWithoutLoginCount} คน',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.update(
        TimeSystemSettingsUpdate(
          effectiveFrom: _effectiveFrom,
          defaultProfileCode: _defaultProfile,
          processProfiles: _selectedProfiles,
          requestPolicies: _selectedPolicies,
          reason: _reason.text,
          stateToken: source.stateToken,
        ),
      );
      await _load();
      if (mounted) _show('บันทึกการตั้งค่าสำเร็จ', error: false);
    } catch (error) {
      if (mounted) _show(timeErrorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?.caption ?? 'กำหนดค่าระบบเวลา';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.systemSettings,
      child: Stack(
        children: [
          Positioned.fill(child: _content(caption)),
          if (_message != null)
            Positioned(
              top: 12,
              right: 12,
              child: buildTimeMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(String caption) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final source = _source;
    if (source == null) return const Center(child: Text('ไม่พบข้อมูล'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          caption,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _readiness(source),
        const SizedBox(height: 12),
        _section(
          title: 'รูปแบบการอนุมัติ',
          description:
              'ค่าหลักของบริษัทและค่าที่เลือกใช้แยกตามกระบวนการ',
          children: [
            _dropdown(
              label: 'ค่าหลักของบริษัท',
              value: _defaultProfile,
              options: _profiles,
              onChanged: (value) => setState(() => _defaultProfile = value),
            ),
            for (final entry in _approvalProcesses.entries)
              _dropdown(
                label: entry.value,
                value: _selectedProfiles[entry.key] ?? 'DEFAULT',
                options: _processProfiles,
                onChanged: (value) => setState(
                  () => _selectedProfiles[entry.key] = value,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _section(
          title: 'ผู้เริ่มคำขอ',
          description:
              'กำหนดว่าพนักงานทำเอง ผู้ดูแลทำแทน หรือรองรับทั้งสองแบบ',
          children: [
            for (final entry in _requestProcesses.entries)
              _dropdown(
                label: entry.value,
                value:
                    _selectedPolicies[entry.key] ?? 'SELF_SERVICE_AND_PROXY',
                options: _requestPolicies,
                onChanged: (value) => setState(
                  () => _selectedPolicies[entry.key] = value,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _section(
          title: 'การเริ่มใช้งานและ Audit',
          description: 'ทุกการแก้ไขต้องระบุวันที่เริ่มใช้และเหตุผลเพื่อเก็บ Log',
          children: [
            InkWell(
              onTap: _canEdit ? _pickDate : null,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'วันที่เริ่มใช้ *',
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(_formatDate(_effectiveFrom)),
              ),
            ),
            TextField(
              controller: _reason,
              enabled: _canEdit,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'เหตุผลในการแก้ไข *',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _canEdit && !_saving ? _save : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
        ),
      ],
    );
  }

  Widget _readiness(TimeSystemSettings source) {
    final ready = source.selfServiceReady;
    return Card(
      margin: EdgeInsets.zero,
      color: ready ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          ready ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: ready ? Colors.green.shade700 : Colors.orange.shade800,
        ),
        title: Text(
          ready
              ? 'พร้อมเปิดใช้งาน Self-service'
              : 'ยังมีพนักงานไม่มี Active Login '
                    '${source.employeeWithoutLoginCount} คน',
        ),
        subtitle: Text('พนักงานที่ใช้งานอยู่ ${source.activeEmployeeCount} คน'),
      ),
    );
  }

  Widget _section({
    required String title,
    required String description,
    required List<Widget> children,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: children
                  .map(
                    (child) => SizedBox(
                      width: constraints.maxWidth < 650
                          ? constraints.maxWidth
                          : 340,
                      child: child,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false),
    onChanged: _canEdit
        ? (value) {
            if (value != null) onChanged(value);
          }
        : null,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
