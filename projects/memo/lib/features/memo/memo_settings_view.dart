import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'memo_feature_host.dart';

class MemoSettingsView extends StatefulWidget {
  const MemoSettingsView({
    super.key,
    required this.api,
    required this.value,
    required this.canEdit,
    required this.onSaved,
  });
  final JsonApiClient api;
  final Map<String, dynamic> value;
  final bool canEdit;
  final Future<void> Function() onSaved;
  @override
  State<MemoSettingsView> createState() => _State();
}

class _State extends State<MemoSettingsView> {
  late final max = TextEditingController(
    text: '${widget.value['maxAttachmentMb'] ?? 20}',
  );
  late final ext = TextEditingController(
    text:
        '${widget.value['allowedExtensions'] ?? 'pdf,doc,docx,xls,xlsx,ppt,pptx,jpg,jpeg,png'}',
  );
  late bool auto = widget.value['autoDistribute'] != false;
  bool saving = false;
  @override
  void dispose() {
    max.dispose();
    ext.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final size = int.tryParse(max.text);
    if (size == null || size < 1 || size > 200 || ext.text.trim().isEmpty) {
      memoMessage(context, 'ตรวจสอบขนาดไฟล์และนามสกุลที่อนุญาต', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.put(
        '/api/company/memo/settings',
        body: {
          'maxAttachmentMb': size,
          'allowedExtensions': ext.text.trim(),
          'autoDistribute': auto,
        },
      );
      if (mounted) memoMessage(context, 'บันทึกการตั้งค่าแล้ว');
      await widget.onSaved();
    } catch (e) {
      if (mounted) memoMessage(context, 'บันทึกไม่สำเร็จ: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LaooSurfaceCard(
    tokens: memoTokens,
    child: LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: c.maxWidth < 760 ? c.maxWidth : 760,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ค่าการทำงานปัจจุบัน',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                controller: max,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ขนาดไฟล์แนบสูงสุด (MB) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ext,
                enabled: widget.canEdit,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'นามสกุลไฟล์ที่อนุญาต *',
                  hintText: 'pdf,doc,docx,xlsx,jpg,png',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('แจกจ่ายอัตโนมัติเมื่ออนุมัติครบ'),
                value: auto,
                onChanged: widget.canEdit
                    ? (v) => setState(() => auto = v)
                    : null,
              ),
              const SizedBox(height: 16),
              if (widget.canEdit)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
