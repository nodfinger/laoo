import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync;
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../../core/widgets/combo_box_text.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/api/api_exception.dart';
import '../models/partner.dart';

class PartnerListPage extends StatefulWidget {
  const PartnerListPage({
    super.key,
    required this.loadPartners,
    required this.openCreate,
    required this.openEdit,
    required this.changeStatus,
    required this.deletePartner,
    required this.createPartnerAdmin,
    required this.updatePartnerAdmin,
  });

  final Future<List<Partner>> Function({String? search, bool? isActive})
  loadPartners;
  final Future<void> Function() openCreate;
  final Future<bool> Function(Partner partner) openEdit;
  final Future<void> Function(Partner partner, bool isActive) changeStatus;
  final Future<void> Function(Partner partner) deletePartner;
  final Future<void> Function(Partner partner, String username, String password)
  createPartnerAdmin;
  final Future<void> Function(Partner partner, String username, String password)
  updatePartnerAdmin;

  @override
  State<PartnerListPage> createState() => _PartnerListPageState();
}

class _PartnerListPageState extends State<PartnerListPage> {
  final _searchController = TextEditingController();

  bool? _activeFilter;
  bool _loading = true;
  Object? _error;
  List<Partner> _partners = const [];
  int? _sortColumnIndex = 2;
  bool _sortAscending = true;
  int _currentPage = 0;
  bool _cardMode = false;

  int get _pageSize {
    final value = companySetupController.pageSize;
    return value > 0 ? value : 30;
  }

  int get _pageCount =>
      _partners.isEmpty ? 1 : (_partners.length / _pageSize).ceil();

