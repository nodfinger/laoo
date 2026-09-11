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
  EmployeeTimeSettingsDetail? _detail;
  bool _loading = true;
  bool _detailLoading = false;
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

  Future<void> _load({int? page, int? selectEmployeeId}) async {
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
      final employeeId = selectEmployeeId ?? _detail?.employee.employeeId;
      if (employeeId != null &&
          data.items.any((item) => item.employeeId == employeeId)) {
        await _select(employeeId);
      } else if (_detail != null && mounted) {
        setState(() => _detail = null);
      }
    } catch (error) {
      if (mounted) _show(timeErrorText(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(int employeeId) async {
    setState(() => _detailLoading = true);
    try {
      final detail = await _repository.detail(employeeId);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) _show(timeErrorText(error), error: true);
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  void _show(String message, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageError = error;
    });
  }

  Future<void> _save(EmployeeTimeSettingsUpdate request) async {
    final employeeId = _detail?.employee.employeeId;
    if (employeeId == null || _actions?.canEdit != true) return;
    try {
      await _repository.update(employeeId, request);
      await _load(selectEmployeeId: employeeId);
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
              top: timeUiTokens.cardSpacing,
              right: timeUiTokens.cardSpacing,
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
    final tokens = timeUiTokens;
    return ColoredBox(
      color: tokens.backgroundColor,
      child: Padding(
        padding: EdgeInsets.all(tokens.contentMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: tokens.cardSpacing),
                  Expanded(
                    child: Text(caption, style: tokens.pageCaptionStyle),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.cardSpacing),
            _filterPanel(),
            SizedBox(height: tokens.cardSpacing),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = _listPanel();
                  final editor = _editorPanel();
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        Expanded(child: list),
                        SizedBox(height: tokens.cardSpacing),
                        Expanded(child: editor),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: list),
                      SizedBox(width: tokens.cardSpacing),
                      Expanded(flex: 2, child: editor),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: tokens.cardSpacing),
            _paginationPanel(),
          ],
        ),
      ),
    );
  }

  Widget _filterPanel() => _section(
    Wrap(
      spacing: timeUiTokens.cardSpacing,
      runSpacing: timeUiTokens.cardSpacing,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _search,
            style: timeUiTokens.inputStyle,
            decoration: const InputDecoration(
              labelText: 'ค้นหา',
              hintText: 'PersonID รหัส ชื่อ ฝ่าย แผนก หรือรหัสที่เครื่อง',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _load(page: 1),
          ),
        ),
        _filter<bool?>(
          label: 'สถานะพนักงาน',
          value: _isActive,
          entries: const {true: 'ใช้งาน', false: 'ไม่ใช้งาน', null: 'ทั้งหมด'},
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
          onChanged: (value) => setState(() => _requiresAttendance = value),
        ),
        _button(
          icon: Icons.search,
          label: 'ค้นหา',
          onPressed: _loading ? null : () => _load(page: 1),
        ),
      ],
    ),
  );

  Widget _listPanel() => _section(
    _loading
        ? const Center(child: CircularProgressIndicator())
        : _data.items.isEmpty
        ? const Center(child: Text('ไม่พบข้อมูล'))
        : LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 720
                ? _mobileList()
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DefaultTextStyle.merge(
                        style: timeUiTokens.tableStyle,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('PersonID')),
                            DataColumn(label: Text('รหัสพนักงาน')),
                            DataColumn(label: Text('ชื่อพนักงาน')),
                            DataColumn(label: Text('ฝ่าย')),
                            DataColumn(label: Text('แผนก')),
                            DataColumn(label: Text('ลงเวลา')),
                            DataColumn(label: Text('รหัสที่เครื่อง')),
                          ],
                          rows: _data.items.map(_row).toList(growable: false),
                        ),
                      ),
                    ),
                  ),
          ),
  );

  DataRow _row(EmployeeTimeSettingRecord employee) => DataRow(
    selected: _detail?.employee.employeeId == employee.employeeId,
    onSelectChanged: (_) => _select(employee.employeeId),
    cells: [
      DataCell(Text(employee.personId?.toString() ?? '-')),
      DataCell(Text(employee.employeeCode)),
      DataCell(Text(employee.fullName)),
      DataCell(Text(employee.divisionName ?? '-')),
      DataCell(Text(employee.departmentName ?? '-')),
      DataCell(Text(employee.requiresAttendance ? 'ต้องลงเวลา' : 'ยกเว้น')),
      DataCell(Text(employee.deviceCode ?? '-')),
    ],
  );

  Widget _mobileList() => ListView.separated(
    itemCount: _data.items.length,
    separatorBuilder: (_, _) =>
        Divider(height: 1, color: Theme.of(context).dividerColor),
    itemBuilder: (context, index) {
      final employee = _data.items[index];
      return ListTile(
        selected: _detail?.employee.employeeId == employee.employeeId,
        onTap: () => _select(employee.employeeId),
        title: Text(
          '${employee.employeeCode} - ${employee.fullName}',
          style: timeUiTokens.tableStyle,
        ),
        subtitle: Text(
          'PersonID ${employee.personId ?? '-'} • '
          '${employee.divisionName ?? '-'} / ${employee.departmentName ?? '-'}\n'
          '${employee.requiresAttendance ? 'ต้องลงเวลา' : 'ยกเว้นลงเวลา'} • '
          'รหัสที่เครื่อง ${employee.deviceCode ?? '-'}',
          style: timeUiTokens.tableStyle,
        ),
        trailing: const Icon(Icons.chevron_right),
      );
    },
  );

  Widget _editorPanel() {
    if (_detailLoading) {
      return _section(const Center(child: CircularProgressIndicator()));
    }
    final detail = _detail;
    if (detail == null) {
      return _section(
        const Center(child: Text('เลือกพนักงานเพื่อดูรายละเอียดและแก้ไข')),
      );
    }
    return _section(
      EmployeeTimeSettingsEditor(
        key: ValueKey(
          '${detail.employee.employeeId}-${detail.employee.requirementRowVersion}-${detail.employee.deviceCodeRowVersion}',
        ),
        detail: detail,
        enabled: _actions?.canEdit == true,
        onSave: _save,
      ),
    );
  }

  Widget _paginationPanel() {
    final pages = _data.total == 0 ? 1 : (_data.total / _data.pageSize).ceil();
    return SizedBox(
      height: timeUiTokens.paginationHeight,
      child: _section(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'ทั้งหมด ${_data.total} รายการ',
              style: timeUiTokens.tableStyle,
            ),
            SizedBox(width: timeUiTokens.cardSpacing),
            IconButton(
              tooltip: 'หน้าก่อน',
              onPressed: _page > 1 && !_loading
                  ? () => _load(page: _page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('หน้า $_page / $pages', style: timeUiTokens.tableStyle),
            IconButton(
              tooltip: 'หน้าถัดไป',
              onPressed: _page < pages && !_loading
                  ? () => _load(page: _page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(timeUiTokens.radius),
      side: BorderSide.none,
    ),
    child: Padding(
      padding: EdgeInsets.all(timeUiTokens.cardPadding),
      child: child,
    ),
  );

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    height: timeUiTokens.buttonHeight,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(timeUiTokens.radius),
        ),
        textStyle: timeUiTokens.buttonStyle,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );

  Widget _filter<T>({
    required String label,
    required T value,
    required Map<T, String> entries,
    required ValueChanged<T?> onChanged,
  }) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      style: timeUiTokens.inputStyle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(labelText: label),
      items: entries.entries
          .map(
            (entry) =>
                DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
          )
          .toList(growable: false),
      onChanged: onChanged,
    ),
  );
}

