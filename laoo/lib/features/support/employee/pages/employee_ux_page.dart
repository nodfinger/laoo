import 'package:flutter/material.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/company_setup/company_date_formatter.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/combo_box_text.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../../organization/data/organization_repository.dart';
import '../../../partner/data/partner_company_repository.dart';
import '../../../partner/models/partner_company.dart';
import '../data/employee_repository.dart';
import '../../../support/master_data/data/master_data_api.dart';
import '../../../../core/master/master_group_codes.dart';

class _EmployeeCalendarDelegate extends GregorianCalendarDelegate {
  const _EmployeeCalendarDelegate(this.buddhist);

  final bool buddhist;

  @override
  String formatMonthYear(DateTime date, MaterialLocalizations localizations) {
    final formatted = localizations.formatMonthYear(date);
    if (!buddhist) return formatted;
    return formatted.replaceAll(
      date.year.toString(),
      (date.year + 543).toString(),
    );
  }

  @override
  String formatYear(int year, MaterialLocalizations localizations) {
    return buddhist ? (year + 543).toString() : year.toString();
  }
}

class EmployeeUxPage extends StatefulWidget {
  const EmployeeUxPage({
    super.key,
    this.customer = false,
    this.companyScoped = false,
    this.menuScope = WorkspaceMenuScope.support,
  });
  final bool customer;
  final bool companyScoped;
  final WorkspaceMenuScope menuScope;

  @override
  State<EmployeeUxPage> createState() => _EmployeeUxPageState();
}

class _EmployeeUxPageState extends State<EmployeeUxPage> {
  bool showEmployeeImage = false;
  bool form = false;
  bool isActive = true;
  String? _alertMessage;
  bool _alertIsError = false;
  int sortColumn = 3;
  bool sortAscending = true;
  final OrganizationRepository _organizationRepository =
      OrganizationRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final MasterDataApi _masterDataApi = MasterDataApi();
  final PartnerCompanyRepository _companyRepository =
      PartnerCompanyRepository();
  List<PartnerCompany> companies = [];
  int? selectedCompanyId;
  String get _menuKey =>
      widget.customer ? 'customerEmployees' : 'partnerEmployees';
  List<Map<String, dynamic>> organizationUnits = [];
  int organizationMode = 1;
  int? selectedDivisionId;
  int? selectedDepartmentId;
  int? filterDivisionId;
  int? filterDepartmentId;
  DateTime? startDate;
  int? editingEmployeeId;
  final searchController = TextEditingController();
  final employeeCodeController = TextEditingController();
  final fullNameController = TextEditingController();
  final nickNameController = TextEditingController();
  final positionController = TextEditingController();
  final emailController = TextEditingController();
  final telephoneController = TextEditingController();
  final contName1Controller = TextEditingController();
  final contRelation1Controller = TextEditingController();
  final contPhone1Controller = TextEditingController();
  final contName2Controller = TextEditingController();
  final contRelation2Controller = TextEditingController();
  final contPhone2Controller = TextEditingController();
  final carId1Controller = TextEditingController();
  final carColor1Controller = TextEditingController();
  final carId2Controller = TextEditingController();
  final carColor2Controller = TextEditingController();
  List<Map<String, dynamic>> carTypes = [];
  List<Map<String, dynamic>> oilTypes = [];
  String? carType1, carOilType1, carType2, carOilType2;

  List<(String, String, String, String, String, String)> rows = [
    ('1', 'บริหาร', 'EMP0001', 'สมชาย ใจดี', 'ชาย', '081-234-5678'),
    ('2', 'ปฏิบัติการ', 'EMP0002', 'สุดา รักงาน', 'ดา', '089-876-5432'),
  ];
  List<(String, String, String, String, String, String)> allRows = [];
  final Map<String, int> _employeeIdsByCode = {};
  int _currentPage = 1;
  int _totalCount = 0;

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 50;

  int get _totalPages => _totalCount == 0
      ? 1
      : (_totalCount + _pageSize - 1) ~/ _pageSize;

  @override
  void initState() {
    super.initState();
    _resetEmployeeFilters();
    allRows = List.of(rows);
    _loadOrganizationUnits();
    _loadVehicleMasters();
    if (widget.customer && !widget.companyScoped) _loadCompanies();
    _loadEmployees();
  }

  void _resetEmployeeFilters() {
    searchController.clear();
    filterDivisionId = null;
    filterDepartmentId = null;
    _currentPage = 1;
    showEmployeeImage = false;
  }

