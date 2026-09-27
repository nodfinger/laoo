import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'vote_feature_host.dart';

class VotePage extends StatefulWidget {
  const VotePage(this.kind, {super.key});
  final String kind;
  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  late final JsonApiClient api = createVoteApiClient();
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void dispose() {
    disposeVoteApiClient(api);
    super.dispose();
  }

  Future<dynamic> _load() {
    if (widget.kind == 'results') {
      return Future.wait([
        api.get('/api/company/votes/results/dashboard'),
        api.get('/api/company/votes/results'),
      ]);
    }
    if (widget.kind == 'topics') {
      return Future.wait([
        api.get('/api/company/votes'),
        api.get('/api/company/votes/actions'),
      ]);
    }
    return api.get(switch (widget.kind) {
      'settings' => '/api/company/votes/settings',
      'topics' => '/api/company/votes',
      'approvals' => '/api/company/votes/approvals',
      'mine' => '/api/company/votes/mine',
      _ => '/api/company/votes/results/dashboard',
    });
  }

  String get title => switch (widget.kind) {
    'settings' => 'ตั้งค่าระบบโหวต',
    'topics' => 'หัวข้อโหวต',
    'approvals' => 'กล่องอนุมัติหัวข้อโหวต',
    'mine' => 'โหวตของฉัน',
    _ => 'ผลและรายงานการโหวต',
  };
  void reload() => setState(() => future = _load());
  @override
  Widget build(BuildContext context) => buildVoteWorkspaceShell(
    pageTitle: title,
    activeMenu: switch (widget.kind) {
      'settings' => '44001',
      'topics' => '44002',
      'approvals' => '44003',
      'mine' => '44004',
      _ => '44005',
    },
    child: FutureBuilder<dynamic>(
      future: future,
      builder: (c, s) {
        if (!s.hasData) {
          return Center(
            child: s.hasError
                ? Text('ไม่สามารถโหลดข้อมูลได้: ${s.error}')
                : const CircularProgressIndicator(),
          );
        }
        if (widget.kind == 'results') {
          final result = s.data as List;
          final dashboard = Map<String, dynamic>.from(result[0] as Map);
          final items = result[1]['items'] as List? ?? [];
          return ListView(
            children: [
              _dashboard(dashboard),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('รายการย้อนหลัง'),
              ),
              for (final item in items)
                Card(
                  child: ListTile(
                    onTap: '${item['status']}' == 'CLOSED'
                        ? () => _viewResult(item['id'])
                        : null,
                    title: Text('${item['voteNo']} | ${item['name']}'),
                    subtitle: Text(
                      '${item['status']} · โหวตแล้ว ${item['voted']}/${item['eligible']} คน',
                    ),
                  ),
                ),
            ],
          );
        }
        final isTopics = widget.kind == 'topics';
        final topicData = isTopics ? s.data as List : null;
        final m = Map<String, dynamic>.from(
          (isTopics ? topicData![0] : s.data) as Map,
        );
        final actions = isTopics
            ? Map<String, dynamic>.from(topicData![1] as Map)
            : const <String, dynamic>{};
        if (widget.kind == 'settings') return _settings(m);
        final items = m['items'] as List? ?? [];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                  ),
                  if (widget.kind == 'topics' && actions['create'] == true)
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                ],
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('ไม่พบรายการ'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (c, i) {
                          final x = Map<String, dynamic>.from(items[i] as Map);
                          return Card(
                            child: ListTile(
                              onTap: widget.kind == 'topics'
                                  ? () => _view(x['id'])
                                  : null,
                              title: Text(
                                '${x['voteNo'] ?? ''} | ${x['name'] ?? ''}',
                              ),
                              subtitle: Text('${x['status'] ?? ''}'),
                              trailing: _action(x, actions),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget _settings(Map x) => Padding(
    padding: const EdgeInsets.all(20),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ตั้งค่าระบบโหวต',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('เปิดใช้งานระบบโหวต'),
              subtitle: Text(
                (x['isEnabled'] ?? true)
                    ? 'ผู้มีสิทธิ์สามารถโหวตในรอบที่เผยแพร่'
                    : 'ปิดรับการใช้งานระบบโหวตชั่วคราว',
              ),
              value: x['isEnabled'] ?? true,
              onChanged: (_) => _editSettings(x),
            ),
            Text(
              'ระยะเวลาเปิดโหวตเริ่มต้น: ${x['defaultOpenHours'] ?? 72} ชั่วโมง',
            ),
            Text(
              'ผู้อนุมัติเริ่มต้น: ${x['defaultApproverUserId'] ?? 'ไม่กำหนด'}',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _editSettings(x),
                icon: const Icon(Icons.edit),
                label: const Text('แก้ไขการตั้งค่า'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _editSettings(Map settings) async {
    var enabled = settings['isEnabled'] ?? true;
    final hours = TextEditingController(
      text: '${settings['defaultOpenHours'] ?? 72}',
    );
    final approver = TextEditingController(
      text: '${settings['defaultApproverUserId'] ?? ''}',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('แก้ไขการตั้งค่าระบบโหวต'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('เปิดใช้งานระบบ'),
                value: enabled,
                onChanged: (v) => setDialogState(() => enabled = v),
              ),
              TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ระยะเวลาเปิดโหวตเริ่มต้น (ชั่วโมง) *',
                ),
              ),
              TextField(
                controller: approver,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'รหัสผู้อนุมัติเริ่มต้น (ไม่บังคับ)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final defaultHours = int.tryParse(hours.text.trim());
                if (defaultHours == null || defaultHours < 1) return;
                await api.put(
                  '/api/company/votes/settings',
                  body: {
                    'isEnabled': enabled,
                    'defaultOpenHours': defaultHours,
                    'defaultApproverUserId': approver.text.trim().isEmpty
                        ? null
                        : int.tryParse(approver.text.trim()),
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                reload();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewResult(Object id) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/company/votes/results/$id') as Map,
    );
    if (!mounted) return;
    final topicGroup = Map<String, dynamic>.from(value['topic'] as Map);
    final topic = Map<String, dynamic>.from(topicGroup['topic'] as Map);
    final options = value['options'] as List? ?? const [];
    final votes = options.fold<int>(
      0,
      (total, row) => total + ((row as Map)['votes'] as num).toInt(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ผลโหวต: ${topic['name']}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('จำนวนคะแนนทั้งหมด $votes เสียง'),
              const Divider(),
              for (final option in options)
                ListTile(
                  title: Text('${option['text']}'),
                  trailing: Text('${option['votes']} เสียง'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(Map x) => Padding(
    padding: const EdgeInsets.all(20),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final e in {
          'หัวข้อเปิด': x['open'],
          'ปิดแล้ว': x['closed'],
          'รออนุมัติ': x['pendingApproval'],
          'อัตราโหวต': '${x['turnout'] ?? 0}%',
        }.entries)
          SizedBox(
            width: 180,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key),
                    Text(
                      '${e.value}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget? _action(Map x, Map<String, dynamic> actions) {
    if (widget.kind == 'topics') {
      final status = '${x['status'] ?? ''}';
      final entries = <PopupMenuEntry<String>>[];
      if ((status == 'DRAFT' || status == 'RETURNED') &&
          actions['submit'] == true) {
        if (actions['edit'] == true) {
          entries.add(const PopupMenuItem(value: 'edit', child: Text('แก้ไข')));
        }
        if (actions['delete'] == true) {
          entries.add(const PopupMenuItem(value: 'delete', child: Text('ลบ')));
        }
        entries.add(
          const PopupMenuItem(value: 'submit', child: Text('ส่งอนุมัติ')),
        );
      }
      if (status == 'APPROVED' && actions['publish'] == true) {
        entries.add(
          const PopupMenuItem(value: 'publish', child: Text('เผยแพร่')),
        );
      }
      if (status == 'PUBLISHED' && actions['close'] == true) {
        entries.add(
          const PopupMenuItem(value: 'close', child: Text('ปิดโหวต')),
        );
      }
      if (entries.isEmpty) return null;
      return PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') return _edit(x['id']);
          if (v == 'delete') return _delete(x);
          await api.post('/api/company/votes/${x['id']}/$v');
          reload();
        },
        itemBuilder: (_) => entries,
      );
    }
    if (widget.kind == 'approvals') {
      return PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'RETURN') return _returnApproval(x['id']);
          await api.post(
            '/api/company/votes/${x['id']}/approval',
            body: {'action': 'APPROVE'},
          );
          reload();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'APPROVE', child: Text('อนุมัติ')),
          PopupMenuItem(value: 'RETURN', child: Text('ส่งกลับแก้ไข')),
        ],
      );
    }
    if (widget.kind == 'mine' && x['votedAt'] == null) {
      return FilledButton(
        onPressed: () => _vote(x['id']),
        child: const Text('ลงคะแนน'),
      );
    }
    return null;
  }

  Future<void> _returnApproval(Object id) async {
    final remark = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ส่งกลับแก้ไข'),
        content: TextField(
          controller: remark,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'เหตุผลที่ต้องแก้ไข *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              if (remark.text.trim().isEmpty) return;
              await api.post(
                '/api/company/votes/$id/approval',
                body: {'action': 'RETURN', 'remark': remark.text.trim()},
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              reload();
            },
            child: const Text('ส่งกลับแก้ไข'),
          ),
        ],
      ),
    );
  }

  Future<void> _vote(Object id) async {
    final detail = Map<String, dynamic>.from(
      await api.get('/api/company/votes/mine/$id') as Map,
    );
    final options = detail['options'] as List? ?? [];
    if (!mounted || options.isEmpty) return;
    Map<String, dynamic> selected = Map<String, dynamic>.from(
      options.first as Map,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('เลือกตัวเลือกโหวต'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<Map<String, dynamic>>(
                groupValue: selected,
                onChanged: (value) => setDialogState(() {
                  if (value != null) {
                    selected = value;
                  }
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      RadioListTile<Map<String, dynamic>>(
                        value: Map<String, dynamic>.from(option as Map),
                        title: Text('${option['text']}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                await api.post(
                  '/api/company/votes/mine/$id/vote',
                  body: {'optionId': selected['id']},
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                reload();
              },
              child: const Text('ยืนยันการโหวต'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final a = TextEditingController();
    final b = TextEditingController();
    var targetMode = 'ALL';
    var targets = <Map<String, dynamic>>[];
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('เพิ่มหัวข้อโหวต'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'ชื่อหัวข้อ'),
                ),
                TextField(
                  controller: a,
                  decoration: const InputDecoration(labelText: 'ตัวเลือก 1'),
                ),
                TextField(
                  controller: b,
                  decoration: const InputDecoration(labelText: 'ตัวเลือก 2'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: targetMode,
                  decoration: const InputDecoration(
                    labelText: 'ผู้มีสิทธิ์โหวต',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text('พนักงาน active ทั้งหมด'),
                    ),
                    DropdownMenuItem(
                      value: 'CUSTOM',
                      child: Text('กำหนดแผนก/พนักงาน'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => targetMode = v ?? 'ALL'),
                ),
                if (targetMode == 'CUSTOM')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final selected = await _pickTargets(targets);
                        if (selected != null) {
                          setDialogState(() => targets = selected);
                        }
                      },
                      icon: const Icon(Icons.group_add),
                      label: Text(
                        targets.isEmpty
                            ? 'เลือกแผนกหรือพนักงาน'
                            : 'เลือกแล้ว ${targets.length} รายการ',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final now = DateTime.now().toUtc();
                await api.post(
                  '/api/company/votes',
                  body: {
                    'name': name.text,
                    'targetMode': targetMode,
                    'identityMode': 'ANONYMOUS',
                    'openAt': now
                        .add(const Duration(hours: 1))
                        .toIso8601String(),
                    'closeAt': now
                        .add(const Duration(hours: 73))
                        .toIso8601String(),
                    'options': [a.text, b.text],
                    'targets': targets,
                  },
                );
                if (c.mounted) Navigator.pop(c);
                reload();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>?> _pickTargets(
    List<Map<String, dynamic>> initial,
  ) async {
    final data = Map<String, dynamic>.from(
      await api.get('/api/company/votes/target-options') as Map,
    );
    if (!mounted) return null;
    final departments = data['departments'] as List? ?? const [];
    final employees = data['employees'] as List? ?? const [];
    final selected = <String, Map<String, dynamic>>{
      for (final item in initial) '${item['type']}:${item['id']}': item,
    };
    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('เลือกผู้มีสิทธิ์โหวต'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: ListView(
              children: [
                const Text('แผนก'),
                for (final item in departments)
                  CheckboxListTile(
                    value: selected.containsKey('DEPARTMENT:${item['id']}'),
                    title: Text('${item['name']}'),
                    onChanged: (checked) => setDialogState(() {
                      final key = 'DEPARTMENT:${item['id']}';
                      if (checked == true) {
                        selected[key] = {
                          'type': 'DEPARTMENT',
                          'id': item['id'],
                        };
                      } else {
                        selected.remove(key);
                      }
                    }),
                  ),
                const Divider(),
                const Text('พนักงาน'),
                for (final item in employees)
                  CheckboxListTile(
                    value: selected.containsKey('EMPLOYEE:${item['id']}'),
                    title: Text('${item['code']} | ${item['name']}'),
                    onChanged: (checked) => setDialogState(() {
                      final key = 'EMPLOYEE:${item['id']}';
                      if (checked == true) {
                        selected[key] = {'type': 'EMPLOYEE', 'id': item['id']};
                      } else {
                        selected.remove(key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, selected.values.toList()),
              child: const Text('ใช้รายชื่อที่เลือก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(Object id) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/company/votes/$id') as Map,
    );
    if (!mounted) return;
    final topic = Map<String, dynamic>.from(value['topic'] as Map);
    final options = value['options'] as List? ?? const [];
    final name = TextEditingController(text: '${topic['name'] ?? ''}');
    final description = TextEditingController(
      text: '${topic['description'] ?? ''}',
    );
    final a = TextEditingController(
      text: options.isNotEmpty ? '${(options[0] as Map)['text']}' : '',
    );
    final b = TextEditingController(
      text: options.length > 1 ? '${(options[1] as Map)['text']}' : '',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('แก้ไขหัวข้อโหวต'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อหัวข้อ *'),
              ),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'รายละเอียด'),
              ),
              TextField(
                controller: a,
                decoration: const InputDecoration(labelText: 'ตัวเลือก 1 *'),
              ),
              TextField(
                controller: b,
                decoration: const InputDecoration(labelText: 'ตัวเลือก 2 *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              await api.put(
                '/api/company/votes/$id',
                body: {
                  'name': name.text,
                  'description': description.text,
                  'targetMode': topic['targetMode'],
                  'identityMode': topic['identityMode'],
                  'openAt': topic['openAt'],
                  'closeAt': topic['closeAt'],
                  'options': [a.text, b.text],
                  'targets': value['targets'] ?? const [],
                },
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              reload();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Map x) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบหัวข้อโหวต'),
        content: Text(
          'ลบ ${x['voteNo']} | ${x['name']} แล้วไม่สามารถเรียกคืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await api.delete('/api/company/votes/${x['id']}');
      reload();
    }
  }

  Future<void> _view(Object id) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/company/votes/$id') as Map,
    );
    if (!mounted) return;
    final topic = Map<String, dynamic>.from(value['topic'] as Map);
    final options = value['options'] as List? ?? [];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${topic['voteNo']} | ${topic['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สถานะ: ${topic['status']}'),
            Text('เปิด ${topic['openAt']} ถึง ${topic['closeAt']}'),
            const SizedBox(height: 12),
            const Text('ตัวเลือก'),
            for (final option in options) Text('• ${option['text']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
