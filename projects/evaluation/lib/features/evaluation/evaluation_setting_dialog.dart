import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';

const evaluationSourceLabels = <String, String>{
  'TRAINING_COURSE': 'หลักสูตรอบรม',
  'TRAINING_INSTRUCTOR': 'วิทยากร',
  'MEETING_ROOM': 'ห้องประชุม',
  'VENDOR': 'Vendor',
  'SERVICE': 'งานบริการ',
  'GENERAL': 'ทั่วไป',
};

class EvaluationSettingDialog extends StatefulWidget {
  const EvaluationSettingDialog({
    super.key,
    this.initial,
    this.readOnly = false,
  });
  final Map<String, dynamic>? initial;
  final bool readOnly;

  @override
  State<EvaluationSettingDialog> createState() =>
      _EvaluationSettingDialogState();
}

class _EvaluationSettingDialogState extends State<EvaluationSettingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final JsonApiClient _api;
  String _source = 'GENERAL';
  int? _templateId;
  bool _active = true;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _api = createEvaluationApiClient();
    final initial = widget.initial;
    _source = initial?['sourceType']?.toString() ?? _source;
    _templateId = (initial?['templateId'] as num?)?.toInt();
    _active = initial?['isActive'] != false;
    _loadTemplates();
  }

  @override
  void dispose() {
    disposeEvaluationApiClient(_api);
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.get(
        '/api/company/evaluations/templates',
        query: {'sourceType': _source},
      );
      final map = Map<String, dynamic>.from(raw as Map);
      final values = List<Map<String, dynamic>>.from(
        map['items'] as List? ?? [],
      );
      if (!mounted) return;
      setState(() {
        _templates = values
            .where((x) => x['isActive'] != false || x['id'] == _templateId)
            .toList();
        if (!_templates.any((x) => x['id'] == _templateId)) _templateId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'ไม่สามารถโหลดรายการแบบประเมินได้');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(context, {
      'sourceType': _source,
      'templateId': _templateId,
      'isActive': _active,
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ตั้งค่าระบบประเมิน > ${widget.readOnly
                        ? 'ดู'
                        : widget.initial == null
                        ? 'เพิ่ม'
                        : 'แก้ไข'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('สถานะ'),
                      const SizedBox(width: 8),
                      Switch(
                        value: _active,
                        onChanged: widget.readOnly
                            ? null
                            : (v) => setState(() => _active = v),
                      ),
                      Text(_active ? 'ใช้งาน' : 'ไม่ใช้งาน'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _source,
                    decoration: const InputDecoration(
                      labelText: 'ประเภทงาน *',
                      border: OutlineInputBorder(),
                    ),
                    items: evaluationSourceLabels.entries
                        .map(
                          (x) => DropdownMenuItem(
                            value: x.key,
                            child: Text(x.value),
                          ),
                        )
                        .toList(),
                    onChanged: widget.readOnly
                        ? null
                        : (v) {
                            if (v == null || v == _source) return;
                            setState(() {
                              _source = v;
                              _templateId = null;
                            });
                            _loadTemplates();
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _templates.any((x) => x['id'] == _templateId)
                        ? _templateId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'แบบประเมินเริ่มต้น *',
                      border: const OutlineInputBorder(),
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    items: _templates
                        .map(
                          (x) => DropdownMenuItem<int>(
                            value: (x['id'] as num).toInt(),
                            child: Text(
                              '${x['code']} | ${x['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (v) =>
                        v == null ? 'กรุณาเลือกแบบประเมินเริ่มต้น' : null,
                    onChanged: widget.readOnly || _loading
                        ? null
                        : (v) => setState(() => _templateId = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.readOnly)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ปิด'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
