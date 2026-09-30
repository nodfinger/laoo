// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

part of 'survey_pages.dart';

extension _SurveyWorkflowDialogs on _SurveyPageState {
  Future<void> _approval(Map<String, dynamic> row) async {
    final detail = _SurveyPageState._map(
      await api.get('/api/company/surveys/${_SurveyPageState._id(row)}'),
    );
    if (!mounted) return;
    final questions = _SurveyPageState._rows(detail['questions']);
    final reason = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: surveyUiTokens,
        icon: Icons.fact_check_outlined,
        title: '$title > ตรวจสอบ',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_SurveyPageState._text(row, 'code')} · ${_SurveyPageState._text(row, 'name')}',
              style: surveyUiTokens.sectionStyle,
            ),
            const SizedBox(height: 16),
            Text(
              'ช่วงเวลา ${_SurveyPageState._date(row['openAt'])} ถึง ${_SurveyPageState._date(row['closeAt'])}',
            ),
            Text('จำนวนคำถาม ${questions.length} ข้อ'),
            const SizedBox(height: 16),
            ...questions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${q['number']}. ${q['text']} (${q['type']})'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              maxLines: 2,
              decoration: _input('เหตุผลกรณีส่งกลับ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (reason.text.trim().isEmpty) {
                showSurveyMessage(
                  context,
                  message: 'กรุณาระบุเหตุผลส่งกลับ',
                  error: true,
                );
                return;
              }
              Navigator.pop(dialogContext);
              await _run(
                () => api.post(
                  '/api/company/surveys/approvals/${_SurveyPageState._id(row)}',
                  body: {'action': 'RETURN', 'reason': reason.text.trim()},
                ),
                'ส่งกลับแก้ไขแล้ว',
              );
            },
            icon: const Icon(Icons.undo_outlined),
            label: const Text('ส่งกลับ'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _run(
                () => api.post(
                  '/api/company/surveys/approvals/${_SurveyPageState._id(row)}',
                  body: {'action': 'APPROVE', 'reason': null},
                ),
                'อนุมัติแบบสอบถามแล้ว',
              );
            },
            icon: const Icon(Icons.check_outlined),
            label: const Text('อนุมัติ'),
          ),
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _targets(int id, Map<String, dynamic> options) async {
    var mode = 'ALL';
    final selectedDepartments = <int>{};
    final selectedEmployees = <int>{};
    final departments = _SurveyPageState._rows(options['departments']);
    final employees = _SurveyPageState._rows(options['employees']);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: surveyUiTokens,
          width: 720,
          icon: Icons.group_add_outlined,
          title: '$title > กำหนดผู้ตอบ',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: _input('กลุ่มผู้ตอบ *'),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('พนักงาน Active ทั้งหมด'),
                  ),
                  DropdownMenuItem(
                    value: 'CUSTOM',
                    child: Text('กำหนดแผนกและพนักงาน'),
                  ),
                ],
                onChanged: (v) => setLocal(() => mode = v ?? 'ALL'),
              ),
              if (mode == 'CUSTOM') ...[
                const SizedBox(height: 16),
                Text('แผนก', style: surveyUiTokens.sectionStyle),
                ...departments.map((e) {
                  final value = (e['id'] as num).toInt();
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${e['code']} - ${e['name']}'),
                    value: selectedDepartments.contains(value),
                    activeColor: surveyUiTokens.primaryColor,
                    onChanged: (v) => setLocal(
                      () => v == true
                          ? selectedDepartments.add(value)
                          : selectedDepartments.remove(value),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text('พนักงานรายคน', style: surveyUiTokens.sectionStyle),
                SizedBox(
                  height: 260,
                  child: ListView(
                    children: employees.map((e) {
                      final value = (e['id'] as num).toInt();
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e['code']} - ${e['name']}'),
                        value: selectedEmployees.contains(value),
                        activeColor: surveyUiTokens.primaryColor,
                        onChanged: (v) => setLocal(
                          () => v == true
                              ? selectedEmployees.add(value)
                              : selectedEmployees.remove(value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (mode == 'CUSTOM' &&
                    selectedDepartments.isEmpty &&
                    selectedEmployees.isEmpty) {
                  showSurveyMessage(
                    context,
                    message: 'เลือกแผนกหรือพนักงานอย่างน้อย 1 รายการ',
                    error: true,
                  );
                  return;
                }
                try {
                  await api.put(
                    '/api/company/surveys/$id/targets',
                    body: {
                      'mode': mode,
                      'departmentIDs': selectedDepartments.toList(),
                      'employeeIDs': selectedEmployees.toList(),
                    },
                  );
                  await api.post('/api/company/surveys/$id/publish');
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  showSurveyMessage(
                    context,
                    message: 'กำหนดผู้ตอบ ตรึงสิทธิ์ และเผยแพร่แล้ว',
                  );
                  reload();
                } catch (error) {
                  if (context.mounted)
                    showSurveyMessage(context, message: '$error', error: true);
                }
              },
              icon: const Icon(Icons.publish_outlined),
              label: const Text('บันทึกและเผยแพร่'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _result(int id) async {
    final data = _SurveyPageState._map(
      await api.get('/api/company/surveys/results/$id'),
    );
    if (!mounted) return;
    final summary = _SurveyPageState._rows(data['summary']).firstOrNull ?? {};
    final questions = _SurveyPageState._rows(data['questions']);
    final options = _SurveyPageState._rows(data['options']);
    final audience = (summary['audienceCount'] as num?)?.toInt() ?? 0;
    final responded = (summary['respondedCount'] as num?)?.toInt() ?? 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: surveyUiTokens,
        width: 760,
        icon: Icons.analytics_outlined,
        title: '$title > ผลรายหัวข้อ',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_SurveyPageState._text(summary, 'code')} · ${_SurveyPageState._text(summary, 'name')}',
              style: surveyUiTokens.sectionStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'ตอบแล้ว $responded/$audience คน · ${audience == 0 ? '0' : (responded * 100 / audience).toStringAsFixed(1)}%',
            ),
            Text(
              summary['anonymous'] == true
                  ? 'ไม่เปิดเผยชื่อผู้ตอบ'
                  : 'เปิดเผยชื่อผู้ตอบตามสิทธิ์รายงาน',
            ),
            const SizedBox(height: 16),
            ...questions.map((q) {
              final qid = (q['id'] as num).toInt();
              final choices = options
                  .where((o) => (o['questionID'] as num).toInt() == qid)
                  .toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: surveyUiTokens.borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${q['number']}. ${q['text']}',
                      style: surveyUiTokens.sectionStyle,
                    ),
                    const SizedBox(height: 6),
                    if (q['type'] == 'SCALE')
                      Text('คะแนนเฉลี่ย ${q['average'] ?? '-'}')
                    else if (choices.isEmpty)
                      Text('จำนวนคำตอบ ${q['answerCount'] ?? 0}')
                    else
                      ...choices.map(
                        (o) => Text('• ${o['text']}: ${o['answerCount'] ?? 0}'),
                      ),
                  ],
                ),
              );
            }),
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

  Future<void> _respond(int id) async {
    final data = _SurveyPageState._map(
      await api.get('/api/company/surveys/mine/$id'),
    );
    if (!mounted) return;
    final header = _SurveyPageState._rows(data['header']).firstOrNull ?? {};
    final questions = _SurveyPageState._rows(data['questions']);
    final options = _SurveyPageState._rows(data['options']);
    final selected = <int, Set<int>>{};
    final texts = <int, TextEditingController>{};
    final numbers = <int, double>{};
    for (final q in questions)
      texts[(q['id'] as num).toInt()] = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: surveyUiTokens,
          width: 760,
          icon: Icons.edit_note_outlined,
          title: '$title > ตอบแบบสอบถาม',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_SurveyPageState._text(header, 'code')} · ${_SurveyPageState._text(header, 'name')}',
                style: surveyUiTokens.sectionStyle,
              ),
              if (header['anonymous'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('คำตอบนี้ไม่เปิดเผยชื่อผู้ตอบ'),
                ),
              const SizedBox(height: 16),
              ...questions.map(
                (q) => _answerEditor(
                  q,
                  options,
                  selected,
                  texts,
                  numbers,
                  setLocal,
                ),
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
                final answers = questions.map((q) {
                  final qid = (q['id'] as num).toInt();
                  final type = '${q['type']}';
                  final yesNo =
                      type == 'YES_NO' && (selected[qid]?.isNotEmpty ?? false)
                      ? (selected[qid]!.first == 1 ? 'YES' : 'NO')
                      : null;
                  return {
                    'questionID': qid,
                    'textValue':
                        yesNo ??
                        (texts[qid]!.text.trim().isEmpty
                            ? null
                            : texts[qid]!.text.trim()),
                    'numberValue': numbers[qid],
                    'optionIDs': type == 'YES_NO'
                        ? <int>[]
                        : selected[qid]?.toList() ?? <int>[],
                  };
                }).toList();
                try {
                  await api.post(
                    '/api/company/surveys/mine/$id/responses',
                    body: {'answers': answers},
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  showSurveyMessage(context, message: 'ส่งคำตอบแล้ว');
                  reload();
                } catch (error) {
                  if (context.mounted)
                    showSurveyMessage(context, message: '$error', error: true);
                }
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('ส่งคำตอบ'),
            ),
          ],
        ),
      ),
    );
    for (final controller in texts.values) controller.dispose();
  }

  Widget _answerEditor(
    Map<String, dynamic> q,
    List<Map<String, dynamic>> allOptions,
    Map<int, Set<int>> selected,
    Map<int, TextEditingController> texts,
    Map<int, double> numbers,
    StateSetter setLocal,
  ) {
    final id = (q['id'] as num).toInt();
    final type = '${q['type']}';
    final choices = allOptions
        .where((o) => (o['questionID'] as num).toInt() == id)
        .toList();
    selected.putIfAbsent(id, () => <int>{});
    if (type == 'SCALE') {
      numbers.putIfAbsent(id, () => (q['minValue'] as num?)?.toDouble() ?? 1);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: surveyUiTokens.borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${q['number']}. ${q['text']}${q['required'] == true ? ' *' : ''}',
            style: surveyUiTokens.sectionStyle,
          ),
          const SizedBox(height: 8),
          if (type == 'TEXT')
            TextField(
              controller: texts[id],
              maxLines: 3,
              decoration: _input('คำตอบ'),
            ),
          if (type == 'SCALE')
            Slider(
              value: numbers[id] ?? ((q['minValue'] as num?)?.toDouble() ?? 1),
              min: (q['minValue'] as num?)?.toDouble() ?? 1,
              max: (q['maxValue'] as num?)?.toDouble() ?? 5,
              divisions:
                  (((q['maxValue'] as num?)?.toInt() ?? 5) -
                          ((q['minValue'] as num?)?.toInt() ?? 1))
                      .clamp(1, 20),
              label: '${numbers[id] ?? q['minValue'] ?? 1}',
              activeColor: surveyUiTokens.primaryColor,
              onChanged: (v) => setLocal(() => numbers[id] = v),
            ),
          if (type == 'YES_NO') ...[
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: const Text('ใช่'),
              value: 1,
              groupValue: selected[id]!.firstOrNull,
              activeColor: surveyUiTokens.primaryColor,
              onChanged: (v) => setLocal(() => selected[id] = {v!}),
            ),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: const Text('ไม่ใช่'),
              value: 0,
              groupValue: selected[id]!.firstOrNull,
              activeColor: surveyUiTokens.primaryColor,
              onChanged: (v) => setLocal(() => selected[id] = {v!}),
            ),
          ],
          if (type == 'SINGLE')
            ...choices.map((o) {
              final oid = (o['id'] as num).toInt();
              return RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: Text('${o['text']}'),
                value: oid,
                groupValue: selected[id]!.firstOrNull,
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(() => selected[id] = {v!}),
              );
            }),
          if (type == 'MULTI')
            ...choices.map((o) {
              final oid = (o['id'] as num).toInt();
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${o['text']}'),
                value: selected[id]!.contains(oid),
                activeColor: surveyUiTokens.primaryColor,
                onChanged: (v) => setLocal(
                  () => v == true
                      ? selected[id]!.add(oid)
                      : selected[id]!.remove(oid),
                ),
              );
            }),
        ],
      ),
    );
  }
}
