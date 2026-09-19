import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../training/training_feature_host.dart';

class TrainingTestPage extends StatefulWidget {
  const TrainingTestPage({
    required this.bookingId,
    required this.initialSection,
    super.key,
  });

  final int bookingId;
  final String initialSection;

  @override
  State<TrainingTestPage> createState() => _TrainingTestPageState();
}

class _TrainingTestPageState extends State<TrainingTestPage>
    with SingleTickerProviderStateMixin {
  late final JsonApiClient _api;
  late final TabController _tabs;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _definition;
  Map<String, dynamic>? _attempt;
  Map<String, dynamic>? _results;
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _error = false;

  String get _section => _tabs.index == 0 ? 'PRE' : 'POST';
  String get _base =>
      '/api/company/training/bookings/${widget.bookingId}/tests';

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _tabs =
        TabController(
          length: 2,
          vsync: this,
          initialIndex: widget.initialSection == 'POST' ? 1 : 0,
        )..addListener(() {
          if (!_tabs.indexIsChanging) _loadSection();
        });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  List<Map<String, dynamic>> _items(dynamic value) =>
      (value as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  void _notice(String value, bool error) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _error = error;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _overview = _map(await _api.get(_base));
      await _loadSection(loading: false);
    } catch (error) {
      _notice(trainingErrorText(error), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSection({bool loading = true}) async {
    if (loading && mounted) setState(() => _loading = true);
    try {
      if (_overview?['canManage'] == true) {
        _definition = _map(await _api.get('$_base/$_section/definition'));
        _results = _map(
          await _api.get(
            '$_base/$_section/results',
            query: {'page': '1', 'pageSize': trainingPageSize.toString()},
          ),
        );
        _attempt = null;
      } else {
        _attempt = _map(await _api.post('$_base/$_section/attempt'));
        _definition = null;
        _results = null;
      }
    } catch (error) {
      _notice(trainingErrorText(error), true);
    } finally {
      if (loading && mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _exam =>
      Map<String, dynamic>.from(_definition?['definition'] as Map? ?? {});

  List<Map<String, dynamic>> get _questions => _items(_exam['questions']);

  Future<String?> _uploadImage() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = selected?.files.single;
    if (file?.bytes == null) return null;
    if (file!.bytes!.length > 1024 * 1024) {
      _notice('รูปภาพต้องมีขนาดไม่เกิน 1 MB', true);
      return null;
    }
    try {
      final response = _map(
        await _api.post(
          '$_base/images',
          body: {'base64': base64Encode(file.bytes!)},
        ),
      );
      return response['id'] as String?;
    } catch (error) {
      _notice(trainingErrorText(error), true);
      return null;
    }
  }

  Future<void> _save(Map<String, dynamic> exam) async {
    setState(() => _saving = true);
    try {
      await _api.put(
        '$_base/$_section/definition',
        body: {'definition': exam, 'rowVersion': _definition?['rowVersion']},
      );
      _notice('บันทึกชุดข้อสอบแล้ว', false);
      await _loadSection(loading: false);
    } catch (error) {
      _notice(trainingErrorText(error), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editQuestion([Map<String, dynamic>? current]) async {
    final question = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _QuestionEditor(current: current, onUploadImage: _uploadImage),
    );
    if (question == null) return;
    final questions = _questions;
    final index = current == null
        ? -1
        : questions.indexWhere((item) => item['id'] == current['id']);
    if (index < 0) {
      questions.add(question);
    } else {
      questions[index] = question;
    }
    final exam = _exam;
    exam['questions'] = questions;
    exam['questionCount'] = min(
      (exam['questionCount'] as num?)?.toInt() ?? questions.length,
      questions.length,
    );
    await _save(exam);
  }

  Future<void> _deleteQuestion(Map<String, dynamic> current) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteQuestionDialog(current: current),
    );
    if (accepted != true) return;
    final questions = _questions
        .where((item) => item['id'] != current['id'])
        .toList();
    final exam = _exam;
    exam['questions'] = questions;
    exam['questionCount'] = questions.isEmpty
        ? 1
        : min((exam['questionCount'] as num?)?.toInt() ?? 1, questions.length);
    await _save(exam);
  }

  Future<void> _saveAttempt(bool submit) async {
    final selected = Map<String, String>.from(
      _attempt?['_selected'] as Map? ?? {},
    );
    final answers = <Map<String, dynamic>>[];
    for (final question in _items(_attempt?['questions'])) {
      final option = selected['${question['id']}'];
      if (option != null) {
        answers.add({'questionId': question['id'], 'optionId': option});
      }
    }
    setState(() => _saving = true);
    try {
      _attempt = _map(
        await _api.put(
          '$_base/$_section/attempt',
          body: {
            'answers': answers,
            'submit': submit,
            'rowVersion': _attempt?['rowVersion'],
          },
        ),
      );
      _attempt!['_selected'] = selected;
      _notice(submit ? 'ส่งข้อสอบแล้ว' : 'บันทึกคำตอบแล้ว', false);
      if (submit) await _loadSection(loading: false);
    } catch (error) {
      _notice(trainingErrorText(error), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    return buildTrainingWorkspaceShell(
      pageTitle: 'แบบทดสอบก่อนและหลังอบรม',
      activeMenu: '',
      child: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                Card(
                  margin: tokens.workspace.contentMargin,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      tokens.workspace.radius,
                    ),
                  ),
                  child: Padding(
                    padding: tokens.workspace.cardPadding,
                    child: Row(
                      children: [
                        Icon(Icons.quiz_outlined, color: tokens.primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (_overview?['subject'] ?? 'การอบรม').toString(),
                            style: tokens.workspace.captionStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: tokens.primaryColor,
                  tabs: const [
                    Tab(text: 'ก่อนอบรม'),
                    Tab(text: 'หลังอบรม'),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: tokens.workspace.contentMargin,
                    child: _overview?['canManage'] == true
                        ? _manager(tokens)
                        : _participant(tokens),
                  ),
                ),
              ],
            ),
          if (_message != null)
            Positioned(
              top: 16,
              right: 16,
              child: buildTrainingMessage(
                message: _message!,
                error: _error,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _manager(TrainingUiTokens tokens) {
    final locked = _definition?['locked'] == true;
    final exam = _exam;
    final questions = _questions;
    final count = (exam['questionCount'] as num?)?.toInt() ?? 1;
    final passing = (exam['passingPercent'] as num?)?.toDouble() ?? 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.workspace.radius),
          ),
          child: Padding(
            padding: tokens.workspace.cardPadding,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Switch(
                  value: exam['isActive'] == true,
                  onChanged: locked
                      ? null
                      : (value) {
                          exam['isActive'] = value;
                          _save(exam);
                        },
                ),
                const Text('เปิดใช้งาน'),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    initialValue: count.toString(),
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนข้อที่สุ่ม',
                    ),
                    onFieldSubmitted: (value) {
                      exam['questionCount'] = int.tryParse(value) ?? count;
                      _save(exam);
                    },
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    initialValue: passing.toString(),
                    enabled: !locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'เกณฑ์ผ่าน (%)',
                    ),
                    onFieldSubmitted: (value) {
                      exam['passingPercent'] =
                          double.tryParse(value) ?? passing;
                      _save(exam);
                    },
                  ),
                ),
                if (!locked)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _editQuestion(),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มข้อสอบ'),
                  ),
                if (locked)
                  const Text('ล็อกการแก้ไข เพราะมีผู้เริ่มทำข้อสอบแล้ว'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (questions.isEmpty)
          _empty(tokens, 'ยังไม่มีข้อสอบ')
        else
          ...questions.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _questionCard(tokens, entry.key, entry.value, locked),
            ),
          ),
        const SizedBox(height: 10),
        _resultTable(tokens),
      ],
    );
  }

  Widget _questionCard(
    TrainingUiTokens tokens,
    int index,
    Map<String, dynamic> question,
    bool locked,
  ) {
    final options = _items(question['options']);
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.workspace.radius),
      ),
      child: Padding(
        padding: tokens.workspace.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ข้อ ${index + 1}', style: tokens.workspace.sectionStyle),
                const Spacer(),
                if (!locked)
                  IconButton(
                    onPressed: () => _editQuestion(question),
                    color: tokens.primaryColor,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (!locked)
                  IconButton(
                    onPressed: () => _deleteQuestion(question),
                    color: Colors.red,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if ((question['text'] as String?)?.isNotEmpty == true)
              Text(question['text'] as String),
            if (question['imageId'] != null)
              TrainingExamImage(
                bookingId: widget.bookingId,
                imageId: question['imageId'].toString(),
              ),
            const Divider(),
            ...options.asMap().entries.map(
              (entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}. ${entry.value['text'] ?? '(รูปภาพ)'}${entry.value['isCorrect'] == true ? ' ✓' : ''}',
                  ),
                  if (entry.value['imageId'] != null)
                    TrainingExamImage(
                      bookingId: widget.bookingId,
                      imageId: entry.value['imageId'].toString(),
                      compact: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participant(TrainingUiTokens tokens) {
    if (_attempt == null) return _empty(tokens, 'ยังไม่มีแบบทดสอบในช่วงนี้');
    if (_attempt?['submitted'] == true) {
      final passed = _attempt?['passed'] == true ? 'ผ่าน' : 'ไม่ผ่าน';
      return _empty(
        tokens,
        'ผลการทดสอบ: ${_attempt?['score'] ?? '-'} / ${_attempt?['maxScore'] ?? '-'} · $passed',
      );
    }
    final selected = Map<String, String>.from(
      _attempt?['_selected'] as Map? ??
          {
            for (final answer in _items(_attempt?['answers']))
              answer['questionId'].toString(): answer['optionId'].toString(),
          },
    );
    _attempt!['_selected'] = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_attempt?['canAnswer'] != true)
          _empty(tokens, 'อยู่นอกช่วงเวลาทำแบบทดสอบ'),
        ..._items(_attempt?['questions']).asMap().entries.map((entry) {
          final question = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.workspace.radius),
            ),
            child: Padding(
              padding: tokens.workspace.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อ ${entry.key + 1}',
                    style: tokens.workspace.sectionStyle,
                  ),
                  if ((question['text'] as String?)?.isNotEmpty == true)
                    Text(question['text'] as String),
                  if (question['imageId'] != null)
                    TrainingExamImage(
                      bookingId: widget.bookingId,
                      imageId: question['imageId'].toString(),
                    ),
                  const SizedBox(height: 8),
                  ..._items(question['options']).asMap().entries.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          side: BorderSide(
                            color:
                                selected[question['id'].toString()] ==
                                    option.value['id'].toString()
                                ? tokens.primaryColor
                                : tokens.borderColor,
                          ),
                        ),
                        onPressed: _attempt?['canAnswer'] == true
                            ? () => setState(() {
                                selected[question['id'].toString()] = option
                                    .value['id']
                                    .toString();
                                _attempt!['_selected'] = selected;
                              })
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${option.key + 1}. ${option.value['text'] ?? '(รูปภาพ)'}',
                            ),
                            if (option.value['imageId'] != null)
                              TrainingExamImage(
                                bookingId: widget.bookingId,
                                imageId: option.value['imageId'].toString(),
                                compact: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _saving || _attempt?['canAnswer'] != true
                  ? null
                  : () => _saveAttempt(false),
              child: const Text('บันทึกคำตอบ'),
            ),
            FilledButton.icon(
              onPressed: _saving || _attempt?['canAnswer'] != true
                  ? null
                  : () => _saveAttempt(true),
              icon: const Icon(Icons.send_outlined),
              label: const Text('ส่งข้อสอบ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultTable(TrainingUiTokens tokens) {
    final rows = _items(_results?['items']);
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.workspace.radius),
      ),
      child: Padding(
        padding: tokens.workspace.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('สรุปผลสอบ', style: tokens.workspace.sectionStyle),
            Text(
              'ผ่าน ${_results?['passed'] ?? 0} · ไม่ผ่าน ${_results?['failed'] ?? 0} · ยังไม่ส่ง ${_results?['unfinished'] ?? 0}',
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ลำดับ')),
                  DataColumn(label: Text('รหัส')),
                  DataColumn(label: Text('ชื่อ')),
                  DataColumn(label: Text('คะแนน')),
                  DataColumn(label: Text('ผล')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row['order'].toString())),
                          DataCell(Text(row['code'].toString())),
                          DataCell(Text(row['name'].toString())),
                          DataCell(
                            Text(
                              row['score'] == null
                                  ? '-'
                                  : '${row['score']}/${row['maxScore']}',
                            ),
                          ),
                          DataCell(Text(_resultText(row['result'].toString()))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultText(String value) {
    if (value == 'PASSED') return 'ผ่าน';
    if (value == 'FAILED') return 'ไม่ผ่าน';
    return 'ยังไม่ส่ง';
  }

  Widget _empty(TrainingUiTokens tokens, String value) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.workspace.radius),
    ),
    child: Padding(padding: tokens.workspace.cardPadding, child: Text(value)),
  );
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({required this.current, required this.onUploadImage});

  final Map<String, dynamic>? current;
  final Future<String?> Function() onUploadImage;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final TextEditingController _prompt;
  late final List<TextEditingController> _options;
  late String _questionId;
  late List<String> _optionIds;
  String? _promptImage;
  late List<String?> _optionImages;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _questionId = (current?['id'] ?? _uuid()).toString();
    _prompt = TextEditingController(text: current?['text'] as String? ?? '');
    final options = (current?['options'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    _options = List.generate(
      4,
      (index) => TextEditingController(
        text: index < options.length
            ? (options[index]['text'] ?? '').toString()
            : '',
      ),
    );
    _optionIds = List.generate(
      4,
      (index) =>
          index < options.length ? options[index]['id'].toString() : _uuid(),
    );
    _optionImages = List.generate(
      4,
      (index) =>
          index < options.length ? options[index]['imageId'] as String? : null,
    );
    _promptImage = current?['imageId'] as String?;
    _correct = options.indexWhere((option) => option['isCorrect'] == true);
    if (_correct < 0) _correct = 0;
  }

  @override
  void dispose() {
    _prompt.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _image(bool prompt, int index) async {
    final image = await widget.onUploadImage();
    if (image == null || !mounted) return;
    setState(() {
      if (prompt) {
        _promptImage = image;
      } else {
        _optionImages[index] = image;
      }
    });
  }

  @override
  Widget build(BuildContext context) => TrainingActionDialog(
    icon: Icons.quiz_outlined,
    title: widget.current == null ? 'เพิ่มข้อสอบ' : 'แก้ไขข้อสอบ',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _prompt,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'คำถาม'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _image(true, -1),
            icon: const Icon(Icons.image_outlined),
            label: Text(
              _promptImage == null ? 'เลือกรูปคำถาม' : 'เปลี่ยนรูปคำถาม',
            ),
          ),
        ),
        const Divider(),
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _options[index],
                    decoration: InputDecoration(
                      labelText: 'ตัวเลือก ${index + 1}',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _image(false, index),
                  icon: Icon(
                    Icons.image_outlined,
                    color: _optionImages[index] == null
                        ? null
                        : trainingUiTokens.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: _correct,
          decoration: const InputDecoration(labelText: 'คำตอบที่ถูกต้อง'),
          items: List.generate(
            4,
            (index) => DropdownMenuItem(
              value: index,
              child: Text('ตัวเลือก ${index + 1}'),
            ),
          ),
          onChanged: (value) => setState(() => _correct = value ?? 0),
        ),
        const SizedBox(height: 12),
        const Text('กำหนดคำตอบที่ถูกต้องได้เพียงข้อเดียว'),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (_prompt.text.trim().isEmpty && _promptImage == null) return;
          if (_options.asMap().entries.any(
            (entry) =>
                entry.value.text.trim().isEmpty &&
                _optionImages[entry.key] == null,
          )) {
            return;
          }
          Navigator.pop(context, {
            'id': _questionId,
            'text': _prompt.text.trim(),
            'imageId': _promptImage,
            'options': List.generate(
              4,
              (index) => {
                'id': _optionIds[index],
                'text': _options[index].text.trim(),
                'imageId': _optionImages[index],
                'isCorrect': index == _correct,
              },
            ),
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}

class _DeleteQuestionDialog extends StatelessWidget {
  const _DeleteQuestionDialog({required this.current});

  final Map<String, dynamic> current;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(trainingUiTokens.workspace.radius),
      side: const BorderSide(color: Colors.red),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: trainingUiTokens.workspace.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  'ยืนยันการลบข้อมูล',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(),
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text((current['text'] ?? 'ข้อสอบรูปภาพ').toString()),
            ),
            const SizedBox(height: 12),
            const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
            const Divider(),
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

class TrainingExamImage extends StatefulWidget {
  const TrainingExamImage({
    required this.bookingId,
    required this.imageId,
    this.compact = false,
    super.key,
  });

  final int bookingId;
  final String imageId;
  final bool compact;

  @override
  State<TrainingExamImage> createState() => _TrainingExamImageState();
}

class _TrainingExamImageState extends State<TrainingExamImage> {
  late final JsonApiClient _api;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _load();
  }

  @override
  void dispose() {
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/training/bookings/${widget.bookingId}/tests/images/${widget.imageId}',
            )
            as Map,
      );
      if (!mounted) return;
      setState(() => _bytes = base64Decode(value['base64'] as String));
    } catch (_) {
      // The question remains usable if a referenced file is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.compact ? 120 : 260),
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    );
  }
}

String _uuid() {
  final bytes = Uint8List(16);
  final random = Random.secure();
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = random.nextInt(256);
  }
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
