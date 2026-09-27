import 'package:flutter/material.dart';

class EvaluationTemplateDialog extends StatefulWidget {
  const EvaluationTemplateDialog({
    super.key,
    this.initial,
    this.readOnly = false,
  });
  final Map<String, dynamic>? initial;
  final bool readOnly;

  @override
  State<EvaluationTemplateDialog> createState() =>
      _EvaluationTemplateDialogState();
}

class _EvaluationTemplateDialogState extends State<EvaluationTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  String _source = 'GENERAL';
  late final List<_QuestionDraft> _questions;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      _questions = [_QuestionDraft()];
      return;
    }
    _code.text = initial['code']?.toString() ?? '';
    _name.text = initial['name']?.toString() ?? '';
    _source = initial['sourceType']?.toString() ?? _source;
    _questions = (initial['questions'] as List? ?? [])
        .map(
          (item) =>
              _QuestionDraft.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    if (_questions.isEmpty) _questions.add(_QuestionDraft());
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    for (final question in _questions) {
      if (!question.isValid) {
        setState(() => question.showError = true);
        return;
      }
    }
    Navigator.pop(context, {
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'sourceType': _source,
      'questions': _questions.indexed.map((entry) {
        final index = entry.$1;
        final question = entry.$2;
        return {
          'text': question.text.text.trim(),
          'type': question.type,
          'isRequired': question.type == 'TEXT' ? question.required : true,
          'sortOrder': index + 1,
          'options': question.options.indexed
              .where((entry) => entry.$2.text.trim().isNotEmpty)
              .map(
                (entry) => {
                  'text': entry.$2.text.trim(),
                  'sortOrder': entry.$1 + 1,
                },
              )
              .toList(),
        };
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'แบบประเมิน > ${widget.readOnly
                    ? 'ดู'
                    : widget.initial == null
                    ? 'เพิ่ม'
                    : 'แก้ไข'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'รหัสแบบประเมิน *',
                ),
                readOnly: widget.readOnly,
                validator: widget.readOnly
                    ? null
                    : (value) => value == null || value.trim().isEmpty
                          ? 'กรุณาระบุรหัส'
                          : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'ชื่อแบบประเมิน *',
                ),
                readOnly: widget.readOnly,
                validator: widget.readOnly
                    ? null
                    : (value) => value == null || value.trim().isEmpty
                          ? 'กรุณาระบุชื่อ'
                          : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: const InputDecoration(labelText: 'ประเภทงาน *'),
                items: const [
                  DropdownMenuItem(
                    value: 'TRAINING_COURSE',
                    child: Text('หลักสูตรอบรม'),
                  ),
                  DropdownMenuItem(
                    value: 'TRAINING_INSTRUCTOR',
                    child: Text('วิทยากร'),
                  ),
                  DropdownMenuItem(
                    value: 'MEETING_ROOM',
                    child: Text('ห้องประชุม'),
                  ),
                  DropdownMenuItem(value: 'VENDOR', child: Text('Vendor')),
                  DropdownMenuItem(value: 'SERVICE', child: Text('งานบริการ')),
                  DropdownMenuItem(value: 'GENERAL', child: Text('ทั่วไป')),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (value) => setState(() => _source = value ?? _source),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'คำถาม',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.readOnly
                        ? null
                        : () =>
                              setState(() => _questions.add(_QuestionDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มคำถาม'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _questions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _QuestionEditor(
                    index: index,
                    draft: _questions[index],
                    readOnly: widget.readOnly,
                    canDelete: !widget.readOnly && _questions.length > 1,
                    onDelete: () => setState(() {
                      _questions[index].dispose();
                      _questions.removeAt(index);
                    }),
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  if (widget.readOnly)
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ปิด'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuestionDraft {
  final text = TextEditingController();
  String type = 'RATING_5';
  bool required = false;
  bool showError = false;
  final options = [TextEditingController(), TextEditingController()];
  _QuestionDraft();
  factory _QuestionDraft.fromMap(Map<String, dynamic> map) {
    final draft = _QuestionDraft();
    draft.text.text = map['text']?.toString() ?? '';
    draft.type = map['type']?.toString() ?? draft.type;
    draft.required = map['isRequired'] == true;
    final values = (map['options'] as List? ?? [])
        .map(
          (item) => Map<String, dynamic>.from(item as Map)['text'].toString(),
        )
        .toList();
    if (values.isNotEmpty) {
      for (final option in draft.options) {
        option.dispose();
      }
      draft.options
        ..clear()
        ..addAll(values.map((value) => TextEditingController(text: value)));
    }
    return draft;
  }
  bool get selectable => type == 'SINGLE_CHOICE' || type == 'MULTIPLE_CHOICE';
  bool get isValid =>
      text.text.trim().isNotEmpty &&
      (!selectable ||
          options.where((item) => item.text.trim().isNotEmpty).length >= 2);
  void dispose() {
    text.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.draft,
    required this.readOnly,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });
  final int index;
  final _QuestionDraft draft;
  final bool readOnly;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ข้อ ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          TextField(
            controller: draft.text,
            readOnly: readOnly,
            onChanged: readOnly ? null : (_) => onChanged(),
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: 'คำถาม *',
              errorText: draft.showError && draft.text.text.trim().isEmpty
                  ? 'กรุณาระบุคำถาม'
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: draft.type,
            decoration: const InputDecoration(labelText: 'รูปแบบคำถาม'),
            items: const [
              DropdownMenuItem(value: 'RATING_5', child: Text('คะแนน 1–5')),
              DropdownMenuItem(
                value: 'SINGLE_CHOICE',
                child: Text('เลือกหนึ่งข้อ'),
              ),
              DropdownMenuItem(
                value: 'MULTIPLE_CHOICE',
                child: Text('เลือกได้หลายข้อ'),
              ),
              DropdownMenuItem(value: 'TEXT', child: Text('ข้อความอิสระ')),
            ],
            onChanged: readOnly
                ? null
                : (value) {
                    draft.type = value ?? draft.type;
                    onChanged();
                  },
          ),
          if (draft.type == 'TEXT')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('บังคับตอบ'),
              value: draft.required,
              onChanged: readOnly
                  ? null
                  : (value) {
                      draft.required = value;
                      onChanged();
                    },
            ),
          if (draft.selectable) ...[
            const SizedBox(height: 8),
            Text(
              'ตัวเลือกอย่างน้อย 2 ค่า',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            ...draft.options.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: entry.$2,
                  readOnly: readOnly,
                  onChanged: readOnly ? null : (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'ตัวเลือก ${entry.$1 + 1}',
                    errorText:
                        draft.showError &&
                            entry.$1 < 2 &&
                            entry.$2.text.trim().isEmpty
                        ? 'กรุณาระบุตัวเลือก'
                        : null,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: readOnly
                    ? null
                    : () {
                        draft.options.add(TextEditingController());
                        onChanged();
                      },
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มตัวเลือก'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
