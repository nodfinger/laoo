// ignore_for_file: curly_braces_in_flow_control_structures

part of 'survey_pages.dart';

extension _SurveyDocumentDialogs on _SurveyPageState {
  Future<void> _editSettings(
    Map<String, dynamic> current,
    Map<String, dynamic> options,
  ) async {
    var enabled = current['isEnabled'] == true;
    var approval = current['requireApproval'] != false;
    var anonymous = current['defaultAnonymous'] != false;
    var afterClose = current['resultsAfterClose'] != false;
    var approver = (current['defaultApproverEmployeeID'] as num?)?.toInt();
    final days = TextEditingController(
      text: '${current['defaultDurationDays'] ?? 14}',
    );
    final employees = _SurveyPageState._rows(options['employees']);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: surveyUiTokens,
          icon: Icons.settings_outlined,
          title: '$title > แก้ไข',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งานระบบ'),
                value: enabled,
                activeTrackColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => enabled = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: _input('ระยะเวลาเริ่มต้น (วัน) *'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: approver,
                decoration: _input('ผู้อนุมัติเริ่มต้น'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่กำหนด'),
                  ),
                  ...employees.map(
                    (e) => DropdownMenuItem<int?>(
                      value: (e['id'] as num).toInt(),
                      child: Text('${e['code']} - ${e['name']}'),
                    ),
                  ),
                ],
                onChanged: (v) => approver = v,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ต้องผ่านอนุมัติก่อนเผยแพร่'),
                value: approval,
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => approval = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ค่าเริ่มต้นไม่เปิดเผยชื่อ'),
                value: anonymous,
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => anonymous = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('แสดงผลหลังปิดแบบสอบถาม'),
                value: afterClose,
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => afterClose = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final value = int.tryParse(days.text);
                if (value == null || value < 1 || value > 365) {
                  showSurveyMessage(
                    context,
                    message: 'ระยะเวลาต้องอยู่ระหว่าง 1-365 วัน',
                    error: true,
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                await _run(
                  () => api.put(
                    '/api/company/surveys/settings',
                    body: {
                      'isEnabled': enabled,
                      'defaultDurationDays': value,
                      'requireApproval': approval,
                      'defaultAnonymous': anonymous,
                      'resultsAfterClose': afterClose,
                      'defaultApproverEmployeeID': approver,
                    },
                  ),
                  'บันทึกการตั้งค่าแล้ว',
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    days.dispose();
  }

  Future<void> _editDocument(int? id, Map<String, dynamic> options) async {
    Map<String, dynamic> header = {};
    List<Map<String, dynamic>> oldQuestions = [];
    List<Map<String, dynamic>> oldOptions = [];
    if (id != null) {
      final detail = _SurveyPageState._map(
        await api.get('/api/company/surveys/$id'),
      );
      header = _SurveyPageState._rows(detail['header']).firstOrNull ?? {};
      oldQuestions = _SurveyPageState._rows(detail['questions']);
      oldOptions = _SurveyPageState._rows(detail['options']);
    }
    if (!mounted) return;
    final code = TextEditingController(
      text: _SurveyPageState._text(header, 'code', ''),
    );
    final name = TextEditingController(
      text: _SurveyPageState._text(header, 'name', ''),
    );
    final description = TextEditingController(
      text: _SurveyPageState._text(header, 'description', ''),
    );
    final now = DateTime.now();
    final openAt = TextEditingController(
      text: _isoLocal(header['openAt'] ?? now),
    );
    final closeAt = TextEditingController(
      text: _isoLocal(header['closeAt'] ?? now.add(const Duration(days: 14))),
    );
    var anonymous = header['anonymous'] != false;
    var showAfterClose = header['showResultAfterClose'] != false;
    var approver = (header['approverEmployeeID'] as num?)?.toInt();
    final drafts = oldQuestions.map((q) {
      final qid = (q['id'] as num).toInt();
      final opts = oldOptions
          .where((o) => (o['questionID'] as num).toInt() == qid)
          .map((o) => '${o['text']}')
          .join('\n');
      return _QuestionDraft(
        text: '${q['text']}',
        type: '${q['type']}',
        required: q['required'] == true,
        options: opts,
        min: '${q['minValue'] ?? 1}',
        max: '${q['maxValue'] ?? 5}',
      );
    }).toList();
    if (drafts.isEmpty) drafts.add(_QuestionDraft());
    final employees = _SurveyPageState._rows(options['employees']);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: surveyUiTokens,
          width: 820,
          icon: id == null ? Icons.add_outlined : Icons.edit_outlined,
          title: '$title > ${id == null ? 'เพิ่ม' : 'แก้ไข'}',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Header', style: surveyUiTokens.sectionStyle),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: _input('รหัส (เว้นว่างเพื่อสร้างอัตโนมัติ)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: _input('ชื่อแบบสอบถาม *'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: _input('รายละเอียด'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: openAt,
                      decoration: _input('วันเวลาเปิด (yyyy-MM-dd HH:mm) *'),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: closeAt,
                      decoration: _input('วันเวลาปิด (yyyy-MM-dd HH:mm) *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: approver,
                decoration: _input('ผู้อนุมัติ'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ใช้ค่าเริ่มต้นระบบ'),
                  ),
                  ...employees.map(
                    (e) => DropdownMenuItem<int?>(
                      value: (e['id'] as num).toInt(),
                      child: Text('${e['code']} - ${e['name']}'),
                    ),
                  ),
                ],
                onChanged: (v) => approver = v,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ไม่เปิดเผยชื่อผู้ตอบ'),
                value: anonymous,
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => anonymous = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('แสดงผลหลังปิดแบบสอบถาม'),
                value: showAfterClose,
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => showAfterClose = v ?? true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detail · คำถาม',
                      style: surveyUiTokens.sectionStyle,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setLocal(() => drafts.add(_QuestionDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มคำถาม'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < drafts.length; i++)
                _questionEditor(i, drafts, setLocal),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final start = DateTime.tryParse(
                  openAt.text.replaceFirst(' ', 'T'),
                );
                final end = DateTime.tryParse(
                  closeAt.text.replaceFirst(' ', 'T'),
                );
                final questions = drafts.map((q) => q.toJson()).toList();
                final valid =
                    name.text.trim().isNotEmpty &&
                    start != null &&
                    end != null &&
                    start.isBefore(end) &&
                    questions.isNotEmpty &&
                    questions.every(
                      (q) =>
                          '${q['text']}'.isNotEmpty &&
                          (!(q['type'] == 'SINGLE' || q['type'] == 'MULTI') ||
                              (q['options'] as List).length >= 2),
                    );
                if (!valid) {
                  showSurveyMessage(
                    context,
                    message:
                        'กรอก Header/Detail ให้ครบ และคำถามแบบตัวเลือกต้องมีอย่างน้อย 2 ตัวเลือก',
                    error: true,
                  );
                  return;
                }
                final body = {
                  'code': code.text.trim().isEmpty ? null : code.text.trim(),
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'openAt': start.toIso8601String(),
                  'closeAt': end.toIso8601String(),
                  'isAnonymous': anonymous,
                  'showResultAfterClose': showAfterClose,
                  'approverEmployeeID': approver,
                  'questions': questions,
                };
                Navigator.pop(dialogContext);
                await _run(
                  () => id == null
                      ? api.post('/api/company/surveys', body: body)
                      : api.put('/api/company/surveys/$id', body: body),
                  'บันทึกแบบสอบถามแล้ว',
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    for (final q in drafts) q.dispose();
    code.dispose();
    name.dispose();
    description.dispose();
    openAt.dispose();
    closeAt.dispose();
  }

  Widget _questionEditor(
    int index,
    List<_QuestionDraft> drafts,
    StateSetter setLocal,
  ) {
    final q = drafts[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: surveyUiTokens.borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'คำถาม ${index + 1}',
                  style: surveyUiTokens.sectionStyle,
                ),
              ),
              if (drafts.length > 1)
                IconButton(
                  tooltip: 'ลบคำถาม',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => setLocal(() {
                    q.dispose();
                    drafts.removeAt(index);
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          TextField(controller: q.text, decoration: _input('คำถาม *')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: q.type,
            decoration: _input('ประเภทคำถาม *'),
            items: const [
              DropdownMenuItem(value: 'SINGLE', child: Text('เลือกข้อเดียว')),
              DropdownMenuItem(value: 'MULTI', child: Text('เลือกหลายข้อ')),
              DropdownMenuItem(value: 'SCALE', child: Text('ระดับคะแนน')),
              DropdownMenuItem(value: 'TEXT', child: Text('ข้อความ')),
              DropdownMenuItem(value: 'YES_NO', child: Text('ใช่/ไม่ใช่')),
            ],
            onChanged: (v) => setLocal(() => q.type = v ?? 'TEXT'),
          ),
          const SizedBox(height: 16),
          if (q.type == 'SINGLE' || q.type == 'MULTI')
            TextField(
              controller: q.options,
              minLines: 2,
              maxLines: 5,
              decoration: _input('ตัวเลือก (1 บรรทัดต่อ 1 ตัวเลือก) *'),
            ),
          if (q.type == 'SCALE')
            Wrap(
              spacing: 8,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: q.min,
                    keyboardType: TextInputType.number,
                    decoration: _input('คะแนนต่ำสุด *'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: q.max,
                    keyboardType: TextInputType.number,
                    decoration: _input('คะแนนสูงสุด *'),
                  ),
                ),
              ],
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('บังคับตอบ'),
            value: q.required,
            activeColor: surveyUiTokens.primaryColor,
            onChanged: (v) => setLocal(() => q.required = v ?? true),
          ),
        ],
      ),
    );
  }

  Future<void> _viewDocument(int id) async {
    final data = _SurveyPageState._map(
      await api.get('/api/company/surveys/$id'),
    );
    if (!mounted) return;
    final header = _SurveyPageState._rows(data['header']).firstOrNull ?? {};
    final questions = _SurveyPageState._rows(data['questions']);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: surveyUiTokens,
        icon: Icons.visibility_outlined,
        title: '$title > ดูรายการ',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_SurveyPageState._text(header, 'code')} · ${_SurveyPageState._text(header, 'name')}',
              style: surveyUiTokens.sectionStyle,
            ),
            const SizedBox(height: 16),
            Text('สถานะ: ${_SurveyPageState._text(header, 'status')}'),
            Text(
              'เปิด ${_SurveyPageState._date(header['openAt'])} ถึง ${_SurveyPageState._date(header['closeAt'])}',
            ),
            const SizedBox(height: 16),
            ...questions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${q['number']}. ${q['text']} (${q['type']})'),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final error = Theme.of(context).colorScheme.error;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: surveyUiTokens,
        icon: Icons.delete_outline,
        title: 'ยืนยันการลบข้อมูล',
        content: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: error.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${_SurveyPageState._text(row, 'code')} · ${_SurveyPageState._text(row, 'name')}\nข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: error),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (accepted == true)
      await _run(
        () => api.delete('/api/company/surveys/${_SurveyPageState._id(row)}'),
        'ลบแบบสอบถามแล้ว',
      );
  }

  String _isoLocal(dynamic value) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse('$value') ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }
}
