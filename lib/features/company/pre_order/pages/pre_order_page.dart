import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/pre_order_api.dart';
import 'pre_order_action_page.dart';

class PreOrderPage extends StatelessWidget {
  const PreOrderPage({this.action = false, this.preOrderId, super.key});

  final bool action;
  final int? preOrderId;

  @override
  Widget build(BuildContext context) => action
      ? PreOrderActionPage(preOrderId: preOrderId)
      : const PreOrderListPage();
}

class PreOrderListPage extends StatefulWidget {
  const PreOrderListPage({super.key});

  @override
  State<PreOrderListPage> createState() => _PreOrderListPageState();
}

class _PreOrderListPageState extends State<PreOrderListPage> {
  static const _activeMenu = 'companyPreOrders';
  final _api = PreOrderApi();
  final _profile = UserProfileRepository();
  final _search = TextEditingController();

  List<Map<String, dynamic>> _rows = const [];
  Map<String, bool> _actions = const {};
  String _menuName = 'ใบรับจองสินค้า';
  String _status = 'ALL';
  bool _loading = true;
  bool _card = false;
  int _page = 0;

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  int get _pageCount => math.max(1, (_rows.length / _pageSize).ceil());
  List<Map<String, dynamic>> get _visibleRows {
    final safePage = _page.clamp(0, _pageCount - 1);
    return _rows.skip(safePage * _pageSize).take(_pageSize).toList();
  }

  @override
  void initState() {
    super.initState();
    _resolveMenuName();
    _loadDefaultViewMode();
    _load();
  }

  Future<void> _resolveMenuName() async {
    try {
      final value = await NavigationMenuRepository().resolveMenuName(
        routeName: _activeMenu,
        fallback: 'ใบรับจองสินค้า',
      );
      if (mounted && value.trim().isNotEmpty) {
        setState(() => _menuName = value.trim());
      }
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
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.list(search: _search.text, status: _status),
        _api.actions(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = values[0] as List<Map<String, dynamic>>;
        _actions = values[1] as Map<String, bool>;
        _page = _page.clamp(0, _pageCount - 1);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('ไม่สามารถโหลดรายการใบรับจองสินค้าได้', error);
    }
  }

  void _showError(String message, Object error) {
    showTimedSnackBar(
      context,
      message: '$message\nรายละเอียด: $error',
      error: true,
    );
  }

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final valueDate = DateTime.tryParse(raw);
    if (valueDate == null) return raw;
    return '${valueDate.day.toString().padLeft(2, '0')}/'
        '${valueDate.month.toString().padLeft(2, '0')}/'
        '${valueDate.year}';
  }

