import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/combo_box_text.dart';
import '../../../core/widgets/auto_dismiss_message.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../../support/partner/data/api_partner_repository.dart';
import '../../support/partner/data/core_partner_api_client.dart';
import '../../support/partner/models/partner.dart';
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
  late final TextEditingController _adminUsername;
  late final TextEditingController _adminPassword;
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
    _adminUsername = TextEditingController();
    _adminPassword = TextEditingController();
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
      _adminUsername,
      _adminPassword,
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
        adminUsername: _optional(_adminUsername),
        adminPassword: _optional(_adminPassword),
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
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (_, _, _) => SupportWorkspaceShell(
        menuScope: widget.support
            ? WorkspaceMenuScope.support
            : WorkspaceMenuScope.partner,
        pageTitle: '${widget.menuName} > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
        activeMenu: widget.support ? 'company' : 'partnerCompanies',
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceActionHeader(
                    title:
                        '${widget.menuName} > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
                    favoriteKey: 'company',
                    actions: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('ยกเลิก'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
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
                          if (!editing)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _formField(
                                    _nameEn,
                                    'ชื่อลูกค้า (ภาษาอังกฤษ)',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _formField(
                                    _adminUsername,
                                    'Username ผู้ดูแลระบบ *',
                                    required: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _formField(
                                    _adminPassword,
                                    'Password ผู้ดูแลระบบ *',
                                    required: true,
                                    obscureText: true,
                                  ),
                                ),
                              ],
                            )
                          else
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
                ],
              ),
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
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
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
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String? _error;
  String? _message;
  String _menuName = '';
  int _currentPage = 0;
  int _sortColumnIndex = 3;
  bool _sortAscending = true;
  Timer? _messageTimer;

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
    _loadActions();
    _load();
  }

  Future<void> _loadActions() async {
    try {
      final permissions = await _repository.actions(
        support: widget.menuScope == WorkspaceMenuScope.support,
      );
      if (!mounted) return;
      setState(() {
        _canCreate = permissions['create'] == true;
        _canEdit = permissions['edit'] == true;
        _canDelete = permissions['delete'] == true;
      });
    } catch (_) {}
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
    _messageTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleMessageDismiss() {
    if (_message == null || _messageTimer != null) return;
    _messageTimer = Timer(
      Duration(seconds: companySetupController.current?.timeAlert ?? 30),
      () {
        if (mounted) setState(() => _message = null);
        _messageTimer = null;
      },
    );
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
      if (mounted) {
        setState(() {
          _items = result;
          _currentPage = 0;
        });
      }
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
    }
  }

  Future<void> _confirmDelete(PartnerCompany item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                  style: LaooTypography.popupTitleStyle,
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
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'ลบข้อมูลไม่สำเร็จ: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: _menuName,
      activeMenu: _menuCode,
      child: ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (_, _, child) => Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceSectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: WorkspacePageTitle(
                            title: _menuName,
                            favoriteKey:
                                widget.menuScope == WorkspaceMenuScope.support
                                ? 'company'
                                : 'partnerCompanies',
                          ),
                        ),
                        if (widget.menuScope != WorkspaceMenuScope.support &&
                            _canCreate)
                          FilledButton.icon(
                            onPressed: () => _openFullForm(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มลูกค้า'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: LaooColors.border),
                  WorkspaceSectionCard(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 0,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 600
                                ? constraints.maxWidth
                                : 260,
                            child: TextField(
                              controller: _search,
                              onSubmitted: (_) => _load(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  tooltip: 'ค้นหา',
                                  onPressed: _load,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                ),
                                isDense: true,
                                labelText: 'ค้นหาชื่อ และเบอร์โทรศัพท์',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _statusFilter = 'ทั้งหมด';
                                _partnerFilterId = null;
                                _currentPage = 0;
                              });
                              _load();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้าง Filter'),
                          ),
                          if (widget.menuScope ==
                              WorkspaceMenuScope.support) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: constraints.maxWidth < 600
                                  ? constraints.maxWidth
                                  : 240,
                              child: DropdownButtonFormField<int?>(
                                isExpanded: true,
                                initialValue: _partnerFilterId,
                                decoration: const InputDecoration(
                                  labelText: 'Partner',
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: LaooComboBoxText('ทุก Partner'),
                                  ),
                                  ..._partners.map(
                                    (partner) => DropdownMenuItem<int?>(
                                      value: partner.partnerId,
                                      child: LaooComboBoxText(
                                        partner.partnerNameTh,
                                      ),
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
                          const SizedBox(width: 4),
                          SizedBox(
                            width: constraints.maxWidth < 600
                                ? constraints.maxWidth
                                : 150,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _statusFilter,
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
                              onChanged: (value) {
                                setState(() {
                                  _statusFilter = value ?? 'ทั้งหมด';
                                  _currentPage = 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: LaooColors.border),
                  Expanded(child: _buildBody()),
                ],
              ),
              if (_message != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AutoDismissMessage(
                    key: ValueKey(_message),
                    message: _message!,
                    error: false,
                    onClose: () => setState(() => _message = null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    _scheduleMessageDismiss();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) {
      return const Center(child: Text('ยังไม่มีข้อมูลลูกค้า'));
    }

    if (MediaQuery.sizeOf(context).width < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMobileCards(context)),
          const Divider(height: 1, color: LaooColors.border),
          WorkspaceSectionCard(child: _paginationBar()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SingleChildScrollView(
                    child: DataTable(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: LaooColors.border.withValues(alpha: .45),
                          width: .25,
                        ),
                      ),
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      horizontalMargin: 12,
                      columnSpacing: 18,
                      dividerThickness: .25,
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
                        const DataColumn(
                          columnWidth: LaooDataTable.idColumnWidth,
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('ID'),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 82,
                            child: Center(child: Text('Action')),
                          ),
                        ),
                        if (widget.menuScope == WorkspaceMenuScope.support)
                          const DataColumn(
                            label: Center(child: Text('Partner')),
                          ),
                        DataColumn(
                          label: const Center(child: Text('ชื่อลูกค้า')),
                          onSort: (i, a) =>
                              _sortBy(i, (x) => x.companyNameTh, a),
                        ),
                        DataColumn(
                          label: const Center(child: Text('เลขผู้เสียภาษี')),
                          onSort: (i, a) => _sortBy(i, (x) => x.taxId ?? "", a),
                        ),
                        DataColumn(
                          label: const SizedBox(
                            width: 110,
                            child: Center(child: Text('Email')),
                          ),
                          onSort: (i, a) => _sortBy(i, (x) => x.email ?? "", a),
                        ),
                        DataColumn(
                          label: const SizedBox(
                            width: 110,
                            child: Center(child: Text('โทรศัพท์')),
                          ),
                          onSort: (i, a) =>
                              _sortBy(i, (x) => x.telephone ?? "", a),
                        ),
                        DataColumn(
                          label: const SizedBox(
                            width: 110,
                            child: Center(child: Text('สถานะ')),
                          ),
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
                                    width: 28,
                                    child: Center(
                                      child: Text(
                                        '${_visibleItems.indexOf(item) + 1 + (_currentPage * _pageSize)}',
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.menuScope !=
                                                  WorkspaceMenuScope.support &&
                                              _canEdit)
                                            IconButton(
                                              tooltip: 'กำหนดผู้ดูแลระบบ',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  _openAdminCredentials(item),
                                              icon: Icon(
                                                Icons
                                                    .admin_panel_settings_outlined,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          if (_canEdit)
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
                                          if (_canDelete)
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
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item.adminUsername != null &&
                                          item.adminUsername!.trim().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person_outline,
                                                size: 14,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.adminUsername!,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: LaooTypography.body,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (item.adminUsername != null &&
                                          item.adminUsername!.trim().isNotEmpty)
                                        const SizedBox(width: 8),
                                      Text(item.companyNameTh),
                                    ],
                                  ),
                                ),
                                DataCell(Text(item.taxId ?? '-')),
                                DataCell(Text(item.email ?? '-')),
                                DataCell(Text(item.telephone ?? '-')),
                                DataCell(
                                  SizedBox(
                                    width: 110,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.isActive
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.12)
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          item.isActive
                                              ? 'เปิดใช้งาน'
                                              : 'ปิดใช้งาน',
                                          style: TextStyle(
                                            color: item.isActive
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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
        const Divider(height: 1, color: LaooColors.border),
        WorkspaceSectionCard(child: _paginationBar()),
      ],
    );
  }

  Widget _buildMobileCards(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemCount: _visibleItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = _visibleItems[index];
        final primary = Theme.of(context).colorScheme.primary;
        final statusColor = item.isActive
            ? primary
            : Theme.of(context).colorScheme.error;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (widget.menuScope != WorkspaceMenuScope.support &&
                        _canEdit)
                      IconButton(
                        tooltip: 'กำหนดผู้ดูแลระบบ',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openAdminCredentials(item),
                        icon: Icon(
                          Icons.admin_panel_settings_outlined,
                          color: primary,
                        ),
                      ),
                    if (_canEdit)
                      IconButton(
                        tooltip: 'แก้ไข',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openFullForm(existing: item),
                        icon: Icon(Icons.edit_outlined, color: primary),
                      ),
                    if (_canDelete)
                      IconButton(
                        tooltip: 'ลบ',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDelete(item),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    const Spacer(),
                    Text('ID ${item.companyId}  รหัส ${item.companyCode}'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.companyNameTh,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text('โทรศัพท์ ${item.telephone ?? '-'}')),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        item.isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _paginationBar() {
    final page = _currentPage.clamp(0, _pageCount - 1);
    final first = _items.isEmpty ? 0 : page * _pageSize + 1;
    final last = _items.isEmpty
        ? 0
        : ((page + 1) * _pageSize).clamp(0, _items.length);
    final pageIndexes = <int>[];
    if (_pageCount <= 7) {
      pageIndexes.addAll(List<int>.generate(_pageCount, (index) => index));
    } else {
      final start = (page - 2).clamp(0, _pageCount - 5);
      pageIndexes.addAll(List<int>.generate(5, (index) => start + index));
    }
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _pagerArrow(
          icon: Icons.chevron_left_rounded,
          tooltip: 'หน้าก่อนหน้า',
          enabled: page > 0,
          onPressed: () => setState(() => _currentPage--),
        ),
        if (_pageCount > 7 && pageIndexes.first > 0) ...[
          _pageNumberButton(0, page),
          if (pageIndexes.first > 1) const Text('...'),
        ],
        for (final i in pageIndexes) _pageNumberButton(i, page),
        if (_pageCount > 7 && pageIndexes.last < _pageCount - 1) ...[
          if (pageIndexes.last < _pageCount - 2) const Text('...'),
          _pageNumberButton(_pageCount - 1, page),
        ],
        _pagerArrow(
          icon: Icons.chevron_right_rounded,
          tooltip: 'หน้าถัดไป',
          enabled: page < _pageCount - 1,
          onPressed: () => setState(() => _currentPage++),
        ),
        Text('$first-$last จาก ${_items.length}'),
      ],
    );
  }

  Future<void> _openAdminCredentials(PartnerCompany item) async {
    final formKey = GlobalKey<FormState>();
    final username = TextEditingController();
    final password = TextEditingController();
    username.text = item.adminUsername ?? '';
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final primary = workspaceThemeController.value.primary;
          String? dialogError;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
              title: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Text(
                  'กำหนดผู้ดูแลระบบ - ${item.companyNameTh}',
                  style: LaooTypography.popupTitleStyle,
                ),
              ),
              content: Stack(
                clipBehavior: Clip.none,
                children: [
                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                          color: primary.withValues(alpha: 0.25),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: username,
                          decoration: const InputDecoration(
                            labelText: 'Username *',
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'กรุณาระบุ Username' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password *',
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณาระบุ Password' : null,
                        ),
                      ],
                    ),
                  ),
                  if (dialogError != null)
                    Positioned(
                      top: -10,
                      right: -8,
                      child: AutoDismissMessage(
                        key: ValueKey(dialogError),
                        message: dialogError!,
                        error: true,
                        onClose: () => setDialogState(() => dialogError = null),
                      ),
                    ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text('ยกเลิก', style: TextStyle(color: primary)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        try {
                          await _repository.updateAdmin(
                            item.companyId,
                            username.text.trim(),
                            password.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(
                              () =>
                                  dialogError = error.toString().contains('ซ้ำ')
                                  ? 'Username นี้มีในระบบแล้ว กรุณาใช้ Username อื่น'
                                  : 'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลอีกครั้ง',
                            );
                          }
                        }
                      },
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
      if (saved == true && mounted) {
        await _load();
        if (mounted) setState(() => _message = 'กำหนดผู้ดูแลระบบสำเร็จ');
      }
    } finally {
      username.dispose();
      password.dispose();
    }
  }

  Widget _pagerArrow({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.grey.shade700,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade500,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(34),
          maximumSize: const Size.square(34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Tooltip(message: tooltip, child: Icon(icon)),
      ),
    );
  }

  Widget _pageNumberButton(int index, int currentPage) {
    return SizedBox(
      width: 34,
      height: 34,
      child: index == currentPage
          ? FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              child: Text('${index + 1}'),
            )
          : OutlinedButton(
              onPressed: () => setState(() => _currentPage = index),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: Colors.grey.shade600,
                side: BorderSide(color: LaooColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              child: Text('${index + 1}'),
            ),
    );
  }
}
