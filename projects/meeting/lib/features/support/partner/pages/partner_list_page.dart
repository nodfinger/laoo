import 'package:flutter/material.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
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
  int? _sortColumnIndex = 1;
  bool _sortAscending = true;
  String? _message;
  bool _messageIsError = false;
  int _currentPage = 0;

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
    setState(() {
      _message = message;
      _messageIsError = error;
    });
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
      color: LaooColors.background,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceSectionCard(
              child: Row(
                children: [
                  const Expanded(
                    child: WorkspacePageTitle(
                      title: 'Partner',
                      favoriteKey: 'Partner',
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      await widget.openCreate();
                      await _load();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('เพิ่ม'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LaooColors.border),
            if (_message != null) ...[
              AutoDismissMessage(
                message: _message!,
                error: _messageIsError,
                onClose: () => setState(() => _message = null),
              ),
              const SizedBox(height: 12),
            ],
            WorkspaceSectionCard(
              child: _Toolbar(
                searchController: _searchController,
                activeFilter: _activeFilter,
                accent: accent,
                onSearch: _load,
                onActiveChanged: (value) {
                  setState(() => _activeFilter = value);
                  _load();
                },
                onClear: _clearFilters,
                onRefresh: _load,
              ),
            ),
            const Divider(height: 1, color: LaooColors.border),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _StateCard(
        icon: Icons.error_outline,
        title: 'ไม่สามารถโหลดข้อมูล Partner ได้',
        actionLabel: 'ลองใหม่',
        onAction: _load,
      );
    }

    if (_partners.isEmpty) {
      return _StateCard(
        icon: Icons.search_off_rounded,
        title: _searchController.text.trim().isEmpty && _activeFilter == null
            ? 'ยังไม่มีข้อมูล Partner'
            : 'ไม่พบข้อมูลตามเงื่อนไขที่ค้นหา',
      );
    }

    if (MediaQuery.sizeOf(context).width < 900) {
      return Column(
        children: [
          Expanded(child: _mobileList()),
          const Divider(height: 1, color: LaooColors.border),
          WorkspaceSectionCard(child: _paginationBar()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: double.infinity, child: _tableView()),
          ),
        ),
        const Divider(height: 1, color: LaooColors.border),
        WorkspaceSectionCard(child: _paginationBar()),
      ],
    );
  }

  Widget _tableView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 920.0;
        const horizontalMargin = 6.0;
        const columnSpacing = 6.0;

        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth < minTableWidth
            ? minTableWidth
            : availableWidth;

        // Fixed columns are intentionally compact so the last Status column
        // always stays inside the visible table area.
        const actionWidth = 124.0;
        const codeWidth = 112.0;
        const adminWidth = 118.0;
        const statusWidth = 82.0;

        // DataTable also consumes width for margins, inter-column spacing,
        // sortable-column arrow/padding and small internal layout overhead.
        const sortAndInternalReserve = 86.0;
        final tableOverhead =
            (horizontalMargin * 2) +
            (columnSpacing * 5) +
            sortAndInternalReserve;

        final flexibleWidth =
            (tableWidth -
                    actionWidth -
                    codeWidth -
                    adminWidth -
                    statusWidth -
                    tableOverhead)
                .clamp(360.0, double.infinity);

        final nameWidth = flexibleWidth * 0.45;
        final contactWidth = flexibleWidth * 0.31;
        final phoneWidth = flexibleWidth * 0.24;

        Widget cellText(String text, double width) {
          return SizedBox(
            width: width,
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }

        Widget headerText(String text, double width) {
          return SizedBox(
            width: width,
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }

        return SizedBox(
          height: constraints.maxHeight,
          child: Align(
            alignment: Alignment.topLeft,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: SingleChildScrollView(
                    child: DataTable(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: LaooColors.border.withValues(alpha: .45),
                          width: .25,
                        ),
                      ),
                      horizontalMargin: horizontalMargin,
                      columnSpacing: columnSpacing,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      headingTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 60,
                      columns: [
                        const DataColumn(
                          label: SizedBox(
                            width: actionWidth,
                            child: Center(child: Text('Action')),
                          ),
                        ),
                        DataColumn(
                          label: headerText('รหัส Partner', codeWidth),
                          onSort: (index, ascending) => _sortBy(
                            index,
                            (p) => p.partnerCode.toLowerCase(),
                            ascending,
                          ),
                        ),
                        DataColumn(
                          label: headerText('ชื่อ Partner', nameWidth),
                          onSort: (index, ascending) => _sortBy(
                            index,
                            (p) => p.partnerNameTh.toLowerCase(),
                            ascending,
                          ),
                        ),
                        const DataColumn(
                          label: SizedBox(
                            width: adminWidth,
                            child: Text('admin'),
                          ),
                        ),
                        DataColumn(
                          label: headerText('ผู้ติดต่อ', contactWidth),
                          onSort: (index, ascending) => _sortBy(
                            index,
                            (p) => (p.contactName1 ?? '').toLowerCase(),
                            ascending,
                          ),
                        ),
                        DataColumn(
                          label: headerText('เบอร์โทรศัพท์', phoneWidth),
                          onSort: (index, ascending) => _sortBy(
                            index,
                            (p) => (p.contactPhone1 ?? '').toLowerCase(),
                            ascending,
                          ),
                        ),
                        DataColumn(
                          label: headerText('สถานะ', statusWidth),
                          onSort: (index, ascending) => _sortBy(
                            index,
                            (p) => p.isActive ? 1 : 0,
                            ascending,
                          ),
                        ),
                      ],
                      rows: _visiblePartners.map((partner) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: actionWidth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(38, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => _manageAdmin(partner),
                                      child: const Text('admin'),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'แก้ไข',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () async {
                                        final updated = await widget.openEdit(
                                          partner,
                                        );
                                        if (updated) {
                                          await _load();
                                          if (mounted) {
                                            _showMessage(
                                              'แก้ไขข้อมูล Partner สำเร็จ',
                                            );
                                          }
                                        }
                                      },
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'ลบ',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () => _confirmDelete(partner),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: LaooColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(cellText(partner.partnerCode, codeWidth)),
                            DataCell(
                              cellText(partner.partnerNameTh, nameWidth),
                            ),
                            DataCell(
                              cellText(
                                partner.partnerAdminUsername ?? '-',
                                adminWidth,
                              ),
                            ),
                            DataCell(
                              cellText(
                                partner.contactName1 ?? '-',
                                contactWidth,
                              ),
                            ),
                            DataCell(
                              cellText(
                                partner.contactPhone1 ?? '-',
                                phoneWidth,
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: statusWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: _StatusChip(
                                      active: partner.isActive,
                                    ),
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
        );
      },
    );
  }

  Widget _paginationBar() {
    final pageCount = _pageCount;
    final page = _currentPage.clamp(0, pageCount - 1);
    final firstRow = _partners.isEmpty ? 0 : (page * _pageSize) + 1;
    final lastRow = _partners.isEmpty
        ? 0
        : ((page + 1) * _pageSize).clamp(0, _partners.length);

    final accent = Theme.of(context).colorScheme.primary;

    final pageIndexes = <int>[];
    if (pageCount <= 7) {
      for (var i = 0; i < pageCount; i++) {
        pageIndexes.add(i);
      }
    } else {
      final start = (page - 2).clamp(0, pageCount - 5);
      final end = (start + 5).clamp(0, pageCount);
      for (var i = start; i < end; i++) {
        pageIndexes.add(i);
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: page > 0
              ? () => setState(() => _currentPage = page - 1)
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            side: BorderSide(color: LaooColors.border),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          child: const Icon(Icons.chevron_left),
        ),
        if (pageCount > 7 && pageIndexes.first > 0) ...[
          _pageNumberButton(0, page, accent),
          if (pageIndexes.first > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text('...'),
            ),
        ],
        for (final index in pageIndexes) _pageNumberButton(index, page, accent),
        if (pageCount > 7 && pageIndexes.last < pageCount - 1) ...[
          if (pageIndexes.last < pageCount - 2)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text('...'),
            ),
          _pageNumberButton(pageCount - 1, page, accent),
        ],
        OutlinedButton(
          onPressed: page + 1 < pageCount
              ? () => setState(() => _currentPage = page + 1)
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            side: BorderSide(color: LaooColors.border),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          child: const Icon(Icons.chevron_right),
        ),
        Text(
          '$firstRow-$lastRow จาก ${_partners.length}',
          style: const TextStyle(color: LaooColors.textSecondary),
        ),
      ],
    );
  }

  Widget _pageNumberButton(int index, int currentPage, Color accent) {
    final selected = index == currentPage;

    return SizedBox(
      width: 36,
      height: 34,
      child: selected
          ? FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: accent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
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
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              child: Text('${index + 1}'),
            ),
    );
  }

  Future<void> _confirmDelete(Partner partner) async {
    final accent = Theme.of(context).colorScheme.primary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(LaooLayout.cardPadding),
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
                            style: LaooTypography.popupTitleStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: LaooColors.error.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurface,
                            fontSize: LaooTypography.body,
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
                        fontSize: LaooTypography.body,
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
                            style: TextStyle(fontSize: LaooTypography.button),
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
                            style: TextStyle(fontSize: LaooTypography.button),
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

  Widget _mobileList() {
    return ListView.separated(
      itemCount: _visiblePartners.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final partner = _visiblePartners[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'แก้ไข',
                      onPressed: () async {
                        final updated = await widget.openEdit(partner);
                        if (updated) {
                          await _load();
                          if (mounted) {
                            _showMessage('แก้ไขข้อมูล Partner สำเร็จ');
                          }
                        }
                      },
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'ลบ',
                      onPressed: () => _confirmDelete(partner),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: LaooColors.error,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _manageAdmin(partner),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('admin'),
                    ),
                    const Spacer(),
                    _StatusChip(active: partner.isActive),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${partner.partnerCode} - ${partner.partnerNameTh}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Admin: ${partner.partnerAdminUsername ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        partner.contactPhone1 ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
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
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.activeFilter,
    required this.accent,
    required this.onSearch,
    required this.onActiveChanged,
    required this.onClear,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final bool? activeFilter;
  final Color accent;
  final VoidCallback onSearch;
  final ValueChanged<bool?> onActiveChanged;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? constraints.maxWidth : 260,
              child: TextField(
                controller: searchController,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  hintText: 'ค้นหา Partner...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'ค้นหา',
                    onPressed: onSearch,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onSearch,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('ค้นหา'),
            ),
            SizedBox(
              width: compact ? constraints.maxWidth : 180,
              child: DropdownButtonFormField<bool?>(
                isExpanded: true,
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
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('ล้าง Filter'),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, color: accent),
            ),
          ],
        );
      },
    );
  }
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
          fontSize: LaooTypography.tableBody,
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
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              color: theme.colorScheme.primaryContainer,
              child: Text(
                widget.editing ? 'แก้ไข Partner Admin' : 'สร้าง Partner Admin',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                children: [
                  TextField(
                    controller: _username,
                    decoration: _fieldDecoration('Username Admin'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: _fieldDecoration(
                      widget.editing
                          ? 'Password ใหม่ (เว้นว่างได้)'
                          : 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'แสดง Password'
                            : 'ซ่อน Password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
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
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_error!, style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(widget.editing ? 'บันทึก' : 'สร้าง Admin'),
                  ),
                ],
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color.outline),
    );
    return InputDecoration(
      labelText: label,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color.primary, width: 2),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
