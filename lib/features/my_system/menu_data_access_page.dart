import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../app/theme/laoo_design_tokens.dart';
import '../../app/theme/laoo_typography.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class MenuDataAccessPage extends StatefulWidget {
  const MenuDataAccessPage({super.key});
  @override
  State<MenuDataAccessPage> createState() => _MenuDataAccessPageState();
}

class _MenuDataAccessPageState extends State<MenuDataAccessPage> {
  final _api = ApiClient();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  String _query = '', _title = 'การเข้าถึงข้อมูล';
  bool _loading = true, _canManage = false, _card = false;
  String? _error;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTitle();
  }

  Future<void> _loadTitle() async {
    final menu = await NavigationMenuRepository().findMenu(menuCode: '10010');
    if (mounted && menu != null) setState(() => _title = menu.name);
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/api/company/menu-data-access');
      if (data is! Map || data['rows'] is! List) {
        throw StateError('Invalid response');
      }
      if (!mounted) return;
      setState(() {
        _rows = (data['rows'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _canManage = data['canManage'] == true;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'ไม่สามารถโหลดข้อมูลได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _configure(Map<String, dynamic> row) async {
    final effective = row['effective'];
    if (effective is! Map) return;
    final values = Map<String, dynamic>.from(effective);
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final primary = Theme.of(dialogContext).colorScheme.primary;
          Widget part(String title, String prefix) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(dialogContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('$prefix-${values['${prefix}Scope']}'),
                initialValue: values['${prefix}Scope'] as String?,
                decoration: ocrInput(dialogContext, 'ขอบเขตข้อมูล'),
                items: const [
                  DropdownMenuItem(
                    value: 'SELF',
                    child: Text('เฉพาะของตัวเอง'),
                  ),
                  DropdownMenuItem(
                    value: 'DEPARTMENT',
                    child: Text('ภายในแผนก'),
                  ),
                  DropdownMenuItem(value: 'DIVISION', child: Text('ภายในฝ่าย')),
                  DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
                ],
                onChanged: saving
                    ? null
                    : (value) => update(() {
                        values['${prefix}Scope'] = value;
                        if (value == 'SELF') {
                          values['${prefix}Staff'] = false;
                          values['${prefix}Head'] = false;
                          values['${prefix}Manager'] = false;
                        } else if (value == 'DEPARTMENT') {
                          values['${prefix}Manager'] = false;
                        }
                      }),
              ),
              Wrap(
                spacing: 8,
                children: [
                  Tooltip(
                    message: values['${prefix}Scope'] == 'DIVISION'
                        ? 'ฝ่ายเดียวกันของเจ้าของข้อมูล'
                        : values['${prefix}Scope'] == 'ALL'
                        ? 'ทุกคนตามสิทธิ์เมนู'
                        : 'แผนกเดียวกันของเจ้าของข้อมูล',
                    child: _accessCheckbox(
                      prefix == 'edit'
                          ? 'เจ้าหน้าที่ภายในสังกัดทุกคนแก้ไขได้'
                          : prefix == 'delete'
                          ? 'เจ้าหน้าที่ภายในสังกัดทุกคนลบได้'
                          : 'เจ้าหน้าที่ภายในสังกัดทุกคนเข้าถึงได้',
                      values['${prefix}Scope'] != 'SELF',
                      null,
                    ),
                  ),
                  _accessCheckbox(
                    prefix == 'edit'
                        ? 'หัวหน้าแก้ไขได้'
                        : prefix == 'delete'
                        ? 'หัวหน้าลบได้'
                        : 'หัวหน้าเข้าถึงได้',
                    values['${prefix}Scope'] != 'SELF' &&
                        (values['${prefix}Scope'] == 'ALL' ||
                            values['${prefix}Head'] == true),
                    saving ||
                            values['${prefix}Scope'] == 'SELF' ||
                            values['${prefix}Scope'] == 'ALL'
                        ? null
                        : (value) =>
                              update(() => values['${prefix}Head'] = value),
                  ),
                  _accessCheckbox(
                    prefix == 'edit'
                        ? 'ผู้จัดการแก้ไขได้'
                        : prefix == 'delete'
                        ? 'ผู้จัดการลบได้'
                        : 'ผู้จัดการเข้าถึงได้',
                    values['${prefix}Scope'] != 'SELF' &&
                        values['${prefix}Scope'] != 'DEPARTMENT' &&
                        (values['${prefix}Scope'] == 'ALL' ||
                            values['${prefix}Manager'] == true),
                    saving ||
                            values['${prefix}Scope'] == 'SELF' ||
                            values['${prefix}Scope'] == 'DEPARTMENT' ||
                            values['${prefix}Scope'] == 'ALL'
                        ? null
                        : (value) =>
                              update(() => values['${prefix}Manager'] = value),
                  ),
                ],
              ),
              const Divider(thickness: .6),
            ],
          );
          Future<void> save(bool reset) async {
            if (reset) {
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(
                        Icons.restore,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('ยืนยันคืนค่าส่วนกลาง')),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(thickness: .6),
                      const SizedBox(height: 12),
                      Text('คืนค่านโยบายของ ${row['name']} ตามค่ากลางหรือไม่'),
                      const SizedBox(height: 12),
                      const Divider(thickness: .6),
                    ],
                  ),
                  actions: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ยืนยัน'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !dialogContext.mounted) return;
            }
            update(() => saving = true);
            var resetCompleted = false;
            try {
              final path = '/api/company/menu-data-access/${row['code']}';
              if (reset) {
                await _api.delete(path);
                resetCompleted = true;
                final data = await _api.get('/api/company/menu-data-access');
                if (data is! Map || data['rows'] is! List) {
                  throw StateError('Invalid response');
                }
                final refreshed = (data['rows'] as List)
                    .whereType<Map>()
                    .where((item) => item['code'] == row['code'])
                    .firstOrNull;
                if (refreshed == null || refreshed['effective'] is! Map) {
                  throw StateError('Default policy unavailable');
                }
                if (!dialogContext.mounted) return;
                update(() {
                  values
                    ..clear()
                    ..addAll(
                      Map<String, dynamic>.from(refreshed['effective'] as Map),
                    );
                  saving = false;
                });
                if (mounted) {
                  showTimedSnackBar(context, message: 'คืนค่าส่วนกลางแล้ว');
                  await _load();
                }
                return;
              } else {
                await _api.put(path, body: values);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              showTimedSnackBar(
                context,
                message: reset
                    ? 'คืนค่าส่วนกลางแล้ว'
                    : 'บันทึกการเข้าถึงข้อมูลแล้ว',
              );
              await _load();
            } catch (_) {
              if (dialogContext.mounted) update(() => saving = false);
              if (mounted) {
                showTimedSnackBar(
                  context,
                  message: resetCompleted
                      ? 'คืนค่าแล้ว แต่โหลดค่าล่าสุดไม่สำเร็จ กรุณาปิดและเปิดหน้าจอใหม่'
                      : 'ทำรายการไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
                  error: true,
                );
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Row(
              children: [
                Icon(Icons.security, color: primary),
                const SizedBox(width: 10),
                Expanded(child: Text('กำหนดการเข้าถึง > ${row['name']}')),
              ],
            ),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(thickness: .6),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'หมายเหตุ\n'
                        'เฉพาะของตัวเอง : ผู้ใช้อื่นจะเข้าถึงข้อมูลของผู้บันทึกไม่ได้\n'
                        'ภายในแผนก : ผู้ใช้ทุกคนที่สังกัดแผนกเดียวกับผู้บันทึก สามารถเข้าถึงข้อมูลได้\n'
                        'ภายในฝ่าย : ผู้ใช้ทุกคนที่สังกัดฝ่ายเดียวกับผู้บันทึก สามารถเข้าถึงข้อมูลได้\n'
                        'ทั้งนี้ขึ้นอยู่กับสิทธิ์เมนูและตัวเลือกเจ้าหน้าที่ หัวหน้า และผู้จัดการด้านล่าง',
                      ),
                    ),
                    const SizedBox(height: 16),
                    part('การแสดงข้อมูล', 'view'),
                    part('การแก้ไขข้อมูล', 'edit'),
                    part('การลบข้อมูล', 'delete'),
                  ],
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: 760,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(thickness: .6),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                          ),
                          onPressed: saving ? null : () => save(true),
                          child: const Text('คืนค่าส่วนกลาง'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                          ),
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('ยกเลิก'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: saving ? null : () => save(false),
                          child: const Text('บันทึก'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _accessCheckbox(
    String label,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged == null ? null : (v) => onChanged(v == true),
          ),
          Text(label),
        ],
      ),
    );
  }

  String _updatedAt(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _tableText(String value) => Tooltip(
    message: value,
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _rows
        .where(
          (r) => '${r['project']} ${r['group']} ${r['name']}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    final pages = ((filtered.length + _pageSize - 1) ~/ _pageSize).clamp(
      1,
      999999,
    );
    final current = _page.clamp(0, pages - 1);
    final visible = filtered.skip(current * _pageSize).take(_pageSize).toList();
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, _, _) => SupportWorkspaceShell(
        pageTitle: _title,
        activeMenu: '10010',
        menuScope: WorkspaceMenuScope.company,
        child: LayoutBuilder(
          builder: (context, available) {
            const columnWidths = <double>[90, 110, 150, 145, 160, 180];
            final tableWidth =
                available.maxWidth -
                2 * LaooLayout.cardMargin -
                2 * LaooLayout.cardPadding;
            final textScale = MediaQuery.textScalerOf(
              context,
            ).scale(1).clamp(1.0, double.infinity);
            final minimumTableWidth =
                columnWidths.reduce((a, b) => a + b) * textScale;
            final forcedCard =
                tableWidth < 600 || tableWidth < minimumTableWidth;
            final showCards = forcedCard || _card;
            return Padding(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceSectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: WorkspacePageTitle(
                            title: _title,
                            favoriteKey: '10010',
                          ),
                        ),
                        if (!forcedCard)
                          LaooListCardToggle(
                            tokens: businessCardOcrUi(context),
                            cards: _card,
                            onChanged: (value) => setState(() => _card = value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  WorkspaceSectionCard(
                    child: FilterHeightSync(
                      builder: (context, key, height) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 340,
                            child: TextField(
                              key: key,
                              controller: _search,
                              decoration: ocrInput(
                                context,
                                'ค้นหาชื่อระบบหรือเมนู',
                                icon: Icons.search,
                              ),
                              onSubmitted: (_) => setState(() {
                                _query = _search.text.trim();
                                _page = 0;
                              }),
                            ),
                          ),
                          FilledButton.icon(
                            style: filterActionHeightStyle(height),
                            onPressed: () => setState(() {
                              _query = _search.text.trim();
                              _page = 0;
                            }),
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton.icon(
                            style: filterActionHeightStyle(height),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                              _page = 0;
                            }),
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('ล้าง Filter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(child: Text(_error!))
                          : Padding(
                              padding: const EdgeInsets.all(10),
                              child: showCards
                                  ? ListView.separated(
                                      itemCount: visible.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final row = visible[index];
                                        return Card(
                                          margin: EdgeInsets.zero,
                                          elevation: 0,
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              14,
                                              10,
                                              8,
                                              10,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${row['name']}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              color:
                                                                  businessCardOcrUi(
                                                                    context,
                                                                  ).primaryColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: _canManage
                                                          ? () =>
                                                                _configure(row)
                                                          : null,
                                                      child: const Text(
                                                        'กำหนด',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text('ระบบ: ${row['project']}'),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'นโยบาย: ${row['hasOverride'] == true ? 'กำหนดเฉพาะเมนู' : 'ส่วนกลาง'}',
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'พนักงานแก้ไขล่าสุด: ${row['updatedByName'] ?? '-'}',
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'วันที่-เวลาแก้ไขล่าสุด: ${_updatedAt(row['updatedAt'])}',
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : SingleChildScrollView(
                                      child: DataTable(
                                        horizontalMargin: 8,
                                        columnSpacing: 20,
                                        headingRowColor: WidgetStatePropertyAll(
                                          businessCardOcrUi(
                                            context,
                                          ).primaryColor.withValues(alpha: .12),
                                        ),
                                        headingTextStyle: TextStyle(
                                          color: businessCardOcrUi(
                                            context,
                                          ).primaryColor,
                                          fontSize: LaooTypography.tableHeader,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        dividerThickness: .6,
                                        columns: [
                                          for (final (index, label) in <String>[
                                            'กำหนดค่า',
                                            'ระบบ',
                                            'เมนู',
                                            'นโยบาย',
                                            'พนักงานแก้ไขล่าสุด',
                                            'วันที่-เวลาแก้ไขล่าสุด',
                                          ].indexed)
                                            DataColumn(
                                              columnWidth: FlexColumnWidth(
                                                columnWidths[index],
                                              ),
                                              label: Expanded(
                                                child: Text(
                                                  label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                        ],
                                        rows: visible
                                            .map(
                                              (row) => DataRow(
                                                cells: [
                                                  DataCell(
                                                    TextButton(
                                                      onPressed: _canManage
                                                          ? () =>
                                                                _configure(row)
                                                          : null,
                                                      child: const Text(
                                                        'กำหนด',
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      '${row['project']}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      '${row['name']}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      row['hasOverride'] == true
                                                          ? 'กำหนดเฉพาะเมนู'
                                                          : 'ส่วนกลาง',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      '${row['updatedByName'] ?? '-'}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      _updatedAt(
                                                        row['updatedAt'],
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
                  const SizedBox(height: LaooLayout.cardSpacing),
                  LaooPaginationCard(
                    tokens: businessCardOcrUi(context),
                    borderless: true,
                    page: current + 1,
                    pageCount: pages,
                    pageSize: _pageSize,
                    total: filtered.length,
                    onPrevious: current > 0
                        ? () => setState(() => _page = current - 1)
                        : null,
                    onNext: current + 1 < pages
                        ? () => setState(() => _page = current + 1)
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
