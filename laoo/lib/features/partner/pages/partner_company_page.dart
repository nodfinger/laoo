import 'package:flutter/material.dart';

import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../data/partner_company_repository.dart';
import '../models/partner_company.dart';

/// Shared user-service company screen. The API applies the caller's data scope:
/// Support sees all records, Partner sees records belonging to that partner.
class PartnerCompanyPage extends StatefulWidget {
  const PartnerCompanyPage({super.key, this.menuScope = WorkspaceMenuScope.partner});

  final WorkspaceMenuScope menuScope;

  @override
  State<PartnerCompanyPage> createState() => _PartnerCompanyPageState();
}

class _PartnerCompanyFormPage extends StatefulWidget {
  const _PartnerCompanyFormPage({this.existing});

  final PartnerCompany? existing;

  @override
  State<_PartnerCompanyFormPage> createState() => _PartnerCompanyFormPageState();
}

class _PartnerCompanyFormPageState extends State<_PartnerCompanyFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameTh;
  late final TextEditingController _nameEn;
  late final TextEditingController _taxId;
  late final TextEditingController _email;
  late final TextEditingController _telephone;
  late final TextEditingController _address;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _nameTh = TextEditingController(text: item?.companyNameTh ?? '');
    _nameEn = TextEditingController(text: item?.companyNameEn ?? '');
    _taxId = TextEditingController(text: item?.taxId ?? '');
    _email = TextEditingController(text: item?.email ?? '');
    _telephone = TextEditingController(text: item?.telephone ?? '');
    _address = TextEditingController(text: item?.addressText ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_nameTh, _nameEn, _taxId, _email, _telephone, _address]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final input = PartnerCompanyInput(
        companyNameTh: _nameTh.text.trim(),
        companyNameEn: _optional(_nameEn),
        taxId: _optional(_taxId),
        email: _optional(_email),
        telephone: _optional(_telephone),
        addressText: _optional(_address),
      );
      final repository = PartnerCompanyRepository();
      if (widget.existing == null) {
        await repository.createCompany(input);
      } else {
        await repository.updateCompany(widget.existing!.companyId, input);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = 'บันทึกไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.partner,
      pageTitle: 'ข้อมูลผู้ใช้บริการ > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
      activeMenu: 'partnerCompanies',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  MaterialBanner(
                    content: Text(_error!),
                    leading: const Icon(Icons.error_outline),
                    actions: [TextButton(onPressed: () => setState(() => _error = null), child: const Text('ปิด'))],
                  ),
                ],
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('ข้อมูลผู้ใช้บริการ', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        _formField(_nameTh, 'ชื่อผู้ใช้บริการ (ภาษาไทย) *', required: true),
                        _formField(_nameEn, 'ชื่อผู้ใช้บริการ (ภาษาอังกฤษ)'),
                        _formField(_taxId, 'เลขประจำตัวผู้เสียภาษี'),
                        _formField(_email, 'อีเมล', keyboardType: TextInputType.emailAddress),
                        _formField(_telephone, 'โทรศัพท์', keyboardType: TextInputType.phone),
                        _formField(_address, 'ที่อยู่', maxLines: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController controller, String label, {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required ? (value) => value == null || value.trim().isEmpty ? 'กรุณาระบุชื่อผู้ใช้บริการ' : null : null,
      ),
    );
  }
}

