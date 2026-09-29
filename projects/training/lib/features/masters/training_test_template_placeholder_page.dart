import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../training/training_feature_host.dart';
import '../training/training_pagination_card.dart';
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
  String? _message;
  bool _messageError = false;
  bool get _canCreate =>
      _actions?['screenType'] == 1 && _actions?['create'] == true;
  bool get _canEdit =>
      _actions?['screenType'] == 1 && _actions?['edit'] == true;
  bool get _canDelete =>
      _actions?['screenType'] == 1 && _actions?['delete'] == true;

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
    setState(() {
      _loading = true;
      _error = null;
      _actions = null;
    });
    try {
      _actions = Map<String, dynamic>.from(
        await _api.get('$_path/actions') as Map,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = trainingErrorText(error);
          _loading = false;
        });
      }
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
    if (item == null ? !_canCreate : !_canEdit) return;
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
              : (onSelected) =>
                    _uploadImage((item['id'] as num).toInt(), onSelected),
          onSave: (request) async {
            if (item == null) {
              await _api.post(_path, body: request);
            } else {
              await _api.put('$_path/${item['id']}', body: request);
            }
          },
        ),
      );
      if (request == null) return;
      await _load(targetPage: _page);
      if (mounted) {
        setState(() {
          _message = 'บันทึกข้อมูลสำเร็จ';
          _messageError = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    }
  }

  Future<void> _clone(Map<String, dynamic> item) async {
    if (!_canCreate) return;
    try {
      await _api.post('$_path/${item['id']}/clone');
      await _load(targetPage: _page);
    } catch (error) {
      if (mounted) setState(() => _error = trainingErrorText(error));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!_canDelete) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => TrainingActionDialog(
        icon: Icons.delete_outline,
        destructive: true,
        title: 'ยืนยันการลบข้อมูล',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).colorScheme.error.withValues(alpha: .08),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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

  Future<_UploadedTemplateImage?> _uploadImage(
    int templateId,
    ValueChanged<Uint8List> onSelected,
  ) async {
    // The web implementation exposes this option but the shared interface does
    // not. Keep the web-only call here so native pickers retain their contract.
    final FilePickerResult? selected = kIsWeb
        ? await (FilePicker.platform as dynamic).pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
            withData: true,
            // Focus may return before change; rely on the input cancel event.
            cancelUploadOnWindowBlur: false,
          )
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
            withData: true,
          );
    final file = selected?.files.single;
    if (file == null) return null;
    if (file.bytes == null) {
      throw StateError('อ่านไฟล์รูปไม่ได้ กรุณาเลือกไฟล์ใหม่');
    }
    onSelected(file.bytes!);
    final bytes = await _fitImage(file.bytes!);
    if (bytes == null) throw StateError('ลดขนาดรูปไม่ได้ กรุณาเลือกไฟล์ใหม่');
    try {
      final response = Map<String, dynamic>.from(
        await _api.post(
              '$_path/$templateId/images',
              body: {'base64': base64Encode(bytes)},
            )
            as Map,
      );
      final imageId = response['id']?.toString();
      if (imageId == null || imageId.isEmpty) {
        throw StateError(
          'อัปโหลดรูปไม่ได้: ระบบไม่ส่งรหัสรูปกลับมา กรุณาลองใหม่',
        );
      }
      return _UploadedTemplateImage(imageId, bytes);
    } catch (error) {
      rethrow;
    }
  }

  Future<Uint8List?> _fitImage(Uint8List source) async {
    const limit = 1024 * 1024;
    if (source.length <= limit) return source;
    final decoded = image.decodeImage(source);
    if (decoded == null) {
      if (mounted) setState(() => _error = 'ไม่สามารถอ่านไฟล์รูปภาพได้');
      return null;
    }
    var current = decoded;
    for (var step = 0; step < 6; step++) {
      final encoded = image.encodeJpg(current, quality: 80 - step * 8);
      if (encoded.length <= limit) return Uint8List.fromList(encoded);
      current = image.copyResize(current, width: (current.width * .72).round());
    }
    if (mounted) {
      setState(
        () =>
            _error = 'ไม่สามารถลดขนาดรูปให้ต่ำกว่า 1 MB ได้ กรุณาเลือกรูปอื่น',
      );
    }
    return null;
  }

  String get _caption => _actions?['caption'] as String? ?? 'ชุดแบบทดสอบอบรม';

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    final pageCount = _total == 0 ? 1 : (_total / trainingPageSize).ceil();
    return buildTrainingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: TrainingMenuCodes.testTemplates,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: tokens.workspace,
            caption: LaooCaptionCard(
              tokens: tokens.workspace,
              caption: _caption,
              leading: Icon(Icons.quiz_outlined, color: tokens.primaryColor),
              trailing: _canCreate
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
                TrainingFilterField(
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
                TrainingFilterField(
                  width: 280,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _section,
                    decoration: const InputDecoration(
                      labelText: 'ช่วงแบบทดสอบ',
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'PRE', child: Text('ก่อนอบรม')),
                      DropdownMenuItem(value: 'POST', child: Text('หลังอบรม')),
                    ],
                    onChanged: (value) => setState(() => _section = value),
                  ),
                ),
                TrainingFilterField(
                  width: 280,
                  child: DropdownButtonFormField<bool?>(
                    isExpanded: true,
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
            table: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth < tokens.workspace.compactBreakpoint &&
                      !_loading &&
                      _error == null &&
                      _items.isNotEmpty
                  ? _buildCards(tokens)
                  : _buildTable(tokens.primaryColor),
            ),
            pagination: TrainingPaginationCard(
              tokens: tokens.workspace,
              page: _page,
              pageCount: pageCount,
              pageSize: trainingPageSize,
              total: _total,
              onPrevious: _page > 1 ? () => _load(targetPage: _page - 1) : null,
              onNext: _page < pageCount
                  ? () => _load(targetPage: _page + 1)
                  : null,
            ),
          ),
          if (_message != null)
            Positioned(
              right: 16,
              top: 16,
              child: buildTrainingMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCards(TrainingUiTokens tokens) => ListView.separated(
    itemCount: _items.length,
    separatorBuilder: (_, _) => SizedBox(height: tokens.workspace.itemSpacing),
    itemBuilder: (context, index) {
      final item = _items[index];
      return Card(
        margin: EdgeInsets.zero,
        color: tokens.workspace.surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.workspace.radius),
        ),
        child: Padding(
          padding: tokens.workspace.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${(_page - 1) * trainingPageSize + index + 1} · ${item['code'] ?? '-'}',
                style: tokens.workspace.sectionStyle.copyWith(
                  color: tokens.primaryColor,
                ),
              ),
              Text(
                '${item['name'] ?? '-'}',
                style: tokens.workspace.tableStyle,
              ),
              Text(
                '${item['section'] == 'POST' ? 'หลังอบรม' : 'ก่อนอบรม'} · ${item['questionCount'] ?? 0} ข้อ · เกณฑ์ผ่าน ${item['passingPercent'] ?? 0}%',
                style: tokens.workspace.tableStyle,
              ),
              Text(
                'คลัง ${item['bankCount'] ?? 0} ข้อ · v${item['versionNo'] ?? 1} · ${item['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'}',
                style: tokens.workspace.tableStyle,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  children: [
                    if (_canEdit)
                      IconButton(
                        tooltip: 'แก้ไข',
                        onPressed: () => _edit(item),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: tokens.primaryColor,
                        ),
                      ),
                    if (_canCreate)
                      IconButton(
                        tooltip: 'ทำสำเนา',
                        onPressed: () => _clone(item),
                        icon: Icon(
                          Icons.copy_outlined,
                          color: tokens.primaryColor,
                        ),
                      ),
                    if (_canDelete)
                      IconButton(
                        tooltip: 'ลบ',
                        onPressed: () => _delete(item),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildTable(Color primaryColor) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _initialize,
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, trainingUiTokens.workspace.buttonHeight),
                foregroundColor: trainingUiTokens.primaryColor,
                side: BorderSide(color: trainingUiTokens.primaryColor),
                textStyle: trainingUiTokens.workspace.buttonStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    trainingUiTokens.workspace.radius,
                  ),
                ),
              ),
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
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
                    if (_canEdit)
                      IconButton(
                        tooltip: 'แก้ไข',
                        onPressed: () => _edit(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (_canCreate)
                      IconButton(
                        tooltip: 'ทำสำเนา',
                        onPressed: () => _clone(item),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    if (_canDelete)
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
  const _TemplateDialog({
    required this.caption,
    this.item,
    this.onUploadImage,
    this.onSave,
  });

  final String caption;
  final Map<String, dynamic>? item;
  final Future<_UploadedTemplateImage?> Function(ValueChanged<Uint8List>)?
  onUploadImage;
  final Future<void> Function(Map<String, dynamic> request)? onSave;

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
  bool _saving = false;
  OverlayEntry? _saveErrorOverlay;
  Timer? _saveErrorTimer;

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
    if (item == null) {
      _definition['questions'] = <Map<String, dynamic>>[];
    }
    _definition['questionType'] =
        (_definition['questionType'] as String?) ?? 'SINGLE_CHOICE';
    if (_definition['questionType'] == 'TRUE_FALSE') {
      _definition['questions'] = _questions
          .map(_normalizeTrueFalseQuestion)
          .toList();
    }
    _questionCount = TextEditingController(
      text: '${_definition['questionCount'] as num? ?? 1}',
    );
    _passingPercent = TextEditingController(
      text: '${_definition['passingPercent'] as num? ?? 60}',
    );
  }

  Map<String, dynamic> _starterDefinition() => {
    'questionType': 'SINGLE_CHOICE',
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

  Map<String, dynamic> _normalizeTrueFalseQuestion(
    Map<String, dynamic> question,
  ) {
    final options = (question['options'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final correct = options.indexWhere((item) => item['isCorrect'] == true);
    return {
      ...question,
      'options': [
        {
          'id': options.isNotEmpty
              ? options[0]['id']
              : _QuestionDialogState._newId(),
          'text': 'ถูก',
          'imageId': null,
          'isCorrect': correct != 1,
        },
        {
          'id': options.length > 1
              ? options[1]['id']
              : _QuestionDialogState._newId(),
          'text': 'ผิด',
          'imageId': null,
          'isCorrect': correct == 1,
        },
      ],
    };
  }

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
        caption: widget.caption,
        question: index == null ? null : questions[index],
        trueFalse: _definition['questionType'] == 'TRUE_FALSE',
        onUploadImage: widget.onUploadImage,
        templateId: (widget.item?['id'] as num?)?.toInt(),
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

  Future<void> _saveTemplate() async {
    if (_formKey.currentState?.validate() != true) return;
    final definition = {
      ..._definition,
      'questionCount': int.parse(_questionCount.text),
      'passingPercent': double.parse(_passingPercent.text),
      'isActive': _isActive,
    };
    final request = {
      'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
      'name': _name.text.trim(),
      'section': _section,
      'isActive': _isActive,
      'definition': definition,
      if (widget.item?['rowVersion'] != null)
        'rowVersion': widget.item!['rowVersion'],
    };
    if (widget.onSave == null) {
      Navigator.pop(context, request);
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.onSave!(request);
      if (mounted) Navigator.pop(context, request);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
        _showSaveError(trainingErrorText(error));
      }
    }
  }

  void _showSaveError(String message) {
    _saveErrorTimer?.cancel();
    _saveErrorOverlay?.remove();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 12,
        right: 12,
        child: buildTrainingMessage(
          message: message,
          error: true,
          onClose: _dismissSaveError,
        ),
      ),
    );
    _saveErrorOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    _saveErrorTimer = Timer(const Duration(seconds: 6), _dismissSaveError);
  }

  void _dismissSaveError() {
    _saveErrorTimer?.cancel();
    _saveErrorTimer = null;
    _saveErrorOverlay?.remove();
    _saveErrorOverlay = null;
  }

  @override
  void dispose() {
    _dismissSaveError();
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
          SizedBox(height: trainingUiTokens.popupFieldSpacing),
          TextFormField(
            controller: _code,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'รหัส (เว้นว่างให้ระบบสร้าง)',
            ),
          ),
          SizedBox(height: trainingUiTokens.popupFieldSpacing),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'ชื่อชุดแบบทดสอบ *'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'กรุณาระบุชื่อชุดแบบทดสอบ'
                : null,
          ),
          SizedBox(height: trainingUiTokens.popupFieldSpacing),
          DropdownButtonFormField<String>(
            initialValue: _section,
            decoration: const InputDecoration(labelText: 'ช่วงแบบทดสอบ *'),
            items: const [
              DropdownMenuItem(value: 'PRE', child: Text('ก่อนอบรม')),
              DropdownMenuItem(value: 'POST', child: Text('หลังอบรม')),
            ],
            onChanged: (value) => setState(() => _section = value ?? 'PRE'),
          ),
          SizedBox(height: trainingUiTokens.popupFieldSpacing),
          DropdownButtonFormField<String>(
            initialValue:
                (_definition['questionType'] as String?) == 'TRUE_FALSE'
                ? 'TRUE_FALSE'
                : 'SINGLE_CHOICE',
            decoration: const InputDecoration(labelText: 'ประเภทข้อสอบ *'),
            items: const [
              DropdownMenuItem(
                value: 'SINGLE_CHOICE',
                child: Text('4 ตัวเลือก'),
              ),
              DropdownMenuItem(value: 'TRUE_FALSE', child: Text('ถูก / ผิด')),
            ],
            onChanged: _questions.isNotEmpty
                ? null
                : (value) {
                    if (value == null || value == _definition['questionType']) {
                      return;
                    }
                    final questions = _questions.map((question) {
                      if (value != 'TRUE_FALSE') return question;
                      final options = (question['options'] as List? ?? [])
                          .map((item) => Map<String, dynamic>.from(item as Map))
                          .toList();
                      final correct = options.indexWhere(
                        (item) => item['isCorrect'] == true,
                      );
                      return {
                        ...question,
                        'options': [
                          {
                            'id': _QuestionDialogState._newId(),
                            'text': 'ถูก',
                            'imageId': null,
                            'isCorrect': correct == 0 || correct < 0,
                          },
                          {
                            'id': _QuestionDialogState._newId(),
                            'text': 'ผิด',
                            'imageId': null,
                            'isCorrect': correct != 0,
                          },
                        ],
                      };
                    }).toList();
                    setState(
                      () => _definition = {
                        ..._definition,
                        'questionType': value,
                        'questions': questions,
                      },
                    );
                  },
          ),
          SizedBox(height: trainingUiTokens.popupFieldSpacing),
          TextFormField(
            controller: _questionCount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'จำนวนข้อที่ให้ทำ *',
              helperText:
                  'เช่น มี 30 ข้อ ให้ทำ 20 ข้อ: ระบุ 20 | ให้ทำครบทุกข้อ: ระบุเท่ากับจำนวนข้อสอบ',
            ),
            validator: (value) {
              final number = int.tryParse(value ?? '');
              final bankCount =
                  (_definition['questions'] as List? ?? []).length;
              return number == null || number < 1 || number > bankCount
                  ? 'ระบุจำนวน 1-$bankCount ข้อ'
                  : null;
            },
          ),
          SizedBox(height: trainingUiTokens.popupFieldSpacing),
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
              trueFalse: _definition['questionType'] == 'TRUE_FALSE',
              templateId: (widget.item?['id'] as num?)?.toInt(),
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
        onPressed: _saving ? null : _saveTemplate,
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
    required this.trueFalse,
    required this.templateId,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int number;
  final Map<String, dynamic> question;
  final bool trueFalse;
  final int? templateId;
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
        .take(trueFalse ? 2 : 4)
        .toList();
    final inferredTrueFalse =
        options.length >= 2 &&
        options[0]['text'] == 'ถูก' &&
        options[1]['text'] == 'ผิด';
    final isTrueFalse = trueFalse || inferredTrueFalse;
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
          if (templateId != null && question['imageId'] != null)
            _TemplateImage(
              templateId: templateId!,
              imageId: '${question['imageId']}',
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
          ...List<Widget>.generate(isTrueFalse ? options.length : 4, (index) {
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
  const _QuestionDialog({
    required this.caption,
    this.question,
    this.onUploadImage,
    this.templateId,
    this.trueFalse = false,
  });

  final String caption;
  final Map<String, dynamic>? question;
  final Future<_UploadedTemplateImage?> Function(ValueChanged<Uint8List>)?
  onUploadImage;
  final int? templateId;
  final bool trueFalse;

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
  Uint8List? _questionImagePreview;
  late final List<Uint8List?> _optionImagePreviews;
  int _correctIndex = 0;
  bool _uploading = false;

  int get _optionCount => widget.trueFalse ? 2 : 4;

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
      _optionCount,
      (index) => TextEditingController(
        text: widget.trueFalse
            ? (index == 0 ? 'ถูก' : 'ผิด')
            : index < options.length
            ? options[index]['text'] as String? ?? ''
            : '',
      ),
    );
    _optionIds = List.generate(
      _optionCount,
      (index) => index < options.length
          ? options[index]['id'] as String? ?? _newId()
          : _newId(),
    );
    _optionImageIds = List.generate(
      _optionCount,
      (index) =>
          index < options.length ? options[index]['imageId'] as String? : null,
    );
    _optionImagePreviews = List<Uint8List?>.filled(_optionCount, null);
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
    for (var index = 0; index < _optionCount; index++) {
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
        _optionCount,
        (index) => {
          'id': _optionIds[index],
          'text': _optionTexts[index].text.trim().isEmpty
              ? null
              : _optionTexts[index].text.trim(),
          'imageId': widget.trueFalse ? null : _optionImageIds[index],
          'isCorrect': index == _correctIndex,
        },
      ),
    });
  }

  void _showError(String text) {
    showDialog<void>(
      context: context,
      builder: (_) => TrainingActionDialog(
        icon: Icons.error_outline,
        title: 'ข้อมูลไม่ครบ',
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
    if (upload == null || _uploading) return;
    final oldPreview = question
        ? _questionImagePreview
        : _optionImagePreviews[option];
    setState(() => _uploading = true);
    try {
      final uploaded = await upload((bytes) {
        if (!mounted) return;
        setState(() {
          if (question) {
            _questionImagePreview = bytes;
          } else {
            _optionImagePreviews[option] = bytes;
          }
        });
      });
      if (uploaded == null || !mounted) return;
      setState(() {
        if (question) {
          _questionImageId = uploaded.id;
          _questionImagePreview = uploaded.bytes;
        } else {
          _optionImageIds[option] = uploaded.id;
          _optionImagePreviews[option] = uploaded.bytes;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (question) {
          _questionImagePreview = oldPreview;
        } else {
          _optionImagePreviews[option] = oldPreview;
        }
      });
      _showError(
        'ไม่สามารถแนบรูปภาพได้\nรายละเอียดเพิ่มเติม: ${trainingErrorText(error)}',
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeImage({required bool question, int option = 0}) async {
    final imageId = question ? _questionImageId : _optionImageIds[option];
    if (imageId == null || widget.templateId == null) return;
    final api = createTrainingApiClient();
    try {
      await api.delete(
        '/api/company/training/test-templates/${widget.templateId}/images/$imageId',
      );
      if (!mounted) return;
      setState(() {
        if (question) {
          _questionImageId = null;
          _questionImagePreview = null;
        } else {
          _optionImageIds[option] = null;
          _optionImagePreviews[option] = null;
        }
      });
    } finally {
      disposeTrainingApiClient(api);
    }
  }

  Widget _imageActions(
    String? imageId, {
    Uint8List? previewBytes,
    required bool question,
    int option = 0,
  }) => (imageId == null && previewBytes == null) || widget.templateId == null
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImagePreview(
              previewBytes: previewBytes,
              templateId: widget.templateId!,
              imageId: imageId ?? '',
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                trainingUiTokens.workspace.radius,
                              ),
                            ),
                            child: _ImagePreview(
                              previewBytes: previewBytes,
                              templateId: widget.templateId!,
                              imageId: imageId ?? '',
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),
                TextButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _removeImage(question: question, option: option),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบรูป'),
                ),
              ],
            ),
          ],
        );

  @override
  Widget build(BuildContext context) => TrainingActionDialog(
    icon: Icons.help_outline,
    title:
        '${widget.caption} > ข้อสอบ > ${widget.question == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_uploading) const LinearProgressIndicator(),
        if (_uploading) const Text('กำลังแนบรูปภาพ กรุณารอสักครู่'),
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
        _imageActions(
          _questionImageId,
          previewBytes: _questionImagePreview,
          question: true,
        ),
        const SizedBox(height: 18),
        if (!widget.trueFalse)
          const Text(
            'ตัวเลือก 1–4 และคำตอบที่ถูกต้อง',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        if (widget.trueFalse)
          const Text(
            'ถูก / ผิด และคำตอบที่ถูกต้อง',
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
                _optionCount,
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
                              readOnly: widget.trueFalse,
                              maxLength: 1000,
                              decoration: widget.trueFalse
                                  ? InputDecoration(
                                      labelText: index == 0 ? 'ถูก' : 'ผิด',
                                    )
                                  : InputDecoration(
                                      labelText: 'ตัวเลือก ${index + 1}',
                                    ),
                            ),
                            if (!widget.trueFalse) ...[
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
                              _imageActions(
                                _optionImageIds[index],
                                previewBytes: _optionImagePreviews[index],
                                question: false,
                                option: index,
                              ),
                            ],
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
        onPressed: _uploading ? null : _save,
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
  Widget build(BuildContext context) => TrainingActionDialog(
    icon: Icons.delete_outline,
    destructive: true,
    title: 'ยืนยันการลบข้อมูล',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.error.withValues(alpha: .08),
          child: Text(
            'ข้อ $number${(text?.trim().isNotEmpty ?? false) ? ': ${text!.trim()}' : ''}',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'เมื่อลบแล้ว ข้อสอบนี้จะไม่อยู่ในชุดข้อสอบและไม่สามารถเรียกคืนได้',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.delete_outline),
        label: const Text('ลบ'),
      ),
    ],
  );
}

