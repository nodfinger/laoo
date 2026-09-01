import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';
import 'employee_list_controller.dart';
import 'employee_workspace_dependencies.dart';

typedef EmployeeAction = void Function(EmployeeRecord employee);
typedef EmployeeThumbnailBuilder =
    Widget Function(BuildContext context, EmployeeRecord employee);

class EmployeeListWorkspace extends StatefulWidget {
  const EmployeeListWorkspace({
    super.key,
    required this.caption,
    required this.controller,
    required this.companies,
    required this.organizationUnits,
    required this.organizationMode,
    required this.customerScope,
    required this.titleBuilder,
    required this.tokens,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.onUser,
    this.thumbnailBuilder,
  });

  final String caption;
  final EmployeeListController controller;
  final List<EmployeeCompanyOption> companies;
  final List<OrganizationUnitRecord> organizationUnits;
  final int organizationMode;
  final bool customerScope;
  final SharedAdminTitleBuilder titleBuilder;
  final SharedAdminUiTokens tokens;
  final VoidCallback onAdd;
  final EmployeeAction onEdit;
  final EmployeeAction onDelete;
  final EmployeeAction? onUser;
  final EmployeeThumbnailBuilder? thumbnailBuilder;

  @override
  State<EmployeeListWorkspace> createState() => _EmployeeListWorkspaceState();
}

class _EmployeeListWorkspaceState extends State<EmployeeListWorkspace> {
  final _search = TextEditingController();
  int? _companyId;
  int? _divisionId;
  int? _departmentId;
  bool? _active;
  int _sortColumn = 4;
  bool _sortAscending = true;

  EmployeeListController get controller => widget.controller;

  List<OrganizationUnitRecord> get divisions => widget.organizationUnits
      .where((unit) => unit.unitType == OrganizationUnitTypes.division)
      .toList(growable: false);

  List<OrganizationUnitRecord> get departments => widget.organizationUnits
      .where(
        (unit) =>
            unit.unitType == OrganizationUnitTypes.department &&
            (widget.organizationMode != 2 ||
                _divisionId == null ||
                unit.parentOrgUnitId == _divisionId),
      )
      .toList(growable: false);

  List<EmployeeRecord> get sortedItems {
    final values = [...controller.items];
    Comparable<dynamic> selector(EmployeeRecord item) => switch (_sortColumn) {
      2 => item.departmentName.toLowerCase(),
      3 => item.employeeCode.toLowerCase(),
      4 => item.fullName.toLowerCase(),
      5 => item.nickName.toLowerCase(),
      6 => item.telephone.toLowerCase(),
      7 => item.notifyByEmail ? 1 : 0,
      8 => item.isActive ? 1 : 0,
      _ => item.employeeId,
    };
    values.sort((a, b) {
      final result = selector(a).compareTo(selector(b));
      return _sortAscending ? result : -result;
    });
    return values;
  }

  @override
  void initState() {
    super.initState();
    _companyId = controller.companyId;
    _divisionId = controller.divisionId;
    _departmentId = controller.departmentId;
    _active = controller.isActive;
    _search.text = controller.search;
    controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant EmployeeListWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _applyFilters() => controller.applyFilters(
    searchText: _search.text,
    division: _divisionId,
    department: _departmentId,
    company: _companyId,
    active: _active,
  );

  Future<void> _clearFilters() async {
    _search.clear();
    setState(() {
      _companyId = null;
      _divisionId = null;
      _departmentId = null;
      _active = null;
    });
    await controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(t.radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: t.cardPadding,
            child: Row(
              children: [
                Expanded(
                  child: widget.titleBuilder(context, widget.caption, true),
                ),
                if (controller.canCreate)
                  FilledButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: t.cardPadding, child: _filters()),
          const Divider(height: 1),
          if (controller.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: controller.error != null
                ? _error()
                : LayoutBuilder(
                    builder: (_, constraints) =>
                        constraints.maxWidth < t.compactBreakpoint
                        ? _cards()
                        : _table(),
                  ),
          ),
          const Divider(height: 1),
          _pagination(),
        ],
      ),
    );
  }

