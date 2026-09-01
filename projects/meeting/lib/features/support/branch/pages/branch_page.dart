import 'package:flutter/material.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/combo_box_text.dart';

import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../partner/data/partner_company_repository.dart';
import '../../../partner/models/partner_company.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/branch_repository.dart';
import '../../../profile/pages/user_profile_dialog.dart';

class BranchPage extends StatefulWidget {
  const BranchPage({super.key, this.menuScope = WorkspaceMenuScope.support});
  final WorkspaceMenuScope menuScope;
  @override
  State<BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<BranchPage> {
  final _repo = BranchRepository();
  final _companiesRepo = PartnerCompanyRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<PartnerCompany> _companies = [];
  bool _loading = true;
  bool _showCards = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String? _error;
  String _status = 'ทั้งหมด';
  int? _companyFilterId;
  int _currentPage = 0;
  static const _pageSize = 20;
  int _sortColumnIndex = 3;
  bool _sortAscending = true;
  bool _showAction = false;
  Map<String, dynamic>? _actionItem;
  final _actionFormKey = GlobalKey<FormState>();
  final TextEditingController _actionCode = TextEditingController();
  final TextEditingController _actionName = TextEditingController();
  final TextEditingController _actionNameEn = TextEditingController();
  final TextEditingController _actionEmail = TextEditingController();
  final TextEditingController _actionTelephone = TextEditingController();
  final TextEditingController _actionAddress = TextEditingController();
  final TextEditingController _actionContact = TextEditingController();
  final TextEditingController _actionPhone = TextEditingController();
  final TextEditingController _actionPosition = TextEditingController();
  int? _actionCompanyId;
  bool _actionIsActive = true;
  bool _saving = false;
  String? _actionMessage;
  String? _listMessage;
  String _menuName = 'สาขา';

  String get _menuCode => switch (widget.menuScope) {
    WorkspaceMenuScope.company => '15005',
    WorkspaceMenuScope.partner => '06002',
    _ => '01003',
  };
  bool get _isCompany => widget.menuScope == WorkspaceMenuScope.company;

  List<Map<String, dynamic>> get _filteredItems => _items.where((item) {
    return _status == 'ทั้งหมด' ||
        (_status == 'เปิดใช้งาน'
            ? item['isActive'] == true
            : item['isActive'] != true);
  }).toList();
  List<Map<String, dynamic>> get _visibleItems {
    final start = _currentPage * _pageSize;
    if (start >= _filteredItems.length) return const [];
    final end = (start + _pageSize).clamp(0, _filteredItems.length);
    return _filteredItems.sublist(start, end);
  }

  int get _pageCount => (_filteredItems.length / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _showCards = userDefaultViewModeNotifier.value == 'CARD';
    userDefaultViewModeNotifier.addListener(_syncDefaultViewMode);
    _sortColumnIndex = _isCompany ? 2 : 3;
    _loadCompanies();
    _loadActions();
    _resolveMenuName();
    _load();
  }

  Future<void> _resolveMenuName() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      menuCode: _menuCode,
      routeName: switch (widget.menuScope) {
        WorkspaceMenuScope.company => 'companyBranches',
        WorkspaceMenuScope.partner => 'partnerBranches',
        _ => 'branch',
      },
      fallback: 'สาขา',
    );
    if (mounted) setState(() => _menuName = name);
  }

  Future<void> _loadActions() async {
    final support = widget.menuScope == WorkspaceMenuScope.support;
    try {
      final permissions = await _repo.actions(
        support: support,
        company: _isCompany,
      );
      if (!mounted) return;
      setState(() {
        _canCreate = permissions['create'] == true;
        _canEdit = permissions['edit'] == true;
        _canDelete = permissions['delete'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    userDefaultViewModeNotifier.removeListener(_syncDefaultViewMode);
    _search.dispose();
    _actionCode.dispose();
    _actionName.dispose();
    _actionNameEn.dispose();
    _actionEmail.dispose();
    _actionTelephone.dispose();
    _actionAddress.dispose();
    _actionContact.dispose();
    _actionPhone.dispose();
    _actionPosition.dispose();
    super.dispose();
  }

  void _syncDefaultViewMode() {
    if (mounted) {
      setState(() => _showCards = userDefaultViewModeNotifier.value == 'CARD');
    }
  }

  Future<void> _loadCompanies() async {
    if (_isCompany) {
      if (mounted) setState(() => _companies = []);
      return;
    }
    try {
      final result = await _companiesRepo.getCompanies(
        support: widget.menuScope == WorkspaceMenuScope.support,
      );
      if (mounted) setState(() => _companies = result);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 0;
    });
    try {
      final result = await _repo.get(
        search: _search.text,
        companyId: _companyFilterId,
        support: widget.menuScope == WorkspaceMenuScope.support,
        company: _isCompany,
      );
      if (mounted) setState(() => _items = result);
      _applySort();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sortBy(
    int index,
    Comparable Function(Map<String, dynamic>) selector,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = index;
      _sortAscending = ascending;
      _items = [..._items]
        ..sort((a, b) {
          final r = selector(a).compareTo(selector(b));
          return ascending ? r : -r;
        });
    });
  }

  void _applySort() {
    final selectors = <int, Comparable Function(Map<String, dynamic>)>{
      if (!_isCompany) 2: (x) => '${x['companyName']}'.toLowerCase(),
      _isCompany ? 2 : 3: (x) => '${x['branchCode']}'.toLowerCase(),
      _isCompany ? 3 : 4: (x) => '${x['branchNameTh']}'.toLowerCase(),
      _isCompany ? 7 : 8: (x) => x['isActive'] == true ? 1 : 0,
    };
    final selector = selectors[_sortColumnIndex];
    if (selector != null) _sortBy(_sortColumnIndex, selector, _sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    final page = _showAction
        ? _actionScreen(context)
        : Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _menuName,
                          favoriteKey: _menuCode,
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 900)
                        IconButton(
                          tooltip: _showCards ? 'แสดง List' : 'แสดง Card',
                          style: IconButton.styleFrom(
                            foregroundColor: preset.primary,
                            side: BorderSide(color: preset.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _showCards = !_showCards),
                          icon: Icon(
                            _showCards
                                ? Icons.table_rows_outlined
                                : Icons.grid_view_outlined,
                          ),
                        ),
                      if (MediaQuery.sizeOf(context).width >= 900)
                        const SizedBox(width: 8),
                      if (_canCreate)
                        FilledButton.icon(
                          onPressed: () => _form(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                WorkspaceSectionCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 600;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: compact ? constraints.maxWidth : 260,
                            child: TextField(
                              controller: _search,
                              onSubmitted: (_) => _load(),
                              decoration: InputDecoration(
                                labelText: 'ค้นหา Branch...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  onPressed: _load,
                                  icon: const Icon(Icons.arrow_forward),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: preset.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            onPressed: _load,
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: preset.primary,
                              side: BorderSide(color: preset.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _status = 'ทั้งหมด';
                                _companyFilterId = null;
                                _currentPage = 0;
                              });
                              _load();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้าง Filter'),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 150,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'สถานะ',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ทั้งหมด',
                                  child: LaooComboBoxText('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'เปิดใช้งาน',
                                  child: LaooComboBoxText('เปิดใช้งาน'),
                                ),
                                DropdownMenuItem(
                                  value: 'ปิดใช้งาน',
                                  child: LaooComboBoxText('ปิดใช้งาน'),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _status = v ?? 'ทั้งหมด';
                                _currentPage = 0;
                              }),
                            ),
                          ),
                          if (!_isCompany)
                            SizedBox(
                              width: compact ? constraints.maxWidth : 280,
                              child: DropdownButtonFormField<int?>(
                                isExpanded: true,
                                initialValue: _companyFilterId,
                                decoration: const InputDecoration(
                                  labelText: 'ลูกค้า',
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: LaooComboBoxText('ทั้งหมด'),
                                  ),
                                  ..._companies.map(
                                    (c) => DropdownMenuItem<int?>(
                                      value: c.companyId,
                                      child: LaooComboBoxText(c.companyNameTh),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _companyFilterId = v);
                                  _load();
                                },
                              ),
                            ),
                          if (false)
                            OutlinedButton.icon(
                              onPressed: () {
                                _search.clear();
                                setState(() {
                                  _status = 'ทั้งหมด';
                                  _companyFilterId = null;
                                });
                                _load();
                              },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('ล้าง Filter'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (false && _listMessage != null) ...[
                  AutoDismissMessage(
                    message: _listMessage!,
                    onClose: () => setState(() => _listMessage = null),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) Text(_error!),
                if (_loading) const LinearProgressIndicator(),
                if (!_loading)
                  Expanded(
                    child: _showCards || MediaQuery.sizeOf(context).width < 900
                        ? _buildMobileCards(context)
                        : LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  clipBehavior: Clip.antiAlias,
                                  child: DataTable(
                                    border: TableBorder(
                                      horizontalInside: BorderSide(
                                        color: LaooColors.border.withValues(
                                          alpha: .45,
                                        ),
                                        width: .25,
                                      ),
                                    ),
                                    horizontalMargin: 8,
                                    columnSpacing: 12,
                                    dividerThickness: .25,
                                    headingRowColor: WidgetStatePropertyAll(
                                      workspaceThemeController.value.primary
                                          .withValues(alpha: .12),
                                    ),
                                    headingTextStyle: TextStyle(
                                      color: workspaceThemeController
                                          .value
                                          .primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _sortAscending,
                                    columns: [
                                      const DataColumn(
                                        columnWidth:
                                            LaooDataTable.idColumnWidth,
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
                                        label: Text('ID'),
                                      ),
                                      const DataColumn(
                                        label: SizedBox(
                                          width: 104,
                                          child: Center(child: Text('Action')),
                                        ),
                                      ),
                                      if (!_isCompany)
                                        DataColumn(
                                          label: const Text('ลูกค้า'),
                                          onSort: (i, a) => _sortBy(
                                            i,
                                            (x) => '${x['companyName']}'
                                                .toLowerCase(),
                                            a,
                                          ),
                                        ),
                                      DataColumn(
                                        label: const Text('รหัสสาขา'),
                                        onSort: (i, a) => _sortBy(
                                          i,
                                          (x) => '${x['branchCode']}'
                                              .toLowerCase(),
                                          a,
                                        ),
                                      ),
                                      DataColumn(
                                        label: const Text('ชื่อสาขา'),
                                        onSort: (i, a) => _sortBy(
                                          i,
                                          (x) => '${x['branchNameTh']}'
                                              .toLowerCase(),
                                          a,
                                        ),
                                      ),
                                      const DataColumn(
                                        label: Text('ผู้ติดต่อ'),
                                      ),
                                      const DataColumn(label: Text('โทรศัพท์')),
                                      const DataColumn(label: Text('ตำแหน่ง')),
                                      DataColumn(
                                        label: const Text('สถานะ'),
                                        onSort: (i, a) => _sortBy(
                                          i,
                                          (x) => x['isActive'] == true ? 1 : 0,
                                          a,
                                        ),
                                      ),
                                    ],
                                    rows: _visibleItems.asMap().entries.map((
                                      e,
                                    ) {
                                      final x = e.value;
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: Text(
                                                '${_currentPage * _pageSize + e.key + 1}',
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 104,
                                              child: Center(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (_canEdit)
                                                      IconButton(
                                                        onPressed: () =>
                                                            _form(x),
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                        ),
                                                      ),
                                                    if (_canDelete)
                                                      IconButton(
                                                        onPressed: () =>
                                                            _delete(x),
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (!_isCompany)
                                            DataCell(
                                              Text('${x['companyName']}'),
                                            ),
                                          DataCell(Text('${x['branchCode']}')),
                                          DataCell(
                                            Text('${x['branchNameTh']}'),
                                          ),
                                          DataCell(
                                            Text('${x['contName'] ?? '-'}'),
                                          ),
                                          DataCell(
                                            Text('${x['contPhone'] ?? '-'}'),
                                          ),
                                          DataCell(
                                            Text(
                                              '${x['contPositionName'] ?? '-'}',
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: workspaceThemeController
                                                    .value
                                                    .primary
                                                    .withValues(alpha: .12),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                x['isActive'] == true
                                                    ? 'เปิดใช้งาน'
                                                    : 'ปิดใช้งาน',
                                                style: TextStyle(
                                                  color:
                                                      workspaceThemeController
                                                          .value
                                                          .primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                if (!_loading) const SizedBox(height: 8),
                if (!_loading)
                  WorkspaceSectionCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          child: const Icon(Icons.chevron_left),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: preset.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: null,
                          child: Text('${_currentPage + 1}'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: _currentPage < _pageCount - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          child: const Icon(Icons.chevron_right),
                        ),
                        Text(
                          '${_currentPage * _pageSize + 1}-${((_currentPage + 1) * _pageSize).clamp(0, _filteredItems.length)} จาก ${_filteredItems.length}',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
    final content = Stack(
      children: [
        Positioned.fill(child: page),
        if (_listMessage != null || _actionMessage != null)
          Positioned(
            top: 12,
            right: 24,
            child: AutoDismissMessage(
              message: _listMessage ?? _actionMessage!,
              onClose: () => setState(() {
                _listMessage = null;
                _actionMessage = null;
              }),
            ),
          ),
      ],
    );
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (_, _, _) => SupportWorkspaceShell(
        menuScope: widget.menuScope,
        pageTitle: _menuName,
        activeMenu: _menuCode,
        child: content,
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context) {
    final preset = workspaceThemeController.value;
    final primary = preset.primary;
    final textColor = preset.textPrimary;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _visibleItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _visibleItems[index];
        final statusColor = primary;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        item['isActive'] == true ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_canEdit)
                      IconButton(
                        tooltip: 'แก้ไข',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _form(item),
                        icon: Icon(Icons.edit_outlined, color: primary),
                      ),
                    if (_canDelete)
                      IconButton(
                        tooltip: 'ลบ',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _delete(item),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${item['branchCode']} | ${item['branchNameTh']}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['contName'] ?? '-'}',
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${item['contPhone'] ?? '-'}',
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _form([Map<String, dynamic>? item]) {
    _actionItem = item;
    _actionCode.text = item?['branchCode'] ?? '';
    _actionName.text = item?['branchNameTh'] ?? '';
    _actionNameEn.text = item?['branchNameEn'] ?? '';
    _actionEmail.text = item?['email'] ?? '';
    _actionTelephone.text = item?['telephone'] ?? '';
    _actionAddress.text = item?['addressText'] ?? '';
    _actionContact.text = item?['contName'] ?? '';
    _actionPhone.text = item?['contPhone'] ?? '';
    _actionPosition.text = item?['contPositionName'] ?? '';
    _actionCompanyId =
        item?['companyId'] ??
        (_companies.isNotEmpty ? _companies.first.companyId : 0);
    _actionIsActive = item?['isActive'] ?? true;
    _actionMessage = null;
    setState(() => _showAction = true);
  }

  Widget _actionScreen(BuildContext context) {
    final editing = _actionItem != null;
    final buttons = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, LaooTypography.buttonHeight),
          ),
          onPressed: _saving ? null : _cancelAction,
          child: const Text('ยกเลิก'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, LaooTypography.buttonHeight),
          ),
          onPressed: _saving ? null : _saveAction,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspaceActionHeader(
              title: '$_menuName > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
              favoriteKey: _menuCode,
              actions: [buttons],
            ),
          ),
          const SizedBox(height: 8),
          if (false && _actionMessage != null) ...[
            AutoDismissMessage(
              message: _actionMessage!,
              onClose: () => setState(() => _actionMessage = null),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: WorkspaceSectionCard(
                child: Padding(
                  padding: const EdgeInsets.all(LaooLayout.cardPadding),
                  child: Form(
                    key: _actionFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('สถานะเปิดใช้งาน'),
                            const SizedBox(width: 6),
                            Switch.adaptive(
                              value: _actionIsActive,
                              onChanged: (value) =>
                                  setState(() => _actionIsActive = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!_isCompany)
                          DropdownButtonFormField<int>(
                            initialValue: _actionCompanyId,
                            decoration: const InputDecoration(
                              labelText: 'ลูกค้า *',
                            ),
                            items: _companies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.companyId,
                                    child: LaooComboBoxText(c.companyNameTh),
                                  ),
                                )
                                .toList(),
                            onChanged: editing
                                ? null
                                : (v) => setState(() => _actionCompanyId = v),
                            validator: (value) =>
                                value == null ? 'กรุณาเลือกลูกค้า' : null,
                          ),
                        if (!_isCompany) const SizedBox(height: 12),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _actionCode,
                            decoration: const InputDecoration(
                              labelText: 'รหัสสาขา *',
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'กรุณากรอกรหัสสาขา'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _responsiveActionFields([
                          TextFormField(
                            controller: _actionName,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อสาขา *',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'กรุณากรอกชื่อสาขา'
                                : null,
                          ),
                          TextFormField(
                            controller: _actionNameEn,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อสาขา (อังกฤษ)',
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _responsiveActionFields([
                          TextFormField(
                            controller: _actionEmail,
                            decoration: const InputDecoration(
                              labelText: 'อีเมล',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return email.isEmpty ||
                                      RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(email)
                                  ? null
                                  : 'รูปแบบอีเมลไม่ถูกต้อง';
                            },
                          ),
                          TextFormField(
                            controller: _actionTelephone,
                            decoration: const InputDecoration(
                              labelText: 'โทรศัพท์สาขา',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionAddress,
                          decoration: const InputDecoration(
                            labelText: 'ที่อยู่',
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _responsiveActionFields([
                          TextFormField(
                            controller: _actionContact,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อผู้ติดต่อ',
                            ),
                          ),
                          TextFormField(
                            controller: _actionPhone,
                            decoration: const InputDecoration(
                              labelText: 'โทรศัพท์ผู้ติดต่อ',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          TextFormField(
                            controller: _actionPosition,
                            decoration: const InputDecoration(
                              labelText: 'ตำแหน่ง',
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveActionFields(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              fields[index],
              if (index < fields.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            Expanded(child: fields[index]),
            if (index < fields.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    },
  );

  void _cancelAction() {
    setState(() {
      _showAction = false;
      _actionItem = null;
      _actionMessage = null;
    });
  }

  Future<void> _saveAction() async {
    if (!(_actionFormKey.currentState?.validate() ?? false)) return;
    final editing = _actionItem != null;
    final data = {
      'companyId': _actionCompanyId,
      'branchCode': _actionCode.text.trim(),
      'branchNameTh': _actionName.text.trim(),
      'branchNameEn': _actionNameEn.text.trim(),
      'email': _actionEmail.text.trim(),
      'telephone': _actionTelephone.text.trim(),
      'addressText': _actionAddress.text.trim(),
      'contName': _actionContact.text.trim(),
      'contPhone': _actionPhone.text.trim(),
      'contPositionName': _actionPosition.text.trim(),
      'isActive': _actionIsActive,
    };
    setState(() => _saving = true);
    try {
      if (editing) {
        await _repo.update(
          _actionItem!['branchId'] as int,
          data,
          support: widget.menuScope == WorkspaceMenuScope.support,
          company: _isCompany,
        );
        if (!mounted) return;
        setState(() {
          _showAction = false;
          _actionItem = null;
          _listMessage = 'แก้ไขข้อมูลสาขาสำเร็จ';
        });
        await _load();
      } else {
        await _repo.create(
          data,
          support: widget.menuScope == WorkspaceMenuScope.support,
          company: _isCompany,
        );
        if (!mounted) return;
        _actionCode.clear();
        _actionName.clear();
        _actionNameEn.clear();
        _actionEmail.clear();
        _actionTelephone.clear();
        _actionAddress.clear();
        _actionContact.clear();
        _actionPhone.clear();
        _actionPosition.clear();
        setState(() => _actionMessage = 'เพิ่มข้อมูลสาขาสำเร็จ');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) {
        final red = Theme.of(context).colorScheme.error;
        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_outline, color: red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ยืนยันการลบข้อมูล',
                  style: LaooTypography.popupTitleStyle,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: red.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ต้องการลบ ${item['branchCode']} - ${item['branchNameTh']} หรือไม่?',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => Navigator.pop(d),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: red),
              onPressed: () => Navigator.pop(d, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await _repo.delete(
        item['branchId'] as int,
        support: widget.menuScope == WorkspaceMenuScope.support,
        company: _isCompany,
      );
      if (!mounted) return;
      setState(() => _listMessage = 'ลบข้อมูลสาขาสำเร็จ');
      await _load();
    }
  }
}
