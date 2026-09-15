import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../training/training_feature_host.dart';
import '../training/training_route_contract.dart';

class TrainingMasterPage extends StatefulWidget {
  const TrainingMasterPage.types({super.key}) : _kind = _MasterKind.types;
  const TrainingMasterPage.instructors({super.key})
    : _kind = _MasterKind.instructors;
  final _MasterKind _kind;
  @override
  State<TrainingMasterPage> createState() => _TrainingMasterPageState();
}

enum _MasterKind { types, instructors }

class _TrainingMasterPageState extends State<TrainingMasterPage> {
  final search = TextEditingController();
  late final JsonApiClient api;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> items = [];
  int page = 1, total = 0;
  bool? active = true;
  bool loading = true, error = false;
  String? message;
  bool get instructors => widget._kind == _MasterKind.instructors;
  String get path => instructors
      ? '/api/company/training/instructors'
      : '/api/company/training/types';
  String get menuCode =>
      instructors ? TrainingMenuCodes.instructors : TrainingMenuCodes.types;
  IconData get icon =>
      instructors ? Icons.person_outline : Icons.category_outlined;

  @override
  void initState() {
    super.initState();
    api = createTrainingApiClient();
    _initialize();
  }

  @override
  void dispose() {
    search.dispose();
    disposeTrainingApiClient(api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      actions = Map<String, dynamic>.from(
        await api.get('$path/actions') as Map,
      );
      await _load();
    } catch (e) {
      _notice(trainingErrorText(e), true);
    }
  }

