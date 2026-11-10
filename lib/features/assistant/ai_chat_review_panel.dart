import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import '../../app/theme/laoo_design_tokens.dart';
import '../../app/theme/laoo_typography.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/shared/registry_ui.dart';

class AiChatReviewPanel extends StatefulWidget {
  const AiChatReviewPanel({
    super.key,
    required this.capabilities,
    required this.canEdit,
    required this.cards,
    this.api,
  });
  final List<Map<String, dynamic>> capabilities;
  final bool canEdit;
  final bool cards;
  final ApiClient? api;
  @override
  State<AiChatReviewPanel> createState() => _AiChatReviewPanelState();
}

class _AiChatReviewPanelState extends State<AiChatReviewPanel> {
  late final ApiClient _api;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [], _departments = [];
  String _status = '';
  bool? _interpretationFailed;
  int? _department;
  int _page = 1, _total = 0;
  bool _loading = true;
  final Set<int> _working = {};
  final Map<int, ({String message, bool error})> _rowMessages = {};
  static const _statuses = {
    '': 'ทั้งหมด',
    'PENDING': 'รอตรวจสอบ',
    'PREPARING': 'กำลังจัดเตรียม',
    'TESTING': 'รอทดสอบ',
    'AWAITING_APPROVAL': 'รออนุมัติ',
    'ACTIVE': 'ใช้งานแล้ว',
    'REJECTED': 'ไม่ใช้',
  };