  Future<void> _loadVehicleMasters() async {
    try {
      final values = await Future.wait([
        _masterDataApi.list(MasterGroupCodes.carType),
        _masterDataApi.list(MasterGroupCodes.oilType),
      ]);
      if (mounted) {
        setState(() {
          carTypes = values[0];
          oilTypes = values[1];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    employeeCodeController.dispose();
    fullNameController.dispose();
    nickNameController.dispose();
    positionController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    contName1Controller.dispose();
    contRelation1Controller.dispose();
    contPhone1Controller.dispose();
    contName2Controller.dispose();
    contRelation2Controller.dispose();
    contPhone2Controller.dispose();
    carId1Controller.dispose();
    carColor1Controller.dispose();
    carId2Controller.dispose();
    carColor2Controller.dispose();
    _masterDataApi.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final result = await _employeeRepository.list(
        search: searchController.text.trim(),
        divisionId: filterDivisionId,
        departmentId: _selectedFilterDepartmentId,
        companyId: selectedCompanyId,
        customer: widget.customer,
        company: widget.companyScoped,
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final items = result['items'] is List
          ? result['items'] as List
          : const [];
      final loadedRows = items
          .whereType<Map>()
          .map(
            (item) => (
              _value(item['employeeId']),
              _value(item['departmentName']),
              _value(item['employeeCode']),
              _value(item['fullName']),
              _value(item['nickName']),
              _value(item['telephone']),
            ),
          )
          .toList();
      setState(() {
        _employeeIdsByCode
          ..clear()
          ..addEntries(
            items.whereType<Map>().map((item) {
              final code = _value(item['employeeCode']);
              final rawId = item['employeeId'];
              final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
              return MapEntry(code, id ?? 0);
            }).where((entry) => entry.key.isNotEmpty && entry.value > 0),
          );
        allRows = loadedRows;
        rows = loadedRows;
        final total = result['totalCount'];
        _totalCount = total is num ? total.toInt() : loadedRows.length;
      });
    } catch (_) {
      _applyLocalSearch();
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final loaded = await _companyRepository.getCompanies();
      if (!mounted) return;
      setState(() {
        companies = loaded;
        selectedCompanyId ??= loaded.isNotEmpty ? loaded.first.companyId : null;
      });
      await _loadEmployees();
    } catch (_) {}
  }

  static String _value(dynamic value) => value is String
      ? value
      : value is num
      ? value.toString()
      : '';

  static String? _optionalText(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  int? get _selectedFilterDepartmentId {
    return filterDepartmentId;
  }

  List<Map<String, dynamic>> get filterDivisions => organizationUnits
      .where((unit) => unit['unitType'] == 'DIV' && _unitId(unit) != null)
      .toList();

  List<Map<String, dynamic>> get filterDepartments => organizationUnits.where((unit) {
    if (unit['unitType'] != 'DEP' || _unitId(unit) == null) return false;
    final rawParent = unit['parentOrgUnitId'];
    final parentId = rawParent is num
        ? rawParent.toInt()
        : int.tryParse('$rawParent');
    return filterDivisionId == null || parentId == filterDivisionId;
  }).toList();

  Future<void> _searchEmployees() async {
    _currentPage = 1;
    _applyLocalSearch();
    await _loadEmployees();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() => _currentPage = page);
    await _loadEmployees();
  }

  void _applyLocalSearch() {
    final query = searchController.text.trim().toLowerCase();
    if (allRows.isEmpty) return;
    setState(() {
      rows = allRows.where((row) {
        if (query.isEmpty) return true;
        return row.$1.toLowerCase().contains(query) ||
            row.$2.toLowerCase().contains(query) ||
            row.$3.toLowerCase().contains(query) ||
            row.$4.toLowerCase().contains(query) ||
            row.$5.toLowerCase().contains(query) ||
            row.$6.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadOrganizationUnits() async {
    try {
      final result = await _organizationRepository.load();
      if (!mounted) return;
      final rawUnits = result['units'];
      final units = rawUnits is List
          ? rawUnits
                .whereType<Map>()
                .map((unit) => Map<String, dynamic>.from(unit))
                .toList()
          : <Map<String, dynamic>>[];
      final divisions = units
          .where((unit) => unit['unitType'] == 'DIV' && _unitId(unit) != null)
          .toList();
      final modeValue = result['orgStructureType'];
      final mode = modeValue is num ? modeValue.toInt() : 1;
      final divisionId = mode == 2 && divisions.isNotEmpty
          ? _unitId(divisions.first)
          : null;
      final departments = units.where((unit) {
        if (unit['unitType'] != 'DEP' || _unitId(unit) == null) return false;
        return mode != 2 || unit['parentOrgUnitId'] == divisionId;
      }).toList();
      setState(() {
        organizationUnits = units;
        organizationMode = mode;
        selectedDivisionId = divisionId;
        selectedDepartmentId = departments.isNotEmpty
            ? _unitId(departments.first)
            : null;
      });
    } catch (_) {
      if (mounted) setState(() => organizationUnits = []);
    }
  }

  List<Map<String, dynamic>> get divisions => organizationUnits
      .where((unit) => unit['unitType'] == 'DIV' && _unitId(unit) != null)
      .toList();

  List<Map<String, dynamic>> get departments => organizationUnits.where((unit) {
    if (unit['unitType'] != 'DEP' || _unitId(unit) == null) return false;
    return organizationMode != 2 ||
        unit['parentOrgUnitId'] == selectedDivisionId;
  }).toList();

  int? _unitId(Map<String, dynamic> unit) {
    final value = unit['orgUnitId'];
    return value is num
        ? value.toInt()
        : value is String
        ? int.tryParse(value)
        : null;
  }

  String _unitLabel(Map<String, dynamic> unit) {
    final code = unit['unitCode'];
    final name = unit['nameTh'];
    if (code is String && name is String) return '$code - $name';
    if (name is String) return name;
    if (code is String) return code;
    return 'ไม่ระบุ';
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'พนักงาน',
    activeMenu: widget.customer ? 'customerEmployees' : 'partnerEmployees',
    menuScope: widget.menuScope,
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: form ? _employeeActionForm() : _employeeList(),
        ),
        if (_alertMessage != null)
          Positioned(
            top: 12,
            right: 24,
            child: AutoDismissMessage(
              key: ValueKey(_alertMessage),
              message: _alertMessage!,
              error: _alertIsError,
              onClose: () => setState(() => _alertMessage = null),
            ),
          ),
      ],
    ),
  );

  Widget _employeeList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: WorkspacePageTitle(title: 'พนักงาน', favoriteKey: _menuKey),
          ),
          FilledButton.icon(
            onPressed: _startAddEmployee,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่ม'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: searchController,
              onSubmitted: (_) => _searchEmployees(),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'ค้นหารหัส/ชื่อ/ชื่อเล่น/อีเมล',
                suffixIcon: IconButton(
                  tooltip: 'ค้นหา',
                  onPressed: _searchEmployees,
                  icon: Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          if (organizationMode == 2)
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<int>(
                initialValue: filterDivisionId,
                decoration: const InputDecoration(labelText: 'ฝ่าย'),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: LaooComboBoxText('ทั้งหมด'),
                  ),
                  ...filterDivisions.map(
                    (unit) => DropdownMenuItem<int>(
                      value: _unitId(unit),
                      child: LaooComboBoxText(_unitLabel(unit)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    filterDivisionId = value;
                    filterDepartmentId = null;
                  });
                  _searchEmployees();
                },
              ),
            ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<int>(
              initialValue: filterDepartmentId,
              decoration: const InputDecoration(labelText: 'แผนก'),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: LaooComboBoxText('ทั้งหมด'),
                ),
                ...filterDepartments.map(
                  (unit) => DropdownMenuItem<int>(
                    value: _unitId(unit),
                    child: LaooComboBoxText(_unitLabel(unit)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => filterDepartmentId = value);
                _searchEmployees();
              },
            ),
          ),
          if (widget.customer && !widget.companyScoped)
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<int>(
                initialValue: selectedCompanyId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: companies
                    .map(
                      (company) => DropdownMenuItem<int>(
                        value: company.companyId,
                        child: LaooComboBoxText(company.companyNameTh),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCompanyId = value;
                    _currentPage = 1;
                  });
                  _loadEmployees();
                },
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              searchController.clear();
              setState(() {
                filterDivisionId = null;
                filterDepartmentId = null;
              });
              _searchEmployees();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: showEmployeeImage,
                  onChanged: (value) =>
                      setState(() => showEmployeeImage = value),
                ),
              ),
              const Text('แสดงรูปพนักงาน'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(child: _employeeTableStyle()),
      const SizedBox(height: 12),
      _paginationBar(),
    ],
  );

  Widget _paginationBar() {
    final first = _totalCount == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final last = _totalCount == 0
        ? 0
        : (first + _pageSize - 1).clamp(0, _totalCount);
    final primary = Theme.of(context).colorScheme.primary;
    Widget circleButton({
      required Widget child,
      VoidCallback? onPressed,
      bool selected = false,
    }) => SizedBox(
      width: 34,
      height: 34,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: .65)),
                shape: const CircleBorder(),
              ),
              child: child,
            ),
    );
    return Row(
      children: [
        circleButton(
          onPressed: _currentPage > 1
              ? () => _goToPage(_currentPage - 1)
              : null,
          child: const Icon(Icons.chevron_left, size: 20),
          selected: _currentPage > 1,
        ),
        const SizedBox(width: 8),
        ...List.generate(_totalPages, (index) {
          final page = index + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: circleButton(
              onPressed: () => _goToPage(page),
              selected: page == _currentPage,
              child: Text('$page'),
            ),
          );
        }),
        circleButton(
          onPressed: _currentPage < _totalPages
              ? () => _goToPage(_currentPage + 1)
              : null,
          child: const Icon(Icons.chevron_right, size: 20),
          selected: _currentPage < _totalPages,
        ),
        const SizedBox(width: 8),
        Text('แสดง $first-$last จาก $_totalCount รายการ'),
      ],
    );
  }

  Widget _employeeTableStyle() {
    final primary = Theme.of(context).colorScheme.primary;
    final border = Theme.of(context).dividerColor;
    const minTableWidth = 900.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < minTableWidth
            ? minTableWidth
            : constraints.maxWidth;
        const idWidth = 40.0;
        const actionWidth = 92.0;
        const phoneWidth = 140.0;
        const horizontalMargin = 16.0;
        const columnSpacing = 16.0;
        final remainingWidth =
            tableWidth -
            (idWidth + actionWidth + phoneWidth) -
            (horizontalMargin * 2) -
            (columnSpacing * 6);
        final departmentWidth = remainingWidth * 0.18;
        final employeeCodeWidth = remainingWidth * 0.18;
        final employeeNameWidth = remainingWidth * 0.34;
        final nicknameWidth = remainingWidth * 0.15;

        Widget headerText(String text, double width) => SizedBox(
          width: width,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );

        Widget cellText(String text, double width) => SizedBox(
          width: width,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );

        return Align(
          alignment: Alignment.topLeft,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  horizontalMargin: horizontalMargin,
                  columnSpacing: columnSpacing,
                  sortColumnIndex: sortColumn,
                  sortAscending: sortAscending,
                  headingRowColor: WidgetStateProperty.all(
                    primary.withValues(alpha: 0.12),
                  ),
                  headingTextStyle: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  columns: [
                    DataColumn(
                      label: headerText('ID', idWidth),
                      onSort: (index, ascending) => _sortBy(index, ascending),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: actionWidth,
                        child: const Center(child: Text('Action')),
                      ),
                    ),
                    DataColumn(
                      label: headerText('แผนก', departmentWidth),
                      onSort: (index, ascending) => _sortBy(index, ascending),
                    ),
                    DataColumn(
                      label: headerText('รหัสพนักงาน', employeeCodeWidth),
                      onSort: (index, ascending) => _sortBy(index, ascending),
                    ),
                    DataColumn(
                      label: headerText('ชื่อ-นามสกุล', employeeNameWidth),
                      onSort: (index, ascending) => _sortBy(index, ascending),
                    ),
                    DataColumn(
                      label: headerText('ชื่อเล่น', nicknameWidth),
                      onSort: (index, ascending) => _sortBy(index, ascending),
                    ),
                    DataColumn(
                      label: headerText('โทรศัพท์', phoneWidth),
                      onSort: (index, ascending) => _sortBy(index, ascending),
                    ),
                  ],
                  rows: rows.asMap().entries
                      .map(
                        (entry) {
                          final row = entry.value;
                          final displayId =
                              ((_currentPage - 1) * _pageSize) + entry.key + 1;
                          return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: idWidth,
                                child: Text('$displayId'),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: actionWidth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'แก้ไข',
                                      onPressed: () =>
                                          _openEmployeeEdit(row.$3),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'ลบ',
                                      onPressed: () => _deleteEmployee(row.$3),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(cellText(row.$2, departmentWidth)),
                            DataCell(cellText(row.$3, employeeCodeWidth)),
                            DataCell(
                              SizedBox(
                                width: employeeNameWidth,
                                child: Row(
                                  children: [
                                    if (showEmployeeImage) ...[
                                      const CircleAvatar(
                                        radius: 14,
                                        child: Icon(
                                          Icons.person_outline,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: Text(
                                        row.$4,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(cellText(row.$5, nicknameWidth)),
                            DataCell(cellText(row.$6, phoneWidth)),
                          ],
                          );
                        },
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _list() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: WorkspacePageTitle(title: 'พนักงาน', favoriteKey: _menuKey),
          ),
          FilledButton.icon(
            onPressed: () => setState(() => form = true),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่ม'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const SizedBox(
            width: 300,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'ค้นหารหัส/ชื่อ/ชื่อเล่น/อีเมล',
                suffixIcon: Icon(Icons.arrow_forward),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        title: const Text('แสดงรูปพนักงาน'),
        value: showEmployeeImage,
        onChanged: (value) => setState(() => showEmployeeImage = value),
      ),
      const SizedBox(height: 4),
      Expanded(child: _sortableTable()),
      const SizedBox(height: 12),
      _paginationBar(),
    ],
  );

  Widget _table() => Card(
    child: ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (showEmployeeImage) ...[
              const CircleAvatar(child: Icon(Icons.person_outline)),
              const SizedBox(width: 12),
            ],
            Expanded(flex: 1, child: Text(rows[i].$1)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'แก้ไข',
                  onPressed: () => setState(() => form = true),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
            Expanded(flex: 2, child: Text(rows[i].$2)),
            Expanded(flex: 2, child: Text(rows[i].$3)),
            Expanded(flex: 3, child: Text(rows[i].$4)),
            Expanded(flex: 2, child: Text(rows[i].$5)),
            Expanded(flex: 3, child: Text(rows[i].$6)),
          ],
        ),
      ),
    ),
  );

  Widget _tableWithHeader() => Card(
    child: Column(
      children: [
        _tableHeaderRow(),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (_, i) => _employeeRow(i),
          ),
        ),
      ],
    ),
  );

  Widget _tableHeaderRow() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Text('ID', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          flex: 2,
          child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          flex: 2,
          child: Text('แผนก', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'รหัสพนักงาน',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'ชื่อ-นามสกุล',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'ชื่อเล่น',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'โทรศัพท์',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _employeeRow(int index) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(flex: 1, child: Text(rows[index].$1)),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'แก้ไข',
              onPressed: () => setState(() => form = true),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ),
        Expanded(flex: 2, child: Text(rows[index].$2)),
        Expanded(flex: 2, child: Text(rows[index].$3)),
        Expanded(flex: 3, child: Text(rows[index].$4)),
        Expanded(flex: 2, child: Text(rows[index].$5)),
        Expanded(flex: 3, child: Text(rows[index].$6)),
      ],
    ),
  );

  void _sortBy(int column, bool ascending) {
    setState(() {
      sortColumn = column;
      sortAscending = ascending;
      rows.sort((a, b) {
        final result = _sortValue(a, column).compareTo(_sortValue(b, column));
        return sortAscending ? result : -result;
      });
    });
  }

  String _sortValue(
    (String, String, String, String, String, String) row,
    int column,
  ) => switch (column) {
    0 => row.$1,
    2 => row.$2,
    3 => row.$3,
    4 => row.$4,
    5 => row.$5,
    6 => row.$6,
    _ => '',
  };

  Widget _sortableTable() {
    final borderColor = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _sortableHeaderRow(),
            Divider(height: 1, color: Colors.grey.shade300),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.grey.shade300),
                itemBuilder: (_, i) => _sortableEmployeeRow(i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortableHeaderRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        _sortHeaderCell('ID', 0, 1),
        _sortHeaderCell('Action', 1, 2),
        _sortHeaderCell('แผนก', 2, 2),
        _sortHeaderCell('รหัสพนักงาน', 3, 2),
        _sortHeaderCell('ชื่อ-นามสกุล', 4, 3),
        _sortHeaderCell('ชื่อเล่น', 5, 2),
        _sortHeaderCell('โทรศัพท์', 6, 3),
      ],
    ),
  );

  Widget _sortHeaderCell(String label, int column, int flex) => Expanded(
    flex: flex,
    child: InkWell(
      onTap: () =>
          _sortBy(column, sortColumn == column ? !sortAscending : true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (sortColumn == column)
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
            ),
        ],
      ),
    ),
  );

  Widget _sortableEmployeeRow(int index) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(flex: 1, child: Text(rows[index].$1)),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              IconButton(
                tooltip: 'แก้ไข',
                onPressed: () => setState(() => form = true),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'ลบ',
                onPressed: () {},
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
        Expanded(flex: 2, child: Text(rows[index].$2)),
        Expanded(flex: 2, child: Text(rows[index].$3)),
        Expanded(flex: 3, child: Text(rows[index].$4)),
        Expanded(flex: 2, child: Text(rows[index].$5)),
        Expanded(flex: 3, child: Text(rows[index].$6)),
      ],
    ),
  );

  Widget _employeeActionForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: WorkspacePageTitle(
              title:
                  'พนักงาน > ${editingEmployeeId == null ? 'เพิ่ม' : 'แก้ไข'}',
              favoriteKey: _menuKey,
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => form = false),
            child: const Text('ยกเลิก'),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _saveEmployee, child: const Text('บันทึก')),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: SingleChildScrollView(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ข้อมูลส่วนตัว',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 180,
                        child: Row(
                          children: [
                            const Text('สถานะ'),
                            const SizedBox(width: 8),
                            Switch(
                              value: isActive,
                              onChanged: (value) =>
                                  setState(() => isActive = value),
                            ),
                          ],
                        ),
                      ),
                      _actionField(
                        'รหัสพนักงาน *',
                        employeeCodeController,
                        width: 220,
                      ),
                      _actionField('ชื่อ-นามสกุล *', fullNameController),
                      _startDateField(),
                      _actionField('ชื่อเล่น', nickNameController),
                      if (organizationMode == 2)
                        SizedBox(
                          width: 320,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(selectedDivisionId),
                            initialValue: selectedDivisionId,
                            decoration: const InputDecoration(
                              labelText: 'ฝ่าย',
                            ),
                            items: divisions
                                .map(
                                  (unit) => DropdownMenuItem<int>(
                                    value: _unitId(unit),
                                    child: LaooComboBoxText(_unitLabel(unit)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedDivisionId = value;
                                selectedDepartmentId = departments.isNotEmpty
                                    ? _unitId(departments.first)
                                    : null;
                              });
                            },
                          ),
                        ),
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(
                            '${organizationMode}_$selectedDivisionId',
                          ),
                          initialValue:
                              departments.any(
                                (unit) =>
                                    unit['orgUnitId'] == selectedDepartmentId,
                              )
                              ? selectedDepartmentId
                              : null,
                          decoration: const InputDecoration(labelText: 'แผนก'),
                          items: departments
                              .map(
                                (unit) => DropdownMenuItem<int>(
                                  value: _unitId(unit),
                                  child: LaooComboBoxText(_unitLabel(unit)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedDepartmentId = value),
                        ),
                      ),
                      _actionField('ตำแหน่ง', positionController),
                      _actionField('Email', emailController),
                      _actionField('โทรศัพท์', telephoneController),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'กรณีฉุกเฉิน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _emergencyRow(
                            contName1Controller,
                            contRelation1Controller,
                            contPhone1Controller,
                          ),
                          const SizedBox(height: 12),
                          _emergencyRow(
                            contName2Controller,
                            contRelation2Controller,
                            contPhone2Controller,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _vehicleCard(),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => form = false),
              child: const Text('ยกเลิก'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _saveEmployee, child: const Text('บันทึก')),
          ],
        ),
      ),
    ],
  );

  Widget _actionField(
    String label,
    TextEditingController controller, {
    double width = 320,
  }) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _startDateField() => SizedBox(
    width: 220,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickStartDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'วันที่เริ่มงาน',
          suffixIcon: Icon(Icons.calendar_month_outlined),
        ),
          child: Text(
            startDate == null
                ? 'เลือกวันที่'
              : CompanyDateFormatter.formatDateByYearFormat(
                  startDate!,
                  companySetupController.current?.yearFormat ?? 'C',
                ),
        ),
      ),
    ),
  );

  Widget _vehicleCard() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ยานพาหนะที่ใช้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          _vehicleRow(carId1Controller, carColor1Controller, carType1, carOilType1, (v) => setState(() => carType1 = v), (v) => setState(() => carOilType1 = v)),
          const SizedBox(height: 12),
          _vehicleRow(carId2Controller, carColor2Controller, carType2, carOilType2, (v) => setState(() => carType2 = v), (v) => setState(() => carOilType2 = v)),
        ],
      ),
    ),
  );

  Widget _vehicleRow(TextEditingController id, TextEditingController color, String? type, String? oil, ValueChanged<String?> onType, ValueChanged<String?> onOil) => Row(
    children: [
      Expanded(child: _actionField('ทะเบียนรถ', id)),
      const SizedBox(width: 12),
      Expanded(child: _actionField('สีรถ', color)),
      const SizedBox(width: 12),
      Expanded(child: DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'ประเภทรถ'), items: carTypes.map((x) => DropdownMenuItem(value: _value(x['code']), child: LaooComboBoxText(_value(x['name'])))).toList(), onChanged: onType)),
      const SizedBox(width: 12),
      Expanded(child: DropdownButtonFormField<String>(initialValue: oil, decoration: const InputDecoration(labelText: 'เชื้อเพลิง'), items: oilTypes.map((x) => DropdownMenuItem(value: _value(x['code']), child: LaooComboBoxText(_value(x['name'])))).toList(), onChanged: onOil)),
    ],
  );

  Widget _emergencyRow(
    TextEditingController name,
    TextEditingController relation,
    TextEditingController phone,
  ) => Row(
    children: [
      Expanded(child: _emergencyField('ผู้ติดต่อ', name)),
      const SizedBox(width: 12),
      Expanded(child: _emergencyField('ความสัมพันธ์', relation)),
      const SizedBox(width: 12),
      Expanded(child: _emergencyField('โทรศัพท์', phone)),
    ],
  );

  Widget _emergencyField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      );

  Future<void> _saveEmployee() async {
    final wasEditing = editingEmployeeId != null;
    if (employeeCodeController.text.trim().isEmpty ||
        fullNameController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _alertMessage = 'กรุณากรอกรหัสพนักงานและชื่อ-นามสกุล';
          _alertIsError = true;
        });
      }
      return;
    }
    if (selectedDepartmentId == null ||
        (organizationMode == 2 && selectedDivisionId == null)) {
      if (mounted) {
        setState(() {
          _alertMessage = organizationMode == 2
              ? 'กรุณาเลือกฝ่ายและแผนกก่อนบันทึก'
              : 'กรุณาเลือกแผนกก่อนบันทึก';
          _alertIsError = true;
        });
      }
      return;
    }
    final body = {
      'divisionOrgUnitId': selectedDivisionId,
      'departmentOrgUnitId': selectedDepartmentId,
      'employeeCode': employeeCodeController.text.trim(),
      'fullName': fullNameController.text.trim(),
      'nickName': nickNameController.text.trim().isEmpty
          ? null
          : nickNameController.text.trim(),
      'positionCode': positionController.text.trim().isEmpty
          ? null
          : positionController.text.trim(),
      'email': emailController.text.trim().isEmpty
          ? null
          : emailController.text.trim(),
      'telephone': telephoneController.text.trim().isEmpty
          ? null
          : telephoneController.text.trim(),
      'contName1': contName1Controller.text.trim().isEmpty
          ? null
          : contName1Controller.text.trim(),
      'contRelation1': contRelation1Controller.text.trim().isEmpty
          ? null
          : contRelation1Controller.text.trim(),
      'contPhone1': contPhone1Controller.text.trim().isEmpty
          ? null
          : contPhone1Controller.text.trim(),
      'contName2': contName2Controller.text.trim().isEmpty
          ? null
          : contName2Controller.text.trim(),
      'contRelation2': contRelation2Controller.text.trim().isEmpty
          ? null
          : contRelation2Controller.text.trim(),
      'contPhone2': contPhone2Controller.text.trim().isEmpty
          ? null
          : contPhone2Controller.text.trim(),
      'carID1': _optionalText(carId1Controller),
      'carColor1': _optionalText(carColor1Controller),
      'carTypeCode1': carType1,
      'carOilType1': carOilType1,
      'carID2': _optionalText(carId2Controller),
      'carColor2': _optionalText(carColor2Controller),
      'carTypeCode2': carType2,
      'carOilType2': carOilType2,
      'startWorkDate': startDate?.toIso8601String().split('T').first,
      'isActive': isActive,
    };
    try {
      body['companyId'] = widget.customer ? selectedCompanyId : null;
      if (editingEmployeeId == null) {
        await _employeeRepository.create(
          body,
          customer: widget.customer,
          company: widget.companyScoped,
        );
      } else {
        await _employeeRepository.update(
          editingEmployeeId!,
          body,
          customer: widget.customer,
          company: widget.companyScoped,
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _alertMessage = 'บันทึกไม่สำเร็จ: ${error.message}';
        _alertIsError = true;
      });
      return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _alertMessage = 'บันทึกไม่สำเร็จ: $error';
        _alertIsError = true;
      });
      return;
    }
    if (!mounted) return;
    employeeCodeController.clear();
    fullNameController.clear();
    nickNameController.clear();
    positionController.clear();
      emailController.clear();
      telephoneController.clear();
      contName1Controller.clear();
      contRelation1Controller.clear();
      contPhone1Controller.clear();
      contName2Controller.clear();
      contRelation2Controller.clear();
      contPhone2Controller.clear();
      carId1Controller.clear(); carColor1Controller.clear(); carId2Controller.clear(); carColor2Controller.clear();
    setState(() {
      startDate = null;
      selectedDivisionId = null;
      selectedDepartmentId = null;
      isActive = true;
      editingEmployeeId = null;
      form = !wasEditing;
    });
    setState(() {
      _alertMessage = !wasEditing
          ? 'เพิ่มข้อมูลใหม่สำเร็จ'
          : 'แก้ไขพนักงานสำเร็จ';
      _alertIsError = false;
    });
    await _loadEmployees();
  }

  void _startAddEmployee() {
    employeeCodeController.clear();
    fullNameController.clear();
    nickNameController.clear();
    positionController.clear();
    emailController.clear();
    telephoneController.clear();
    contName1Controller.clear();
    contRelation1Controller.clear();
    contPhone1Controller.clear();
    contName2Controller.clear();
    contRelation2Controller.clear();
      contPhone2Controller.clear();
      carId1Controller.clear(); carColor1Controller.clear(); carId2Controller.clear(); carColor2Controller.clear();
    setState(() {
      editingEmployeeId = null;
      startDate = null;
      selectedDivisionId = null;
      selectedDepartmentId = null;
      isActive = true;
      _alertMessage = null;
      form = true;
    });
  }

  Future<void> _openEmployeeEdit(String value) async {
    final id = _employeeIdsByCode[value] ?? int.tryParse(value);
    if (id == null) return;
    final result = await _employeeRepository.list(
      page: _currentPage,
      pageSize: _pageSize,
      companyId: selectedCompanyId,
      customer: widget.customer,
      company: widget.companyScoped,
    );
    final items = result['items'] is List ? result['items'] as List : const [];
    final item = items.whereType<Map>().cast<Map<String, dynamic>>().firstWhere(
      (row) => row['employeeId'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (item.isEmpty || !mounted) return;
    setState(() {
      editingEmployeeId = id;
      employeeCodeController.text = _value(item['employeeCode']);
      fullNameController.text = _value(item['fullName']);
      nickNameController.text = _value(item['nickName']);
      positionController.text = _value(item['positionCode']);
      emailController.text = _value(item['email']);
      telephoneController.text = _value(item['telephone']);
      contName1Controller.text = _value(item['contName1']);
      contRelation1Controller.text = _value(item['contRelation1']);
      contPhone1Controller.text = _value(item['contPhone1']);
      contName2Controller.text = _value(item['contName2']);
      contRelation2Controller.text = _value(item['contRelation2']);
      contPhone2Controller.text = _value(item['contPhone2']);
      carId1Controller.text = _value(item['carID1']);
      carColor1Controller.text = _value(item['carColor1']);
      carType1 = _value(item['carTypeCode1']).isEmpty ? null : _value(item['carTypeCode1']);
      carOilType1 = _value(item['carOilType1']).isEmpty ? null : _value(item['carOilType1']);
      carId2Controller.text = _value(item['carID2']);
      carColor2Controller.text = _value(item['carColor2']);
      carType2 = _value(item['carTypeCode2']).isEmpty ? null : _value(item['carTypeCode2']);
      carOilType2 = _value(item['carOilType2']).isEmpty ? null : _value(item['carOilType2']);
      selectedDivisionId = item['divisionOrgUnitId'] as int?;
      selectedDepartmentId = item['departmentOrgUnitId'] as int?;
      isActive = item['isActive'] == true;
      final rawDate = item['startWorkDate'];
      startDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
      form = true;
    });
  }

  Future<void> _deleteEmployee(String value) async {
    final id = _employeeIdsByCode[value] ?? int.tryParse(value);
    if (id == null) return;
    var employeeName = value;
    for (final row in rows) {
      if (row.$3 == value) {
        employeeName = row.$4;
        break;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFE9F0EC),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.red),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูลพนักงาน',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ $value - $employeeName หรือไม่?',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(82, 44),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _employeeRepository.delete(
        id,
        companyId: selectedCompanyId,
        customer: widget.customer,
        company: widget.companyScoped,
      );
      if (!mounted) return;
      setState(() {
        _alertMessage = 'ลบข้อมูลพนักงานสำเร็จ';
        _alertIsError = true;
      });
      await _loadEmployees();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _alertMessage = 'ลบข้อมูลไม่สำเร็จ: ${error.message}';
          _alertIsError = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _alertMessage = 'ลบข้อมูลไม่สำเร็จ: $error';
          _alertIsError = true;
        });
      }
    }
  }

  Future<void> _pickStartDate() async {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final selected = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: _isBuddhistYear
          ? const Locale('th', 'TH')
          : const Locale('en', 'US'),
      calendarDelegate: _EmployeeCalendarDelegate(_isBuddhistYear),
      builder: (context, child) {
        final dateTheme = theme.copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: primary,
            headerForegroundColor: theme.colorScheme.onPrimary,
            todayForegroundColor: WidgetStatePropertyAll(primary),
            todayBorder: BorderSide(color: primary),
            dayForegroundColor: WidgetStatePropertyAll(
              theme.colorScheme.onSurface,
            ),
            dayOverlayColor: WidgetStatePropertyAll(
              primary.withValues(alpha: 0.12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
        return Theme(
          data: dateTheme,
          child: Transform.scale(scale: 0.88, child: child!),
        );
      },
    );
    if (selected != null && mounted) setState(() => startDate = selected);
  }

  bool get _isBuddhistYear {
    final format = companySetupController.current?.yearFormat.toUpperCase();
    return format == 'B' ||
        format == 'BE' ||
        format == 'T' ||
        format == 'TH' ||
        format == 'THAI';
  }

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: WorkspacePageTitle(
              title: 'พนักงาน > เพิ่ม',
              favoriteKey: _menuKey,
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => form = false),
            child: const Text('ยกเลิก'),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () {}, child: const Text('บันทึก')),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: SingleChildScrollView(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ข้อมูลส่วนตัว',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('สถานะ'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final label in const [
                        'รหัสพนักงาน *',
                        'ชื่อ-นามสกุล *',
                        'ชื่อเล่น',
                        'ฝ่าย',
                        'แผนก',
                        'ตำแหน่ง',
                        'Email',
                        'โทรศัพท์',
                        'โทรศัพท์ส่วนตัว',
                        'วันที่เริ่มงาน',
                      ])
                        SizedBox(
                          width: 320,
                          child: TextField(
                            decoration: InputDecoration(labelText: label),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('กรณีฉุกเฉินติดต่อ (สูงสุด 2 คน)'),
                  const SizedBox(height: 70),
                  const Text('ยานพาหนะส่วนตัว (สูงสุด 2 คัน)'),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => form = false),
              child: const Text('ยกเลิก'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () {}, child: const Text('บันทึก')),
          ],
        ),
      ),
    ],
  );
}
