import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'site_host.dart';

class SiteTasksDialog extends StatefulWidget {
  const SiteTasksDialog({
    super.key,
    required this.project,
    required this.api,
    required this.title,
  });
  final Map<String, dynamic> project;
  final JsonApiClient api;
  final String title;
  @override
  State<SiteTasksDialog> createState() => _SiteTasksDialogState();
}

class _SiteTasksDialogState extends State<SiteTasksDialog> {
  List<Map<String, dynamic>> tasks = [];
  bool loading = true;
  LaooWorkspaceUiTokens get tokens => siteTokens();
  String get path => '/api/company/site/projects/${widget.project['id']}/tasks';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.api.get(path) as List;
      tasks = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => loading = false);
    } catch (error) {
      if (mounted) {
        siteMessage(
          context,
          message: siteErrorText(error, 'โหลดงานย่อย'),
          error: true,
        );
        setState(() => loading = false);
      }
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: '${row?['name'] ?? ''}');
    final weight = TextEditingController(text: '${row?['weight'] ?? '1'}');
    final progress = TextEditingController(
      text: '${row?['progressPercent'] ?? '0'}',
    );
    var active = row?['active'] != false;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => LaooActionDialog(
          tokens: tokens,
          icon: Icons.rule_folder_outlined,
          title:
              '${widget.title} > ${row == null ? 'เพิ่มงานย่อย' : 'แก้ไขงานย่อย'}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'ชื่องาน *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'น้ำหนัก *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: progress,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ความคืบหน้า 0–100%',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                title: const Text('ใช้งาน'),
                value: active,
                onChanged: (v) => update(() => active = v),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final w = double.tryParse(weight.text),
                          p = double.tryParse(progress.text);
                      if (name.text.trim().isEmpty ||
                          w == null ||
                          w <= 0 ||
                          w > 100 ||
                          p == null ||
                          p < 0 ||
                          p > 100) {
                        siteMessage(
                          context,
                          message: 'กรอกชื่อ น้ำหนัก และความคืบหน้าให้ถูกต้อง',
                          error: true,
                        );
                        return;
                      }
                      update(() => saving = true);
                      try {
                        final body = {
                          'name': name.text.trim(),
                          'weight': w,
                          'progressPercent': p,
                          'sortOrder':
                              (row?['sortOrder'] as num?)?.toInt() ??
                              tasks.length * 10,
                          'active': active,
                        };
                        if (row == null) {
                          await widget.api.post(path, body: body);
                        } else {
                          await widget.api.put(
                            '$path/${row['id']}',
                            body: body,
                          );
                        }
                        if (dialog.mounted) Navigator.pop(dialog);
                        await load();
                        if (mounted) {
                          siteMessage(
                            this.context,
                            message: 'บันทึกงานย่อยแล้ว',
                            error: false,
                          );
                        }
                      } catch (error) {
                        if (dialog.mounted) {
                          siteMessage(
                            dialog,
                            message: siteErrorText(error, 'บันทึกงานย่อย'),
                            error: true,
                          );
                        }
                      } finally {
                        if (dialog.mounted) update(() => saving = false);
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
    weight.dispose();
    progress.dispose();
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: tokens,
    icon: Icons.rule_folder_outlined,
    title: '${widget.title} > งานย่อย',
    content: loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ยังไม่มีงานย่อย'),
                ),
              for (final task in tasks)
                ListTile(
                  title: Text('${task['name']}'),
                  subtitle: Text(
                    'น้ำหนัก ${task['weight']} · ความคืบหน้า ${task['progressPercent']}%',
                  ),
                  trailing: IconButton(
                    tooltip: 'แก้ไข',
                    onPressed: () => edit(task),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
            ],
          ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
      FilledButton.icon(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มงาน'),
      ),
    ],
  );
}