  Widget _filters() => Wrap(
    spacing: widget.tokens.cardSpacing,
    runSpacing: widget.tokens.cardSpacing,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 260,
        child: TextField(
          controller: _search,
          onSubmitted: (_) => _applyFilters(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'ค้นหารหัส/ชื่อ/ชื่อเล่น/อีเมล',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'ค้นหา',
              onPressed: _applyFilters,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
      ),
      if (widget.customerScope)
        _dropdown<int?>(
          width: 280,
          label: 'ลูกค้า',
          value: _companyId,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
            ...widget.companies.map(
              (item) => DropdownMenuItem<int?>(
                value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          changed: (value) => setState(() => _companyId = value),
        ),
      if (widget.organizationMode == 2)
        _dropdown<int?>(
          width: 220,
          label: 'ฝ่าย',
          value: _divisionId,
          items: _organizationItems(divisions),
          changed: (value) => setState(() {
            _divisionId = value;
            _departmentId = null;
          }),
        ),
      _dropdown<int?>(
        width: 220,
        label: 'แผนก',
        value: _departmentId,
        items: _organizationItems(departments),
        changed: (value) => setState(() => _departmentId = value),
      ),
      _dropdown<bool?>(
        width: 180,
        label: 'สถานะ',
        value: _active,
        items: const [
          DropdownMenuItem<bool?>(value: null, child: Text('ทั้งหมด')),
          DropdownMenuItem<bool?>(value: true, child: Text('เปิดใช้งาน')),
          DropdownMenuItem<bool?>(value: false, child: Text('ปิดใช้งาน')),
        ],
        changed: (value) => setState(() => _active = value),
      ),
      FilledButton.icon(
        onPressed: _applyFilters,
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
      ),
      OutlinedButton.icon(
        onPressed: _clearFilters,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('ล้าง Filter'),
      ),
    ],
  );

  List<DropdownMenuItem<int?>> _organizationItems(
    List<OrganizationUnitRecord> values,
  ) => [
    const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
    ...values.map(
      (unit) => DropdownMenuItem<int?>(
        value: unit.orgUnitId,
        child: Text(
          '${unit.unitCode} - ${unit.nameTh}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  ];

  Widget _dropdown<T>({
    required double width,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> changed,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<T>(
      key: ValueKey((label, value)),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: changed,
    ),
  );

  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline),
        SizedBox(height: widget.tokens.cardSpacing),
        Text(controller.error.toString()),
        TextButton.icon(
          onPressed: controller.load,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่'),
        ),
      ],
    ),
  );

  Widget _table() {
    if (sortedItems.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลพนักงาน'));
    }
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .10),
          ),
          headingTextStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
          sortColumnIndex: _sortColumn,
          sortAscending: _sortAscending,
          columns: [
            _column('ID', 0),
            const DataColumn(label: Text('Action')),
            _column('แผนก', 2),
            _column('รหัสพนักงาน', 3),
            _column('ชื่อ-นามสกุล', 4),
            _column('ชื่อเล่น', 5),
            _column('โทรศัพท์', 6),
            _column('รูปแบบแจ้งเตือน', 7),
            _column('สถานะ', 8),
          ],
          rows: sortedItems.indexed
              .map((entry) {
                final item = entry.$2;
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        (((controller.page - 1) * controller.pageSize) +
                                entry.$1 +
                                1)
                            .toString(),
                      ),
                    ),
                    DataCell(_actions(item)),
                    DataCell(Text(_dash(item.departmentName))),
                    DataCell(Text(item.employeeCode)),
                    DataCell(Text(item.fullName)),
                    DataCell(Text(_dash(item.nickName))),
                    DataCell(Text(_dash(item.telephone))),
                    DataCell(Text(_notifications(item))),
                    DataCell(_status(item)),
                  ],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  DataColumn _column(String label, int index) => DataColumn(
    label: Text(label),
    onSort: (_, ascending) => setState(() {
      _sortColumn = index;
      _sortAscending = ascending;
    }),
  );

  Widget _cards() {
    if (sortedItems.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลพนักงาน'));
    }
    return ListView.separated(
      padding: widget.tokens.cardPadding,
      itemCount: sortedItems.length,
      separatorBuilder: (_, _) => SizedBox(height: widget.tokens.itemSpacing),
      itemBuilder: (_, index) {
        final item = sortedItems[index];
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(widget.tokens.radius),
          child: Padding(
            padding: widget.tokens.cardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.thumbnailBuilder != null) ...[
                  widget.thumbnailBuilder!(context, item),
                  SizedBox(width: widget.tokens.cardSpacing),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${item.employeeCode} - ${item.fullName}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: widget.tokens.itemSpacing),
                      Text('แผนก: ${_dash(item.departmentName)}'),
                      Text('โทร: ${_dash(item.telephone)}'),
                      Text('แจ้งเตือน: ${_notifications(item)}'),
                      _status(item),
                    ],
                  ),
                ),
                _actions(item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actions(EmployeeRecord item) => Wrap(
    spacing: 2,
    children: [
      if (controller.canEdit)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => widget.onEdit(item),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (widget.onUser != null && controller.canEdit)
        IconButton(
          tooltip: 'กำหนด User',
          onPressed: () => widget.onUser!(item),
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
      if (controller.canDelete)
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => widget.onDelete(item),
          color: Theme.of(context).colorScheme.error,
          icon: const Icon(Icons.delete_outline),
        ),
      if (!controller.canEdit && !controller.canDelete) const Text('-'),
    ],
  );

  Widget _status(EmployeeRecord item) {
    final color = item.isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Text(
      item.isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  String _notifications(EmployeeRecord item) => [
    if (item.notifyByEmail) 'Email',
    if (item.notifyInSystem) 'ระบบ',
  ].join(', ');

  String _dash(String value) => value.trim().isEmpty ? '-' : value;

  Widget _pagination() => SizedBox(
    height: widget.tokens.paginationHeight,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.tokens.cardPadding.left),
      child: Row(
        children: [
          IconButton(
            tooltip: 'ก่อนหน้า',
            onPressed: controller.page > 1 ? controller.previousPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(widget.tokens.radius),
            ),
            child: Text(
              controller.page.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'ถัดไป',
            onPressed: controller.page < controller.totalPages
                ? controller.nextPage
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              '${controller.firstRow}-${controller.lastRow} '
              'จาก ${controller.totalCount}',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    ),
  );
}
