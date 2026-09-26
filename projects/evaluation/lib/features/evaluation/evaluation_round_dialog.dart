import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';

class EvaluationRoundDialog extends StatefulWidget {
  const EvaluationRoundDialog({super.key, this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<EvaluationRoundDialog> createState() => _EvaluationRoundDialogState();
}

class _EvaluationRoundDialogState extends State<EvaluationRoundDialog> {
  late final JsonApiClient _api;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _reference = TextEditingController();
  String _source = 'GENERAL';
  DateTime _openAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _closeAt = DateTime.now().add(const Duration(days: 7));
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _users = [];
  final Set<int> _respondents = {};
  int? _templateId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = createEvaluationApiClient();
    final initial = widget.initial;
    if (initial != null) {
      _name.text = initial['name']?.toString() ?? '';
      _reference.text = initial['referenceTitle']?.toString() ?? '';
      _source = initial['sourceType']?.toString() ?? _source;
      _templateId = (initial['templateId'] as num?)?.toInt();
      _openAt = DateTime.tryParse('${initial['openAt']}')?.toLocal() ?? _openAt;
      _closeAt =
          DateTime.tryParse('${initial['closeAt']}')?.toLocal() ?? _closeAt;
      for (final item in initial['respondents'] as List? ?? const []) {
        final id = (Map<String, dynamic>.from(item as Map)['id'] as num?)
            ?.toInt();
        if (id != null) _respondents.add(id);
      }
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _reference.dispose();
    disposeEvaluationApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/templates?sourceType=$_source')
            as Map,
      );
      final users = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/respondents') as Map,
      );
      if (!mounted) return;
      setState(() {
        _templates = (templates['items'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _users = (users['items'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (widget.initial == null) _templateId = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'โหลดข้อมูลสำหรับสร้างรอบไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสิทธิ์และลองโหลดใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool open) async {
    final current = open ? _openAt : _closeAt;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        current.hour,
        current.minute,
      );
      if (open) {
        _openAt = value;
      } else {
        _closeAt = value;
      }
    });
  }

  void _save() {
    if (_form.currentState?.validate() != true) {
      return;
    }
    if (_templateId == null ||
        _respondents.isEmpty ||
        !_closeAt.isAfter(_openAt)) {
      setState(
        () => _error =
            'ข้อมูลรอบประเมินไม่ครบ\nรายละเอียดเพิ่มเติม: กรุณาเลือก Template ผู้ตอบอย่างน้อย 1 คน และกำหนดวันปิดหลังวันเปิด',
      );
      return;
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'sourceType': _source,
      'templateId': _templateId,
      'openAt': _openAt.toUtc().toIso8601String(),
      'closeAt': _closeAt.toUtc().toIso8601String(),
      'respondentUserIds': _respondents.toList(),
      'referenceTitle': _reference.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'รอบประเมิน > ${widget.initial == null ? 'เพิ่ม' : 'แก้ไข'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) _RoundError(text: _error!),
                    TextFormField(
                      controller: _name,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อรอบประเมิน *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'กรุณาระบุชื่อรอบ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _source,
                      decoration: const InputDecoration(
                        labelText: 'ประเภทงาน *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'GENERAL',
                          child: Text('ทั่วไป'),
                        ),
                        DropdownMenuItem(
                          value: 'VENDOR',
                          child: Text('Vendor'),
                        ),
                      ],
                      onChanged: widget.initial != null
                          ? null
                          : (value) {
                              if (value != null && value != _source) {
                                setState(() => _source = value);
                                _load();
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _templateId,
                      decoration: const InputDecoration(
                        labelText: 'Template *',
                      ),
                      items: _templates
                          .map(
                            (item) => DropdownMenuItem(
                              value: (item['id'] as num).toInt(),
                              child: Text('${item['code']} | ${item['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _templateId = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reference,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'หัวข้ออ้างอิง',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('เปิด: ${_dateText(_openAt)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('ปิด: ${_dateText(_closeAt)}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ผู้ตอบ (${_respondents.length}) *',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_isSourceBound)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'ผู้ตอบอ้างอิงจากผู้เข้าร่วมที่ตอบรับและเช็กอินแล้ว จึงแก้ไขไม่ได้',
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (_, index) {
                          final user = _users[index];
                          final id = (user['id'] as num).toInt();
                          return CheckboxListTile(
                            value: _respondents.contains(id),
                            onChanged: _isSourceBound
                                ? null
                                : (checked) => setState(() {
                                    checked == true
                                        ? _respondents.add(id)
                                        : _respondents.remove(id);
                                  }),
                            title: Text(user['name'] as String),
                            subtitle: Text(user['username'] as String),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ยกเลิก'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึกร่าง'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    ),
  );

  bool get _isSourceBound =>
      widget.initial != null && _source != 'GENERAL' && _source != 'VENDOR';

  String _dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _RoundError extends StatelessWidget {
  const _RoundError({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Text(text),
  );
}
