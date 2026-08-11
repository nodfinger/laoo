import 'package:flutter/material.dart';

import '../../../app/theme/laoo_typography.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../../support/partner/data/api_partner_repository.dart';
import '../../support/partner/data/core_partner_api_client.dart';
import '../../support/partner/models/partner.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../data/partner_company_repository.dart';
import '../models/partner_company.dart';

/// Shared user-service company screen. The API applies the caller's data scope:
/// Support sees all records, Partner sees records belonging to that partner.
class PartnerCompanyPage extends StatefulWidget {
  const PartnerCompanyPage({
    super.key,
    this.menuScope = WorkspaceMenuScope.partner,
  });

  final WorkspaceMenuScope menuScope;

  @override
  State<PartnerCompanyPage> createState() => _PartnerCompanyPageState();
}

class _PartnerCompanyFormPage extends StatefulWidget {
  const _PartnerCompanyFormPage({
    required this.menuName,
    this.existing,
    this.support = false,
  });

  final String menuName;
  final PartnerCompany? existing;
  final bool support;

  @override
  State<_PartnerCompanyFormPage> createState() =>
      _PartnerCompanyFormPageState();
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
  bool _isActive = true;
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
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameTh,
      _nameEn,
      _taxId,
      _email,
      _telephone,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final input = PartnerCompanyInput(
        companyNameTh: _nameTh.text.trim(),
        isActive: _isActive,
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
        await repository.updateCompany(
          widget.existing!.companyId,
          input,
          support: widget.support,
        );
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
      menuScope: widget.support
          ? WorkspaceMenuScope.support
          : WorkspaceMenuScope.partner,
      pageTitle: '${widget.menuName} > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
      activeMenu: widget.support ? 'company' : 'partnerCompanies',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WorkspacePageTitle(
                        title:
                            '${widget.menuName} > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
                        favoriteKey: 'company',
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ],
                ),
                if (editing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Partner: ${widget.existing?.partnerNameTh ?? '-'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  MaterialBanner(
                    content: Text(_error!),
                    leading: const Icon(Icons.error_outline),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('ปิด'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('สถานะใช้งาน'),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _isActive,
                              onChanged: (value) =>
                                  setState(() => _isActive = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          _nameTh,
                          'ชื่อลูกค้า (ภาษาไทย) *',
                          required: true,
                        ),
                        _formField(_nameEn, 'ชื่อลูกค้า (ภาษาอังกฤษ)'),
                        _formField(_taxId, 'เลขประจำตัวผู้เสียภาษี'),
                        _formField(
                          _email,
                          'อีเมล',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _formField(
                          _telephone,
                          'โทรศัพท์',
                          keyboardType: TextInputType.phone,
                        ),
                        _formField(_address, 'ที่อยู่', maxLines: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: LaooTypography.fontFamily,
          fontSize: LaooTypography.inputText,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontSize: LaooTypography.inputHint,
          ),
          floatingLabelStyle: const TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontSize: LaooTypography.inputLabel,
          ),
          hintStyle: const TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontSize: LaooTypography.inputHint,
          ),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'กรุณาระบุชื่อลูกค้า'
                  : null
            : null,
      ),
    );
  }
}

class _PartnerCompanyPageState extends State<PartnerCompanyPage> {
  final _repository = PartnerCompanyRepository();
  final _partnerRepository = ApiPartnerRepository(CorePartnerApiClient());
  final _search = TextEditingController();
  List<PartnerCompany> _items = const [];
  List<Partner> _partners = const [];
  int? _partnerFilterId;
  String _statusFilter = 'ทั้งหมด';
  bool _loading = true;
  String? _error;
  String? _message;
  String _menuName = '';
  int _currentPage = 0;
  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  String get _menuCode => widget.menuScope == WorkspaceMenuScope.support
      ? 'company'
      : 'partnerCompanies';

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 30;
  List<PartnerCompany> get _filteredItems => _items.where((item) {
    return _statusFilter == 'ทั้งหมด' ||
        (_statusFilter == 'เปิดใช้งาน' ? item.isActive : !item.isActive);
  }).toList();

  int get _pageCount =>
      _filteredItems.isEmpty ? 1 : (_filteredItems.length / _pageSize).ceil();
  List<PartnerCompany> get _visibleItems {
    final page = _currentPage.clamp(0, _pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredItems.length);
    return _filteredItems.sublist(start, end);
  }