  String _money(dynamic value) {
    final amount = num.tryParse('$value') ?? 0;
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _statusName(dynamic value) {
    return switch (value?.toString().toUpperCase()) {
      'DRAFT' => 'ร่าง',
      'CONFIRMED' => 'ยืนยันแล้ว',
      'WAITING_STOCK' => 'รอสินค้า',
      'PARTIAL_STOCK' => 'สินค้าเข้าบางส่วน',
      'READY' => 'พร้อมส่ง',
      'DELIVERED' => 'ส่งมอบแล้ว',
      'CANCELLED' => 'ยกเลิก',
      'CLOSED' => 'ปิดเอกสาร',
      _ => value?.toString() ?? '-',
    };
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final accent = workspaceThemeController.value.primary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Text('ยืนยันการลบข้อมูล', style: LaooTypography.screenCaptionStyle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ต้องการลบ ${row['preOrderCode']} - ${row['customerName']} หรือไม่?',
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('ยกเลิก', style: TextStyle(color: accent)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete((row['preOrderId'] as num).toInt());
      if (!mounted) return;
      showTimedSnackBar(
        context,
        message: 'ลบใบรับจองสินค้า ${row['preOrderCode']} สำเร็จ',
      );
      await _load();
    } catch (error) {
      if (mounted) _showError('ไม่สามารถลบใบรับจองสินค้าได้', error);
    }
  }

  void _edit(Map<String, dynamic> row) {
    context.go('/company/pre-orders?action=edit&id=${row['preOrderId']}');
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  Widget _statusBadge(Map<String, dynamic> row, Color accent) {
    final cancelled = row['statusCode']?.toString() == 'CANCELLED';
    final color = cancelled ? Colors.red : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusName(row['statusCode']),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actionsCell(Map<String, dynamic> row, Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: _actions['edit'] == true ? () => _edit(row) : null,
          icon: Icon(Icons.edit_outlined, color: accent),
        ),
        IconButton(
          tooltip: 'ลบ',
          onPressed: _actions['delete'] == true ? () => _delete(row) : null,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ],
    );
  }

  Widget _table(Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              accent.withValues(alpha: .10),
            ),
            dividerThickness: .6,
            columnSpacing: 20,
            headingTextStyle: TextStyle(
              color: accent,
              fontSize: LaooTypography.tableHeader,
              fontWeight: FontWeight.w700,
            ),
            dataTextStyle: const TextStyle(
              color: LaooColors.textPrimary,
              fontSize: LaooTypography.tableBody,
            ),
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('เลขที่ใบจอง')),
              DataColumn(label: Text('วันที่เอกสาร')),
              DataColumn(label: Text('ลูกค้า')),
              DataColumn(label: Text('ใบเสนอราคา')),
              DataColumn(label: Text('รวมเงิน'), numeric: true),
              DataColumn(label: Text('คงเหลือ'), numeric: true),
              DataColumn(label: Text('สถานะ')),
            ],
            rows: [
              for (var index = 0; index < _visibleRows.length; index++)
                DataRow(
                  cells: [
                    DataCell(Text('${_page * _pageSize + index + 1}')),
                    DataCell(_actionsCell(_visibleRows[index], accent)),
                    DataCell(Text('${_visibleRows[index]['preOrderCode']}')),
                    DataCell(Text(_date(_visibleRows[index]['preOrderDate']))),
                    DataCell(
                      Text(
                        '${_visibleRows[index]['customerCode']} | ${_visibleRows[index]['customerName']}',
                      ),
                    ),
                    DataCell(Text('${_visibleRows[index]['quoteCode']}')),
                    DataCell(Text(_money(_visibleRows[index]['totalAmount']))),
                    DataCell(
                      Text(_money(_visibleRows[index]['balanceAmount'])),
                    ),
                    DataCell(_statusBadge(_visibleRows[index], accent)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardList(Color accent) {
    if (_visibleRows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('ไม่พบข้อมูลใบรับจองสินค้า')),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < _visibleRows.length; index++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: LaooShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_visibleRows[index]['preOrderCode']} | ${_visibleRows[index]['customerName']}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _statusBadge(_visibleRows[index], accent),
                    _actionsCell(_visibleRows[index], accent),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Text(
                      'วันที่ ${_date(_visibleRows[index]['preOrderDate'])}',
                    ),
                    Text('ใบเสนอราคา ${_visibleRows[index]['quoteCode']}'),
                    Text(
                      'รวมเงิน ${_money(_visibleRows[index]['totalAmount'])}',
                    ),
                    Text(
                      'คงเหลือ ${_money(_visibleRows[index]['balanceAmount'])}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (index < _visibleRows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _pagination(Color accent) {
    final start = _rows.isEmpty ? 0 : _page * _pageSize + 1;
    final end = math.min((_page + 1) * _pageSize, _rows.length);
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Row(
        children: [
          InkWell(
            onTap: _page > 0 ? () => setState(() => _page--) : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_page + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: _page + 1 < _pageCount
                ? () => setState(() => _page++)
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Text('$start-$end จาก ${_rows.length}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu: _activeMenu,
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  final cardMode = compact || _card;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _surface(
                        child: Row(
                          children: [
                            Expanded(
                              child: WorkspacePageTitle(
                                title: _menuName,
                                favoriteKey: _activeMenu,
                                titleColor: Colors.black,
                              ),
                            ),
                            if (!compact) ...[
                              IconButton(
                                tooltip: cardMode
                                    ? 'แสดงแบบรายการ'
                                    : 'แสดงแบบการ์ด',
                                style: IconButton.styleFrom(
                                  foregroundColor: accent,
                                  backgroundColor: accent.withValues(
                                    alpha: .10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: () => setState(() => _card = !_card),
                                icon: Icon(
                                  cardMode
                                      ? Icons.view_list_outlined
                                      : Icons.grid_view_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: _actions['create'] == true
                                  ? () => context.go(
                                      '/company/pre-orders?action=new',
                                    )
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มเอกสาร'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _surface(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: compact ? constraints.maxWidth : 360,
                              child: TextField(
                                controller: _search,
                                onSubmitted: (_) => _load(),
                                style: const TextStyle(
                                  fontSize: LaooTypography.inputText,
                                ),
                                decoration: const InputDecoration(
                                  labelText:
                                      'ค้นหาเลขที่ใบจอง/ลูกค้า/ใบเสนอราคา',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: compact
                                  ? constraints.maxWidth
                                  : math.min(250, constraints.maxWidth),
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_status),
                                initialValue: _status,
                                style: const TextStyle(
                                  color: LaooColors.textPrimary,
                                  fontSize: LaooTypography.comboBox,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'สถานะ',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'ALL',
                                    child: Text('ทั้งหมด'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DRAFT',
                                    child: Text('ร่าง'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'CONFIRMED',
                                    child: Text('ยืนยันแล้ว'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'WAITING_STOCK',
                                    child: Text('รอสินค้า'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PARTIAL_STOCK',
                                    child: Text('สินค้าเข้าบางส่วน'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'READY',
                                    child: Text('พร้อมส่ง'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DELIVERED',
                                    child: Text('ส่งมอบแล้ว'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'CANCELLED',
                                    child: Text('ยกเลิก'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'CLOSED',
                                    child: Text('ปิดเอกสาร'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _status = value ?? 'ALL');
                                  _load();
                                },
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: _load,
                              icon: const Icon(Icons.search),
                              label: const Text('ค้นหา'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accent,
                                side: BorderSide(color: accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: () {
                                _search.clear();
                                setState(() {
                                  _status = 'ALL';
                                  _page = 0;
                                });
                                _load();
                              },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('ล้าง Filter'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _surface(
                        padding: cardMode
                            ? const EdgeInsets.all(8)
                            : EdgeInsets.zero,
                        child: cardMode ? _cardList(accent) : _table(accent),
                      ),
                      const SizedBox(height: 8),
                      _surface(
                        padding: EdgeInsets.zero,
                        child: _pagination(accent),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