  List<Partner> get _visiblePartners {
    final safePage = _currentPage.clamp(0, _pageCount - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, _partners.length);
    return _partners.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final partners = await widget.loadPartners(
        search: _searchController.text.trim(),
        isActive: _activeFilter,
      );

      if (!mounted) return;
      setState(() {
        _partners = partners;
        _currentPage = 0;
      });
      _applyCurrentSort();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    showTimedSnackBar(context, message: message, error: error);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _activeFilter = null);
    _load();
  }

  Future<void> _manageAdmin(Partner partner) async {
    final editing = partner.partnerAdminUserId != null;
    final result = await showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PartnerAdminDialog(
        initialUsername: partner.partnerAdminUsername,
        editing: editing,
      ),
    );
    if (result == null) return;
    try {
      if (editing) {
        await widget.updatePartnerAdmin(partner, result.$1, result.$2);
      } else {
        await widget.createPartnerAdmin(partner, result.$1, result.$2);
      }
      await _load();
      if (mounted) {
        _showMessage(
          editing ? 'แก้ไข Partner Admin สำเร็จ' : 'สร้าง Partner Admin สำเร็จ',
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'ไม่สามารถสร้าง Partner Admin ได้';
        _showMessage(message, error: true);
      }
    }
  }

  void _sortBy(
    int columnIndex,
    Comparable Function(Partner partner) selector,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _partners = [..._partners]
        ..sort((a, b) {
          final av = selector(a);
          final bv = selector(b);
          final result = av.compareTo(bv);
          return ascending ? result : -result;
        });
    });
  }

  void _applyCurrentSort() {
    final index = _sortColumnIndex;
    if (index == null) return;

    if (index == 1) {
      _sortBy(1, (p) => p.partnerCode.toLowerCase(), _sortAscending);
    } else if (index == 2) {
      _sortBy(2, (p) => p.partnerNameTh.toLowerCase(), _sortAscending);
    } else if (index == 3) {
      _sortBy(3, (p) => (p.contactName1 ?? '').toLowerCase(), _sortAscending);
    } else if (index == 4) {
      _sortBy(4, (p) => (p.contactPhone1 ?? '').toLowerCase(), _sortAscending);
    } else if (index == 5) {
      _sortBy(5, (p) => p.isActive ? 1 : 0, _sortAscending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final cardMode = compact || _cardMode;
          return Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: WorkspacePageTitle(
                            title: 'Partner',
                            favoriteKey: 'Partner',
                          ),
                        ),
                        if (!compact) ...[
                          SizedBox(
                            width: LaooLayout.listViewToggleSize,
                            height: LaooLayout.listViewToggleSize,
                            child: IconButton(
                              tooltip: cardMode
                                  ? 'แสดงแบบตาราง'
                                  : 'แสดงแบบการ์ด',
                              style: IconButton.styleFrom(
                                backgroundColor: accent.withValues(alpha: .1),
                                foregroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => _cardMode = !_cardMode),
                              icon: Icon(
                                cardMode
                                    ? Icons.view_list_outlined
                                    : Icons.grid_view,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        SizedBox(
                          height: LaooTypography.buttonHeight,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await widget.openCreate();
                              await _load();
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('เพิ่ม'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _section(
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _Toolbar(
                      searchController: _searchController,
                      activeFilter: _activeFilter,
                      onSearch: _load,
                      onActiveChanged: (value) =>
                          setState(() => _activeFilter = value),
                      onClear: _clearFilters,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? _section(
                          const Center(child: CircularProgressIndicator()),
                        )
                      : _error != null
                      ? _section(
                          _StateCard(
                            icon: Icons.error_outline,
                            title:
                                'ไม่สามารถโหลดข้อมูล Partner ได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองใหม่',
                            actionLabel: 'ลองใหม่',
                            onAction: _load,
                          ),
                        )
                      : _partners.isEmpty
                      ? _section(
                          _StateCard(
                            icon: Icons.search_off_rounded,
                            title: 'ไม่พบข้อมูล Partner',
                          ),
                        )
                      : cardMode
                      ? _mobileList()
                      : _tableView(),
                ),
                const SizedBox(height: 8),
                _paginationBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Future<void> _editPartner(Partner partner) async {
    final updated = await widget.openEdit(partner);
    if (updated) {
      await _load();
      if (mounted) _showMessage('แก้ไขข้อมูล Partner สำเร็จ');
    }
  }

  Widget _actions(Partner partner) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () => _manageAdmin(partner),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 40),
        ),
        child: const Text('admin'),
      ),
      IconButton(
        tooltip: 'แก้ไข',
        onPressed: () => _editPartner(partner),
        icon: Icon(
          Icons.edit_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
      IconButton(
        tooltip: 'ลบ',
        onPressed: () => _confirmDelete(partner),
        icon: const Icon(Icons.delete_outline_rounded, color: LaooColors.error),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    ],
  );

  Widget _tableView() {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final border = theme.dividerColor;
    final columns = <double>[.45, 2, 2.2, 1.2, 1.4, 1.3, 1.3];
    Widget row(List<Widget> cells, {bool heading = false}) => Container(
      height: heading ? 56 : 56,
      decoration: BoxDecoration(
        color: heading ? color.withValues(alpha: .12) : Colors.white,
        border: Border(bottom: BorderSide(color: border, width: .6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: (columns[i] * 100).round(), child: cells[i]),
        ],
      ),
    );
    Widget label(String value) => Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
    );
    Widget value(String value) => Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14),
    );
    Widget sortable(
      String title,
      int index,
      Comparable Function(Partner) selector,
    ) => InkWell(
      onTap: () => _sortBy(
        index,
        selector,
        _sortColumnIndex == index ? !_sortAscending : true,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label(title)),
          if (_sortColumnIndex == index)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: color,
            ),
        ],
      ),
    );
    return _section(
      Column(
        children: [
          row([
            label('ID'),
            label('Action'),
            sortable('ชื่อ Partner', 2, (p) => p.partnerNameTh.toLowerCase()),
            label('admin'),
            sortable(
              'ผู้ติดต่อ',
              3,
              (p) => (p.contactName1 ?? '').toLowerCase(),
            ),
            sortable(
              'เบอร์โทรศัพท์',
              4,
              (p) => (p.contactPhone1 ?? '').toLowerCase(),
            ),
            sortable('สถานะ', 5, (p) => p.isActive ? 1 : 0),
          ], heading: true),
          Expanded(
            child: ListView.builder(
              itemCount: _visiblePartners.length,
              itemBuilder: (context, index) {
                final p = _visiblePartners[index];
                return row([
                  value('${_currentPage * _pageSize + index + 1}'),
                  _actions(p),
                  value(p.partnerNameTh),
                  value(p.partnerAdminUsername ?? '-'),
                  value(p.contactName1 ?? '-'),
                  value(p.contactPhone1 ?? '-'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(active: p.isActive),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginationBar() {
    final page = _currentPage.clamp(0, _pageCount - 1);
    final first = _partners.isEmpty ? 0 : page * _pageSize + 1;
    final last = _partners.isEmpty
        ? 0
        : ((page + 1) * _pageSize).clamp(0, _partners.length);
    final primary = Theme.of(context).colorScheme.primary;
    Widget button(
      Widget child,
      VoidCallback? action, {
      bool selected = false,
    }) => SizedBox(
      width: LaooLayout.paginationButtonSize,
      height: LaooLayout.paginationButtonSize,
      child: FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: primary,
          disabledBackgroundColor: selected ? primary : Colors.grey.shade300,
          disabledForegroundColor: selected
              ? Colors.white
              : Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        child: child,
      ),
    );
    return _section(
      SizedBox(
        height: LaooLayout.paginationCardHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              button(
                const Icon(Icons.chevron_left),
                page > 0 ? () => setState(() => _currentPage = page - 1) : null,
              ),
              const SizedBox(width: 6),
              button(Text('${page + 1}'), null, selected: true),
              const SizedBox(width: 6),
              button(
                const Icon(Icons.chevron_right),
                page + 1 < _pageCount
                    ? () => setState(() => _currentPage = page + 1)
                    : null,
              ),
              const SizedBox(width: 12),
              Text('$first-$last จาก ${_partners.length}'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Partner partner) async {
    final accent = Theme.of(context).colorScheme.primary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: LaooColors.error.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: LaooColors.error.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: LaooColors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'ยืนยันการลบ Partner',
                            style: TextStyle(
                              color: LaooColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: LaooColors.error.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.45,
                          ),
                          children: [
                            const TextSpan(text: 'ต้องการลบ '),
                            TextSpan(
                              text: partner.partnerCode,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' - '),
                            TextSpan(
                              text: partner.partnerNameTh,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' หรือไม่?'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนจากหน้าจอนี้ได้',
                      style: TextStyle(
                        color: LaooColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: LaooColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'ลบ',
                            style: TextStyle(fontSize: 14),
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
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.deletePartner(partner);
      await _load();
      if (mounted) {
        _showMessage('ลบ Partner สำเร็จ');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('ไม่สามารถลบ Partner ได้: $error', error: true);
    }
  }

  Widget _mobileList() => ListView.separated(
    itemCount: _visiblePartners.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final partner = _visiblePartners[index];
      final primary = Theme.of(context).colorScheme.primary;
      return _section(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    partner.partnerNameTh,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  _StatusChip(active: partner.isActive),
                  _actions(partner),
                ],
              ),
              const SizedBox(height: 8),
              Text('Admin: ${partner.partnerAdminUsername ?? '-'}'),
              Text('ผู้ติดต่อ: ${partner.contactName1 ?? '-'}'),
              Text('โทรศัพท์: ${partner.contactPhone1 ?? '-'}'),
            ],
          ),
        ),
      );
    },
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.activeFilter,
    required this.onSearch,
    required this.onActiveChanged,
    required this.onClear,
  });
  final TextEditingController searchController;
  final bool? activeFilter;
  final VoidCallback onSearch;
  final ValueChanged<bool?> onActiveChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final primary = Theme.of(context).colorScheme.primary;
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      );
      return FilterHeightSync(
        builder: (context, searchKey, height) => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth < 330 ? constraints.maxWidth : 330,
              child: TextField(
                key: searchKey,
                controller: searchController,
                onSubmitted: (_) => onSearch(),
                decoration: const InputDecoration(
                  hintText: 'ค้นหา Partner...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: height,
              child: FilledButton.icon(
                onPressed: onSearch,
                style: FilledButton.styleFrom(
                  shape: shape,
                  minimumSize: Size(0, height),
                  maximumSize: Size(double.infinity, height),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  visualDensity: VisualDensity.standard,
                ),
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
            ),
            SizedBox(
              height: height,
              child: OutlinedButton.icon(
                onPressed: onClear,
                style: OutlinedButton.styleFrom(
                  shape: shape,
                  minimumSize: Size(0, height),
                  maximumSize: Size(double.infinity, height),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  visualDensity: VisualDensity.standard,
                  foregroundColor: primary,
                  side: BorderSide(color: primary),
                ),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('ล้าง Filter'),
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<bool?>(
                initialValue: activeFilter,
                decoration: const InputDecoration(
                  labelText: 'สถานะ',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: LaooComboBoxText('ทั้งหมด'),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: LaooComboBoxText('เปิดใช้งาน'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: LaooComboBoxText('ระงับใช้งาน'),
                  ),
                ],
                onChanged: onActiveChanged,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'เปิดใช้งาน' : 'ระงับใช้งาน',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: LaooColors.textSecondary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: LaooColors.textSecondary)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _PartnerAdminDialog extends StatefulWidget {
  const _PartnerAdminDialog({this.initialUsername, required this.editing});

  final String? initialUsername;
  final bool editing;

  @override
  State<_PartnerAdminDialog> createState() => _PartnerAdminDialogState();
}

class _PartnerAdminDialogState extends State<_PartnerAdminDialog> {
  late final TextEditingController _username;
  final _password = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.initialUsername ?? 'admin');
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: shape,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.editing
                            ? 'แก้ไข Partner Admin'
                            : 'สร้าง Partner Admin',
                        style: LaooTypography.pageCaptionStyle,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: theme.dividerColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _username,
                        style: const TextStyle(
                          fontSize: LaooTypography.inputText,
                        ),
                        decoration: _fieldDecoration('Username Admin'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          fontSize: LaooTypography.inputText,
                        ),
                        decoration: _fieldDecoration(
                          widget.editing
                              ? 'Password ใหม่ (เว้นว่างได้)'
                              : 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'แสดง Password'
                                : 'ซ่อน Password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password ใหม่ต้องมีอย่างน้อย 6 ตัวอักษร พร้อมตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก และอักขระพิเศษ',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(color: theme.dividerColor),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(84, LaooTypography.buttonHeight),
                      shape: shape,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('ยกเลิก'),
                  ),
                  FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(100, LaooTypography.buttonHeight),
                      shape: shape,
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(widget.editing ? 'บันทึก' : 'สร้าง Admin'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || (!widget.editing && password.isEmpty)) {
      setState(() => _error = 'กรุณากรอก Username และ Password');
      return;
    }
    Navigator.pop(context, (username, password));
  }

  InputDecoration _fieldDecoration(String label, {Widget? suffixIcon}) {
    final color = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: color.outline),
    );
    return InputDecoration(
      labelText: label,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: BorderSide(color: color.primary, width: 2),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
