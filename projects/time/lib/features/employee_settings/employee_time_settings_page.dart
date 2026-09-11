import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'employee_time_settings_models.dart';
import 'employee_time_settings_repository.dart';

class EmployeeTimeSettingsPage extends StatefulWidget {
  const EmployeeTimeSettingsPage({super.key});

  @override
  State<EmployeeTimeSettingsPage> createState() =>
      _EmployeeTimeSettingsPageState();
}

class _EmployeeTimeSettingsPageState extends State<EmployeeTimeSettingsPage> {
  final _search = TextEditingController();
  late final JsonApiClient _api;
  late final EmployeeTimeSettingsRepository _repository;
  EmployeeTimeActions? _actions;
  EmployeeTimeSettingsResult _data = const EmployeeTimeSettingsResult(
    total: 0,
    page: 1,
    pageSize: 30,
    items: [],
  );
  bool _loading = true;
  bool? _isActive = true;
  bool? _requiresAttendance;
  int _page = 1;
  String? _message;
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repository = EmployeeTimeSettingsRepository(_api);
    _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
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
      setState(() => _loading = false);
      _show(timeErrorText(error), error: true);
    }
  }

  Future<void> _load({int? page}) async {
    if (mounted) setState(() => _loading = true);
    try {
      final nextPage = page ?? _page;
      final data = await _repository.list(
        search: _search.text,
        isActive: _isActive,
        requiresAttendance: _requiresAttendance,
        page: nextPage,
        pageSize: timePageSize,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _page = data.page;
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

  Future<void> _edit(EmployeeTimeSettingRecord employee) async {
    if (_actions?.canEdit != true) return;
    final request = await showDialog<EmployeeTimeSettingsUpdate>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EmployeeTimeSettingsDialog(employee: employee),
    );
    if (request == null) return;
    try {
      await _repository.update(employee.employeeId, request);
      await _load();
      if (mounted) _show('บันทึกข้อมูลสำเร็จ', error: false);
    } catch (error) {
      if (mounted) _show(timeErrorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?.caption ?? 'พนักงาน–ลงเวลาทำงาน';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.employeeSettings,
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
    final pages = _data.total == 0 ? 1 : (_data.total / _data.pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            caption,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'ค้นหา',
                        hintText: 'รหัส ชื่อ หรือรหัสที่เครื่อง',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _load(page: 1),
                    ),
                  ),
                  _filter<bool?>(
                    label: 'สถานะพนักงาน',
                    value: _isActive,
                    entries: const {
                      true: 'ใช้งาน',
                      false: 'ไม่ใช้งาน',
                      null: 'ทั้งหมด',
                    },
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  _filter<bool?>(
                    label: 'การลงเวลา',
                    value: _requiresAttendance,
                    entries: const {
                      true: 'ต้องลงเวลา',
                      false: 'ยกเว้นลงเวลา',
                      null: 'ทั้งหมด',
                    },
                    onChanged: (value) =>
                        setState(() => _requiresAttendance = value),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _load(page: 1),
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _data.items.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูล'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 900) return _mobileList();
                        return SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('รหัสพนักงาน')),
                                DataColumn(label: Text('ชื่อพนักงาน')),
                                DataColumn(label: Text('ลงเวลา')),
                                DataColumn(label: Text('รหัสที่เครื่อง')),
                                DataColumn(label: Text('Login')),
                                DataColumn(label: Text('จัดการ')),
                              ],
                              rows: _data.items
                                  .map((employee) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(employee.employeeCode)),
                                        DataCell(Text(employee.fullName)),
                                        DataCell(
                                          Text(
                                            employee.requiresAttendance
                                                ? 'ต้องลงเวลา'
                                                : 'ยกเว้น',
                                          ),
                                        ),
                                        DataCell(
                                          Text(employee.deviceCode ?? '-'),
                                        ),
                                        DataCell(
                                          Icon(
                                            employee.hasActiveLogin
                                                ? Icons.check_circle
                                                : Icons.warning_amber,
                                            color: employee.hasActiveLogin
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            tooltip: 'แก้ไข',
                                            onPressed: _actions?.canEdit == true
                                                ? () => _edit(employee)
                                                : null,
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: Card(
              margin: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('ทั้งหมด ${_data.total} รายการ'),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'หน้าก่อน',
                    onPressed: _page > 1 && !_loading
                        ? () => _load(page: _page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('หน้า $_page / $pages'),
                  IconButton(
                    tooltip: 'หน้าถัดไป',
                    onPressed: _page < pages && !_loading
                        ? () => _load(page: _page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _data.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final employee = _data.items[index];
        return Card.outlined(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text('${employee.employeeCode} - ${employee.fullName}'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${employee.requiresAttendance ? 'ต้องลงเวลา' : 'ยกเว้นลงเวลา'}'
                ' • รหัสที่เครื่อง: ${employee.deviceCode ?? '-'}'
                ' • Login: ${employee.hasActiveLogin ? 'พร้อม' : 'ไม่พร้อม'}',
              ),
            ),
            trailing: IconButton(
              tooltip: 'แก้ไข',
              onPressed: _actions?.canEdit == true
                  ? () => _edit(employee)
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      },
    );
  }

  Widget _filter<T>({
    required String label,
    required T value,
    required Map<T, String> entries,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: entries.entries
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }
}

class _EmployeeTimeSettingsDialog extends StatefulWidget {
  const _EmployeeTimeSettingsDialog({required this.employee});

  final EmployeeTimeSettingRecord employee;

  @override
  State<_EmployeeTimeSettingsDialog> createState() =>
      _EmployeeTimeSettingsDialogState();
}

class _EmployeeTimeSettingsDialogState
    extends State<_EmployeeTimeSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deviceCode;
  late final TextEditingController _reason;
  late bool _requiresAttendance;
  DateTime _effectiveFrom = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _requiresAttendance = widget.employee.requiresAttendance;
    _deviceCode = TextEditingController(text: widget.employee.deviceCode);
    _reason = TextEditingController();
  }

  @override
  void dispose() {
    _deviceCode.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ไขการลงเวลาทำงาน'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.employee.employeeCode} - ${widget.employee.fullName}',
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ต้องลงเวลาทำงาน'),
                  value: _requiresAttendance,
                  onChanged: (value) =>
                      setState(() => _requiresAttendance = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deviceCode,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'รหัสที่เครื่อง',
                    hintText: 'รหัสพนักงานในเครื่องบันทึกเวลา',
                  ),
                ),
                const SizedBox(height: 12),
                InputDatePickerFormField(
                  firstDate: DateUtils.dateOnly(DateTime.now()),
                  lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                  initialDate: _effectiveFrom,
                  fieldLabelText: 'วันที่เริ่มใช้',
                  onDateSubmitted: (value) => _effectiveFrom = value,
                  onDateSaved: (value) => _effectiveFrom = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'เหตุผลในการแก้ไข *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุเหตุผล'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    _formKey.currentState?.save();
    Navigator.pop(
      context,
      EmployeeTimeSettingsUpdate(
        requiresAttendance: _requiresAttendance,
        deviceCode: _deviceCode.text,
        effectiveFrom: _effectiveFrom,
        reason: _reason.text,
        requirementRowVersion: widget.employee.requirementRowVersion,
        deviceCodeRowVersion: widget.employee.deviceCodeRowVersion,
      ),
    );
  }
}
