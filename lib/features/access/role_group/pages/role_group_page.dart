import 'dart:async';
import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/pinned_data_table.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/role_group_repository.dart';
import '../models/role_group.dart';
import '../../../profile/data/user_profile_repository.dart';

class RoleGroupPage extends StatefulWidget {
  const RoleGroupPage({
    super.key,
    required this.scope,
    required this.activeMenu,
    this.embedded = false,
    this.onSelected,
  });
  final String scope;
  final String activeMenu;
  final bool embedded;
  final ValueChanged<RoleGroup>? onSelected;
  @override
  State<RoleGroupPage> createState() => _RoleGroupPageState();
}

class _RoleGroupPageState extends State<RoleGroupPage> {
  final _repo = RoleGroupRepository();
  final _profile = UserProfileRepository();
  final _search = TextEditingController();
  final _formKey = GlobalKey<_FormState>();
  late Future<List<RoleGroup>> _future;
  RoleGroup? _editing;
  Timer? _alertTimer;
  String? _alert;
  bool _alertError = false;
  bool _form = false;
  bool _card = false;
  bool _loading = false;
  bool _canCreate = false, _canEdit = false, _canDelete = false;
  String _caption = 'กลุ่มสิทธิ์';
  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _load();
    _loadDefaultViewMode();
    _loadCaption();
  }

  Future<void> _loadCaption() async {
    final menuCode = widget.scope == 'partner'
        ? '11003'
        : widget.scope == 'laoo'
        ? '12003'
        : '10003';
    try {
      final caption = await NavigationMenuRepository().resolveMenuName(
        menuCode: menuCode,
        fallback: _caption,
      );
      if (mounted) setState(() => _caption = caption);
    } catch (_) {}
  }

  Future<void> _loadDefaultViewMode() async {
    try {
      final profile = await _profile.get();
      if (mounted) {
        setState(
          () => _card =
              profile['defaultViewMode']?.toString().toUpperCase() == 'CARD',
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    final future = _repo.list(widget.scope, search: _search.text);
    setState(() {
      _future = future;
    });
  }

  Future<void> _loadPermissions() async {
    try {
      final p = await _repo.actions(widget.scope);
      if (mounted) {
        setState(() {
          _canCreate = p['create'] == true;
          _canEdit = p['edit'] == true;
          _canDelete = p['delete'] == true;
        });
      }
    } catch (_) {}
  }

  void _notice(String message, {bool error = false}) {
    _alertTimer?.cancel();
    setState(() {
      _alert = message;
      _alertError = error;
    });
    _alertTimer = Timer(companySetupController.alertDuration, () {
      if (mounted) setState(() => _alert = null);
    });
  }

  String _thaiError(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('403')) return 'ไม่มีสิทธิ์ดำเนินการรายการนี้';
    if (text.contains('401')) return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
    if (text.contains('404')) return 'ไม่พบข้อมูลที่ต้องการ';
    if (text.contains('409') || text.contains('ซ้ำ')) {
      return 'ข้อมูลนี้มีอยู่แล้ว';
    }
    if (text.contains('SocketException') || text.contains('Timeout')) {
      return 'ไม่สามารถเชื่อมต่อระบบได้';
    }
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }

  Future<bool> _save(String code, String name, String desc, bool active) async {
    if ((widget.scope != 'customer' && code.trim().isEmpty) ||
        name.trim().isEmpty) {
      _notice('กรุณาระบุข้อมูลกลุ่มสิทธิ์ให้ครบ', error: true);
      return false;
    }
    final editing = _editing != null;
    setState(() => _loading = true);
    try {
      final item = RoleGroup(
        id: _editing?.id ?? 0,
        scope: widget.scope,
        code: code.trim(),
        name: name.trim(),
        description: desc.trim().isEmpty ? null : desc.trim(),
        isActive: active,
      );
      if (editing) {
        await _repo.update(widget.scope, item);
        setState(() {
          _form = false;
          _editing = null;
        });
        _notice('แก้ไขข้อมูลกลุ่มสิทธิ์สำเร็จ');
      } else {
        await _repo.create(widget.scope, item);
        _formKey.currentState?.clearFields();
        _notice('เพิ่มข้อมูลใหม่สำเร็จ');
      }
      _load();
      return true;
    } catch (e) {
      _notice(_thaiError(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCustomerForm(RoleGroup? item) async {
    _editing = item;
    final name = TextEditingController(text: item?.name);
    final description = TextEditingController(text: item?.description);
    var active = item?.isActive ?? true;
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .54),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(LaooRadius.xs)),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: LaooLayout.popupHeaderMinHeight,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: workspaceThemeController.value.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'กลุ่มสิทธิ์ > ${item == null ? 'เพิ่ม' : 'แก้ไข'}',
                            style: LaooTypography.popupTitleStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: LaooColors.border,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text('สถานะ'),
                            const SizedBox(width: 8),
                            Switch(
                              value: active,
                              activeTrackColor:
                                  workspaceThemeController.value.primary,
                              onChanged: saving
                                  ? null
                                  : (value) =>
                                        setDialogState(() => active = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: LaooLayout.popupFieldSpacing),
                        TextField(
                          controller: name,
                          cursorColor: workspaceThemeController.value.primary,
                          enabled: !saving,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                          decoration: _rolePopupDecoration(
                            context,
                            'ชื่อกลุ่มสิทธิ์ *',
                            errorText: error,
                          ),
                        ),
                        const SizedBox(height: LaooLayout.popupFieldSpacing),
                        TextField(
                          controller: description,
                          cursorColor: workspaceThemeController.value.primary,
                          enabled: !saving,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                          decoration: _rolePopupDecoration(
                            context,
                            'รายละเอียด',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: LaooColors.border,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              workspaceThemeController.value.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(
                            fontFamily: LaooTypography.fontFamily,
                            fontSize: LaooTypography.button,
                            fontWeight: FontWeight.w700,
                          ),
                          minimumSize: const Size(
                            84,
                            LaooTypography.buttonHeight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('ยกเลิก'),
                      ),
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                if (name.text.trim().isEmpty) {
                                  setDialogState(
                                    () => error = 'กรุณาระบุชื่อกลุ่มสิทธิ์',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  saving = true;
                                  error = null;
                                });
                                final success = await _save(
                                  item?.code ?? '',
                                  name.text,
                                  description.text,
                                  active,
                                );
                                if (!dialogContext.mounted) return;
                                if (success) {
                                  Navigator.pop(dialogContext);
                                } else {
                                  setDialogState(() {
                                    saving = false;
                                    error =
                                        'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและลองอีกครั้ง';
                                  });
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              workspaceThemeController.value.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(
                            fontFamily: LaooTypography.fontFamily,
                            fontSize: LaooTypography.button,
                            fontWeight: FontWeight.w700,
                          ),
                          minimumSize: const Size(
                            100,
                            LaooTypography.buttonHeight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    description.dispose();
    _editing = null;
  }

  InputDecoration _rolePopupDecoration(
    BuildContext context,
    String label, {
    String? errorText,
  }) {
    final primary = workspaceThemeController.value.primary;
    final error = Theme.of(context).colorScheme.error;
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: const TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontSize: LaooTypography.inputLabel,
      ),
      errorStyle: const TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontSize: LaooTypography.validation,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? error
              : states.contains(WidgetState.focused)
              ? primary
              : Theme.of(context).inputDecorationTheme.labelStyle?.color ??
                    Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: LaooTypography.materialFloatingLabelSource,
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(LaooColors.border),
      enabledBorder: border(LaooColors.border),
      disabledBorder: border(LaooColors.border),
      focusedBorder: border(primary, width: 1.5),
      errorBorder: border(error),
      focusedErrorBorder: border(error, width: 1.5),
    );
  }

  Future<void> _delete(RoleGroup item) async {
    final accent = workspaceThemeController.value.primary;
    final errorColor = Theme.of(context).colorScheme.error;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: BorderSide(color: errorColor, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: errorColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: LaooTypography.popupTitleStyle.copyWith(
                  color: errorColor,
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
                color: errorColor.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ ${item.code} - ${item.name} หรือไม่?',
                textAlign: TextAlign.center,
                style: TextStyle(color: errorColor),
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
            const Divider(height: 24),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _repo.delete(widget.scope, item.id);
      _notice('ลบกลุ่มสิทธิ์สำเร็จ');
      _load();
    } catch (e) {
      _notice(_thaiError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (widget.embedded) return content;
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: widget.activeMenu,
      menuScope: widget.scope == 'partner'
          ? WorkspaceMenuScope.partner
          : widget.scope == 'laoo'
          ? WorkspaceMenuScope.support
          : WorkspaceMenuScope.company,
      child: content,
    );
  }

  Widget _buildContent() => ColoredBox(
    color: const Color(0xFFF8F9FB),
    child: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _form
                  ? _Form(
                      key: _formKey,
                      onCancel: () => setState(() {
                        _form = false;
                        _editing = null;
                      }),
                      onSave: (code, name, desc, active) async {
                        await _save(code, name, desc, active);
                      },
                      editing: _editing,
                      loading: _loading,
                      favoriteKey: widget.scope == 'partner'
                          ? '11003'
                          : widget.scope == 'laoo'
                          ? '12003'
                          : '10003',
                    )
                  : _List(
                      caption: _caption,
                      future: _future,
                      search: _search,
                      onSearch: _load,
                      canCreate: _canCreate,
                      canEdit: _canEdit,
                      canDelete: _canDelete,
                      hideAutoCode: widget.scope == 'customer',
                      isCard: _card,
                      onToggleView: () => setState(() => _card = !_card),
                      favoriteKey: widget.scope == 'partner'
                          ? '11003'
                          : widget.scope == 'laoo'
                          ? '12003'
                          : '10003',
                      onAdd: () => widget.scope == 'customer'
                          ? _openCustomerForm(null)
                          : setState(() {
                              _form = true;
                              _editing = null;
                            }),
                      onEdit: (x) => widget.scope == 'customer'
                          ? _openCustomerForm(x)
                          : setState(() {
                              _form = true;
                              _editing = x;
                            }),
                      onDelete: _delete,
                      onSelected: widget.onSelected,
                    ),
            ),
          ],
        ),
        if (_alert != null)
          Positioned(
            top: 16,
            right: 24,
            child: _AlertBanner(
              message: _alert!,
              error: _alertError,
              onClose: () => setState(() => _alert = null),
            ),
          ),
      ],
    ),
  );
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.message,
    required this.error,
    required this.onClose,
  });
  final String message;
  final bool error;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) {
        final color = error ? Colors.red : preset.primary;
        final foreground = error
            ? Theme.of(context).colorScheme.onError
            : Theme.of(context).colorScheme.onPrimary;
        return Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .62),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error ? Icons.error_outline : Icons.check_circle_outline,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  color: foreground,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCards(
    BuildContext context,
    List<RoleGroup> rows,
    int start,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final cardBackground = theme.colorScheme.surface;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          color: cardBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.code,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            (item.isActive ? primary : theme.colorScheme.error)
                                .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          item.isActive ? 'เปิด' : 'ปิด',
                          style: TextStyle(
                            color: item.isActive
                                ? primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (false)
                      IconButton(
                        tooltip: 'แก้ไข',
                        onPressed: () {},
                        icon: Icon(Icons.edit_outlined, color: primary),
                      ),
                    if (false)
                      IconButton(
                        tooltip: 'ลบ',
                        onPressed: () {},
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _List extends StatefulWidget {
  const _List({
    required this.caption,
    required this.future,
    required this.search,
    required this.onSearch,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.hideAutoCode,
    required this.isCard,
    required this.onToggleView,
    required this.favoriteKey,
    this.onSelected,
  });
  final String caption;
  final Future<List<RoleGroup>> future;
  final TextEditingController search;
  final VoidCallback onSearch, onAdd;
  final void Function(RoleGroup) onEdit, onDelete;
  final ValueChanged<RoleGroup>? onSelected;
  final bool canCreate, canEdit, canDelete;
  final bool hideAutoCode;
  final bool isCard;
  final VoidCallback onToggleView;
  final String favoriteKey;
  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  int page = 1;
  static const pageSize = 10;
  String statusFilter = 'all';
  String appliedStatusFilter = 'all';
  int? sortColumn;
  bool sortAscending = true;

  void _sort(int column, bool ascending) => setState(() {
    sortColumn = column;
    sortAscending = ascending;
  });

  void _applySearch() {
    setState(() {
      page = 1;
      appliedStatusFilter = statusFilter;
    });
    widget.onSearch();
  }

  void _clearFilters() {
    widget.search.clear();
    setState(() {
      page = 1;
      statusFilter = 'all';
      appliedStatusFilter = 'all';
    });
    widget.onSearch();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide.none,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF5F6F7))),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: WorkspacePageTitle(
                        title: widget.caption,
                        favoriteKey: widget.favoriteKey,
                      ),
                    ),
                    if (constraints.maxWidth >= 600)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .10),
                        ),
                        child: SizedBox.square(
                          dimension: LaooTypography.buttonHeight,
                          child: IconButton(
                            tooltip: widget.isCard
                                ? 'แสดงแบบรายการ'
                                : 'แสดงแบบการ์ด',
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: widget.onToggleView,
                            icon: Icon(
                              widget.isCard
                                  ? Icons.view_list_outlined
                                  : Icons.grid_view_outlined,
                            ),
                          ),
                        ),
                      ),
                    if (widget.canCreate) const SizedBox(width: 8),
                    if (widget.canCreate)
                      FilledButton.icon(
                        onPressed: widget.onAdd,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) => FilterHeightSync(
                    builder: (context, searchKey, height) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 450).clamp(
                                  150.0,
                                  360.0,
                                ),
                          child: TextField(
                            key: searchKey,
                            controller: widget.search,
                            onSubmitted: (_) => _applySearch(),
                            decoration: InputDecoration(
                              labelText: 'ค้นหา',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _applySearch,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ).merge(filterActionHeightStyle(height)),
                          icon: const Icon(Icons.search),
                          label: const Text('ค้นหา'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ).merge(filterActionHeightStyle(height)),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('ล้าง Filter'),
                        ),
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : 170,
                          child: DropdownButtonFormField<String>(
                            initialValue: statusFilter,
                            style: Theme.of(context).textTheme.bodyMedium,
                            decoration: InputDecoration(
                              labelText: 'สถานะ',
                              floatingLabelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: workspaceThemeController.value.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('ทั้งหมด'),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('เปิด'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('ปิด'),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              statusFilter = value ?? 'all';
                              page = 1;
                            }),
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
              child: FutureBuilder<List<RoleGroup>>(
                future: widget.future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 36,
                          ),
                          const Text('โหลดข้อมูลกลุ่มสิทธิ์ไม่สำเร็จ'),
                          const Text('กรุณาลองใหม่อีกครั้ง'),
                          OutlinedButton(
                            onPressed: widget.onSearch,
                            child: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final source = snapshot.data!;
                  final all = (appliedStatusFilter == 'active'
                      ? source.where((item) => item.isActive).toList()
                      : appliedStatusFilter == 'inactive'
                      ? source.where((item) => !item.isActive).toList()
                      : [...source]);
                  if (sortColumn != null) {
                    all.sort((a, b) {
                      final result = switch (sortColumn) {
                        2 when !widget.hideAutoCode => a.code.compareTo(b.code),
                        2 when widget.hideAutoCode => a.name.compareTo(b.name),
                        3 when !widget.hideAutoCode => a.name.compareTo(b.name),
                        3 when widget.hideAutoCode =>
                          a.isActive == b.isActive ? 0 : (a.isActive ? 1 : -1),
                        4 =>
                          a.isActive == b.isActive ? 0 : (a.isActive ? 1 : -1),
                        _ => 0,
                      };
                      return sortAscending ? result : -result;
                    });
                  }
                  final pages = all.isEmpty
                      ? 1
                      : (all.length / pageSize).ceil();
                  if (page > pages) page = pages;
                  final start = (page - 1) * pageSize;
                  final rows = all.skip(start).take(pageSize).toList();
                  final firstItem = rows.isEmpty ? 0 : start + 1;
                  final lastItem = rows.isEmpty ? 0 : start + rows.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: rows.isEmpty
                            ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('ไม่พบข้อมูลตามเงื่อนไข'),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  if (widget.isCard ||
                                      constraints.maxWidth < 600) {
                                    return _buildMobileCards(
                                      context,
                                      rows,
                                      start,
                                    );
                                  }
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: workspaceThemeController
                                              .value
                                              .border,
                                        ),
                                        child: DataTableTheme(
                                          data: DataTableThemeData(
                                            dataRowMinHeight: 48,
                                            dataRowMaxHeight: 56,
                                            headingRowHeight: 56,
                                            headingTextStyle: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  fontSize: LaooTypography
                                                      .tableHeader,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          child: PinnedDataTable(
                                            showCheckboxColumn: false,
                                            horizontalMargin: 8,
                                            columnSpacing: 20,
                                            dividerThickness: .6,
                                            sortColumnIndex: sortColumn,
                                            sortAscending: sortAscending,
                                            headingRowColor:
                                                WidgetStatePropertyAll(
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.12),
                                                ),
                                            columns: [
                                              LaooTableColumns.id,
                                              DataColumn(
                                                label: const SizedBox(
                                                  width: 120,
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 12,
                                                    ),
                                                    child: Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text('Action'),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (!widget.hideAutoCode)
                                                DataColumn(
                                                  label: const Text(
                                                    'รหัสกลุ่มสิทธิ์',
                                                  ),
                                                  onSort: (column, ascending) =>
                                                      _sort(column, ascending),
                                                ),
                                              DataColumn(
                                                label: const Text('ชื่อกลุ่ม'),
                                                onSort: (column, ascending) =>
                                                    _sort(column, ascending),
                                              ),
                                              DataColumn(
                                                label: const Text('สถานะ'),
                                                onSort: (column, ascending) =>
                                                    _sort(column, ascending),
                                              ),
                                            ],
                                            rows: [
                                              for (
                                                var i = 0;
                                                i < rows.length;
                                                i++
                                              )
                                                DataRow(
                                                  onSelectChanged:
                                                      widget.onSelected !=
                                                              null &&
                                                          rows[i].isActive
                                                      ? (_) =>
                                                            widget.onSelected!(
                                                              rows[i],
                                                            )
                                                      : null,
                                                  cells: [
                                                    DataCell(
                                                      SizedBox(
                                                        width: 80,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 12,
                                                              ),
                                                          child: Text(
                                                            '${start + i + 1}',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      SizedBox(
                                                        width: 120,
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children: [
                                                            if (widget.canEdit)
                                                              IconButton(
                                                                onPressed: () =>
                                                                    widget.onEdit(
                                                                      rows[i],
                                                                    ),
                                                                icon: Icon(
                                                                  Icons
                                                                      .edit_outlined,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.primary,
                                                                ),
                                                                tooltip:
                                                                    'แก้ไข',
                                                              ),
                                                            if (widget
                                                                .canDelete)
                                                              IconButton(
                                                                onPressed: () =>
                                                                    widget.onDelete(
                                                                      rows[i],
                                                                    ),
                                                                icon: Icon(
                                                                  Icons
                                                                      .delete_outline,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.error,
                                                                ),
                                                                tooltip: 'ลบ',
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (!widget.hideAutoCode)
                                                      DataCell(
                                                        Text(rows[i].code),
                                                      ),
                                                    DataCell(
                                                      Text(rows[i].name),
                                                    ),
                                                    DataCell(
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              rows[i].isActive
                                                              ? Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          .12,
                                                                    )
                                                              : Colors
                                                                    .red
                                                                    .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          rows[i].isActive
                                                              ? 'เปิด'
                                                              : 'ปิด',
                                                          style: TextStyle(
                                                            color:
                                                                rows[i].isActive
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary
                                                                : Colors.red,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide.none,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: LaooLayout.paginationCardHeight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                _PageButton(
                                  label: 'ก่อนหน้า',
                                  enabled: page > 1,
                                  onTap: () => setState(() => page--),
                                ),
                                _PageButton(
                                  label: '$page',
                                  enabled: false,
                                  onTap: () {},
                                  selected: true,
                                ),
                                _PageButton(
                                  label: 'ถัดไป',
                                  enabled: page < pages,
                                  onTap: () => setState(() => page++),
                                ),
                                const SizedBox(width: 12),
                                Text('$firstItem-$lastItem จาก ${all.length}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCards(
    BuildContext context,
    List<RoleGroup> rows,
    int start,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final cardBackground = theme.colorScheme.surface;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          color: cardBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide.none,
          ),
          child: InkWell(
            onTap: widget.onSelected != null && item.isActive
                ? () => widget.onSelected!(item)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.hideAutoCode ? item.name : item.code,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              (item.isActive
                                      ? primary
                                      : theme.colorScheme.error)
                                  .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            item.isActive ? 'เปิด' : 'ปิด',
                            style: TextStyle(
                              color: item.isActive
                                  ? primary
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (widget.canEdit)
                        IconButton(
                          tooltip: 'แก้ไข',
                          onPressed: () => widget.onEdit(item),
                          icon: Icon(Icons.edit_outlined, color: primary),
                        ),
                      if (widget.canDelete)
                        IconButton(
                          tooltip: 'ลบ',
                          onPressed: () => widget.onDelete(item),
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  if (!widget.hideAutoCode) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final bool enabled, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isPrevious = label == 'ก่อนหน้า';
    final isNext = label == 'ถัดไป';
    final arrow = isPrevious || isNext;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: selected || (arrow && enabled)
                ? primary
                : enabled && !arrow
                ? Colors.white
                : Colors.grey.shade300,
            border: !arrow && enabled && !selected
                ? Border.all(color: primary)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: InkWell(
              onTap: selected || !enabled ? null : onTap,
              borderRadius: BorderRadius.circular(4),
              child: Center(
                child: arrow
                    ? Icon(
                        isPrevious ? Icons.chevron_left : Icons.chevron_right,
                        size: 22,
                        color: selected || enabled
                            ? Colors.white
                            : Colors.grey.shade600,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: selected ? Colors.white : primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({
    super.key,
    required this.onCancel,
    required this.onSave,
    required this.favoriteKey,
    this.editing,
    this.loading,
  });
  final VoidCallback onCancel;
  final Future<void> Function(String, String, String, bool) onSave;
  final RoleGroup? editing;
  final bool? loading;
  final String favoriteKey;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController code, name, desc;
  bool active = true;
  @override
  void initState() {
    super.initState();
    final x = widget.editing;
    code = TextEditingController(text: x?.code);
    name = TextEditingController(text: x?.name);
    desc = TextEditingController(text: x?.description);
    active = x?.isActive ?? true;
  }

  void clearFields() {
    code.clear();
    name.clear();
    desc.clear();
    setState(() => active = true);
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFF0F1F3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceActionHeader(
                  title:
                      'กลุ่มสิทธิ์ > ${widget.editing == null ? 'เพิ่ม' : 'แก้ไข'}',
                  favoriteKey: widget.favoriteKey,
                  actions: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(c).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(c).colorScheme.primary,
                        ),
                      ),
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.loading == true
                          ? null
                          : () => widget.onSave(
                              code.text,
                              name.text,
                              desc.text,
                              active,
                            ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFF0F1F3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('สถานะ'),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'รหัสกลุ่มสิทธิ์ *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อกลุ่มสิทธิ์ *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'รายละเอียด'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