  String _date(dynamic raw) {
    final value = DateTime.tryParse('$raw');
    if (value == null) return '-';
    final local = value.isUtc
        ? value.toLocal()
        : DateTime.utc(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
          ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _capabilityName(dynamic code) {
    if (code == null) return '-';
    for (final item in widget.capabilities) {
      if (item['code'] == code) return '${item['name']}';
    }
    return switch (code) {
      'unknown' => 'ไม่เข้าใจคำถาม',
      'ambiguous' => 'คำถามกำกวม',
      'none' => 'ไม่มีความสามารถที่เปิดใช้งาน',
      'denied' => 'ไม่มีสิทธิ์ใช้ความสามารถ',
      'unavailable' => 'บริการ AI ไม่พร้อม',
      _ => 'ไม่พบความสามารถ',
    };
  }

  String _agentName(dynamic code) {
    final item = widget.capabilities
        .where((entry) => entry['code'] == code)
        .firstOrNull;
    return switch (item?['agentId']) {
      'service' => 'Agent Service',
      'stock' => 'Agent สต๊อก',
      null => 'ไม่ระบุ Agent',
      final value => '$value',
    };
  }

  Future<void> _testResult(int id, {Map? result, String? error}) async {
    final passed = result?['passed'] == true;
    final selected = (result?['expected'] as List?) ?? const [];
    final matches = (result?['matches'] as List?) ?? const [];
    final approve = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Row(
          children: [
            Icon(
              Icons.science_outlined,
              color: workspaceThemeController.value.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ผลทดลองคำถาม',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(thickness: .6),
                const Text(
                  'เป็นการจำลองการจับคู่ ไม่ได้ฝึกโมเดลหรือสร้างรายการจริง',
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(error)
                else ...[
                  Text(
                    passed
                        ? 'ผล: พบความสามารถที่เลือกครบ'
                        : 'ผล: พบความสามารถไม่ครบ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ที่เลือก',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    selected.isEmpty
                        ? '-'
                        : selected.map(_capabilityName).join('\n'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'จำลองพบ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    matches.isEmpty
                        ? '-'
                        : matches.map(_capabilityName).join('\n'),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(thickness: .6),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ปิด'),
          ),
          if (passed && widget.canEdit)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('อนุมัติพร้อมกัน'),
            ),
        ],
      ),
    );
    if (approve == true && mounted) {
      final row =
          _rows.where((item) => item['id'] == id).firstOrNull ??
          {'id': id, 'capabilities': selected};
      await _confirmApprove(row);
    }
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final args = <String, String>{
        'page': '$_page',
        'search': _search.text.trim(),
        'status': _status,
        if (_interpretationFailed != null)
          'interpretationFailed': '$_interpretationFailed',
        if (_department != null) 'department': '$_department',
      };
      final results = await Future.wait([
        _api.get(
          '/api/assistant/chat-review?${Uri(queryParameters: args).query}',
        ),
        _api.get('/api/assistant/chat-review/filters'),
      ]);
      final data = Map<String, dynamic>.from(results[0] as Map),
          filters = Map<String, dynamic>.from(results[1] as Map);
      if (!mounted) return;
      setState(() {
        _rows = (data['rows'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _total = (data['total'] as num).toInt();
        _departments = (filters['departments'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (_department != null &&
            !_departments.any((e) => (e['id'] as num).toInt() == _department)) {
          _department = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: 'โหลดคำถามจาก Chat ไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  Future<void> _action(int id, String action) async {
    if (_working.contains(id)) return;
    setState(() => _working.add(id));
    try {
      final result = await _api.post(
        '/api/assistant/chat-review/$id/$action',
        timeout: action == 'test' ? const Duration(seconds: 100) : null,
      );
      if (!mounted) return;
      final passed = result is Map && result['passed'] == true;
      final matches = result is Map && result['matches'] is List
          ? (result['matches'] as List).map(_capabilityName).join(', ')
          : '-';
      final expected = result is Map && result['expected'] is List
          ? (result['expected'] as List).map(_capabilityName).join(', ')
          : '-';
      final message = action == 'test'
          ? (passed
                ? 'จำลองพบ: $matches\nที่เลือก: $expected\nตรงครบ รออนุมัติ'
                : 'จำลองพบ: $matches\nที่เลือก: $expected\nไม่ตรง กรุณาปรับแล้วทดลองอีกครั้ง')
          : action == 'approve'
          ? 'อนุมัติตัวอย่างแล้ว'
          : 'ย้ายรายการเป็นไม่ใช้แล้ว';
      setState(() {
        if (action == 'test') {
          _rowMessages.remove(id);
        } else {
          _rowMessages[id] = (message: message, error: false);
        }
        _status = '';
        _page = 1;
      });
      await _load();
      if (action == 'test' && mounted) {
        setState(() => _working.remove(id));
        await _testResult(id, result: result is Map ? result : null);
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'ทำรายการไม่สำเร็จ กรุณาตรวจสอบสิทธิ์ ข้อมูลซ้ำ หรือบริการ AI แล้วลองใหม่';
        if (action == 'test') {
          await _load();
          if (mounted) await _testResult(id, error: message);
        } else {
          setState(() => _rowMessages[id] = (message: message, error: true));
        }
      }
    } finally {
      if (mounted) setState(() => _working.remove(id));
    }
  }

  Future<void> _prepare(Map<String, dynamic> row) async {
    final text = TextEditingController(
      text: '${row['reviewText'] ?? row['text']}',
    );
    final selected = <String>{
      if (row['capabilities'] is List)
        ...(row['capabilities'] as List).whereType<String>()
      else if (row['capability'] is String)
        row['capability'] as String,
    };
    var originalSelected = Set<String>.of(selected);
    var originalText = text.text.trim();
    final search = TextEditingController();
    String agentFilter = '';
    bool selectedOnly = false;
    bool saving = false;
    bool savedChanged = false;
    String? saveMessage;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.sizeOf(ctx).height * .85,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: workspaceThemeController.value.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'จัดเตรียมคำถาม',
                            style: LaooTypography.popupTitleStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(thickness: .6),
                    const SizedBox(height: 12),
                    TextField(
                      controller: text,
                      enabled: !saving,
                      onChanged: (_) => refresh(() {}),
                      style: const TextStyle(
                        fontSize: LaooTypography.inputText,
                      ),
                      maxLines: 4,
                      maxLength: 300,
                      decoration: registryInput(
                        ctx,
                        label: 'คำถาม *',
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ความสามารถ *',
                      style: TextStyle(
                        color: workspaceThemeController.value.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: search,
                      onChanged: (_) => refresh(() {}),
                      decoration: registryInput(
                        ctx,
                        label: 'ค้นหาความสามารถหรือ Agent',
                      ).copyWith(prefixIcon: const Icon(Icons.search)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: agentFilter,
                      decoration: registryInput(ctx, label: 'Agent'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('ทั้งหมด'),
                        ),
                        ...widget.capabilities
                            .map((e) => '${e['agentId'] ?? ''}')
                            .where((id) => id.isNotEmpty)
                            .toSet()
                            .map(
                              (id) => DropdownMenuItem(
                                value: id,
                                child: Text(
                                  _agentName(
                                    widget.capabilities.firstWhere(
                                      (e) => e['agentId'] == id,
                                    )['code'],
                                  ),
                                ),
                              ),
                            ),
                      ],
                      onChanged: (value) =>
                          refresh(() => agentFilter = value ?? ''),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: workspaceThemeController.value.primary,
                      title: Text(
                        'แสดงเฉพาะรายการที่เลือก (${selected.length})',
                      ),
                      value: selectedOnly,
                      onChanged: (value) =>
                          refresh(() => selectedOnly = value ?? false),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...widget.capabilities
                                .where((item) {
                                  final code = '${item['code']}';
                                  final agentId = '${item['agentId'] ?? ''}';
                                  final query = search.text
                                      .trim()
                                      .toLowerCase();
                                  return (agentFilter.isEmpty ||
                                          agentId == agentFilter) &&
                                      (!selectedOnly ||
                                          selected.contains(code)) &&
                                      (query.isEmpty ||
                                          '${item['name']}'
                                              .toLowerCase()
                                              .contains(query) ||
                                          _agentName(
                                            code,
                                          ).toLowerCase().contains(query));
                                })
                                .map((item) {
                                  final code = '${item['code']}';
                                  final enabled = item['isEnabled'] == true;
                                  final agentId = '${item['agentId'] ?? ''}';
                                  final agentName = agentId == 'service'
                                      ? 'Agent Service'
                                      : agentId == 'stock'
                                      ? 'Agent สต๊อก'
                                      : agentId;
                                  return CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor:
                                        workspaceThemeController.value.primary,
                                    title: Text('${item['name']}'),
                                    subtitle: Text(
                                      enabled
                                          ? agentName
                                          : '$agentName • ปิดใช้งาน',
                                    ),
                                    value: selected.contains(code),
                                    onChanged:
                                        saving ||
                                            (!enabled &&
                                                !selected.contains(code))
                                        ? null
                                        : (value) => refresh(() {
                                            if (value == true) {
                                              selected.add(code);
                                            } else {
                                              selected.remove(code);
                                            }
                                          }),
                                  );
                                }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(thickness: .6),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('ยกเลิก'),
                        ),
                        FilledButton(
                          onPressed: selected.isEmpty || saving
                              ? null
                              : () async {
                                  if (text.text.trim().isEmpty) return;
                                  refresh(() => saving = true);
                                  try {
                                    await _api.put(
                                      '/api/assistant/chat-review/${row['id']}/prepare',
                                      body: {
                                        'text': text.text.trim(),
                                        'capabilities': selected.toList(),
                                      },
                                    );
                                    savedChanged = true;
                                    if (ctx.mounted) {
                                      refresh(
                                        () => saveMessage =
                                            'บันทึกแล้ว กำลังทดลองคำถาม',
                                      );
                                    }
                                    final result = await _api.post(
                                      '/api/assistant/chat-review/${row['id']}/test',
                                      timeout: const Duration(seconds: 100),
                                    );
                                    if (ctx.mounted)
                                      refresh(() {
                                        final passed =
                                            result is Map &&
                                            result['passed'] == true;
                                        originalText = text.text.trim();
                                        originalSelected = Set<String>.of(
                                          selected,
                                        );
                                        row['capabilities'] = selected.toList();
                                        row['status'] = passed
                                            ? 'AWAITING_APPROVAL'
                                            : 'TESTING';
                                        saveMessage = passed
                                            ? 'ทดลองผ่านแล้ว สามารถอนุมัติพร้อมกันได้'
                                            : 'ทดลองไม่ผ่าน กรุณาปรับคำถามหรือความสามารถแล้วบันทึกอีกครั้ง';
                                        saving = false;
                                      });
                                  } catch (error) {
                                    if (ctx.mounted) {
                                      refresh(() {
                                        saving = false;
                                        if (savedChanged)
                                          row['status'] = 'PREPARING';
                                        saveMessage = error is ApiException
                                            ? error.message
                                            : savedChanged
                                            ? 'บันทึกแล้ว แต่ทดลองไม่สำเร็จ กรุณาลองบันทึกอีกครั้ง'
                                            : 'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์';
                                      });
                                    }
                                  }
                                },
                          child: const Text('บันทึก'),
                        ),
                        FilledButton(
                          onPressed:
                              !saving &&
                                  widget.canEdit &&
                                  row['status'] == 'AWAITING_APPROVAL' &&
                                  text.text.trim() == originalText &&
                                  selected.length == originalSelected.length &&
                                  selected.containsAll(originalSelected) &&
                                  selected.every(
                                    (code) => widget.capabilities.any(
                                      (item) =>
                                          item['code'] == code &&
                                          item['isEnabled'] == true,
                                    ),
                                  ) &&
                                  selected.isNotEmpty
                              ? () => Navigator.pop(ctx, 'approve')
                              : null,
                          child: const Text('อนุมัติพร้อมกัน'),
                        ),
                      ],
                    ),
                    if (saveMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        saveMessage!,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    text.dispose();
    search.dispose();
    if (saved == 'approve' && mounted) {
      await _confirmApprove(row);
    } else if (savedChanged && mounted) {
      final id = (row['id'] as num).toInt();
      if (mounted) {
        setState(() {
          _rowMessages[id] = (
            message: 'จัดเตรียมแล้ว เลือกสถานะเพื่อทดลอง',
            error: false,
          );
          _status = '';
          _page = 1;
        });
      }
      await _load();
    }
  }

  Future<void> _confirmApprove(Map<String, dynamic> row) async {
    final codes =
        (row['capabilities'] as List?)?.whereType<String>().toList() ?? [];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: workspaceThemeController.value.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ยืนยันอนุมัติพร้อมกัน',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .55,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(thickness: .6),
                  const Text('เพิ่มคำถามเป็นตัวอย่างให้ความสามารถต่อไปนี้:'),
                  for (var i = 0; i < codes.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. '),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_capabilityName(codes[i])),
                                Text(_agentName(codes[i])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: .6, height: 1),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันอนุมัติ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _action((row['id'] as num).toInt(), 'approve');
    }
  }

  Widget _statusMenu(Map<String, dynamic> row) {
    final status = row['status'];
    final label = '${_statuses[status] ?? status ?? '-'}';
    if (!widget.canEdit ||
        _working.contains(row['id']) ||
        ['ACTIVE', 'REJECTED'].contains(status)) {
      return Text(label);
    }
    final primary = workspaceThemeController.value.primary;
    return PopupMenuButton<String>(
      tooltip: 'เลือกคำสั่งสำหรับ $label',
      onSelected: (value) {
        if (value == 'prepare') {
          _prepare(row);
        } else if (value == 'approve') {
          _confirmApprove(row);
        } else {
          _action((row['id'] as num).toInt(), value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'prepare', child: Text('จัดเตรียม')),
        if (['PREPARING', 'TESTING'].contains(status))
          const PopupMenuItem(value: 'test', child: Text('ทดลอง')),
        if (status == 'AWAITING_APPROVAL')
          const PopupMenuItem(value: 'approve', child: Text('อนุมัติ')),
        const PopupMenuItem(value: 'reject', child: Text('ไม่ใช้')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, style: TextStyle(color: primary)),
          ),
          Icon(Icons.arrow_drop_down, color: primary),
        ],
      ),
    );
  }

  Widget _statusWithMessage(Map<String, dynamic> row) {
    final message = _rowMessages[(row['id'] as num).toInt()];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusMenu(row),
        if (message != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                message.message,
                style: TextStyle(fontSize: 13, color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }

  Widget _interpretationStatus(Map<String, dynamic> row) {
    final failed = row['interpretationFailed'];
    if (failed == null) return const Text('ยังไม่มีผล');
    if (failed != true) return const Text('ตีความได้');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('ตีความไม่ได้', style: TextStyle(color: Colors.red.shade900)),
    );
  }

  Widget _reviewTable(Color primary) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          dataRowMaxHeight: double.infinity,
          headingRowColor: WidgetStatePropertyAll(
            primary.withValues(alpha: .1),
          ),
          headingTextStyle: TextStyle(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
          columns: const [
            DataColumn(label: Text('สถานะ')),
            DataColumn(label: Text('ข้อความ')),
            DataColumn(label: Text('AI ตีความ')),
            DataColumn(label: Text('AI ตีความไม่ได้')),
            DataColumn(label: Text('แผนก')),
            DataColumn(label: Text('วันที่-เวลา')),
          ],
          rows: _rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(_statusWithMessage(row)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          '${row['text'] ?? '-'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_capabilityName(row['detected']))),
                    DataCell(_interpretationStatus(row)),
                    DataCell(Text('${row['department'] ?? '-'}')),
                    DataCell(Text(_date(row['createdAt']))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ),
  );

  Widget _reviewCards() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in _rows) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ข้อความจาก Chat: ${row['text']}'),
                    if (row['reviewText'] != null)
                      Text('ตัวอย่างที่จัดเตรียม: ${row['reviewText']}'),
                    Text('วันที่: ${_date(row['createdAt'])}'),
                    Text('AI ตีความ: ${_capabilityName(row['detected'])}'),
                    _interpretationStatus(row),
                    if (row['capabilities'] is List &&
                        (row['capabilities'] as List).isNotEmpty)
                      Text(
                        'ความสามารถที่กำหนด: ${(row['capabilities'] as List).map(_capabilityName).join(', ')}',
                      ),
                    Text('แผนก: ${row['department'] ?? '-'}'),
                    _statusWithMessage(row),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(thickness: .6),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final primary = workspaceThemeController.value.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        registrySurface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterHeightSync(
                builder: (context, searchKey, height) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        key: searchKey,
                        controller: _search,
                        decoration: registryInput(context, label: 'ค้นหาคำถาม'),
                        onSubmitted: (_) {
                          _page = 1;
                          _load();
                        },
                      ),
                    ),
                    FilledButton.icon(
                      style: registryButton(
                        primary,
                        filled: true,
                      ).merge(filterActionHeightStyle(height)),
                      onPressed: () {
                        _page = 1;
                        _load();
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหา'),
                    ),
                    OutlinedButton.icon(
                      style: registryButton(
                        primary,
                      ).merge(filterActionHeightStyle(height)),
                      onPressed: () {
                        _search.clear();
                        _status = '';
                        _interpretationFailed = null;
                        _department = null;
                        _page = 1;
                        _load();
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('ล้าง Filter'),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('status-$_status'),
                        initialValue: _status,
                        decoration: registryInput(context, label: 'สถานะ'),
                        items: _statuses.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _status = v ?? '');
                          _page = 1;
                          _load();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('interpretation-$_interpretationFailed'),
                        initialValue: _interpretationFailed == null
                            ? ''
                            : _interpretationFailed!
                            ? 'failed'
                            : 'matched',
                        decoration: registryInput(
                          context,
                          label: 'AI ตีความไม่ได้',
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                          DropdownMenuItem(
                            value: 'failed',
                            child: Text('ตีความไม่ได้'),
                          ),
                          DropdownMenuItem(
                            value: 'matched',
                            child: Text('ตีความได้'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(
                            () => _interpretationFailed = value == ''
                                ? null
                                : value == 'failed',
                          );
                          _page = 1;
                          _load();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('department-$_department'),
                        initialValue: _department ?? 0,
                        decoration: registryInput(context, label: 'แผนก'),
                        items: [
                          const DropdownMenuItem<int>(
                            value: 0,
                            child: Text('ทั้งหมด'),
                          ),
                          ..._departments.map(
                            (e) => DropdownMenuItem<int>(
                              value: (e['id'] as num).toInt(),
                              child: Text('${e['name']}'),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _department = v == 0 ? null : v);
                          _page = 1;
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ลำดับ: รอตรวจสอบ → จัดเตรียม → ทดลอง → รออนุมัติ → ใช้งานแล้ว  |  เลือก “ไม่ใช้” เพื่อตัดรายการออก',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 8),
        registrySurface(
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('ไม่พบคำถามจาก Chat')),
                )
              : widget.cards
              ? _reviewCards()
              : _reviewTable(primary),
        ),
        const SizedBox(height: 8),
        registrySurface(
          SizedBox(
            height: LaooLayout.paginationCardHeight - 20,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pageButton(
                    primary,
                    Icons.chevron_left,
                    _page > 1
                        ? () {
                            _page--;
                            _load();
                          }
                        : null,
                  ),
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: LaooLayout.paginationButtonSize,
                    child: Material(
                      color: primary,
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                      child: Center(
                        child: Text(
                          '$_page',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _pageButton(
                    primary,
                    Icons.chevron_right,
                    _page * 30 < _total
                        ? () {
                            _page++;
                            _load();
                          }
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_total == 0 ? 0 : (_page - 1) * 30 + 1}-${(_page * 30).clamp(0, _total)} จาก $_total',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageButton(Color primary, IconData icon, VoidCallback? onTap) =>
      SizedBox.square(
        dimension: LaooLayout.paginationButtonSize,
        child: Material(
          color: onTap == null ? Colors.grey.shade300 : primary,
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            child: Icon(
              icon,
              size: 22,
              color: onTap == null ? Colors.grey.shade600 : Colors.white,
            ),
          ),
        ),
      );
}