  void _sortBy(
    int index,
    Comparable Function(PartnerCompany) selector,
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

  @override
  void initState() {
    super.initState();
    _menuName = NavigationMenuRepository.fallbackMenuName(routeName: _menuCode);
    _loadMenuName();
    if (widget.menuScope == WorkspaceMenuScope.support) _loadPartners();
    _load();
  }

  Future<void> _loadMenuName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        routeName: _menuCode,
        fallback: _menuName,
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {
      // Keep the local fallback when the menu API is unavailable.
    }
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
        partnerId: _partnerFilterId,
        support: widget.menuScope == WorkspaceMenuScope.support,
      );
      if (mounted)
        setState(() {
          _items = result;
          _currentPage = 0;
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearFilters() {
    _search.clear();
    _partnerFilterId = null;
    _statusFilter = 'ทั้งหมด';
    _load();
  }

  Future<void> _loadPartners() async {
    try {
      final result = await _partnerRepository.getPartners(isActive: true);
      if (mounted) setState(() => _partners = result);
    } catch (_) {
      // Keep the company list usable if the partner filter cannot load.
    }
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
          title: Text(
            existing == null ? 'เพิ่มข้อมูลลูกค้า' : 'แก้ไขข้อมูลลูกค้า',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(nameTh, 'ชื่อลูกค้า (ภาษาไทย) *', required: true),
                    _field(nameEn, 'ชื่อลูกค้า (ภาษาอังกฤษ)'),
                    _field(taxId, 'เลขประจำตัวผู้เสียภาษี'),
                    _field(
                      email,
                      'อีเมล',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _field(
                      telephone,
                      'โทรศัพท์',
                      keyboardType: TextInputType.phone,
                    ),
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
        await _repository.updateCompany(
          existing.companyId,
          input,
          support: widget.menuScope == WorkspaceMenuScope.support,
        );
      }
      await _load();
      if (mounted) {
        setState(
          () => _message = existing == null
              ? 'เพิ่มข้อมูลลูกค้าสำเร็จ'
              : 'แก้ไขข้อมูลลูกค้าสำเร็จ',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message!)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')));
      }
    } finally {
      for (final controller in [
        nameTh,
        nameEn,
        taxId,
        email,
        telephone,
        address,
      ]) {
        controller.dispose();
      }
    }
  }

  Future<void> _openFullForm({PartnerCompany? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PartnerCompanyFormPage(
          menuName: _menuName,
          existing: existing,
          support: widget.menuScope == WorkspaceMenuScope.support,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _load();
      setState(
        () => _message = existing == null
            ? 'เพิ่มข้อมูลลูกค้าสำเร็จ'
            : 'แก้ไขข้อมูลลูกค้าสำเร็จ',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message!)));
    }
  }

  Future<void> _confirmDelete(PartnerCompany item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade200),
        ),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: LaooTypography.fontFamily,
                    fontSize: LaooTypography.sectionTitle,
                    color: Colors.red,
                  ),
                  children: [
                    TextSpan(text: 'ยืนยันการลบ '),
                    TextSpan(
                      text: 'Partner',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: LaooTypography.fontFamily,
                    fontSize: LaooTypography.inputText,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(text: 'ต้องการลบ '),
                    TextSpan(
                      text: '${item.companyCode} - ${item.companyNameTh}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF146B3A),
                      ),
                    ),
                    const TextSpan(text: ' หรือไม่?'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
              style: TextStyle(
                fontFamily: LaooTypography.fontFamily,
                fontSize: LaooTypography.validation,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(
                fontFamily: LaooTypography.fontFamily,
                fontSize: LaooTypography.button,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text(
              'ลบ',
              style: TextStyle(
                fontFamily: LaooTypography.fontFamily,
                fontSize: LaooTypography.button,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteCompany(
        item.companyId,
        support: widget.menuScope == WorkspaceMenuScope.support,
      );
      await _load();
      if (mounted) {
        setState(() => _message = 'ลบข้อมูลลูกค้าสำเร็จ');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message!)));
      }
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
        style: const TextStyle(
          fontFamily: LaooTypography.fontFamily,
          fontSize: LaooTypography.inputText,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontSize: LaooTypography.inputHint,
          ),
          floatingLabelStyle: const TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontSize: LaooTypography.inputLabel,
          ),
          hintStyle: const TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontSize: LaooTypography.inputHint,
          ),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'กรุณาระบุชื่อลูกค้า'
                  : null
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
      pageTitle: _menuName,
      activeMenu: _menuCode,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: WorkspacePageTitle(
                    title: _menuName,
                    favoriteKey: widget.menuScope == WorkspaceMenuScope.support
                        ? 'company'
                        : 'partnerCompanies',
                  ),
                ),
                if (widget.menuScope != WorkspaceMenuScope.support)
                  FilledButton.icon(
                    onPressed: () => _openFullForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มลูกค้า'),
                  ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          fontFamily: LaooTypography.fontFamily,
                          fontSize: LaooTypography.inputText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: () => setState(() => _message = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
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
                if (widget.menuScope == WorkspaceMenuScope.support) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int?>(
                      value: _partnerFilterId,
                      decoration: const InputDecoration(
                        labelText: 'Partner',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('ทุก Partner'),
                        ),
                        ..._partners.map(
                          (partner) => DropdownMenuItem<int?>(
                            value: partner.partnerId,
                            child: Text(partner.partnerNameTh),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _partnerFilterId = value);
                        _load();
                      },
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(labelText: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(
                        value: 'ทั้งหมด',
                        child: Text('ทั้งหมด'),
                      ),
                      DropdownMenuItem(
                        value: 'เปิดใช้งาน',
                        child: Text('เปิดใช้งาน'),
                      ),
                      DropdownMenuItem(
                        value: 'ปิดใช้งาน',
                        child: Text('ปิดใช้งาน'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value ?? 'ทั้งหมด';
                        _currentPage = 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'รีเฟรช',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
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
    if (_items.isEmpty)
      return const Center(child: Text('ยังไม่มีข้อมูลลูกค้า'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SingleChildScrollView(
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      horizontalMargin: 12,
                      columnSpacing: 18,
                      dividerThickness: 1,
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      headingTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      columns: [
                        DataColumn(
                          label: SizedBox(
                            width: 82,
                            child: Center(child: Text('Action')),
                          ),
                        ),
                        if (widget.menuScope == WorkspaceMenuScope.support)
                          const DataColumn(label: Text('Partner')),
                        DataColumn(
                          label: Text('รหัสลูกค้า'),
                          onSort: (i, a) => _sortBy(i, (x) => x.companyCode, a),
                        ),
                        DataColumn(
                          label: Text('ชื่อลูกค้า'),
                          onSort: (i, a) =>
                              _sortBy(i, (x) => x.companyNameTh, a),
                        ),
                        DataColumn(
                          label: Text('ชื่อภาษาอังกฤษ'),
                          onSort: (i, a) =>
                              _sortBy(i, (x) => x.companyNameEn ?? "", a),
                        ),
                        DataColumn(
                          label: Text('เลขผู้เสียภาษี'),
                          onSort: (i, a) => _sortBy(i, (x) => x.taxId ?? "", a),
                        ),
                        DataColumn(
                          label: Text('Email'),
                          onSort: (i, a) => _sortBy(i, (x) => x.email ?? "", a),
                        ),
                        DataColumn(
                          label: Text('โทรศัพท์'),
                          onSort: (i, a) =>
                              _sortBy(i, (x) => x.telephone ?? "", a),
                        ),
                        DataColumn(
                          label: Text('สถานะ'),
                          onSort: (i, a) =>
                              _sortBy(i, (x) => x.isActive ? 1 : 0, a),
                        ),
                      ],
                      rows: _visibleItems
                          .map(
                            (item) => DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 82,
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'แก้ไข',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () =>
                                                _openFullForm(existing: item),
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'ลบ',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () =>
                                                _confirmDelete(item),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.menuScope ==
                                    WorkspaceMenuScope.support)
                                  DataCell(Text(item.partnerNameTh ?? '-')),
                                DataCell(Text(item.companyCode)),
                                DataCell(Text(item.companyNameTh)),
                                DataCell(Text(item.companyNameEn ?? '-')),
                                DataCell(Text(item.taxId ?? '-')),
                                DataCell(Text(item.email ?? '-')),
                                DataCell(Text(item.telephone ?? '-')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.isActive
                                          ? Colors.green.shade50
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      item.isActive
                                          ? 'เปิดใช้งาน'
                                          : 'ปิดใช้งาน',
                                      style: TextStyle(
                                        color: item.isActive
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
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
    final last = _items.isEmpty
        ? 0
        : ((page + 1) * _pageSize).clamp(0, _items.length);
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: page == 0 ? null : () => setState(() => _currentPage--),
          child: const Text('ก่อนหน้า'),
        ),
        for (var i = 0; i < _pageCount; i++)
          i == page
              ? FilledButton(onPressed: null, child: Text('${i + 1}'))
              : OutlinedButton(
                  onPressed: () => setState(() => _currentPage = i),
                  child: Text('${i + 1}'),
                ),
        OutlinedButton(
          onPressed: page >= _pageCount - 1
              ? null
              : () => setState(() => _currentPage++),
          child: const Text('ถัดไป'),
        ),
        Text('แสดง $first-$last จาก ${_items.length} รายการ'),
      ],
    );
  }
}
