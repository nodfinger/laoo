import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../training/training_feature_host.dart';
import '../training/training_route_contract.dart';

class TrainingTestTemplatePlaceholderPage extends StatefulWidget {
  const TrainingTestTemplatePlaceholderPage({super.key});

  @override
  State<TrainingTestTemplatePlaceholderPage> createState() =>
      _TrainingTestTemplatePlaceholderPageState();
}

class _TrainingTestTemplatePlaceholderPageState
    extends State<TrainingTestTemplatePlaceholderPage> {
  static const _path = '/api/company/training/test-templates';
  final _search = TextEditingController();
  late final dynamic _api;
  Map<String, dynamic>? _actions;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _total = 0;
  String? _section;
  bool? _isActive = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _actions = Map<String, dynamic>.from(
        await _api.get('$_path/actions') as Map,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    }
  }

  Future<void> _load({int targetPage = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = Map<String, dynamic>.from(
        await _api.get(
              _path,
              query: {
                'page': '$targetPage',
                'pageSize': '$trainingPageSize',
                if (_search.text.trim().isNotEmpty)
                  'search': _search.text.trim(),
                if (_section?.isNotEmpty ?? false) 'section': _section!,
                if (_isActive != null) 'isActive': '$_isActive',
              },
            )
            as Map,
      );
      if (!mounted) return;
      setState(() {
        _page = (response['page'] as num?)?.toInt() ?? targetPage;
        _total = (response['total'] as num?)?.toInt() ?? 0;
        _items = (response['items'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _section = null;
      _isActive = true;
    });
    _load();
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    Map<String, dynamic>? detail;
    try {
      if (item != null) {
        detail = Map<String, dynamic>.from(
          await _api.get('$_path/${item['id']}') as Map,
        );
      }
      if (!mounted) return;
      final request = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TemplateDialog(
          caption: _caption,
          item: detail,
          onUploadImage: item == null
              ? null
              : () => _uploadImage((item['id'] as num).toInt()),
        ),
      );
      if (request == null) return;
      if (item == null) {
        await _api.post(_path, body: request);
      } else {
        await _api.put('$_path/${item['id']}', body: request);
      }
      await _load(targetPage: _page);
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    }
  }

  Future<void> _clone(Map<String, dynamic> item) async {
    try {
      await _api.post('$_path/${item['id']}/clone');
      await _load(targetPage: _page);
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => TrainingActionDialog(
        icon: Icons.delete_outline,
        iconColor: Colors.red,
        title: 'ยืนยันการลบข้อมูล',
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
    if (accepted != true) return;
    try {
      await _api.delete(
        '$_path/${item['id']}',
        query: {'rowVersion': '${item['rowVersion']}'},
      );
      await _load(targetPage: _page);
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    }
  }

  Future<String?> _uploadImage(int templateId) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = selected?.files.single;
    if (file?.bytes == null) return null;
    if (file!.bytes!.length > 1024 * 1024) {
      if (mounted) setState(() => _error = 'รูปภาพต้องมีขนาดไม่เกิน 1 MB');
      return null;
    }
    try {
      final response = Map<String, dynamic>.from(
        await _api.post(
              '$_path/$templateId/images',
              body: {'base64': base64Encode(file.bytes!)},
            )
            as Map,
      );
      return response['id']?.toString();
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
      return null;
    }
  }

  String get _caption => _actions?['caption'] as String? ?? 'ชุดแบบทดสอบอบรม';

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    final pageCount = _total == 0 ? 1 : (_total / trainingPageSize).ceil();
    return buildTrainingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: TrainingMenuCodes.testTemplates,
      child: LaooListWorkspace(
        tokens: tokens.workspace,
        caption: LaooCaptionCard(
          tokens: tokens.workspace,
          caption: _caption,
          leading: Icon(Icons.quiz_outlined, color: tokens.primaryColor),
          trailing: _actions?['create'] == true
              ? FilledButton.icon(
                  onPressed: _loading ? null : _edit,
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
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(
                  labelText: 'ค้นหารหัสหรือชื่อชุดแบบทดสอบ',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String?>(
                initialValue: _section,
                decoration: const InputDecoration(labelText: 'ช่วงแบบทดสอบ'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'PRE', child: Text('ก่อนอบรม')),
                  DropdownMenuItem(value: 'POST', child: Text('หลังอบรม')),
                ],
                onChanged: (value) => setState(() => _section = value),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<bool?>(
                initialValue: _isActive,
                decoration: const InputDecoration(labelText: 'สถานะ'),
                items: const [
                  DropdownMenuItem(value: true, child: Text('ใช้งาน')),
                  DropdownMenuItem(value: false, child: Text('ไม่ใช้งาน')),
                  DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                ],
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.search),
              label: const Text('ค้นหา'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('ล้าง Filter'),
            ),
          ],
        ),
        table: _buildTable(tokens.primaryColor),
        pagination: LaooPaginationCard(
          tokens: tokens.workspace,
          page: _page,
          pageCount: pageCount,
          pageSize: trainingPageSize,
          total: _total,
          onPrevious: _page > 1 ? () => _load(targetPage: _page - 1) : null,
          onNext: _page < pageCount ? () => _load(targetPage: _page + 1) : null,
        ),
      ),
    );
  }

  Widget _buildTable(Color primaryColor) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 42, color: primaryColor),
            const SizedBox(height: 12),
            const Text('ยังไม่มีชุดแบบทดสอบอบรม'),
            const SizedBox(height: 4),
            const Text('ปรับเงื่อนไขค้นหา หรือตรวจสอบรายการอีกครั้ง'),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('จัดการ')),
          DataColumn(label: Text('รหัส')),
          DataColumn(label: Text('ชื่อชุดแบบทดสอบ')),
          DataColumn(label: Text('ช่วง')),
          DataColumn(label: Text('สุ่มข้อสอบ')),
          DataColumn(label: Text('คลังข้อสอบ')),
          DataColumn(label: Text('เกณฑ์ผ่าน')),
          DataColumn(label: Text('เวอร์ชัน')),
          DataColumn(label: Text('สถานะ')),
        ],
        rows: _items.asMap().entries.map((entry) {
          final item = entry.value;
          return DataRow(
            cells: [
              DataCell(
                Text('${(_page - 1) * trainingPageSize + entry.key + 1}'),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_actions?['edit'] == true)
                      IconButton(
                        tooltip: 'แก้ไข',
                        onPressed: () => _edit(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (_actions?['create'] == true)
                      IconButton(
                        tooltip: 'ทำสำเนา',
                        onPressed: () => _clone(item),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    if (_actions?['delete'] == true)
                      IconButton(
                        tooltip: 'ลบ',
                        onPressed: () => _delete(item),
                        color: Colors.red,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
              DataCell(Text('${item['code'] ?? '-'}')),
              DataCell(Text('${item['name'] ?? '-'}')),
              DataCell(
                Text(item['section'] == 'POST' ? 'หลังอบรม' : 'ก่อนอบรม'),
              ),
              DataCell(Text('${item['questionCount'] ?? 0} ข้อ')),
              DataCell(Text('${item['bankCount'] ?? 0} ข้อ')),
              DataCell(Text('${item['passingPercent'] ?? 0}%')),
              DataCell(Text('v${item['versionNo'] ?? 1}')),
              DataCell(Text(item['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน')),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.caption, this.item, this.onUploadImage});

  final String caption;
  final Map<String, dynamic>? item;
  final Future<String?> Function()? onUploadImage;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _questionCount;
  late final TextEditingController _passingPercent;
  late String _section;
  late bool _isActive;
  late Map<String, dynamic> _definition;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _code = TextEditingController(text: item?['code'] as String? ?? '');
    _name = TextEditingController(text: item?['name'] as String? ?? '');
    _section = item?['section'] as String? ?? 'PRE';
    _isActive = item?['isActive'] as bool? ?? true;
    _definition = Map<String, dynamic>.from(
      item?['definition'] as Map? ?? _starterDefinition(),
    );
    _questionCount = TextEditingController(
      text: '${_definition['questionCount'] as num? ?? 1}',
    );
    _passingPercent = TextEditingController(
      text: '${_definition['passingPercent'] as num? ?? 60}',
    );
  }

  Map<String, dynamic> _starterDefinition() => {
    'questionCount': 1,
    'passingPercent': 60,
    'isActive': true,
    'questions': [
      {
        'id': '00000000-0000-0000-0000-000000000001',
        'text': 'ตัวอย่างคำถาม',
        'imageId': null,
        'options': [
          {
            'id': '00000000-0000-0000-0000-000000000011',
            'text': 'ตัวเลือก 1',
            'imageId': null,
            'isCorrect': true,
          },
          {
            'id': '00000000-0000-0000-0000-000000000012',
            'text': 'ตัวเลือก 2',
            'imageId': null,
            'isCorrect': false,
          },
          {
            'id': '00000000-0000-0000-0000-000000000013',
            'text': 'ตัวเลือก 3',
            'imageId': null,
            'isCorrect': false,
          },
          {
            'id': '00000000-0000-0000-0000-000000000014',
            'text': 'ตัวเลือก 4',
            'imageId': null,
            'isCorrect': false,
          },
        ],
      },
    ],
  };

  List<Map<String, dynamic>> get _questions =>
      (_definition['questions'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  void _setQuestions(List<Map<String, dynamic>> questions) {
    setState(() {
      _definition = {..._definition, 'questions': questions};
      final selectedCount = int.tryParse(_questionCount.text) ?? 1;
      if (selectedCount > questions.length) {
        _questionCount.text = questions.length.toString();
      }
    });
  }

  Future<void> _editQuestion({int? index}) async {
    final questions = _questions;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionDialog(
        question: index == null ? null : questions[index],
        onUploadImage: widget.onUploadImage,
      ),
    );
    if (result == null || !mounted) return;
    if (index == null) {
      questions.add(result);
    } else {
      questions[index] = result;
    }
    _setQuestions(questions);
  }

  Future<void> _deleteQuestion(int index) async {
    final questions = _questions;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _QuestionDeleteDialog(
        number: index + 1,
        text: questions[index]['text'] as String?,
      ),
    );
    if (confirmed != true || !mounted) return;
    questions.removeAt(index);
    _setQuestions(questions);
  }

  void _moveQuestion(int index, int direction) {
    final questions = _questions;
    final target = index + direction;
    if (target < 0 || target >= questions.length) return;
    final question = questions.removeAt(index);
    questions.insert(target, question);
    _setQuestions(questions);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _questionCount.dispose();
    _passingPercent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrainingActionDialog(
    icon: Icons.quiz_outlined,
    title: '${widget.caption} > ${widget.item == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('สถานะ'),
              const SizedBox(width: 8),
              Switch(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'รหัส (เว้นว่างให้ระบบสร้าง)',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'ชื่อชุดแบบทดสอบ *'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'กรุณาระบุชื่อชุดแบบทดสอบ'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _section,
            decoration: const InputDecoration(labelText: 'ช่วงแบบทดสอบ *'),
            items: const [
              DropdownMenuItem(value: 'PRE', child: Text('ก่อนอบรม')),
              DropdownMenuItem(value: 'POST', child: Text('หลังอบรม')),
            ],
            onChanged: (value) => setState(() => _section = value ?? 'PRE'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _questionCount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'จำนวนข้อที่สุ่ม *'),
            validator: (value) {
              final number = int.tryParse(value ?? '');
              final bankCount =
                  (_definition['questions'] as List? ?? []).length;
              return number == null || number < 1 || number > bankCount
                  ? 'ระบุจำนวน 1-$bankCount ข้อ'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passingPercent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'เกณฑ์ผ่าน (%) *'),
            validator: (value) {
              final number = double.tryParse(value ?? '');
              return number == null || number < 0 || number > 100
                  ? 'ระบุค่า 0-100'
                  : null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ข้อสอบ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _editQuestion,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มข้อสอบ'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._questions.asMap().entries.map(
            (entry) => _QuestionCard(
              number: entry.key + 1,
              question: entry.value,
              canMoveUp: entry.key > 0,
              canMoveDown: entry.key < _questions.length - 1,
              onEdit: () => _editQuestion(index: entry.key),
              onDelete: () => _deleteQuestion(entry.key),
              onMoveUp: () => _moveQuestion(entry.key, -1),
              onMoveDown: () => _moveQuestion(entry.key, 1),
            ),
          ),
          if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('ยังไม่มีข้อสอบ กรุณาเพิ่มข้อสอบอย่างน้อย 1 ข้อ'),
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
          if (_formKey.currentState?.validate() != true) return;
          _definition = {
            ..._definition,
            'questionCount': int.parse(_questionCount.text),
            'passingPercent': double.parse(_passingPercent.text),
            'isActive': _isActive,
          };
          Navigator.pop(context, {
            'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
            'name': _name.text.trim(),
            'section': _section,
            'isActive': _isActive,
            'definition': _definition,
            if (widget.item?['rowVersion'] != null)
              'rowVersion': widget.item!['rowVersion'],
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int number;
  final Map<String, dynamic> question;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final options = (question['options'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: trainingUiTokens.borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'ข้อ $number',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'เลื่อนขึ้น',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'เลื่อนลง',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: 'แก้ไขข้อสอบ',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'ลบข้อสอบ',
                onPressed: onDelete,
                color: Colors.red,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            (question['text'] as String?)?.trim().isNotEmpty == true
                ? question['text'] as String
                : 'คำถามเป็นรูปภาพ',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              question['imageId'] == null
                  ? 'เพิ่มรูปภาพคำถาม (เร็ว ๆ นี้)'
                  : 'มีรูปภาพคำถาม',
            ),
          ),
          const SizedBox(height: 6),
          ...List<Widget>.generate(4, (index) {
            final option = index < options.length
                ? options[index]
                : const <String, dynamic>{};
            final text = (option['text'] as String?)?.trim();
            final correct = option['isCorrect'] == true;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${index + 1}. ${text?.isNotEmpty == true ? text! : 'ตัวเลือกเป็นรูปภาพ'}${correct ? '  (คำตอบถูก)' : ''}',
                style: TextStyle(
                  color: correct ? trainingUiTokens.primaryColor : null,
                  fontWeight: correct ? FontWeight.w700 : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({this.question, this.onUploadImage});

  final Map<String, dynamic>? question;
  final Future<String?> Function()? onUploadImage;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  static int _idSeed = 0;
  late final TextEditingController _questionText;
  late final List<TextEditingController> _optionTexts;
  late final String _questionId;
  late final List<String> _optionIds;
  String? _questionImageId;
  late final List<String?> _optionImageIds;
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _questionId = question?['id'] as String? ?? _newId();
    _questionText = TextEditingController(
      text: question?['text'] as String? ?? '',
    );
    _questionImageId = question?['imageId'] as String?;
    final options = (question?['options'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    _optionTexts = List.generate(
      4,
      (index) => TextEditingController(
        text: index < options.length
            ? options[index]['text'] as String? ?? ''
            : '',
      ),
    );
    _optionIds = List.generate(
      4,
      (index) => index < options.length
          ? options[index]['id'] as String? ?? _newId()
          : _newId(),
    );
    _optionImageIds = List.generate(
      4,
      (index) =>
          index < options.length ? options[index]['imageId'] as String? : null,
    );
    final savedCorrect = options.indexWhere(
      (option) => option['isCorrect'] == true,
    );
    _correctIndex = savedCorrect < 0 ? 0 : savedCorrect;
  }

  static String _newId() {
    final value = (DateTime.now().microsecondsSinceEpoch + _idSeed++)
        .toRadixString(16);
    final padded = value
        .padLeft(32, '0')
        .substring(value.length > 32 ? value.length - 32 : 0);
    return '${padded.substring(0, 8)}-${padded.substring(8, 12)}-4000-8000-${padded.substring(20)}';
  }

  @override
  void dispose() {
    _questionText.dispose();
    for (final controller in _optionTexts) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_questionText.text.trim().isEmpty && _questionImageId == null) {
      _showError('กรุณาระบุคำถามหรือเพิ่มรูปภาพคำถาม');
      return;
    }
    for (var index = 0; index < 4; index++) {
      if (_optionTexts[index].text.trim().isEmpty &&
          _optionImageIds[index] == null) {
        _showError('กรุณาระบุตัวเลือก ${index + 1}');
        return;
      }
    }
    Navigator.pop(context, {
      'id': _questionId,
      'text': _questionText.text.trim().isEmpty
          ? null
          : _questionText.text.trim(),
      'imageId': _questionImageId,
      'options': List.generate(
        4,
        (index) => {
          'id': _optionIds[index],
          'text': _optionTexts[index].text.trim().isEmpty
              ? null
              : _optionTexts[index].text.trim(),
          'imageId': _optionImageIds[index],
          'isCorrect': index == _correctIndex,
        },
      ),
    });
  }

  void _showError(String text) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ข้อมูลไม่ครบ'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectImage({required bool question, int option = 0}) async {
    final upload = widget.onUploadImage;
    if (upload == null) return;
    final imageId = await upload();
    if (imageId == null || !mounted) return;
    setState(() {
      if (question) {
        _questionImageId = imageId;
      } else {
        _optionImageIds[option] = imageId;
      }
    });
  }

  @override
  Widget build(BuildContext context) => TrainingActionDialog(
    icon: Icons.help_outline,
    title: widget.question == null ? 'เพิ่มข้อสอบ' : 'แก้ไขข้อสอบ',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _questionText,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'คำถาม'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onUploadImage == null
              ? null
              : () => _selectImage(question: true),
          icon: const Icon(Icons.image_outlined),
          label: Text(
            _questionImageId == null ? 'เลือกรูปภาพคำถาม' : 'มีรูปภาพคำถาม',
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'ตัวเลือก 1–4 และคำตอบที่ถูกต้อง',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        RadioGroup<int>(
          groupValue: _correctIndex,
          onChanged: (value) => setState(() => _correctIndex = value ?? 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...List<Widget>.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Radio<int>(value: index),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _optionTexts[index],
                              maxLength: 1000,
                              decoration: InputDecoration(
                                labelText: 'ตัวเลือก ${index + 1}',
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: widget.onUploadImage == null
                                  ? null
                                  : () => _selectImage(
                                      question: false,
                                      option: index,
                                    ),
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                _optionImageIds[index] == null
                                    ? 'เลือกรูปภาพตัวเลือก'
                                    : 'มีรูปภาพตัวเลือก',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึกข้อสอบ'),
      ),
    ],
  );
}

class _QuestionDeleteDialog extends StatelessWidget {
  const _QuestionDeleteDialog({required this.number, required this.text});

  final int number;
  final String? text;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 34),
            const SizedBox(height: 10),
            const Text(
              'ลบข้อสอบ',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xffffebee),
              child: Text(
                'ข้อ $number${(text?.trim().isNotEmpty ?? false) ? ': ${text!.trim()}' : ''}',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'เมื่อลบแล้ว ข้อสอบนี้จะไม่อยู่ในชุดข้อสอบและไม่สามารถเรียกคืนได้',
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบ'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