class _PartnerCompanyPageState extends State<PartnerCompanyPage> {
  final _repository = PartnerCompanyRepository();
  final _search = TextEditingController();
  List<PartnerCompany> _items = const [];
  bool _loading = true;
  String? _error;
  String? _message;
  int _currentPage = 0;

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 30;
  int get _pageCount => _items.isEmpty ? 1 : (_items.length / _pageSize).ceil();
  List<PartnerCompany> get _visibleItems {
    final page = _currentPage.clamp(0, _pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, _items.length);
    return _items.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.getCompanies(
        search: _search.text,
        support: widget.menuScope == WorkspaceMenuScope.support,
      );
      if (mounted) setState(() { _items = result; _currentPage = 0; });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearFilters() {
    _search.clear();
    _load();
  }

  Future<void> _openForm({PartnerCompany? existing}) async {
    final formKey = GlobalKey<FormState>();
    final nameTh = TextEditingController(text: existing?.companyNameTh ?? '');
    final nameEn = TextEditingController(text: existing?.companyNameEn ?? '');
    final taxId = TextEditingController(text: existing?.taxId ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final telephone = TextEditingController(text: existing?.telephone ?? '');
    final address = TextEditingController(text: existing?.addressText ?? '');
    try {
      final input = await showDialog<PartnerCompanyInput>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มข้อมูลผู้ใช้บริการ' : 'แก้ไขข้อมูลผู้ใช้บริการ'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(nameTh, 'ชื่อผู้ใช้บริการ (ภาษาไทย) *', required: true),
                    _field(nameEn, 'ชื่อผู้ใช้บริการ (ภาษาอังกฤษ)'),
                    _field(taxId, 'เลขประจำตัวผู้เสียภาษี'),
                    _field(email, 'อีเมล', keyboardType: TextInputType.emailAddress),
                    _field(telephone, 'โทรศัพท์', keyboardType: TextInputType.phone),
                    _field(address, 'ที่อยู่', maxLines: 3),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  PartnerCompanyInput(
                    companyNameTh: nameTh.text.trim(),
                    companyNameEn: _optional(nameEn),
                    taxId: _optional(taxId),
                    email: _optional(email),
                    telephone: _optional(telephone),
                    addressText: _optional(address),
                  ),
                );
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      );
      if (input == null) return;
      if (existing == null) {
        await _repository.createCompany(input);
      } else {
        await _repository.updateCompany(existing.companyId, input);
      }
      await _load();
      if (mounted) {
        setState(() => _message = existing == null
            ? 'เพิ่มข้อมูลผู้ใช้บริการสำเร็จ'
            : 'แก้ไขข้อมูลผู้ใช้บริการสำเร็จ');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
        );
      }
    } finally {
      for (final controller in [nameTh, nameEn, taxId, email, telephone, address]) {
        controller.dispose();
      }
    }
  }

  Future<void> _openFullForm({PartnerCompany? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PartnerCompanyFormPage(existing: existing),
      ),
    );
    if (saved == true && mounted) {
      await _load();
      setState(() => _message = existing == null
          ? 'เพิ่มข้อมูลผู้ใช้บริการสำเร็จ'
          : 'แก้ไขข้อมูลผู้ใช้บริการสำเร็จ');
    }
  }

  Future<void> _confirmDelete(PartnerCompany item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบผู้ใช้บริการ'),
        content: Text('ต้องการลบ ${item.companyNameTh} หรือไม่?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteCompany(item.companyId);
      await _load();
      if (mounted) setState(() => _message = 'ลบข้อมูลผู้ใช้บริการสำเร็จ');
    } catch (error) {
      if (mounted) setState(() => _error = 'ลบข้อมูลไม่สำเร็จ: $error');
    }
  }

  static Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty ? 'กรุณาระบุชื่อผู้ใช้บริการ' : null
            : null,
      ),
    );
  }

  static String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: 'ข้อมูลผู้ใช้บริการ',
      activeMenu: widget.menuScope == WorkspaceMenuScope.support
          ? 'company'
          : 'partnerCompanies',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: WorkspacePageTitle(
                    title: 'ข้อมูลผู้ใช้บริการ',
                    favoriteKey: widget.menuScope == WorkspaceMenuScope.support
                        ? 'company'
                        : 'partnerCompanies',
                  ),
                ),
                if (widget.menuScope != WorkspaceMenuScope.support)
                  FilledButton.icon(
                    onPressed: () => _openFullForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มผู้ใช้บริการ'),
                  ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              MaterialBanner(
                content: Text(_message!),
                leading: const Icon(Icons.check_circle_outline),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _message = null),
                    child: const Text('ปิด'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'ค้นหาชื่อ รหัส หรือเลขผู้เสียภาษี',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(tooltip: 'รีเฟรช', onPressed: _load, icon: const Icon(Icons.refresh)),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('ล้าง Filter'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) return const Center(child: Text('ยังไม่มีข้อมูลผู้ใช้บริการ'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 18,
                  dividerThickness: 1,
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  columns: const [
                    DataColumn(label: SizedBox(width: 82, child: Center(child: Text('Action')))),
                    DataColumn(label: Text('รหัสผู้ใช้บริการ')),
                    DataColumn(label: Text('ชื่อผู้ใช้บริการ')),
                    DataColumn(label: Text('ชื่อภาษาอังกฤษ')),
                    DataColumn(label: Text('เลขผู้เสียภาษี')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('โทรศัพท์')),
                    DataColumn(label: Text('สถานะ')),
                  ],
                  rows: _visibleItems.map((item) => DataRow(cells: [
                    DataCell(SizedBox(width: 82, child: Center(child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'แก้ไข', visualDensity: VisualDensity.compact, onPressed: () => _openFullForm(existing: item), icon: const Icon(Icons.edit_outlined, size: 18)),
                        IconButton(tooltip: 'ลบ', visualDensity: VisualDensity.compact, onPressed: () => _confirmDelete(item), icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red)),
                      ],
                    )))),
                    DataCell(Text(item.companyCode)),
                    DataCell(Text(item.companyNameTh)),
                    DataCell(Text(item.companyNameEn ?? '-')),
                    DataCell(Text(item.taxId ?? '-')),
                    DataCell(Text(item.email ?? '-')),
                    DataCell(Text(item.telephone ?? '-')),
                    DataCell(Text(item.isActive ? 'ใช้งาน' : 'ปิดใช้งาน')),
                  ])).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: _paginationBar()),
      ],
    );
  }

  Widget _paginationBar() {
    final page = _currentPage.clamp(0, _pageCount - 1);
    final first = _items.isEmpty ? 0 : page * _pageSize + 1;
    final last = _items.isEmpty ? 0 : ((page + 1) * _pageSize).clamp(0, _items.length);
    return Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      OutlinedButton(onPressed: page == 0 ? null : () => setState(() => _currentPage--), child: const Text('ก่อนหน้า')),
      for (var i = 0; i < _pageCount; i++)
        i == page
            ? FilledButton(onPressed: null, child: Text('${i + 1}'))
            : OutlinedButton(onPressed: () => setState(() => _currentPage = i), child: Text('${i + 1}')),
      OutlinedButton(onPressed: page >= _pageCount - 1 ? null : () => setState(() => _currentPage++), child: const Text('ถัดไป')),
      Text('แสดง $first-$last จาก ${_items.length} รายการ (หน้าละ $_pageSize)'),
    ]);
  }
}
