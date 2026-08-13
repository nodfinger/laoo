import 'package:flutter/material.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/combo_box_text.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../../../partner/data/partner_company_repository.dart';
import '../../../partner/models/partner_company.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/branch_repository.dart';

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
    _loadCompanies();
    _load();
  }

  @override
  void dispose() {
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

  Future<void> _loadCompanies() async {
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
      2: (x) => '${x['companyName']}'.toLowerCase(),
      3: (x) => '${x['branchCode']}'.toLowerCase(),
      4: (x) => '${x['branchNameTh']}'.toLowerCase(),
      8: (x) => x['isActive'] == true ? 1 : 0,
    };
    final selector = selectors[_sortColumnIndex];
    if (selector != null) _sortBy(_sortColumnIndex, selector, _sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = _showAction
        ? _actionScreen(context)
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WorkspacePageTitle(
                        title: 'สาขา',
                        favoriteKey: 'branch',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _form(),
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
                    SizedBox(
                      width: 330,
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'สถานะ'),
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
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _companyFilterId,
                        decoration: const InputDecoration(labelText: 'ลูกค้า'),
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
                    const SizedBox(width: 8),
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
                ),
                const SizedBox(height: 12),
                if (_listMessage != null) ...[
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
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            child: DataTable(
                              border: TableBorder(
                                top: BorderSide(color: Theme.of(context).dividerColor, width: .5),
                                bottom: BorderSide(color: Theme.of(context).dividerColor, width: .5),
                                horizontalInside: BorderSide(color: Theme.of(context).dividerColor, width: .5),
                              ),
                              horizontalMargin: 8,
                              columnSpacing: 12,
                              dividerThickness: 1,
                              headingRowColor: WidgetStatePropertyAll(
                                scheme.primary.withValues(alpha: .12),
                              ),
                              headingTextStyle: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              columns: [
                                const DataColumn(
                                  numeric: true,
                                  label: SizedBox(width: 50, child: Text('ID')),
                                ),
                                const DataColumn(
                                  label: SizedBox(
                                    width: 82,
                                    child: Center(child: Text('Action')),
                                  ),
                                ),
                                DataColumn(
                                  label: const Text('ลูกค้า'),
                                  onSort: (i, a) => _sortBy(
                                    i,
                                    (x) => '${x['companyName']}'.toLowerCase(),
                                    a,
                                  ),
                                ),
                                DataColumn(
                                  label: const Text('รหัสสาขา'),
                                  onSort: (i, a) => _sortBy(
                                    i,
                                    (x) => '${x['branchCode']}'.toLowerCase(),
                                    a,
                                  ),
                                ),
                                DataColumn(
                                  label: const Text('ชื่อสาขา'),
                                  onSort: (i, a) => _sortBy(
                                    i,
                                    (x) => '${x['branchNameTh']}'.toLowerCase(),
                                    a,
                                  ),
                                ),
                                const DataColumn(label: Text('ผู้ติดต่อ')),
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
                              rows: _visibleItems.asMap().entries.map((e) {
                                final x = e.value;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          '${_currentPage * _pageSize + e.key + 1}',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 82,
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: () => _form(x),
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () => _delete(x),
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
                                    DataCell(Text('${x['companyName']}')),
                                    DataCell(Text('${x['branchCode']}')),
                                    DataCell(Text('${x['branchNameTh']}')),
                                    DataCell(Text('${x['contName'] ?? '-'}')),
                                    DataCell(Text('${x['contPhone'] ?? '-'}')),
                                    DataCell(
                                      Text('${x['contPositionName'] ?? '-'}'),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: x['isActive'] == true
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          x['isActive'] == true
                                              ? 'เปิดใช้งาน'
                                              : 'ปิดใช้งาน',
                                          style: TextStyle(
                                            color: x['isActive'] == true
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
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
                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          child: const Text('ก่อนหน้า'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: null,
                          child: Text('${_currentPage + 1}'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _currentPage < _pageCount - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          child: const Text('ถัดไป'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'แสดง ${_currentPage * _pageSize + 1}-${((_currentPage + 1) * _pageSize).clamp(0, _filteredItems.length)} จาก ${_filteredItems.length} รายการ',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: 'สาขา',
      activeMenu: 'branch',
      child: content,
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
        (_companies.isNotEmpty ? _companies.first.companyId : null);
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: WorkspacePageTitle(
                  title: 'สาขา > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
                  favoriteKey: 'branch',
                ),
              ),
              const SizedBox(width: 16),
              buttons,
            ],
          ),
          const SizedBox(height: 8),
          if (_actionMessage != null) ...[
            AutoDismissMessage(
              message: _actionMessage!,
              onClose: () => setState(() => _actionMessage = null),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                        const SizedBox(height: 12),
                        TextFormField(
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
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionNameEn,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อสาขา (อังกฤษ)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionEmail,
                          decoration: const InputDecoration(labelText: 'อีเมล'),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionTelephone,
                          decoration: const InputDecoration(
                            labelText: 'โทรศัพท์สาขา',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
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
                        TextFormField(
                          controller: _actionContact,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อผู้ติดต่อ',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionPhone,
                          decoration: const InputDecoration(
                            labelText: 'โทรศัพท์ผู้ติดต่อ',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionPosition,
                          decoration: const InputDecoration(
                            labelText: 'ตำแหน่ง',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          buttons,
        ],
      ),
    );
  }

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: red, width: 1.5),
          ),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: red.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.delete_outline, color: red),
          ),
          title: Text(
            'ยืนยันการลบ สาขา',
            style: TextStyle(color: red, fontWeight: FontWeight.w700),
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
      );
      if (!mounted) return;
      setState(() => _listMessage = 'ลบข้อมูลสาขาสำเร็จ');
      await _load();
    }
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
