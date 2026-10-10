import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'pet_host.dart';
import 'pet_photos_dialog.dart';

class PetWorkPage extends StatefulWidget {
  const PetWorkPage({super.key});
  @override
  State<PetWorkPage> createState() => _PetWorkPageState();
}

class _PetWorkPageState extends State<PetWorkPage> {
  late final api = petApi();
  Map<String, dynamic> metadata = {}, actions = {};
  List<Map<String, dynamic>> rows = [];
  int page = 1, total = 0;
  bool loading = true, acting = false, cards = false;
  String? error;
  LaooWorkspaceUiTokens get tokens => petTokens();
  String get title => metadata['MenuName']?.toString() ?? 'กำลังโหลด...';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    petDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = Map<String, dynamic>.from(
        await api.get('/api/company/pet/actions/62007') as Map,
      );
      metadata = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูงานบริการสัตว์เลี้ยง');
      }
      final data = Map<String, dynamic>.from(
        await api.get(
              '/api/company/pet/work',
              query: {'page': '$page', 'pageSize': '20'},
            )
            as Map,
      );
      rows = (data['items'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      total = (data['total'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => loading = false);
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(exception, 'โหลดงานบริการสัตว์เลี้ยง');
        });
      }
    }
  }

  Future<void> transition(Map<String, dynamic> row, String action) async {
    if (acting || actions[action] != true) return;
    final id = (row['id'] as num).toInt();
    final label = action == 'checkin' ? 'เช็กอิน' : 'ปิดงานบริการ';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => LaooActionDialog(
        tokens: tokens,
        icon: Icons.pets_outlined,
        title: '$title > $label',
        content: Text(
          'ยืนยัน$label ${row['petName'] ?? ''} · ${row['bookingNo'] ?? ''}?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => acting = true);
    try {
      await api.post('/api/company/pet/work/$id/$action');
      if (mounted) {
        petMessage(context, message: '$labelแล้ว', error: false);
        await load();
      }
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, label),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> care(Map<String, dynamic> row) async {
    if (actions['edit'] != true) return;
    final id = (row['id'] as num).toInt();
    try {
      final logs = (await api.get('/api/company/pet/work/$id/care') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _CareDialog(title: title, stayId: id, logs: logs, api: api),
      );
      if (saved == true && mounted) {
        petMessage(context, message: 'บันทึกงานดูแลแล้ว', error: false);
        await load();
      }
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'โหลดงานดูแล'),
          error: true,
        );
      }
    }
  }

  Widget actionsFor(Map<String, dynamic> row) => Wrap(
    spacing: 4,
    children: [
      TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => PetPhotosDialog(
            title: title,
            petId: (row['petId'] as num).toInt(),
            stayId: (row['id'] as num).toInt(),
            canEdit: actions['edit'] == true,
          ),
        ),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('รูปภาพ'),
      ),
      if (row['status'] == 'BOOKED' && actions['checkin'] == true)
        TextButton.icon(
          onPressed: acting ? null : () => transition(row, 'checkin'),
          icon: const Icon(Icons.login_outlined),
          label: const Text('เช็กอิน'),
        ),
      if (row['status'] == 'CHECKED_IN') ...[
        if (actions['edit'] == true)
          TextButton.icon(
            onPressed: acting ? null : () => care(row),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('บันทึกดูแล'),
          ),
        if (actions['complete'] == true)
          TextButton.icon(
            onPressed: acting ? null : () => transition(row, 'complete'),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('ปิดงาน'),
          ),
      ],
    ],
  );

  Widget result(double width) {
    if (loading) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }
    if (rows.isEmpty) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('ยังไม่มีงานที่รอดำเนินการ')),
        ),
      );
    }
    if (cards || width < tokens.compactBreakpoint) {
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.itemSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rows[i]['bookingNo'] ?? ''} · ${rows[i]['petName'] ?? ''}',
                    style: tokens.sectionStyle,
                  ),
                  Text('สถานะ: ${rows[i]['status'] ?? '—'}'),
                  Text('ห้อง/กรง: ${rows[i]['roomCode'] ?? 'ไม่ระบุ'}'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionsFor(rows[i]),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return LaooSurfaceCard(
      tokens: tokens,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              tokens.primaryColor.withValues(alpha: 0.1),
            ),
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('เลขที่จอง')),
              DataColumn(label: Text('สัตว์เลี้ยง')),
              DataColumn(label: Text('ห้อง/กรง')),
              DataColumn(label: Text('สถานะ')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text('${row['id']}')),
                    DataCell(actionsFor(row)),
                    DataCell(Text('${row['bookingNo'] ?? '—'}')),
                    DataCell(Text('${row['petName'] ?? '—'}')),
                    DataCell(Text('${row['roomCode'] ?? '—'}')),
                    DataCell(Text('${row['status'] ?? '—'}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => petShell(
    pageTitle: title,
    activeMenu: 'pet-work',
    child: ColoredBox(
      color: tokens.backgroundColor,
      child: SingleChildScrollView(
        padding: tokens.contentMargin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => LaooCaptionCard(
                tokens: tokens,
                caption: title,
                favoriteKey: 'pet-work',
                leading: Icon(
                  petMenuIcon(metadata['IconName']?.toString()),
                  color: tokens.primaryColor,
                ),
                trailing: constraints.maxWidth >= tokens.compactBreakpoint
                    ? LaooListCardToggle(
                        tokens: tokens,
                        cards: cards,
                        onChanged: (value) => setState(() => cards = value),
                      )
                    : null,
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            LayoutBuilder(
              builder: (context, constraints) => result(constraints.maxWidth),
            ),
            SizedBox(height: tokens.sectionSpacing),
            LaooPaginationCard(
              tokens: tokens,
              page: page,
              pageCount: total == 0 ? 1 : (total / 20).ceil(),
              pageSize: 20,
              total: total,
              onPrevious: page > 1
                  ? () {
                      page--;
                      load();
                    }
                  : null,
              onNext: page * 20 < total
                  ? () {
                      page++;
                      load();
                    }
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CareDialog extends StatefulWidget {
  const _CareDialog({
    required this.title,
    required this.stayId,
    required this.logs,
    required this.api,
  });
  final String title;
  final int stayId;
  final List<Map<String, dynamic>> logs;
  final JsonApiClient api;
  @override
  State<_CareDialog> createState() => _CareDialogState();
}

class _CareDialogState extends State<_CareDialog> {
  final key = GlobalKey<FormState>();
  final detail = TextEditingController();
  String event = 'CARE';
  bool saving = false;
  @override
  void dispose() {
    detail.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !key.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.api.post(
        '/api/company/pet/work/${widget.stayId}/care',
        body: {'eventCode': event, 'detail': detail.text.trim()},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'บันทึกงานดูแล'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = petTokens();
    return LaooActionDialog(
      tokens: tokens,
      icon: Icons.pets_outlined,
      title: '${widget.title} > บันทึกดูแล',
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.logs.isNotEmpty) ...[
              Text('บันทึกก่อนหน้า', style: tokens.sectionStyle),
              for (final log in widget.logs.take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${log['eventCode']}: ${log['detail'] ?? '—'}'),
                ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: event,
              decoration: InputDecoration(
                labelText: 'ประเภทงาน *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'CARE', child: Text('ดูแลทั่วไป')),
                DropdownMenuItem(value: 'FEED', child: Text('ให้อาหาร')),
                DropdownMenuItem(value: 'CLEAN', child: Text('ทำความสะอาด')),
                DropdownMenuItem(value: 'NOTE', child: Text('หมายเหตุ')),
              ],
              onChanged: (value) => setState(() => event = value ?? event),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: detail,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'รายละเอียด *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'กรุณาระบุรายละเอียด'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }
}
