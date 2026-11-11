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
import 'personal_approval_dialog.dart';

class ApprovalAssignmentPage extends StatefulWidget {
  const ApprovalAssignmentPage({super.key});
  @override
  State<ApprovalAssignmentPage> createState() => _ApprovalAssignmentPageState();
}

class _ApprovalAssignmentPageState extends State<ApprovalAssignmentPage> {
  final api = ApiClient();
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [], patterns = [];
  String query = '', project = '', title = 'กำหนดการอนุมัติ';
  bool loading = true, canManage = false, cards = false;
  String? error;
  int page = 0;
  static const pageSize = 10;

  @override
  void initState() {
    super.initState();
    load();
    loadTitle();
  }

  Future<void> loadTitle() async {
    final menu = await NavigationMenuRepository().findMenu(menuCode: '68002');
    if (mounted && menu != null) setState(() => title = menu.name);
  }

  @override
  void dispose() {
    search.dispose();
    api.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await api.get('/api/company/approval-assignment');
      if (data is! Map || data['rows'] is! List || data['patterns'] is! List) {
        throw StateError('Invalid response');
      }
      if (!mounted) return;
      setState(() {
        rows = (data['rows'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        patterns = (data['patterns'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        canManage = data['canManage'] == true;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'โหลดรายการไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> configure(Map<String, dynamic> row) async {
    if (patterns.isEmpty) {
      showTimedSnackBar(
        context,
        message: 'ยังไม่มีรูปแบบอนุมัติ กรุณากำหนดรูปแบบก่อน',
        error: true,
      );
      return;
    }
    String? selected = patterns.any((p) => p['code'] == row['patternCode'])
        ? row['patternCode'] as String?
        : null;
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                color: businessCardOcrUi(context).primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('กำหนดการอนุมัติ > ${row['name']}')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(thickness: .6),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: LaooTypography.comboBox,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: ocrInput(context, 'รูปแบบการอนุมัติ'),
                  items: patterns
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['code'] as String,
                          child: Text(
                            '${p['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => update(() => selected = value),
                ),
                const SizedBox(height: 12),
                const Divider(thickness: .6),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (selected == null) {
                        showTimedSnackBar(
                          context,
                          message: 'กรุณาเลือกรูปแบบการอนุมัติ',
                          error: true,
                        );
                        return;
                      }
                      update(() => saving = true);
                      try {
                        await api.put(
                          '/api/company/approval-assignment/${Uri.encodeComponent(row['code'] as String)}',
                          body: {'patternCode': selected},
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          update(() => saving = false);
                          showTimedSnackBar(
                            context,
                            message:
                                'บันทึกไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
                            error: true,
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      showTimedSnackBar(context, message: 'บันทึกการกำหนดอนุมัติเรียบร้อยแล้ว');
      await load();
    }
  }

  Future<void> configurePersonal(Map<String, dynamic> row) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PersonalApprovalDialog(
        api: api,
        menuCode: row['code'] as String,
        menuName: row['name'] as String,
      ),
    );
    if (mounted && result == true) {
      showTimedSnackBar(
        context,
        message: 'บันทึกการอนุมัติเฉพาะบุคคลเรียบร้อยแล้ว',
      );
      await load();
    }
  }

  Widget personalAction(Map<String, dynamic> row, {bool card = false}) {
    final primary = businessCardOcrUi(context).primaryColor;
    final count = (row['personalCount'] as num?)?.toInt() ?? 0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          onPressed: canManage ? () => configurePersonal(row) : null,
          child: Text(card ? 'เฉพาะบุคคล' : 'กำหนด'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count คน',
            style: TextStyle(color: primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _tableText(String value) => Tooltip(
    message: value,
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  String _formatUpdatedAt(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final systems = rows.map((r) => '${r['project']}').toSet().toList()..sort();
    final filtered = rows
        .where(
          (r) =>
              (project.isEmpty || r['project'] == project) &&
              '${r['project']} ${r['name']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final pages = ((filtered.length + pageSize - 1) ~/ pageSize).clamp(
      1,
      999999,
    );
    final current = page.clamp(0, pages - 1);
    final visible = filtered.skip(current * pageSize).take(pageSize).toList();
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, _, _) => SupportWorkspaceShell(
        pageTitle: title,
        activeMenu: '68002',
        menuScope: WorkspaceMenuScope.company,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Minimum widths include the column padding and both action controls.
            const columnWidths = <double>[90, 160, 100, 130, 130, 145, 180];
            final tableWidth =
                constraints.maxWidth -
                2 * LaooLayout.cardMargin -
                2 * LaooLayout.cardPadding;
            final textScale = MediaQuery.textScalerOf(
              context,
            ).scale(1).clamp(1.0, double.infinity);
            final minimumTableWidth =
                columnWidths.reduce((a, b) => a + b) * textScale;
            final forceCards =
                tableWidth < 600 || tableWidth < minimumTableWidth;
            final showCards = forceCards || cards;
            final tokens = businessCardOcrUi(context);
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
                            title: title,
                            favoriteKey: '68002',
                          ),
                        ),
                        if (!forceCards)
                          LaooListCardToggle(
                            tokens: tokens,
                            cards: cards,
                            onChanged: (v) => setState(() => cards = v),
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
                            width:
                                (constraints.maxWidth -
                                        2 * LaooLayout.cardMargin -
                                        2 * LaooLayout.cardPadding)
                                    .clamp(0.0, 340.0),
                            child: TextField(
                              key: key,
                              controller: search,
                              decoration: ocrInput(
                                context,
                                'ค้นหาชื่อระบบหรือเมนู',
                                icon: Icons.search,
                              ),
                              onSubmitted: (_) => setState(() {
                                query = search.text.trim();
                                page = 0;
                              }),
                            ),
                          ),
                          FilledButton.icon(
                            style: filterActionHeightStyle(height),
                            onPressed: () => setState(() {
                              query = search.text.trim();
                              page = 0;
                            }),
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton.icon(
                            style: filterActionHeightStyle(height),
                            onPressed: () => setState(() {
                              search.clear();
                              query = '';
                              project = '';
                              page = 0;
                            }),
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('ล้าง Filter'),
                          ),
                          SizedBox(
                            width:
                                (constraints.maxWidth -
                                        2 * LaooLayout.cardMargin -
                                        2 * LaooLayout.cardPadding)
                                    .clamp(0.0, 240.0),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(project),
                              initialValue: project,
                              isExpanded: true,
                              style: TextStyle(
                                fontSize: LaooTypography.comboBox,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: ocrInput(context, 'ระบบ'),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('ทั้งหมด'),
                                ),
                                for (final name in systems)
                                  DropdownMenuItem(
                                    value: name,
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                project = v ?? '';
                                page = 0;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                          ? Center(child: Text(error!))
                          : visible.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : Padding(
                              padding: const EdgeInsets.all(
                                LaooLayout.cardPadding,
                              ),
                              child: showCards
                                  ? ListView.separated(
                                      itemCount: visible.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final row = visible[index];
                                        return Card(
                                          margin: EdgeInsets.zero,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${row['name']}',
                                                        style: TextStyle(
                                                          color: tokens
                                                              .primaryColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: canManage
                                                          ? () => configure(row)
                                                          : null,
                                                      child: const Text(
                                                        'กำหนด',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                personalAction(row, card: true),
                                                const SizedBox(height: 6),
                                                Text('ระบบ: ${row['project']}'),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'เงื่อนไข: ${row['patternName'] ?? 'ยังไม่กำหนด'}',
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'ผู้กำหนดค่าล่าสุด: ${row['updatedByName'] ?? '-'}',
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'วันที่-เวลากำหนดล่าสุด: ${_formatUpdatedAt(row['updatedAt'])}',
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
                                          tokens.primaryColor.withValues(
                                            alpha: .12,
                                          ),
                                        ),
                                        headingTextStyle: TextStyle(
                                          color: tokens.primaryColor,
                                          fontSize: LaooTypography.tableHeader,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        dividerThickness: .6,
                                        columns: [
                                          for (final (index, label) in <String>[
                                            'กำหนดค่า',
                                            'เฉพาะบุคคล',
                                            'ระบบ',
                                            'เมนู',
                                            'เงื่อนไข',
                                            'ผู้กำหนดค่าล่าสุด',
                                            'วันที่-เวลากำหนดล่าสุด',
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
                                                      onPressed: canManage
                                                          ? () => configure(row)
                                                          : null,
                                                      child: const Text(
                                                        'กำหนด',
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(personalAction(row)),
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
                                                      '${row['patternName'] ?? 'ยังไม่กำหนด'}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      '${row['updatedByName'] ?? '-'}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _tableText(
                                                      _formatUpdatedAt(
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
                    tokens: tokens,
                    borderless: true,
                    page: current + 1,
                    pageCount: pages,
                    pageSize: pageSize,
                    total: filtered.length,
                    onPrevious: current > 0
                        ? () => setState(() => page = current - 1)
                        : null,
                    onNext: current + 1 < pages
                        ? () => setState(() => page = current + 1)
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
