import 'dart:convert';
import 'dart:typed_data';

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
    this.canShowEmployeeImages = false,
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
  final bool canShowEmployeeImages;

  @override
  State<EmployeeListWorkspace> createState() => _EmployeeListWorkspaceState();
}

class _EmployeeListWorkspaceState extends State<EmployeeListWorkspace> {
  final _search = TextEditingController();
  final _searchFieldKey = GlobalKey();
  double? _searchFieldHeight;
  int? _companyId;
  int? _divisionId;
  int? _departmentId;
  bool? _active;
  int _sortColumn = 4;
  bool _sortAscending = true;
  bool _cardMode = false;
  bool _showEmployeeImages = false;
  final Map<(int, int?), Future<Uint8List?>> _images = {};

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
      7 => item.internalTelephone.toLowerCase(),
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
    if (!widget.canShowEmployeeImages) _showEmployeeImages = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final field = _searchFieldKey.currentContext?.findRenderObject();
      if (!mounted || field is! RenderBox || !field.hasSize) return;
      final height = field.size.height;
      if (_searchFieldHeight != height) {
        setState(() => _searchFieldHeight = height);
      }
    });
    return LayoutBuilder(
      builder: (context, layout) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _standardCard(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: widget.titleBuilder(context, widget.caption, true),
                  ),
                  if (layout.maxWidth >= 1000) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                      child: SizedBox.square(
                        dimension: t.filterActionHeight,
                        child: IconButton(
                          tooltip: _cardMode ? 'แสดงแบบรายการ' : 'แสดงแบบการ์ด',
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () =>
                              setState(() => _cardMode = !_cardMode),
                          icon: Icon(
                            _cardMode
                                ? Icons.view_list_outlined
                                : Icons.grid_view_outlined,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    if (controller.canCreate) const SizedBox(width: 8),
                  ],
                  if (controller.canCreate)
                    SizedBox(
                      height: t.filterActionHeight,
                      child: FilledButton.icon(
                        onPressed: widget.onAdd,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _standardCard(
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.canShowEmployeeImages)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _showEmployeeImages,
                          onChanged: (value) => setState(
                            () => _showEmployeeImages = value ?? false,
                          ),
                        ),
                        const Text('แสดงรูปพนักงาน'),
                      ],
                    ),
                  _filters(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _standardCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: controller.error != null
                        ? _error()
                        : LayoutBuilder(
                            builder: (_, constraints) =>
                                _cardMode || constraints.maxWidth < 1000
                                ? _cards()
                                : _table(),
                          ),
                  ),
                ],
              ),
              color:
                  (_cardMode || layout.maxWidth < 1000) &&
                      controller.items.isNotEmpty
                  ? Theme.of(context).scaffoldBackgroundColor
                  : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _paginationCard(),
        ],
      ),
    );
  }

  Widget _standardCard(Widget child, {Color color = Colors.white}) => Card(
    margin: EdgeInsets.zero,
    color: color,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.tokens.radius),
      side: BorderSide.none,
    ),
    child: child,
  );

  Widget _filters() => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: constraints.maxWidth < 600 ? constraints.maxWidth : 260,
          child: TextField(
            key: _searchFieldKey,
            controller: _search,
            onSubmitted: (_) => _applyFilters(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'ค้นหารหัส/ชื่อ/ชื่อเล่น/อีเมล',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _applyFilters,
          icon: const Icon(Icons.search),
          label: const Text('ค้นหา'),
          style: _filterButtonStyle,
        ),
        OutlinedButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('ล้าง Filter'),
          style: _filterButtonStyle.copyWith(
            foregroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primary,
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
        if (widget.customerScope)
          _dropdown<int?>(
            width: constraints.maxWidth < 280 ? constraints.maxWidth : 280,
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
            width: constraints.maxWidth < 220 ? constraints.maxWidth : 220,
            label: 'ฝ่าย',
            value: _divisionId,
            items: _organizationItems(divisions),
            changed: (value) => setState(() {
              _divisionId = value;
              _departmentId = null;
            }),
          ),
        _dropdown<int?>(
          width: constraints.maxWidth < 220 ? constraints.maxWidth : 220,
          label: 'แผนก',
          value: _departmentId,
          items: _organizationItems(departments),
          changed: (value) => setState(() => _departmentId = value),
        ),
        _dropdown<bool?>(
          width: constraints.maxWidth < 170 ? constraints.maxWidth : 170,
          label: 'สถานะ',
          value: _active,
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('ทั้งหมด')),
            DropdownMenuItem<bool?>(value: true, child: Text('เปิดใช้งาน')),
            DropdownMenuItem<bool?>(value: false, child: Text('ปิดใช้งาน')),
          ],
          changed: (value) => setState(() => _active = value),
        ),
      ],
    ),
  );

  ButtonStyle get _filterButtonStyle => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(0, _searchFieldHeight ?? widget.tokens.filterActionHeight),
    ),
    maximumSize: WidgetStatePropertyAll(
      Size(
        double.infinity,
        _searchFieldHeight ?? widget.tokens.filterActionHeight,
      ),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.tokens.radius),
      ),
    ),
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
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, constraints) {
        final available = constraints.maxWidth;
        final remaining = available - 72 - 100 - (_showEmployeeImages ? 80 : 0);
        final unit = remaining / 8.7;
        return SizedBox(
          width: available,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 20,
                  headingRowHeight: 56,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  dividerThickness: .6,
                  showBottomBorder: true,
                  headingRowColor: WidgetStatePropertyAll(
                    scheme.primary.withValues(alpha: .12),
                  ),
                  headingTextStyle: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                  dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                  sortColumnIndex:
                      _sortColumn +
                      (_showEmployeeImages && _sortColumn >= 2 ? 1 : 0),
                  sortAscending: _sortAscending,
                  columns: [
                    DataColumn(
                      columnWidth: const FixedColumnWidth(72),
                      label: const SizedBox(width: 32, child: Text('ID')),
                      onSort: (_, ascending) => setState(() {
                        _sortColumn = 0;
                        _sortAscending = ascending;
                      }),
                    ),
                    const DataColumn(
                      columnWidth: FixedColumnWidth(100),
                      label: SizedBox(
                        width: 80,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Action'),
                        ),
                      ),
                    ),
                    if (_showEmployeeImages)
                      const DataColumn(
                        columnWidth: FixedColumnWidth(80),
                        label: Text('รูป'),
                      ),
                    _column('แผนก', 2, unit),
                    _column('รหัสพนักงาน', 3, unit * 1.3),
                    _column('ชื่อ-นามสกุล', 4, unit * 1.9),
                    _column('ชื่อเล่น', 5, unit),
                    _column('โทรศัพท์', 6, unit * 1.2),
                    _column('เบอร์ภายใน', 7, unit * 1.2),
                    _column('สถานะ', 8, unit * 1.1),
                  ],
                  rows: sortedItems.indexed
                      .map((entry) {
                        final item = entry.$2;
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 32,
                                child: Text(
                                  (((controller.page - 1) *
                                              controller.pageSize) +
                                          entry.$1 +
                                          1)
                                      .toString(),
                                ),
                              ),
                            ),
                            DataCell(_actions(item)),
                            if (_showEmployeeImages) DataCell(_thumbnail(item)),
                            DataCell(_tableText(_dash(item.departmentName))),
                            DataCell(_tableText(item.employeeCode)),
                            DataCell(_tableText(item.fullName)),
                            DataCell(_tableText(_dash(item.nickName))),
                            DataCell(_tableText(_dash(item.telephone))),
                            DataCell(_tableText(_dash(item.internalTelephone))),
                            DataCell(_status(item)),
                          ],
                        );
                      })
                      .toList(growable: false),
                ),
                if (sortedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('ไม่พบข้อมูลพนักงาน')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tableText(String value) => Tooltip(
    message: value,
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  DataColumn _column(String label, int index, double width) => DataColumn(
    columnWidth: FixedColumnWidth(width),
    label: Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
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
      padding: EdgeInsets.zero,
      itemCount: sortedItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = sortedItems[index];
        return Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.tokens.radius),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showEmployeeImages) ...[
                  _thumbnail(item),
                  SizedBox(width: widget.tokens.cardSpacing),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${item.employeeCode} - ${item.fullName}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: widget.tokens.itemSpacing),
                      Text('แผนก: ${_dash(item.departmentName)}'),
                      Text('ชื่อเล่น: ${_dash(item.nickName)}'),
                      Text('โทร: ${_dash(item.telephone)}'),
                      Text('เบอร์ภายใน: ${_dash(item.internalTelephone)}'),
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

  Widget _actions(EmployeeRecord item) => SizedBox(
    width: 80,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (controller.canEdit)
          IconButton(
            tooltip: 'แก้ไข',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => widget.onEdit(item),
            icon: Icon(
              Icons.edit_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (controller.canDelete)
          IconButton(
            tooltip: 'ลบ',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => widget.onDelete(item),
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline),
          ),
        if (!controller.canEdit && !controller.canDelete) const Text('-'),
      ],
    ),
  );

  Widget _thumbnail(EmployeeRecord item) {
    final placeholder = Container(
      width: 36,
      height: 44,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
      child: Icon(
        Icons.person_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    if (!item.hasImage) {
      return widget.thumbnailBuilder?.call(context, item) ?? placeholder;
    }
    final future = _images.putIfAbsent(
      (item.employeeId, item.companyId),
      () async {
        try {
          final image = await controller.repository.getFormalImage(
            item.employeeId,
            companyId: item.companyId,
          );
          final encoded = image?['imageDataBase64'];
          return encoded is String && encoded.isNotEmpty
              ? base64Decode(encoded)
              : null;
        } catch (_) {
          return null;
        }
      },
    );
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) => snapshot.data == null
          ? placeholder
          : Tooltip(
              message: 'ดูรูปขนาดใหญ่',
              child: InkWell(
                onTap: () => _showFullImage(snapshot.data!, item.fullName),
                child:
                    widget.thumbnailBuilder?.call(context, item) ??
                    Image.memory(
                      snapshot.data!,
                      width: 36,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
              ),
            ),
    );
  }

  void _showFullImage(Uint8List bytes, String name) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(EmployeeRecord item) {
    final color = item.isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            item.isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  String _dash(String value) => value.trim().isEmpty ? '-' : value;

  Widget _paginationCard() => _standardCard(
    SizedBox(
      width: double.infinity,
      height: widget.tokens.paginationHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.tokens.cardPadding.left,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _paginationButton(
                        tooltip: 'ก่อนหน้า',
                        onPressed: controller.page > 1
                            ? controller.previousPage
                            : null,
                        label: '<',
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: widget.tokens.paginationButtonSize,
                        height: widget.tokens.paginationButtonSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(
                            widget.tokens.radius,
                          ),
                        ),
                        child: Text(
                          controller.page.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _paginationButton(
                        tooltip: 'ถัดไป',
                        onPressed: controller.page < controller.totalPages
                            ? controller.nextPage
                            : null,
                        label: '>',
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${controller.firstRow}-${controller.lastRow} '
                        'จาก ${controller.totalCount}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _paginationButton({
    required String tooltip,
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: widget.tokens.paginationButtonSize,
    height: widget.tokens.paginationButtonSize,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: onPressed == null
            ? Colors.grey.shade300
            : Theme.of(context).colorScheme.primary,
        foregroundColor: onPressed == null
            ? Colors.grey.shade600
            : Theme.of(context).colorScheme.onPrimary,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.tokens.radius),
        ),
      ),
      child: Tooltip(
        message: tooltip,
        child: Icon(
          label == '<' ? Icons.chevron_left : Icons.chevron_right,
          size: 22,
        ),
      ),
    ),
  );
}
