import 'package:flutter/material.dart';
import '../../app/theme/laoo_typography.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';

class PersonalApprovalDialog extends StatefulWidget {
  const PersonalApprovalDialog({
    super.key,
    required this.api,
    required this.menuCode,
    required this.menuName,
  });
  final ApiClient api;
  final String menuCode, menuName;
  @override
  State<PersonalApprovalDialog> createState() => _PersonalApprovalDialogState();
}

class _PersonalApprovalDialogState extends State<PersonalApprovalDialog> {
  List<Map<String, dynamic>> employees = [], saved = [];
  final List<int?> approvers = [];
  int? requester;
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.api.get(
        '/api/company/approval-assignment/${Uri.encodeComponent(widget.menuCode)}/personal',
      );
      if (data is! Map ||
          data['employees'] is! List ||
          data['steps'] is! List) {
        throw StateError('invalid response');
      }
      if (!mounted) return;
      setState(() {
        employees = (data['employees'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        saved = (data['steps'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'โหลดข้อมูลพนักงานไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  String employeeName(int? id) {
    for (final e in employees) {
      if (e['id'] == id) {
        return '${e['name']}${e['active'] == true ? '' : ' (ไม่ใช้งาน)'}';
      }
    }
    return id == null ? '' : 'ไม่พบพนักงาน';
  }

  Future<int?> chooseEmployee(String caption) async {
    var query = '';
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final matches = employees
              .where(
                (e) =>
                    e['active'] == true &&
                    '${e['name']} ${e['department']}'.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.person_search,
                  color: businessCardOcrUi(context).primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(caption)),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: MediaQuery.sizeOf(context).height * .5,
              child: Column(
                children: [
                  const Divider(thickness: .6),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: businessCardOcrUi(context).inputStyle,
                    decoration: ocrInput(
                      context,
                      'ค้นหาพนักงาน',
                      icon: Icons.search,
                    ),
                    onChanged: (v) => update(() => query = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('ไม่พบพนักงาน'))
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, thickness: .6),
                            itemBuilder: (context, i) => ListTile(
                              title: Text('${matches[i]['name']}'),
                              subtitle: Text('${matches[i]['department']}'),
                              onTap: () => Navigator.pop(
                                dialogContext,
                                matches[i]['id'] as int,
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
  }

  Future<void> chooseRequester() async {
    final selected = await chooseEmployee('ค้นหาผู้ทำรายการ');
    if (!mounted || selected == null) return;
    selectRequester(selected);
  }

  void selectRequester(int selected) {
    setState(() {
      requester = selected;
      approvers.clear();
      for (final s in saved.where((s) => s['requesterId'] == selected)) {
        approvers.add(s['approverId'] as int);
      }
      if (approvers.isEmpty) approvers.add(null);
    });
  }

  Future<void> chooseApprover(int index) async {
    final selected = await chooseEmployee('ค้นหาผู้อนุมัติ');
    if (!mounted || selected == null) return;
    if (selected == requester ||
        approvers.asMap().entries.any(
          (e) => e.key != index && e.value == selected,
        )) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกผู้อนุมัติที่ไม่ซ้ำและไม่ใช่ผู้ทำรายการ',
        error: true,
      );
      return;
    }
    setState(() => approvers[index] = selected);
  }

  Future<void> save() async {
    if (requester == null ||
        approvers.isEmpty ||
        approvers.any((id) => id == null)) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกผู้ทำรายการและผู้อนุมัติให้ครบ',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.put(
        '/api/company/approval-assignment/${Uri.encodeComponent(widget.menuCode)}/personal',
        body: {
          'requesterEmployeeId': requester,
          'approverEmployeeIds': approvers,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        showTimedSnackBar(
          context,
          message: 'บันทึกไม่สำเร็จ กรุณาตรวจสอบพนักงานและสิทธิ์ แล้วลองใหม่',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = businessCardOcrUi(context).primaryColor;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.manage_accounts_outlined, color: primary),
          const SizedBox(width: 10),
          Expanded(child: Text('เฉพาะบุคคล > ${widget.menuName}')),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: MediaQuery.sizeOf(context).height * .62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(thickness: .6),
            const SizedBox(height: 12),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(child: Center(child: Text(error!)))
            else ...[
              TextFormField(
                key: ValueKey('requester-$requester'),
                initialValue: employeeName(requester),
                readOnly: true,
                enabled: !saving,
                style: TextStyle(
                  fontSize: LaooTypography.inputText,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: ocrInput(
                  context,
                  'ผู้ทำรายการ',
                ).copyWith(suffixIcon: Icon(Icons.search, color: primary)),
                onTap: chooseRequester,
              ),
              const SizedBox(height: 12),
              const Text(
                'หากผู้ทำรายการมีการกำหนดเฉพาะบุคคล ระบบจะใช้ลำดับนี้แทนรูปแบบปกติของเมนู',
              ),
              const SizedBox(height: 10),
              if (requester == null && saved.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('ผู้ทำรายการที่กำหนดไว้'),
                ),
              Expanded(
                child: requester == null
                    ? savedRequesters()
                    : ListView.separated(
                        itemCount: approvers.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) => Row(
                          children: [
                            Text('${i + 1}'),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('approver-$i-${approvers[i]}'),
                                initialValue: employeeName(approvers[i]),
                                readOnly: true,
                                enabled: !saving,
                                decoration: ocrInput(context, 'ผู้อนุมัติ')
                                    .copyWith(
                                      suffixIcon: Icon(
                                        Icons.search,
                                        color: primary,
                                      ),
                                    ),
                                onTap: () => chooseApprover(i),
                              ),
                            ),
                            IconButton(
                              tooltip: 'เลื่อนขึ้น',
                              onPressed: saving || i == 0
                                  ? null
                                  : () => setState(() {
                                      final item = approvers.removeAt(i);
                                      approvers.insert(i - 1, item);
                                    }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'เลื่อนลง',
                              onPressed: saving || i == approvers.length - 1
                                  ? null
                                  : () => setState(() {
                                      final item = approvers.removeAt(i);
                                      approvers.insert(i + 1, item);
                                    }),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'นำออก',
                              onPressed: saving
                                  ? null
                                  : () => setState(() => approvers.removeAt(i)),
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: requester == null || saving
                      ? null
                      : () => setState(() => approvers.add(null)),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มลำดับ'),
                ),
              ),
            ],
            const Divider(thickness: .6),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: loading || error != null || saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }

  Widget savedRequesters() {
    final ids = saved
        .map((step) => step['requesterId'])
        .whereType<int>()
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const Center(child: Text('ยังไม่มีการกำหนดเฉพาะบุคคล'));
    }
    return ListView.separated(
      itemCount: ids.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final id = ids[index];
        final count = saved.where((step) => step['requesterId'] == id).length;
        final primary = businessCardOcrUi(context).primaryColor;
        return ListTile(
          tileColor: primary.withValues(alpha: .08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text(
            employeeName(id),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('ผู้อนุมัติ $count ลำดับ'),
          trailing: Icon(Icons.chevron_right, color: primary),
          onTap: saving ? null : () => selectRequester(id),
        );
      },
    );
  }
}