class _UploadedTemplateImage {
  const _UploadedTemplateImage(this.id, this.bytes);

  final String id;
  final Uint8List bytes;
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.previewBytes,
    required this.templateId,
    required this.imageId,
  });

  final Uint8List? previewBytes;
  final int templateId;
  final String imageId;

  @override
  Widget build(BuildContext context) => previewBytes == null
      ? _TemplateImage(templateId: templateId, imageId: imageId)
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: Image.memory(previewBytes!, fit: BoxFit.contain),
          ),
        );
}

class _TemplateImage extends StatefulWidget {
  const _TemplateImage({required this.templateId, required this.imageId});
  final int templateId;
  final String imageId;
  @override
  State<_TemplateImage> createState() => _TemplateImageState();
}

class _TemplateImageState extends State<_TemplateImage> {
  late final dynamic _api = createTrainingApiClient();
  Uint8List? _bytes;
  String? _loadError;
  int _loadVersion = 0;
  @override
  void didUpdateWidget(covariant _TemplateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId ||
        oldWidget.templateId != widget.templateId) {
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _bytes = null;
      _loadError = null;
    });
    try {
      final value = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/training/test-templates/${widget.templateId}/images/${widget.imageId}',
            )
            as Map,
      );
      if (mounted && version == _loadVersion) {
        setState(() => _bytes = base64Decode(value['base64'] as String));
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _loadError = trainingErrorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _bytes == null
      ? _loadError == null
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('โหลดรูปภาพไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $_loadError'),
                  TextButton(
                    onPressed: _load,
                    child: const Text('ลองโหลดรูปใหม่'),
                  ),
                ],
              )
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: Image.memory(_bytes!, fit: BoxFit.contain),
          ),
        );
}