class EmployeeTimeSettingsEditor extends StatefulWidget {
  const EmployeeTimeSettingsEditor({
    super.key,
    required this.detail,
    required this.enabled,
    required this.onSave,
  });

  final EmployeeTimeSettingsDetail detail;
  final bool enabled;
  final Future<void> Function(EmployeeTimeSettingsUpdate request) onSave;

  @override
  State<EmployeeTimeSettingsEditor> createState() =>
      _EmployeeTimeSettingsEditorState();
}

class _EmployeeTimeSettingsEditorState
    extends State<EmployeeTimeSettingsEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deviceCode;
  late final TextEditingController _reason;
  late bool _requiresAttendance;
  late DateTime _effectiveFrom;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _requiresAttendance = widget.detail.employee.requiresAttendance;
    _deviceCode = TextEditingController(
      text: widget.detail.employee.deviceCode,
    );
    _reason = TextEditingController();
    final requirementDate = widget.detail.employee.requirementEffectiveFrom;
    final deviceDate = widget.detail.employee.deviceCodeEffectiveFrom;
    _effectiveFrom = [
      widget.detail.businessDate,
      ?requirementDate,
      ?deviceDate,
    ].reduce((left, right) => left.isAfter(right) ? left : right);
  }

  @override
  void dispose() {
    _deviceCode.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.detail.employee;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('แก้ไขการลงเวลาทำงาน', style: timeUiTokens.sectionTitleStyle),
            SizedBox(height: timeUiTokens.formSpacing),
            Text('${employee.employeeCode} - ${employee.fullName}'),
            Text(
              'PersonID ${employee.personId ?? '-'} • '
              '${employee.divisionName ?? '-'} / ${employee.departmentName ?? '-'}',
            ),
            SizedBox(height: timeUiTokens.formSpacing),
            Row(
              children: [
                const Text('ต้องลงเวลาทำงาน'),
                SizedBox(width: timeUiTokens.cardSpacing),
                Switch.adaptive(
                  value: _requiresAttendance,
                  onChanged: widget.enabled
                      ? (value) => setState(() => _requiresAttendance = value)
                      : null,
                ),
              ],
            ),
            SizedBox(height: timeUiTokens.formSpacing),
            TextFormField(
              controller: _deviceCode,
              enabled: widget.enabled,
              maxLength: 100,
              style: timeUiTokens.inputStyle,
              decoration: const InputDecoration(
                labelText: 'รหัสที่เครื่อง',
                hintText: 'รหัสพนักงานในเครื่องบันทึกเวลา',
              ),
            ),
            SizedBox(height: timeUiTokens.formSpacing),
            IgnorePointer(
              ignoring: !widget.enabled,
              child: InputDatePickerFormField(
                firstDate: widget.detail.businessDate,
                lastDate: DateTime(widget.detail.businessDate.year + 5, 12, 31),
                initialDate: _effectiveFrom,
                fieldLabelText: 'วันที่เริ่มใช้',
                onDateSubmitted: (value) => _effectiveFrom = value,
                onDateSaved: (value) => _effectiveFrom = value,
              ),
            ),
            SizedBox(height: timeUiTokens.formSpacing),
            TextFormField(
              controller: _reason,
              enabled: widget.enabled,
              maxLength: 1000,
              maxLines: 3,
              style: timeUiTokens.inputStyle,
              decoration: const InputDecoration(
                labelText: 'เหตุผลในการแก้ไข *',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'กรุณาระบุเหตุผล'
                  : null,
            ),
            SizedBox(height: timeUiTokens.formSpacing),
            SizedBox(
              height: timeUiTokens.buttonHeight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(timeUiTokens.radius),
                  ),
                  textStyle: timeUiTokens.buttonStyle,
                ),
                onPressed: widget.enabled && !_saving ? _save : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('บันทึก'),
              ),
            ),
            SizedBox(height: timeUiTokens.cardSpacing),
            const Divider(),
            Text('ประวัติการกำหนดค่า', style: timeUiTokens.sectionTitleStyle),
            SizedBox(height: timeUiTokens.cardSpacing),
            ...widget.detail.auditHistory.map(
              (audit) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(audit.reason, style: timeUiTokens.tableStyle),
                subtitle: Text(
                  '${audit.actorName ?? 'ผู้ใช้ ${audit.actorUserId}'} • '
                  '${_displayDateTime(audit.occurredDateUtc)} เวลาไทย',
                  style: timeUiTokens.tableStyle,
                ),
              ),
            ),
            if (widget.detail.auditHistory.isEmpty)
              const Text('ยังไม่มีประวัติการแก้ไข'),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    _formKey.currentState?.save();
    setState(() => _saving = true);
    try {
      await widget.onSave(
        EmployeeTimeSettingsUpdate(
          requiresAttendance: _requiresAttendance,
          deviceCode: _deviceCode.text,
          effectiveFrom: _effectiveFrom,
          reason: _reason.text,
          requirementRowVersion: widget.detail.employee.requirementRowVersion,
          deviceCodeRowVersion: widget.detail.employee.deviceCodeRowVersion,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _displayDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toUtc().add(const Duration(hours: 7));
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