  Future<void> _load({int target = 1}) async {
    setState(() => loading = true);
    try {
      final value = Map<String, dynamic>.from(
        await api.get(
              path,
              query: {
                'page': '$target',
                'pageSize': '$trainingPageSize',
                if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
                if (active != null) 'isActive': '$active',
              },
            )
            as Map,
      );
      if (!mounted) return;
      setState(() {
        page = (value['page'] as num?)?.toInt() ?? target;
        total = (value['total'] as num?)?.toInt() ?? 0;
        items = (value['items'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
      });
    } catch (e) {
      _notice(trainingErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _notice(String text, bool isError) => setState(() {
    message = text;
    error = isError;
  });
  Future<void> _edit([Map<String, dynamic>? item]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MasterDialog(
        instructors: instructors,
        caption: actions?['caption'] as String? ?? '',
        item: item,
      ),
    );
    if (result == null) return;
    try {
      final id = result['id'];
      if (id == null) {
        await api.post(path, body: result);
      } else {
        await api.put('$path/$id', body: result);
      }
      await _load(target: page);
      _notice('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      _notice(trainingErrorText(e), true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TrainingActionDialog(
        icon: Icons.delete_outline,
        iconColor: Colors.red,
        title: 'ยืนยันการลบ',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text('${item['code']} — ${item['name']}'),
            ),
            const SizedBox(height: 12),
            const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(
        '$path/${item['id']}',
        query: {'rowVersion': '${item['rowVersion']}'},
      );
      await _load(target: page);
      _notice('ลบข้อมูลสำเร็จ', false);
    } catch (e) {
      _notice(trainingErrorText(e), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    final pages = total == 0 ? 1 : (total / trainingPageSize).ceil();
    return buildTrainingWorkspaceShell(
      pageTitle: actions?['caption'] as String? ?? '',
      activeMenu: menuCode,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: tokens.workspace,
            caption: LaooCaptionCard(
              tokens: tokens.workspace,
              caption: actions?['caption'] as String? ?? '',
              leading: Icon(icon, color: tokens.primaryColor),
              trailing: actions?['create'] == true
                  ? FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    )
                  : null,
            ),
            filter: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: search,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      labelText: 'ค้นหา',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: active,
                    decoration: const InputDecoration(labelText: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('ใช้งาน')),
                      DropdownMenuItem(value: false, child: Text('ไม่ใช้งาน')),
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    ],
                    onChanged: (value) => setState(() => active = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : _load,
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
                OutlinedButton(
                  onPressed: () {
                    search.clear();
                    setState(() => active = true);
                    _load();
                  },
                  child: const Text('ล้าง Filter'),
                ),
              ],
            ),
            table: loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        LaooWorkspaceTableColumns.id,
                        const DataColumn(label: Text('จัดการ')),
                        const DataColumn(label: Text('รหัส')),
                        DataColumn(
                          label: Text(
                            instructors ? 'ชื่อวิทยากร' : 'ประเภทการอบรม',
                          ),
                        ),
                        if (instructors)
                          const DataColumn(label: Text('สถาบัน')),
                        const DataColumn(label: Text('สถานะ')),
                      ],
                      rows: items.asMap().entries.map((entry) {
                        final x = entry.value;
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${(page - 1) * trainingPageSize + entry.key + 1}',
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (actions?['edit'] == true)
                                    IconButton(
                                      onPressed: () => _edit(x),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: tokens.primaryColor,
                                      ),
                                    ),
                                  if (actions?['delete'] == true)
                                    IconButton(
                                      onPressed: () => _delete(x),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text('${x['code']}')),
                            DataCell(Text('${x['name']}')),
                            if (instructors)
                              DataCell(Text('${x['instituteName'] ?? '-'}')),
                            DataCell(
                              Text(
                                x['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
            pagination: LaooPaginationCard(
              tokens: tokens.workspace,
              page: page,
              pageCount: pages,
              pageSize: trainingPageSize,
              total: total,
              onPrevious: page > 1 ? () => _load(target: page - 1) : null,
              onNext: page < pages ? () => _load(target: page + 1) : null,
            ),
          ),
          if (message != null)
            Positioned(
              right: 16,
              top: 16,
              child: buildTrainingMessage(
                message: message!,
                error: error,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _MasterDialog extends StatefulWidget {
  const _MasterDialog({
    required this.instructors,
    required this.caption,
    this.item,
  });
  final bool instructors;
  final String caption;
  final Map<String, dynamic>? item;
  @override
  State<_MasterDialog> createState() => _MasterDialogState();
}

class _MasterDialogState extends State<_MasterDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController code,
      name,
      phone,
      email,
      contactDate,
      institute,
      remark;
  late bool active;
  @override
  void initState() {
    super.initState();
    final x = widget.item;
    code = TextEditingController(text: x?['code'] as String?);
    name = TextEditingController(text: x?['name'] as String?);
    phone = TextEditingController(text: x?['phoneNumber'] as String?);
    email = TextEditingController(text: x?['email'] as String?);
    contactDate = TextEditingController(
      text: x?['contactStartDate'] as String?,
    );
    institute = TextEditingController(text: x?['instituteName'] as String?);
    remark = TextEditingController(text: x?['remark'] as String?);
    active = x?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      code,
      name,
      phone,
      email,
      contactDate,
      institute,
      remark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrainingActionDialog(
    icon: widget.instructors ? Icons.person_outline : Icons.category_outlined,
    title: '${widget.caption} > ${widget.item == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
          TextFormField(
            controller: code,
            decoration: const InputDecoration(
              labelText: 'รหัส (เว้นว่างให้ระบบสร้าง)',
            ),
            maxLength: 30,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: name,
            decoration: InputDecoration(
              labelText:
                  '${widget.instructors ? 'ชื่อวิทยากร' : 'ชื่อประเภทการอบรม'} *',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null,
          ),
          if (widget.instructors) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: email,
              decoration: const InputDecoration(labelText: 'อีเมล'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: contactDate,
              decoration: const InputDecoration(
                labelText: 'วันที่เริ่มติดต่อ (yyyy-MM-dd)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: institute,
              decoration: const InputDecoration(labelText: 'ชื่อสถาบัน'),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: remark,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'หมายเหตุ'),
          ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (key.currentState?.validate() != true) return;
          Navigator.pop(context, {
            'id': widget.item?['id'],
            'code': code.text.trim(),
            'name': name.text.trim(),
            'phoneNumber': phone.text.trim(),
            'email': email.text.trim(),
            'contactStartDate': contactDate.text.trim().isEmpty
                ? null
                : contactDate.text.trim(),
            'instituteName': institute.text.trim(),
            'remark': remark.text.trim(),
            'isActive': active,
            'rowVersion': widget.item?['rowVersion'],
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}
