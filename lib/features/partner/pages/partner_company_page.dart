import 'dart:async';
import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/combo_box_text.dart';
import '../../../core/widgets/auto_dismiss_message.dart';

import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/pinned_data_table.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../../support/partner/data/api_partner_repository.dart';
import '../../support/partner/data/core_partner_api_client.dart';
import '../../support/partner/models/partner.dart';
import '../../support/project_package/pages/project_package_page.dart';
import '../data/partner_company_repository.dart';
import '../models/partner_company.dart';
import 'partner_company_modules_page.dart';

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
            padding: EdgeInsets.all(
              widget.support ? 24 : LaooLayout.cardMargin,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) {
                      final header = WorkspaceActionHeader(
                        title:
                            '${widget.menuName} > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
                        favoriteKey: widget.support
                            ? 'company'
                            : 'partnerCompanies',
                        actions: [
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('ยกเลิก'),
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
                      );
                      return widget.support
                          ? header
                          : WorkspaceSectionCard(child: header);
                    },
                  ),
                  if (editing) ...[
                    const SizedBox(height: LaooLayout.cardSpacing),
                    WorkspaceSectionCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            color: workspaceThemeController.value.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Partner: ',
                                    style: TextStyle(
                                      color: workspaceThemeController.value.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: widget.existing?.partnerNameTh ?? '-'),
                                ],
                              ),
                              style: TextStyle(
                                color: workspaceThemeController.value.textPrimary,
                                fontSize: LaooTypography.sectionTitle,
                                height: LaooTypography.bodyLineHeight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: widget.support ? 8 : LaooLayout.cardSpacing),
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
                  if (widget.support) const SizedBox(height: 8),
                  Card(
                    margin: widget.support ? null : EdgeInsets.zero,
                    color: widget.support ? null : LaooColors.white,
                    surfaceTintColor: widget.support
                        ? null
                        : Colors.transparent,
                    elevation: widget.support ? null : 0,
                    shape: widget.support
                        ? null
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                            side: BorderSide.none,
                          ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        widget.support ? 20 : LaooLayout.cardPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'สถานะใช้งาน',
                                style: TextStyle(
                                  fontSize: LaooTypography.inputLabel,
                                  color: workspaceThemeController.value.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch.adaptive(
                                value: _isActive,
                                activeTrackColor: workspaceThemeController.value.primary,
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth < 700
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 24) / 3;
                                return Wrap(
                                  spacing: 12,
                                  children: [
                                    SizedBox(
                                      width: width,
                                      child: _formField(
                                        _nameEn,
                                        'ชื่อลูกค้า (ภาษาอังกฤษ)',
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: _formField(
                                        _adminUsername,
                                        'Username ผู้ดูแลระบบ *',
                                        required: true,
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: _formField(
                                        _adminPassword,
                                        'Password ผู้ดูแลระบบ *',
                                        required: true,
                                        obscureText: true,
                                      ),
                                    ),
                                  ],
                                );
                              },
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
    final preset = workspaceThemeController.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: LaooLayout.popupFieldSpacing),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
        cursorColor: preset.primary,
        style: TextStyle(
          fontFamily: LaooTypography.fontFamily,
          fontFamilyFallback: LaooTypography.fontFallback,
          fontSize: LaooTypography.inputText,
          height: LaooTypography.bodyLineHeight,
          color: preset.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontFamilyFallback: LaooTypography.fontFallback,
            fontSize: LaooTypography.inputLabel,
            color: preset.textSecondary,
          ),
          floatingLabelStyle: TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontFamilyFallback: LaooTypography.fontFallback,
            fontSize: LaooTypography.materialFloatingLabelSource,
            color: preset.primary,
          ),
          hintStyle: TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontFamilyFallback: LaooTypography.fontFallback,
            fontSize: LaooTypography.inputHint,
            color: preset.textSecondary,
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
  String _partnerStatusDraft = 'ทั้งหมด';
  bool _partnerCardMode = false;
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
    _messageTimer = Timer(companySetupController.alertDuration, () {
      if (mounted) setState(() => _message = null);
      _messageTimer = null;
    });
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

  Future<void> _openModules(PartnerCompany company) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PartnerCompanyModulesPage(company: company, menuName: _menuName),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _message = 'บันทึกระบบที่เปิดใช้สำเร็จ');
    }
  }

  Future<void> _openPackageMaster() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ProjectPackagePage()));
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
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'ลบข้อมูลไม่สำเร็จ: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.menuScope == WorkspaceMenuScope.partner) return _partnerPage();
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: _menuName,
      activeMenu: _menuCode,
      child: ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (_, _, child) => Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                      if (widget.menuScope == WorkspaceMenuScope.support &&
                          _canEdit)
                        OutlinedButton.icon(
                          onPressed: _openPackageMaster,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Package Master'),
                        ),
                      if (widget.menuScope == WorkspaceMenuScope.support &&
                          _canEdit)
                        const SizedBox(width: 8),
                      if (widget.menuScope != WorkspaceMenuScope.support &&
                          _canCreate)
                        FilledButton.icon(
                          onPressed: () => _openFullForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มลูกค้า'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 0,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : 420,
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
                            ),
                          ),
                        ),
                        if (widget.menuScope == WorkspaceMenuScope.support) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<int?>(
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
                          width: 150,
                          child: DropdownButtonFormField<String>(
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
                  const SizedBox(height: 16),
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

  Widget _partnerSurface(Widget child) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  void _partnerSearch() {
    setState(() => _statusFilter = _partnerStatusDraft);
    _load();
  }

  void _partnerClear() {
    _search.clear();
    setState(() {
      _partnerStatusDraft = 'ทั้งหมด';
      _statusFilter = 'ทั้งหมด';
    });
    _load();
  }

  Widget _partnerPage() {
    _scheduleMessageDismiss();
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: _menuName,
      activeMenu: _menuCode,
      child: ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (context, preset, _) => LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1050;
            final showCards = compact || _partnerCardMode;
            final color = preset.primary;
            final shape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            );
            return Padding(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _partnerSurface(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: WorkspacePageTitle(
                                  title: _menuName,
                                  favoriteKey: 'partnerCompanies',
                                ),
                              ),
                              if (!compact) ...[
                                SizedBox(
                                  width: LaooLayout.listViewToggleSize,
                                  height: LaooLayout.listViewToggleSize,
                                  child: IconButton(
                                    tooltip: showCards
                                        ? 'แสดงแบบตาราง'
                                        : 'แสดงแบบการ์ด',
                                    style: IconButton.styleFrom(
                                      backgroundColor: color.withValues(
                                        alpha: .1,
                                      ),
                                      foregroundColor: color,
                                      shape: shape,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _partnerCardMode = !_partnerCardMode,
                                    ),
                                    icon: Icon(
                                      showCards
                                          ? Icons.view_list_outlined
                                          : Icons.grid_view_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (_canCreate)
                                SizedBox(
                                  height: LaooTypography.buttonHeight,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(shape: shape),
                                    onPressed: () => _openFullForm(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('เพิ่มลูกค้า'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _partnerSurface(
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, available) => FilterHeightSync(
                              builder: (context, searchKey, height) => Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: available.maxWidth < 330
                                        ? available.maxWidth
                                        : 330,
                                    child: TextField(
                                      key: searchKey,
                                      controller: _search,
                                      onSubmitted: (_) => _partnerSearch(),
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.search),
                                        hintText: 'ค้นหาชื่อ และเบอร์โทรศัพท์',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: height,
                                    child: FilledButton.icon(
                                      onPressed: _partnerSearch,
                                      style: FilledButton.styleFrom(
                                        shape: shape,
                                      ).merge(filterActionHeightStyle(height)),
                                      icon: const Icon(Icons.search),
                                      label: const Text('ค้นหา'),
                                    ),
                                  ),
                                  SizedBox(
                                    height: height,
                                    child: OutlinedButton.icon(
                                      onPressed: _partnerClear,
                                      style: OutlinedButton.styleFrom(
                                        shape: shape,
                                        foregroundColor: color,
                                        side: BorderSide(color: color),
                                      ).merge(filterActionHeightStyle(height)),
                                      icon: const Icon(
                                        Icons.filter_alt_off_outlined,
                                      ),
                                      label: const Text('ล้าง Filter'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: available.maxWidth < 170
                                        ? available.maxWidth
                                        : 170,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _partnerStatusDraft,
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
                                      onChanged: (value) => setState(
                                        () => _partnerStatusDraft =
                                            value ?? 'ทั้งหมด',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _loading
                            ? _partnerSurface(
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _error != null
                            ? _partnerSurface(
                                Center(
                                  child: Text(
                                    'ไม่สามารถโหลดข้อมูลลูกค้าได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองใหม่',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : _filteredItems.isEmpty
                            ? _partnerSurface(
                                const Center(child: Text('ไม่พบข้อมูลลูกค้า')),
                              )
                            : showCards
                            ? _partnerCards()
                            : _partnerTable(),
                      ),
                      const SizedBox(height: 8),
                      _partnerPagination(),
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
            );
          },
        ),
      ),
    );
  }

  Widget _partnerActions(PartnerCompany item) {
    final primary = workspaceThemeController.value.primary;
    final error = LaooColors.error;
    Widget action(
      String tooltip,
      IconData icon,
      Color iconColor,
      VoidCallback onPressed,
    ) => SizedBox(
      width: 34,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 20),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canEdit)
          action(
            'ระบบที่เปิดใช้',
            Icons.apps_outlined,
            primary,
            () => _openModules(item),
          ),
        if (_canEdit)
          action(
            'กำหนดผู้ดูแลระบบ',
            Icons.admin_panel_settings_outlined,
            primary,
            () => _openAdminCredentials(item),
          ),
        if (_canEdit)
          action(
            'แก้ไข',
            Icons.edit_outlined,
            primary,
            () => _openFullForm(existing: item),
          ),
        if (_canDelete)
          action('ลบ', Icons.delete_outline, error, () => _confirmDelete(item)),
      ],
    );
  }

  Widget _partnerStatus(PartnerCompany item) {
    final color = item.isActive
        ? workspaceThemeController.value.primary
        : LaooColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: LaooTypography.tableBody,
        ),
      ),
    );
  }

  Widget _partnerTable() {
    final preset = workspaceThemeController.value;
    final accent = preset.primary;
    const flex = <int>[45, 180, 260, 120, 190, 150, 125];
    Widget line(List<Widget> cells, {bool header = false}) => Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: header ? accent.withValues(alpha: .12) : Colors.white,
        border: Border(bottom: BorderSide(color: preset.border, width: .6)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: flex[i], child: cells[i]),
        ],
      ),
    );
    Widget value(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: LaooTypography.tableBody,
        color: preset.textPrimary,
      ),
    );
    Widget header(
      String text, {
      int? index,
      Comparable Function(PartnerCompany)? selector,
    }) {
      final label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: LaooTypography.tableHeader,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (index != null && _sortColumnIndex == index)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: accent,
            ),
        ],
      );
      return index == null || selector == null
          ? label
          : InkWell(
              onTap: () => _sortBy(
                index,
                selector,
                _sortColumnIndex == index ? !_sortAscending : true,
              ),
              child: label,
            );
    }

    return _partnerSurface(
      Column(
        children: [
          line([
            header('ID'),
            header('Action'),
            header('ชื่อลูกค้า', index: 2, selector: (p) => p.companyNameTh),
            header('เลขผู้เสียภาษี', index: 3, selector: (p) => p.taxId ?? ''),
            header('Email', index: 4, selector: (p) => p.email ?? ''),
            header('โทรศัพท์', index: 5, selector: (p) => p.telephone ?? ''),
            header('สถานะ', index: 6, selector: (p) => p.isActive ? 1 : 0),
          ], header: true),
          Expanded(
            child: ListView.builder(
              itemCount: _visibleItems.length,
              itemBuilder: (context, index) {
                final item = _visibleItems[index];
                return line([
                  value('${_currentPage * _pageSize + index + 1}'),
                  _partnerActions(item),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      value(item.companyNameTh),
                      if ((item.adminUsername ?? '').trim().isNotEmpty)
                        Text(
                          'Admin: ${item.adminUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: LaooTypography.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  value(item.taxId ?? '-'),
                  value(item.email ?? '-'),
                  value(item.telephone ?? '-'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _partnerStatus(item),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerCards() => ListView.separated(
    itemCount: _visibleItems.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final item = _visibleItems[index];
      final primary = workspaceThemeController.value.primary;
      return _partnerSurface(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    item.companyNameTh,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      fontSize: LaooTypography.tableBody,
                    ),
                  ),
                  _partnerStatus(item),
                  _partnerActions(item),
                ],
              ),
              const SizedBox(height: 8),
              Text('Admin: ${item.adminUsername ?? '-'}'),
              Text('เลขผู้เสียภาษี: ${item.taxId ?? '-'}'),
              Text('Email: ${item.email ?? '-'}'),
              Text('โทรศัพท์: ${item.telephone ?? '-'}'),
            ],
          ),
        ),
      );
    },
  );

  Widget _partnerPagination() {
    final page = _currentPage.clamp(0, _pageCount - 1);
    final total = _filteredItems.length;
    final first = total == 0 ? 0 : page * _pageSize + 1;
    final last = total == 0 ? 0 : ((page + 1) * _pageSize).clamp(0, total);
    final preset = workspaceThemeController.value;
    final accent = preset.primary;
    final selectedText = preset.toThemeData().colorScheme.onPrimary;
    Widget button(
      Widget child,
      VoidCallback? onPressed, {
      bool selected = false,
    }) => SizedBox(
      width: LaooLayout.paginationButtonSize,
      height: LaooLayout.paginationButtonSize,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: accent,
          disabledBackgroundColor: selected ? accent : Colors.grey.shade300,
          disabledForegroundColor: selected
              ? selectedText
              : Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        child: child,
      ),
    );
    return _partnerSurface(
      SizedBox(
        height: LaooLayout.paginationCardHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: LaooLayout.cardPadding,
          ),
          child: Row(
            children: [
              button(
                const Icon(Icons.chevron_left, size: 22),
                page > 0 ? () => setState(() => _currentPage = page - 1) : null,
              ),
              const SizedBox(width: 6),
              button(Text('${page + 1}'), null, selected: true),
              const SizedBox(width: 6),
              button(
                const Icon(Icons.chevron_right, size: 22),
                page + 1 < _pageCount
                    ? () => setState(() => _currentPage = page + 1)
                    : null,
              ),
              const SizedBox(width: 12),
              Text('$first-$last จาก $total'),
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

    if (MediaQuery.sizeOf(context).width < 600) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMobileCards(context)),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: _paginationBar()),
        ],
      );
    }

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
                    child: PinnedDataTable(
                      border: TableBorder(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: .5,
                        ),
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: .5,
                        ),
                        horizontalInside: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: .5,
                        ),
                      ),
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
                        LaooTableColumns.id,
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
                                    width: 160,
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.menuScope !=
                                                  WorkspaceMenuScope.support &&
                                              _canEdit)
                                            IconButton(
                                              tooltip: 'ระบบที่เปิดใช้',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  _openModules(item),
                                              icon: Icon(
                                                Icons.apps_outlined,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
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
                                                  fontSize: 14,
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
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: _paginationBar()),
      ],
    );
  }

  Widget _buildMobileCards(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemCount: _visibleItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _visibleItems[index];
        final primary = Theme.of(context).colorScheme.primary;
        final statusColor = item.isActive
            ? primary
            : Theme.of(context).colorScheme.error;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (widget.menuScope != WorkspaceMenuScope.support &&
                        _canEdit)
                      IconButton(
                        tooltip: 'ระบบที่เปิดใช้',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openModules(item),
                        icon: Icon(Icons.apps_outlined, color: primary),
                      ),
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
        barrierDismissible: false,
        builder: (dialogContext) {
          final preset = workspaceThemeController.value;
          final primary = preset.primary;
          String? dialogError;
          bool saving = false;
          return StatefulBuilder(
            builder: (context, setDialogState) => Theme(
              data: preset.toThemeData(),
              child: Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(
                  LaooLayout.dialogInsetPadding,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.sizeOf(context).height - 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.manage_accounts_outlined,
                              color: primary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'กำหนดผู้ดูแลระบบ - ${item.companyNameTh}',
                                style: TextStyle(
                                  color: LaooColors.pageCaption,
                                  fontSize: LaooTypography.workspaceCaption,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: LaooColors.border),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Form(
                                  key: formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        controller: username,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Username *',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(LaooRadius.xs),
                                            ),
                                          ),
                                        ),
                                        validator: (v) => v!.trim().isEmpty
                                            ? 'กรุณาระบุ Username'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: password,
                                        obscureText: true,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Password *',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(LaooRadius.xs),
                                            ),
                                          ),
                                        ),
                                        validator: (v) => v!.isEmpty
                                            ? 'กรุณาระบุ Password'
                                            : null,
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
                                      onClose: () => setDialogState(
                                        () => dialogError = null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: LaooColors.border),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(dialogContext, false),
                              icon: const Icon(Icons.close),
                              label: Text(
                                'ยกเลิก',
                                style: TextStyle(color: primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setDialogState(() {
                                        saving = true;
                                        dialogError = null;
                                      });
                                      try {
                                        await _repository.updateAdmin(
                                          item.companyId,
                                          username.text.trim(),
                                          password.text,
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext, true);
                                        }
                                      } on ApiException catch (error) {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                            () => dialogError =
                                                error.message.trim().isEmpty
                                                ? 'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลอีกครั้ง'
                                                : error.message,
                                          );
                                        }
                                      } catch (_) {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                            () => dialogError =
                                                'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลอีกครั้ง',
                                          );
                                        }
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(() => saving = false);
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('บันทึก'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
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
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              child: Text('${index + 1}'),
            )
          : OutlinedButton(
              onPressed: () => setState(() => _currentPage = index),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              child: Text('${index + 1}'),
            ),
    );
  }
}
