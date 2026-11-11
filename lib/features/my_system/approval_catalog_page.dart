import 'dart:math';

import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../app/theme/laoo_design_tokens.dart';
import '../../app/theme/laoo_typography.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class ApprovalCatalogPage extends StatefulWidget {
  const ApprovalCatalogPage({super.key});
  @override
  State<ApprovalCatalogPage> createState() => _ApprovalCatalogPageState();
}

class _ApprovalCatalogPageState extends State<ApprovalCatalogPage> {
  final api = ApiClient();
  final search = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool loading = true,
      canCreate = false,
      canEdit = false,
      canDelete = false,
      card = false;
  String query = '';
  int page = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    api.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await api.get('/api/company/approval-catalog') as Map;
      if (!mounted) return;
      setState(() {
        items = (data['items'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        canCreate = data['canCreate'] == true;
        canEdit = data['canEdit'] == true;
        canDelete = data['canDelete'] == true;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        showTimedSnackBar(
          context,
          message: 'โหลดรูปแบบการอนุมัติไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final random = Random.secure();
    final code =
        row?['code'] as String? ??
        'AP-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final name = TextEditingController(text: row?['name'] as String? ?? '');
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => StatefulBuilder(
        builder: (dc, update) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: Theme.of(dc).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'รูปแบบการอนุมัติ > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(thickness: .6),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  enabled: !busy,
                  decoration: ocrInput(dc, 'ชื่อการอนุมัติ *'),
                ),
                const SizedBox(height: 12),
                const Divider(thickness: .6),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: busy ? null : () => Navigator.pop(dc),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        showTimedSnackBar(
                          context,
                          message: 'กรุณาระบุชื่อการอนุมัติ',
                          error: true,
                        );
                        return;
                      }
                      update(() => busy = true);
                      try {
                        final body = {'code': code, 'name': name.text.trim()};
                        if (row == null) {
                          await api.post(
                            '/api/company/approval-catalog',
                            body: body,
                          );
                        } else {
                          await api.put(
                            '/api/company/approval-catalog/${Uri.encodeComponent(row['code'] as String)}',
                            body: body,
                          );
                        }
                        if (dc.mounted) Navigator.pop(dc);
                        if (mounted) {
                          showTimedSnackBar(
                            context,
                            message: 'บันทึกรูปแบบการอนุมัติเรียบร้อยแล้ว',
                          );
                          await load();
                        }
                      } catch (_) {
                        if (mounted) {
                          showTimedSnackBar(
                            context,
                            message:
                                'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์',
                            error: true,
                          );
                        }
                        if (dc.mounted) update(() => busy = false);
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  Future<void> configure(Map<String, dynamic> row) async {
    try {
      final code = row['code'] as String;
      final data =
          await api.get(
                '/api/company/approval-catalog/${Uri.encodeComponent(code)}/configuration',
              )
              as Map;
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dc) => _ConfigurationDialog(
          api: api,
          code: code,
          name: row['name'] as String,
          data: data,
        ),
      );
      if (mounted && saved == true) {
        showTimedSnackBar(
          context,
          message: 'บันทึกการกำหนดรูปแบบเรียบร้อยแล้ว',
        );
        await load();
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'โหลดการกำหนดรูปแบบไม่สำเร็จ กรุณาลองใหม่',
          error: true,
        );
      }
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final color = Theme.of(context).colorScheme.error;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: color),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('ยืนยันการลบข้อมูล', style: TextStyle(color: color)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: color.withValues(alpha: .1),
              padding: const EdgeInsets.all(12),
              child: Text('${row['name']}'),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถกู้คืนได้'),
            const Divider(thickness: .6),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await api.delete(
        '/api/company/approval-catalog/${Uri.encodeComponent(row['code'] as String)}',
      );
      if (mounted) {
        showTimedSnackBar(context, message: 'ลบข้อมูลเรียบร้อยแล้ว');
        await load();
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ลบไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items
        .where(
          (x) => '${x['name']}'.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    const size = 10;
    final pages = (filtered.length / size).ceil();
    final current = pages == 0 ? 0 : page.clamp(0, pages - 1);
    final visible = filtered.skip(current * size).take(size).toList();
    Widget actions(Map<String, dynamic> row) => Wrap(
      children: [
        if (canEdit)
          IconButton(
            tooltip: 'กำหนด',
            onPressed: () => configure(row),
            icon: Icon(
              Icons.settings_outlined,
              color: businessCardOcrUi(context).primaryColor,
            ),
          ),
        if (canEdit)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => edit(row),
            icon: Icon(
              Icons.edit_outlined,
              color: businessCardOcrUi(context).primaryColor,
            ),
          ),
        if (canDelete)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => remove(row),
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, _, _) => SupportWorkspaceShell(
        pageTitle: 'รูปแบบการอนุมัติ',
        activeMenu: '10011',
        menuScope: WorkspaceMenuScope.company,
        child: LayoutBuilder(
          builder: (context, available) {
            final forceCards =
                available.maxWidth - 2 * LaooLayout.cardMargin - 20 < 600;
            final showCards = forceCards || card;
            return Padding(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LaooSurfaceCard(
                    tokens: businessCardOcrUi(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tokens = businessCardOcrUi(context);
                        final buttons = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!forceCards)
                              LaooListCardToggle(
                                tokens: tokens,
                                cards: card,
                                onChanged: (value) =>
                                    setState(() => card = value),
                              ),
                            if (canCreate && !forceCards)
                              const SizedBox(width: 8),
                            if (canCreate)
                              SizedBox(
                                height: tokens.buttonHeight,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tokens.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => edit(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('เพิ่ม'),
                                ),
                              ),
                          ],
                        );
                        const title = WorkspacePageTitle(
                          title: 'รูปแบบการอนุมัติ',
                          favoriteKey: '10011',
                        );
                        if (constraints.maxWidth < 420) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: buttons,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 8),
                            buttons,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  WorkspaceSectionCard(
                    child: FilterHeightSync(
                      builder: (context, key, height) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width:
                                (available.maxWidth -
                                        2 * LaooLayout.cardMargin -
                                        20)
                                    .clamp(0.0, 340.0),
                            child: TextField(
                              key: key,
                              controller: search,
                              style: businessCardOcrUi(context).inputStyle,
                              decoration: ocrInput(
                                context,
                                'ค้นหาชื่อการอนุมัติ',
                                icon: Icons.search,
                              ),
                              onSubmitted: (v) => setState(() {
                                query = v.trim();
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
                              page = 0;
                            }),
                            icon: const Icon(Icons.filter_alt_off),
                            label: const Text('ล้าง Filter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Expanded(
                    child: WorkspaceSectionCard(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : visible.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : SingleChildScrollView(
                              child: showCards
                                  ? Column(
                                      children: [
                                        for (
                                          var index = 0;
                                          index < visible.length;
                                          index++
                                        ) ...[
                                          if (index > 0)
                                            const SizedBox(height: 8),
                                          Card(
                                            margin: EdgeInsets.zero,
                                            elevation: 0,
                                            color: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    14,
                                                    10,
                                                    8,
                                                    10,
                                                  ),
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    '${visible[index]['name']}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          color:
                                                              businessCardOcrUi(
                                                                context,
                                                              ).primaryColor,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  actions(visible[index]),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Table(
                                      columnWidths: const {
                                        0: FixedColumnWidth(60),
                                        1: FixedColumnWidth(170),
                                        2: FlexColumnWidth(),
                                      },
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      border: TableBorder(
                                        horizontalInside: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).dividerColor.withValues(alpha: .45),
                                          width: .6,
                                        ),
                                        bottom: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).dividerColor.withValues(alpha: .45),
                                          width: .6,
                                        ),
                                      ),
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: businessCardOcrUi(context)
                                                .primaryColor
                                                .withValues(alpha: .12),
                                          ),
                                          children: [
                                            for (final label in [
                                              'ID',
                                              'Action',
                                              'ชื่อการอนุมัติ',
                                            ])
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    color: businessCardOcrUi(
                                                      context,
                                                    ).primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        for (var i = 0; i < visible.length; i++)
                                          TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Text(
                                                  '${current * size + i + 1}',
                                                ),
                                              ),
                                              actions(visible[i]),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Text(
                                                  '${visible[i]['name']}',
                                                  textAlign: TextAlign.left,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  LaooPaginationCard(
                    tokens: businessCardOcrUi(context),
                    borderless: true,
                    page: current + 1,
                    pageCount: pages == 0 ? 1 : pages,
                    pageSize: size,
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

class _ConfigurationDialog extends StatefulWidget {
  const _ConfigurationDialog({
    required this.api,
    required this.code,
    required this.name,
    required this.data,
  });
  final ApiClient api;
  final String code, name;
  final Map data;
  @override
  State<_ConfigurationDialog> createState() => _ConfigurationDialogState();
}

class _ConfigurationDialogState extends State<_ConfigurationDialog> {
  late String type;
  late String levelOrderMethod;
  late TextEditingController levels;
  final positions = <String, String>{};
  final steps = <Map<String, dynamic>>[];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    type = '${widget.data['type'] ?? 'MANUAL'}';
    levelOrderMethod = '${widget.data['levelOrderMethod'] ?? 'SEQUENCE'}';
    levels = TextEditingController(text: '${widget.data['levelsUp'] ?? 1}');
    for (final p in (widget.data['positions'] as List).whereType<Map>()) {
      positions['${p['code']}'] = '${p['name']}';
    }
    for (final s in (widget.data['steps'] as List).whereType<Map>()) {
      steps.add({
        'condition': '${s['condition']}',
        'positions': (s['positions'] as List)
            .whereType<Map>()
            .map(
              (p) => <String, dynamic>{
                'code': p['code'],
                'unitScope': p['unitScope'],
              },
            )
            .toList(),
      });
    }
  }

  @override
  void dispose() {
    levels.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final n = int.tryParse(levels.text.trim());
    final codes = steps
        .expand((s) => (s['positions'] as List).cast<Map<String, dynamic>>())
        .map((p) => '${p['code'] ?? ''}'.trim())
        .toList();
    if ((type == 'LEVEL' && (n == null || n <= 0)) ||
        ((type == 'POSITION' || type == 'SPECIFIC') &&
            (steps.isEmpty ||
                steps.any((s) => (s['positions'] as List).isEmpty) ||
                codes.any((c) => c.isEmpty) ||
                codes.map((c) => c.toLowerCase()).toSet().length !=
                    codes.length))) {
      showTimedSnackBar(
        context,
        message: 'กรุณาระบุข้อมูลให้ครบ และเลือกตำแหน่งไม่ซ้ำกัน',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.put(
        '/api/company/approval-catalog/${Uri.encodeComponent(widget.code)}/configuration',
        body: {
          'type': type,
          'levelsUp': type == 'LEVEL' ? n : null,
          'levelOrderMethod': type == 'LEVEL' ? levelOrderMethod : null,
          'steps': type == 'POSITION'
              ? steps
              : type == 'SPECIFIC'
              ? steps
                    .map(
                      (step) => {
                        'condition': step['condition'],
                        'positions': (step['positions'] as List)
                            .map((p) => {'code': p['code'], 'unitScope': 'ANY'})
                            .toList(),
                      },
                    )
                    .toList()
              : [],
        },
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์',
          error: true,
        );
        setState(() => busy = false);
      }
    }
  }

  Future<void> _selectPosition(Map<String, dynamic> position) async {
    var query = '';
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final matches = positions.entries
              .where(
                (entry) =>
                    entry.value.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('ค้นหาตำแหน่งงาน')),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: MediaQuery.sizeOf(context).height * .55,
              child: Column(
                children: [
                  const Divider(thickness: .6),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: businessCardOcrUi(context).inputStyle,
                    decoration: ocrInput(context, 'ค้นหา', icon: Icons.search),
                    onChanged: (value) => update(() => query = value.trim()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('ไม่พบตำแหน่งงาน'))
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, thickness: .6),
                            itemBuilder: (context, index) => ListTile(
                              title: Text(matches[index].value),
                              onTap: () => Navigator.pop(
                                dialogContext,
                                matches[index].key,
                              ),
                            ),
                          ),
                  ),
                  const Divider(thickness: .6),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted && chosen != null) setState(() => position['code'] = chosen);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    title: Row(
      children: [
        Icon(
          Icons.settings_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('กำหนด > ${widget.name}')),
      ],
    ),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          const Divider(thickness: .6),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    isExpanded: true,
                    style: businessCardOcrUi(context).inputStyle.copyWith(
                      fontSize: LaooTypography.comboBox,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: ocrInput(context, 'รูปแบบการอนุมัติ'),
                    items: const [
                      DropdownMenuItem(
                        value: 'MANUAL',
                        child: Text('กำหนดทุกครั้งเมื่อทำรายการ'),
                      ),
                      DropdownMenuItem(
                        value: 'LEVEL',
                        child: Text('ตามระดับตำแหน่งขึ้นไป'),
                      ),
                      DropdownMenuItem(
                        value: 'SPECIFIC',
                        child: Text('ตามตำแหน่งงาน-เจาะจงตามตำแหน่งงาน'),
                      ),
                      DropdownMenuItem(
                        value: 'POSITION',
                        child: Text('ตามตำแหน่งงาน'),
                      ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 8),
                  Text(switch (type) {
                    'MANUAL' => 'ผู้บันทึกจะต้องเลือกการส่งอนุมัติทุกครั้ง',
                    'LEVEL' =>
                      'ระบุจำนวนระดับขึ้นไป เช่น 2 ระบบจะส่งอนุมัติตามลำดับขึ้นไป 2 ลำดับต่อจากผู้บันทึก',
                    'SPECIFIC' =>
                      'ระบบจะส่งแบบเจาะจงตามตำแหน่งงาน เช่น ผู้จัดการฝ่ายบัญชี เหมาะสำหรับองค์กรที่ระบุชื่อตำแหน่งงานแบบเจาะจง',
                    'POSITION' =>
                      'ระบบจะส่งตามตำแหน่งงาน เช่น ผู้จัดการ และเลือกได้ว่าต้องอยู่ในฝ่ายเดียวกันหรือไม่ เหมาะสำหรับองค์กรที่ไม่ระบุชื่อตำแหน่งงานแบบเจาะจงฝ่ายชัดเจน',
                    _ => '',
                  }),
                  const SizedBox(height: 14),
                  if (type == 'LEVEL') ...[
                    TextField(
                      controller: levels,
                      style: businessCardOcrUi(context).inputStyle,
                      keyboardType: TextInputType.number,
                      decoration: ocrInput(context, 'จำนวนระดับขึ้นไป'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: levelOrderMethod,
                      isExpanded: true,
                      style: businessCardOcrUi(context).inputStyle.copyWith(
                        fontSize: LaooTypography.comboBox,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: ocrInput(
                        context,
                        'วิธีการจัดระดับของตำแหน่งงาน',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'NAME',
                          child: Text('จัดตามชื่อ'),
                        ),
                        DropdownMenuItem(
                          value: 'SHORTCODE',
                          child: Text('จัดตามรหัสย่อ'),
                        ),
                        DropdownMenuItem(
                          value: 'SEQUENCE',
                          child: Text('จัดตามลำดับ'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) =>
                                setState(() => levelOrderMethod = value!),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'วิธีจัดระดับใช้ข้อมูลชื่อ รหัสย่อ หรือลำดับจากรหัสพื้นฐานกลุ่มระดับตำแหน่งงาน โดยเรียงจากน้อยไปมากและรายการที่อยู่หลังเป็นระดับสูงกว่า',
                    ),
                  ],
                  if (type == 'POSITION' || type == 'SPECIFIC') ...[
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const Divider(thickness: .6),
                      _step(i),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(
                                () => steps.add({
                                  'condition': 'ANY',
                                  'positions': <Map<String, dynamic>>[
                                    {'code': null, 'unitScope': 'ANY'},
                                  ],
                                }),
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มลำดับ'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'หมายเหตุ: ตำแหน่งของผู้บันทึกและตำแหน่งที่ว่างจะถูกข้าม หากมีตำแหน่งอื่นในลำดับเดียวกัน ระบบจะส่งให้ตำแหน่งที่เหลือ',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(thickness: .6),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: busy ? null : save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
  Widget _step(int i) {
    final step = steps[i];
    final list = (step['positions'] as List).cast<Map<String, dynamic>>();
    final t = businessCardOcrUi(context);
    final textStyle = t.inputStyle.copyWith(
      fontSize: LaooTypography.comboBox,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      key: ObjectKey(step),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var j = 0; j < list.length; j++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text('ลำดับ ${i + 1}', style: t.inputStyle),
                    ),
                    SizedBox(
                      width: constraints.maxWidth.clamp(0.0, 240.0),
                      child: TextFormField(
                        key: ValueKey(
                          'position-${identityHashCode(list[j])}-${list[j]['code']}',
                        ),
                        initialValue: positions[list[j]['code']] ?? '',
                        readOnly: true,
                        enabled: !busy,
                        style: textStyle,
                        decoration: ocrInput(context, 'ตำแหน่งงาน').copyWith(
                          suffixIcon: Icon(Icons.search, color: t.primaryColor),
                        ),
                        onTap: busy ? null : () => _selectPosition(list[j]),
                      ),
                    ),
                    if (type == 'POSITION')
                      SizedBox(
                        width: constraints.maxWidth.clamp(0.0, 270.0),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('scope-${identityHashCode(list[j])}'),
                          initialValue:
                              list[j]['unitScope'] as String? ?? 'ANY',
                          isExpanded: true,
                          style: textStyle,
                          decoration: ocrInput(context, 'หน่วยงาน'),
                          items: const [
                            DropdownMenuItem(
                              value: 'ANY',
                              child: Text(
                                'เจาะจงตำแหน่งงานนี้เท่านั้น',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'DEPARTMENT',
                              child: Text('แผนกเดียวกัน'),
                            ),
                            DropdownMenuItem(
                              value: 'DIVISION',
                              child: Text('ฝ่ายเดียวกัน'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (v) => setState(() => list[j]['unitScope'] = v),
                        ),
                      ),
                    IconButton(
                      tooltip: 'ลบตำแหน่ง',
                      onPressed: busy
                          ? null
                          : () => setState(() => list.removeAt(j)),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (type == 'POSITION')
              Padding(
                padding: const EdgeInsets.only(left: 80, bottom: 8),
                child: Text(switch (list[j]['unitScope']) {
                  'DEPARTMENT' =>
                    'ระบบจะส่งไปที่ตำแหน่งงานนี้ที่อยู่แผนกเดียวกับผู้บันทึก เช่น ผู้บันทึกอยู่แผนกบัญชี ระบบส่งไปขออนุมัติที่หัวหน้าแผนกบัญชี',
                  'DIVISION' =>
                    'ระบบจะส่งไปที่ตำแหน่งงานนี้ที่อยู่ฝ่ายเดียวกับผู้บันทึก เช่น ผู้บันทึกอยู่แผนกบัญชี ระบบส่งไปขออนุมัติที่ผู้จัดการฝ่ายบัญชี',
                  _ => 'ระบบจะส่งอนุมัติไปที่ตำแหน่งงานนี้โดยตรง',
                }),
              ),
          ],
          if (list.isEmpty) Text('ลำดับ ${i + 1}', style: t.inputStyle),
          Padding(
            padding: const EdgeInsets.only(left: 80),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: t.primaryColor),
                onPressed: busy
                    ? null
                    : () => setState(
                        () => list.add({'code': null, 'unitScope': 'ANY'}),
                      ),
                child: const Text('เพิ่มตำแหน่งอื่นกรณีอนุมัติแทนได้'),
              ),
            ),
          ),
          Wrap(
            children: [
              IconButton(
                tooltip: 'เลื่อนลำดับขึ้น',
                color: t.primaryColor,
                onPressed: busy || i == 0
                    ? null
                    : () => setState(() {
                        final x = steps.removeAt(i);
                        steps.insert(i - 1, x);
                      }),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'เลื่อนลำดับลง',
                color: t.primaryColor,
                onPressed: busy || i == steps.length - 1
                    ? null
                    : () => setState(() {
                        final x = steps.removeAt(i);
                        steps.insert(i + 1, x);
                      }),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'ลบลำดับ',
                onPressed: busy
                    ? null
                    : () => setState(() => steps.removeAt(i)),
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          if (list.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<String>(
                initialValue: step['condition'] as String,
                isExpanded: true,
                style: textStyle,
                decoration: ocrInput(context, 'เงื่อนไขการอนุมัติ'),
                items: const [
                  DropdownMenuItem(
                    value: 'ANY',
                    child: Text('อนุมัติอย่างน้อย 1 ตำแหน่ง'),
                  ),
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('ต้องอนุมัติครบทุกตำแหน่ง'),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => step['condition'] = v),
              ),
            ),
        ],
      ),
    );
  }
}
