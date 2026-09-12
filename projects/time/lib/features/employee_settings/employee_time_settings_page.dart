import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'employee_time_settings_models.dart';
import 'employee_time_settings_repository.dart';

List<DropdownMenuItem<T>> _uniqueDropdownItems<T>(
  Iterable<DropdownMenuItem<T>> items,
) {
  final seen = <T?>{};
  return items.where((item) => seen.add(item.value)).toList(growable: false);
}

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
  EmployeeOrganizationFilterOptions _organizationFilters =
      const EmployeeOrganizationFilterOptions(divisions: [], departments: []);
  EmployeeTimeSettingRecord? _selected;
  bool _loading = true;
  bool? _isActive = true;
  bool? _requiresAttendance;
  int? _divisionOrgUnitId;
  int? _departmentOrgUnitId;
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
      final organizationFilters = await _repository.organizationFilters();
      if (!mounted) return;
      setState(() => _organizationFilters = organizationFilters);
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
      final data = await _repository.list(
        search: _search.text.trim(),
        isActive: _isActive,
        requiresAttendance: _requiresAttendance,
        divisionOrgUnitId: _divisionOrgUnitId,
        departmentOrgUnitId: _departmentOrgUnitId,
        page: page ?? _page,
        pageSize: timePageSize,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _page = data.page;
        _selected = data.items.isEmpty ? null : data.items.first;
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

  void _select(EmployeeTimeSettingRecord employee) {
    if (_actions?.canEdit != true) return;
    setState(() => _selected = employee);
  }

  Future<void> _save(EmployeeTimeSettingsUpdate request) async {
    final employee = _selected;
    if (employee == null) return;
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
    final tokens = timeUiTokens;
    final pages = _data.total == 0 ? 1 : (_data.total / _data.pageSize).ceil();
    return Container(
      color: tokens.backgroundColor,
      padding: tokens.contentMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            Row(
              children: [
                Icon(Icons.star_border, color: tokens.primaryColor),
                const SizedBox(width: 6),
                Expanded(child: Text(caption, style: tokens.captionStyle)),
              ],
            ),
          ),
          SizedBox(height: tokens.cardSpacing),
          _filterCard(),
          SizedBox(height: tokens.cardSpacing),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final list = _listCard(
                  constraints.maxWidth < tokens.compactBreakpoint,
                );
                final selected = _selected;
                if (selected == null || constraints.maxWidth < 1100) {
                  return Column(
                    children: [
                      Expanded(flex: selected == null ? 1 : 3, child: list),
                      if (selected != null) ...[
                        SizedBox(height: tokens.cardSpacing),
                        Expanded(flex: 4, child: _editorCard(selected)),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: list),
                    SizedBox(width: tokens.cardSpacing),
                    SizedBox(width: 390, child: _editorCard(selected)),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: tokens.cardSpacing),
          _pagination(pages),
        ],
      ),
    );
  }

  Widget _filterCard() {
    final tokens = timeUiTokens;
    return _card(
      Wrap(
        spacing: tokens.itemSpacing,
        runSpacing: tokens.itemSpacing,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _search,
              style: tokens.inputStyle,
              decoration: _inputDecoration(
                label: 'ค้นหา',
                hint: 'รหัส ชื่อ หรือรหัสที่เครื่อง',
                prefix: const Icon(Icons.search),
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
            onChanged: (value) => setState(() => _requiresAttendance = value),
          ),
          _organizationFilter(
            label: 'ฝ่าย',
            value: _divisionOrgUnitId,
            entries: _organizationFilters.divisions,
            onChanged: (value) => setState(() => _divisionOrgUnitId = value),
          ),
          _organizationFilter(
            label: 'แผนก',
            value: _departmentOrgUnitId,
            entries: _organizationFilters.departments,
            onChanged: (value) => setState(() => _departmentOrgUnitId = value),
          ),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _load(page: 1),
              style: _buttonStyle(),
              icon: const Icon(Icons.search),
              label: const Text('ค้นหา'),
            ),
          ),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: _loading
                  ? null
                  : () {
                      _search.clear();
                      setState(() {
                        _isActive = null;
                        _requiresAttendance = null;
                        _divisionOrgUnitId = null;
                        _departmentOrgUnitId = null;
                      });
                      _load(page: 1);
                    },
              style: _buttonStyle(outlined: true),
              child: const Text('ล้าง Filter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard(bool compact) {
    final tokens = timeUiTokens;
    if (_loading)
      return _card(const Center(child: CircularProgressIndicator()));
    if (_data.items.isEmpty)
      return _card(const Center(child: Text('ไม่พบข้อมูล')));
    return _card(
      compact
          ? _mobileList()
          : SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dividerThickness: 1,
                  headingRowColor: WidgetStatePropertyAll(
                    tokens.primaryColor.withValues(alpha: 0.10),
                  ),
                  headingTextStyle: tokens.tableStyle.copyWith(
                    color: tokens.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                  dataTextStyle: tokens.tableStyle,
                  columns: const [
                    DataColumn(label: Text('ลำดับ')),
                    DataColumn(label: Text('จัดการ')),
                    DataColumn(label: Text('รหัสพนักงาน')),
                    DataColumn(label: Text('ชื่อพนักงาน')),
                    DataColumn(label: Text('ลงเวลา')),
                    DataColumn(label: Text('รหัสที่เครื่อง')),
                    DataColumn(label: Text('Login')),
                  ],
                  rows: _data.items
                      .asMap()
                      .entries
                      .map((entry) {
                        final employee = entry.value;
                        final number =
                            ((_page - 1) * _data.pageSize) + entry.key + 1;
                        return DataRow(
                          cells: [
                            DataCell(Text('$number')),
                            DataCell(
                              IconButton(
                                tooltip: 'แก้ไข',
                                onPressed: _actions?.canEdit == true
                                    ? () => _select(employee)
                                    : null,
                                color: tokens.primaryColor,
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ),
                            DataCell(Text(employee.employeeCode)),
                            DataCell(
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(employee.fullName),
                                  Text(
                                    '${employee.divisionName ?? '-'} / '
                                    '${employee.departmentName ?? '-'}',
                                    style: tokens.tableStyle.copyWith(
                                      color: tokens.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                employee.requiresAttendance
                                    ? 'ต้องลงเวลา'
                                    : 'ยกเว้น',
                              ),
                            ),
                            DataCell(Text(employee.deviceCode ?? '-')),
                            DataCell(
                              Icon(
                                employee.hasActiveLogin
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: employee.hasActiveLogin
                                    ? tokens.primaryColor
                                    : Colors.red,
                              ),
                            ),
                          ],
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ),
    );
  }

  Widget _mobileList() {
    final tokens = timeUiTokens;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _data.items.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: tokens.itemSpacing),
      itemBuilder: (context, index) {
        final employee = _data.items[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
          child: ListTile(
            title: Text(
              '${employee.employeeCode} - ${employee.fullName}',
              style: tokens.tableStyle,
            ),
            subtitle: Text(
              '${employee.divisionName ?? '-'} / '
              '${employee.departmentName ?? '-'}\n'
              '${employee.requiresAttendance ? 'ต้องลงเวลา' : 'ยกเว้นลงเวลา'}'
              ' • รหัสที่เครื่อง: ${employee.deviceCode ?? '-'}\n'
              'Login: ${employee.hasActiveLogin ? 'พร้อม' : 'ไม่พร้อม'}',
              style: tokens.tableStyle,
            ),
            trailing: IconButton(
              tooltip: 'แก้ไข',
              onPressed: _actions?.canEdit == true
                  ? () => _select(employee)
                  : null,
              color: tokens.primaryColor,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      },
    );
  }

  Widget _editorCard(EmployeeTimeSettingRecord employee) {
    return _card(
      _EmployeeTimeSettingsEditor(
        key: ValueKey(
          '${employee.employeeId}-${employee.requirementRowVersion}-'
          '${employee.deviceCodeRowVersion}',
        ),
        employee: employee,
        onCancel: () => setState(() => _selected = null),
        onSave: _save,
      ),
    );
  }

  Widget _pagination(int pages) {
    final tokens = timeUiTokens;
    final start = _data.total == 0 ? 0 : ((_page - 1) * _data.pageSize) + 1;
    final end = _data.total == 0
        ? 0
        : ((_page * _data.pageSize) > _data.total
              ? _data.total
              : _page * _data.pageSize);
    return SizedBox(
      height: tokens.paginationHeight,
      child: _card(
        Wrap(
          spacing: tokens.itemSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pageButton(
              icon: Icons.chevron_left,
              enabled: _page > 1 && !_loading,
              onPressed: () => _load(page: _page - 1),
            ),
            _pageButton(
              label: '$_page',
              enabled: true,
              active: true,
              onPressed: null,
            ),
            _pageButton(
              icon: Icons.chevron_right,
              enabled: _page < pages && !_loading,
              onPressed: () => _load(page: _page + 1),
            ),
            Text('$start-$end จาก ${_data.total} รายการ'),
          ],
        ),
      ),
    );
  }

  Widget _pageButton({
    IconData? icon,
    String? label,
    required bool enabled,
    bool active = false,
    VoidCallback? onPressed,
  }) {
    final tokens = timeUiTokens;
    return SizedBox(
      height: 36,
      width: 40,
      child: OutlinedButton(
        onPressed: active
            ? () {}
            : enabled
            ? onPressed
            : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: active ? Colors.white : tokens.primaryColor,
          backgroundColor: active ? tokens.primaryColor : Colors.white,
          side: BorderSide(
            color: enabled ? tokens.primaryColor : tokens.borderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
        child: icon == null ? Text(label!) : Icon(icon),
      ),
    );
  }

  Widget _card(Widget child) {
    final tokens = timeUiTokens;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Padding(padding: tokens.cardPadding, child: child),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? prefix,
  }) {
    final tokens = timeUiTokens;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      isDense: true,
      border: border(tokens.borderColor),
      enabledBorder: border(tokens.borderColor),
      focusedBorder: border(tokens.primaryColor),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red),
    );
  }

  ButtonStyle _buttonStyle({bool outlined = false}) {
    final tokens = timeUiTokens;
    return OutlinedButton.styleFrom(
      textStyle: tokens.buttonStyle,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      foregroundColor: outlined ? tokens.primaryColor : Colors.white,
      backgroundColor: outlined ? Colors.white : tokens.primaryColor,
      side: BorderSide(color: tokens.primaryColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
    );
  }

  Widget _filter<T>({
    required String label,
    required T value,
    required Map<T, String> entries,
    required ValueChanged<T?> onChanged,
  }) {
    final tokens = timeUiTokens;
    final items = _uniqueDropdownItems(
      entries.entries.map(
        (entry) => DropdownMenuItem<T>(
          value: entry.key,
          child: Text(entry.value, style: tokens.inputStyle),
        ),
      ),
    );
    final selectedValue = items.any((item) => item.value == value)
        ? value
        : null;
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        initialValue: selectedValue,
        style: tokens.inputStyle,
        decoration: _inputDecoration(label: label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _organizationFilter({
    required String label,
    required int? value,
    required List<EmployeeOrganizationOption> entries,
    required ValueChanged<int?> onChanged,
  }) {
    final tokens = timeUiTokens;
    final items = _uniqueDropdownItems<int?>([
      const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
      ...entries.map(
        (entry) => DropdownMenuItem<int?>(
          value: entry.id,
          child: Text(entry.name, style: tokens.inputStyle),
        ),
      ),
    ]);
    final selectedValue = items.any((item) => item.value == value)
        ? value
        : null;
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<int?>(
        isExpanded: true,
        initialValue: selectedValue,
        style: tokens.inputStyle,
        decoration: _inputDecoration(label: label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _EmployeeTimeSettingsEditor extends StatefulWidget {
  const _EmployeeTimeSettingsEditor({
    required this.employee,
    required this.onCancel,
    required this.onSave,
    super.key,
  });

  final EmployeeTimeSettingRecord employee;
  final VoidCallback onCancel;
  final ValueChanged<EmployeeTimeSettingsUpdate> onSave;

  @override
  State<_EmployeeTimeSettingsEditor> createState() =>
      _EmployeeTimeSettingsEditorState();
}

class _EmployeeTimeSettingsEditorState
    extends State<_EmployeeTimeSettingsEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deviceCode;
  late final TextEditingController _reason;
  late final TextEditingController _effectiveFromText;
  late bool _requiresAttendance;
  late DateTime _effectiveFrom;

  @override
  void initState() {
    super.initState();
    _requiresAttendance = widget.employee.requiresAttendance;
    _deviceCode = TextEditingController(text: widget.employee.deviceCode);
    _reason = TextEditingController();
    _effectiveFrom = DateUtils.dateOnly(timeUiTokens.businessDate);
    _effectiveFromText = TextEditingController(text: _formatDate(_effectiveFrom));
  }

  @override
  void dispose() {
    _deviceCode.dispose();
    _reason.dispose();
    _effectiveFromText.dispose();
    super.dispose();
  }

  Future<void> _pickEffectiveFrom() async {
    final businessDate = DateUtils.dateOnly(timeUiTokens.businessDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: businessDate,
      lastDate: DateTime(businessDate.year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _effectiveFrom = DateUtils.dateOnly(picked);
      _effectiveFromText.text = _formatDate(_effectiveFrom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = timeUiTokens;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, color: tokens.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text('แก้ไขการลงเวลาทำงาน', style: tokens.sectionStyle),
              ),
              IconButton(
                tooltip: 'ปิดแผงแก้ไข',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Divider(color: tokens.borderColor),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${widget.employee.employeeCode} - ${widget.employee.fullName}',
                    style: tokens.inputStyle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.itemSpacing / 2),
                  Text(
                    'ฝ่าย: ${widget.employee.divisionName ?? '-'}  '
                    'แผนก: ${widget.employee.departmentName ?? '-'}',
                    style: tokens.tableStyle.copyWith(
                      color: tokens.primaryColor,
                    ),
                  ),
                  SizedBox(height: tokens.cardSpacing),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('ต้องลงเวลาทำงาน', style: tokens.inputStyle),
                    value: _requiresAttendance,
                    onChanged: (value) =>
                        setState(() => _requiresAttendance = value),
                  ),
                  SizedBox(height: tokens.cardSpacing),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _deviceCode,
                          style: tokens.inputStyle,
                          maxLength: 100,
                          buildCounter: (
                            context, {
                            required int currentLength,
                            int? maxLength,
                            required bool isFocused,
                          }) => null,
                          decoration: _decoration(
                            label: 'รหัสที่เครื่อง',
                            hint: 'รหัสในเครื่อง',
                          ),
                        ),
                      ),
                      SizedBox(width: tokens.itemSpacing),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _effectiveFromText,
                          readOnly: true,
                          style: tokens.inputStyle,
                          decoration: _decoration(
                            label: 'วันที่เริ่มใช้',
                            suffixIcon: const Icon(Icons.calendar_month_outlined),
                          ),
                          onTap: _pickEffectiveFrom,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.cardSpacing),
                  TextFormField(
                    controller: _reason,
                    style: tokens.inputStyle,
                    maxLength: 1000,
                    buildCounter: (
                      context, {
                      required int currentLength,
                      int? maxLength,
                      required bool isFocused,
                    }) => null,
                    maxLines: 1,
                    decoration: _decoration(label: 'เหตุผลในการแก้ไข'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: _editorButtonStyle(outlined: true),
                  child: const Text('ยกเลิก'),
                ),
                SizedBox(width: tokens.itemSpacing),
                FilledButton.icon(
                  onPressed: _save,
                  style: _editorButtonStyle(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    final tokens = timeUiTokens;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      isDense: true,
      border: border(tokens.borderColor),
      enabledBorder: border(tokens.borderColor),
      focusedBorder: border(tokens.primaryColor),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red),
    );
  }

  ButtonStyle _editorButtonStyle({bool outlined = false}) {
    final tokens = timeUiTokens;
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: tokens.primaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(color: tokens.primaryColor),
          )
        : FilledButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: tokens.primaryColor,
          );
    return style.copyWith(
      textStyle: WidgetStatePropertyAll(tokens.buttonStyle),
      minimumSize: WidgetStatePropertyAll(Size(0, tokens.buttonHeight)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    _formKey.currentState?.save();
    widget.onSave(
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

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
