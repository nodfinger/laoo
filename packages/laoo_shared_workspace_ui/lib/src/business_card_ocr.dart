import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'laoo_list_workspace.dart';

typedef BusinessCardGet =
    Future<dynamic> Function(String path, Map<String, String> query);
typedef BusinessCardUpload =
    Future<dynamic> Function(
      String path,
      Uint8List bytes,
      String name,
      Map<String, String> fields,
    );
typedef BusinessCardNotify =
    void Function(BuildContext context, String message, bool error);
const businessCardFields = <String, String>{
  'name': 'ชื่อผู้ติดต่อ',
  'company': 'ชื่อบริษัท',
  'position': 'ตำแหน่ง',
  'phone': 'โทรศัพท์',
  'email': 'อีเมล',
  'address': 'ที่อยู่',
  'website': 'เว็บไซต์',
  'line': 'LINE ID',
};

class BusinessCardImage {
  const BusinessCardImage(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

class BusinessCardImport {
  const BusinessCardImport({
    required this.values,
    required this.images,
    this.contactSlot = 1,
  });
  final Map<String, String> values;
  final List<BusinessCardImage> images;
  final int contactSlot;
  Map<String, String> forCustomer() {
    final slot = contactSlot == 2 ? 2 : 1;
    final mapping = {
      'company': 'cusName',
      'address': 'cusAddress',
      'website': 'website',
      'name': 'contName$slot',
      'position': 'positionName$slot',
      'phone': 'phone$slot',
      'email': 'email$slot',
    };
    return {
      for (final e in mapping.entries)
        if (values[e.key]?.trim().isNotEmpty == true)
          e.value: values[e.key]!.trim(),
    };
  }

  Map<String, String> forVisitor() => {
    for (final key in ['name', 'phone'])
      if (values[key]?.trim().isNotEmpty == true) key: values[key]!.trim(),
  };
}

Future<bool> confirmBusinessCardChanges(
  BuildContext context,
  LaooWorkspaceUiTokens tokens,
  Map<String, String> current,
  Map<String, String> changes,
  Map<String, String> labels,
) async {
  final conflicts = changes.entries
      .where(
        (e) =>
            current[e.key]?.trim().isNotEmpty == true &&
            current[e.key]!.trim() != e.value.trim(),
      )
      .toList();
  if (conflicts.isEmpty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => LaooActionDialog(
          tokens: tokens,
          icon: Icons.compare_arrows,
          title: 'ตรวจสอบข้อมูลที่จะเปลี่ยน',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ช่องที่ไม่ได้เลือกจะคงข้อมูลเดิมไว้'),
              for (final e in conflicts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    [
                      labels[e.key] ?? e.key,
                      current[e.key] ?? '',
                      '→ ${e.value}',
                    ].join('\n'),
                  ),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('ใช้ข้อมูลที่เลือก'),
            ),
          ],
        ),
      ) ??
      false;
}

/// HTTP adapters preserve the caller's current session and company scope.
class BusinessCardOcrButton extends StatefulWidget {
  const BusinessCardOcrButton({
    required this.tokens,
    required this.target,
    required this.get,
    required this.upload,
    required this.notify,
    required this.onImported,
    this.recordId,
    this.enabled = true,
    super.key,
  });
  final LaooWorkspaceUiTokens tokens;
  final String target;
  final int? recordId;
  final bool enabled;
  final BusinessCardGet get;
  final BusinessCardUpload upload;
  final BusinessCardNotify notify;
  final Future<void> Function(BusinessCardImport result) onImported;
  @override
  State<BusinessCardOcrButton> createState() => _BusinessCardOcrButtonState();
}

class _BusinessCardOcrButtonState extends State<BusinessCardOcrButton> {
  Map? _capabilities;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BusinessCardOcrButton old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target || old.recordId != widget.recordId) _load();
  }

  Future<void> _load() async {
    final target = widget.target, id = widget.recordId;
    try {
      final result = await widget.get(
        '/api/company/ocr/business-cards/capabilities',
        {'target': target, 'action': id == null ? 'CREATE' : 'EDIT'},
      );
      if (mounted && target == widget.target && id == widget.recordId) {
        setState(() => _capabilities = result as Map);
      }
    } catch (_) {
      if (mounted) setState(() => _capabilities = null);
    }
  }

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final result = await Navigator.of(context).push<BusinessCardImport>(
        MaterialPageRoute(
          builder: (_) => BusinessCardOcrPage(
            tokens: widget.tokens,
            target: widget.target,
            recordId: widget.recordId,
            get: widget.get,
            upload: widget.upload,
            notify: widget.notify,
            maxImageSizeMB: (_capabilities!['maxImageSizeMB'] as num).toInt(),
            engineAvailable: _capabilities!['engineAvailable'] == true,
          ),
        ),
      );
      if (result != null && mounted) await widget.onImported(result);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_capabilities?['isEnabled'] != true) return const SizedBox.shrink();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(48, widget.tokens.buttonHeight),
        textStyle: widget.tokens.buttonStyle,
        foregroundColor: widget.tokens.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.tokens.radius),
        ),
      ),
      onPressed: widget.enabled && !_opening ? _open : null,
      icon: const Icon(Icons.document_scanner_outlined),
      label: const Text('อ่านนามบัตร'),
    );
  }
}

class BusinessCardOcrPage extends StatefulWidget {
  const BusinessCardOcrPage({
    required this.tokens,
    required this.target,
    required this.get,
    required this.upload,
    required this.notify,
    required this.maxImageSizeMB,
    required this.engineAvailable,
    this.recordId,
    super.key,
  });
  final LaooWorkspaceUiTokens tokens;
  final String target;
  final int? recordId;
  final BusinessCardGet get;
  final BusinessCardUpload upload;
  final BusinessCardNotify notify;
  final int maxImageSizeMB;
  final bool engineAvailable;
  @override
  State<BusinessCardOcrPage> createState() => _BusinessCardOcrPageState();
}

class _BusinessCardOcrPageState extends State<BusinessCardOcrPage> {
  final _images = <BusinessCardImage?>[null, null];
  final _fields = {
    for (final key in businessCardFields.keys) key: TextEditingController(),
  };
  final _selected = <String>{};
  final _candidates = <String, List<String>>{};
  List<String> _lines = [];
  List<Map<String, dynamic>> _duplicates = [];
  bool _busy = false, _reviewed = false, _analyzed = false;
  int _side = 0, _slot = 1;
  String _assign = 'name';
  LaooWorkspaceUiTokens get t => widget.tokens;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _invalidate() {
    _analyzed = false;
    _reviewed = false;
    _lines = [];
    _duplicates = [];
    _candidates.clear();
    _selected.clear();
    for (final c in _fields.values) {
      c.clear();
    }
  }

  void _error(String message) {
    if (mounted) {
      widget.notify(
        context,
        '$message\nรายละเอียดเพิ่มเติม: ตรวจภาพและการเชื่อมต่อแล้วลองใหม่ ข้อมูลทะเบียนยังไม่ถูกบันทึก',
        true,
      );
    }
  }

  Future<void> _pick(bool camera) async {
    setState(() => _busy = true);
    try {
      Uint8List? bytes;
      String? name;
      if (camera) {
        final file = await ImagePicker().pickImage(source: ImageSource.camera);
        if (file != null) {
          bytes = await file.readAsBytes();
          name = file.name;
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );
        bytes = result?.files.single.bytes;
        name = result?.files.single.name;
      }
      if (!mounted || bytes == null || name == null) return;
      if (bytes.length > widget.maxImageSizeMB * 1024 * 1024) {
        _error('รูปใหญ่เกินค่าที่กำหนด');
        return;
      }
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null ||
          info.width < 32 ||
          info.height < 32 ||
          info.width * info.height > 20000000) {
        _error('ภาพต้องมีขนาดอย่างน้อย 32 พิกเซล และไม่เกิน 20 ล้านพิกเซล');
        return;
      }
      setState(() {
        _images[_side] = BusinessCardImage(bytes!, name!);
        _invalidate();
      });
    } catch (_) {
      _error('เลือกหรือถ่ายรูปไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transform(bool rotate) async {
    final source = _images[_side];
    if (source == null) return;
    setState(() => _busy = true);
    try {
      final decoder = img.findDecoderForData(source.bytes),
          info = img
              .findDecoderForData(source.bytes)
              ?.startDecode(source.bytes);
      if (info == null || info.width * info.height > 20000000) {
        _error('ภาพต้องไม่เกิน 20 ล้านพิกเซล');
        return;
      }
      final decoded = decoder?.decode(source.bytes);
      if (decoded == null) {
        _error('อ่านรูปไม่ได้');
        return;
      }
      final original = img.bakeOrientation(decoded);
      img.Image output;
      if (rotate) {
        output = img.copyRotate(original, angle: 90);
      } else {
        if (!mounted) return;
        final crop = await showDialog<Rect>(
          context: context,
          builder: (_) => _BusinessCardCrop(
            tokens: t,
            bytes: Uint8List.fromList(img.encodeJpg(original)),
          ),
        );
        if (!mounted || crop == null) return;
        final x = (crop.left * original.width).floor(),
            y = (crop.top * original.height).floor();
        output = img.copyCrop(
          original,
          x: x,
          y: y,
          width: (crop.width * original.width).floor().clamp(
            1,
            original.width - x,
          ),
          height: (crop.height * original.height).floor().clamp(
            1,
            original.height - y,
          ),
        );
      }
      final bytes = Uint8List.fromList(img.encodeJpg(output, quality: 95));
      if (bytes.length > widget.maxImageSizeMB * 1024 * 1024) {
        _error('ภาพที่แก้มีขนาดเกินค่ากำหนด');
        return;
      }
      if (mounted) {
        setState(() {
          _images[_side] = BusinessCardImage(bytes, 'business-card.jpg');
          _invalidate();
        });
      }
    } catch (_) {
      _error('แก้ไขภาพไม่ได้');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _invalidate();
    });
    try {
      final results = <Map>[];
      for (final image in _images.whereType<BusinessCardImage>()) {
        results.add(
          await widget.upload(
                '/api/company/ocr/business-cards/analyze',
                image.bytes,
                image.name,
                {
                  'target': widget.target,
                  'action': widget.recordId == null ? 'CREATE' : 'EDIT',
                  if (widget.recordId != null)
                    'recordId': widget.recordId.toString(),
                },
              )
              as Map,
        );
      }
      if (!mounted) return;
      setState(() {
        _lines = results
            .expand((r) => (r['text'] ?? '').toString().split('\n'))
            .where((s) => s.trim().isNotEmpty)
            .toList();
        for (final result in results) {
          for (final raw in result['suggestions'] as List? ?? []) {
            final field = raw['field'].toString();
            if (!_fields.containsKey(field)) continue;
            final options = _candidates.putIfAbsent(field, () => []);
            for (final candidate in raw['candidates'] as List? ?? []) {
              final value = candidate.toString().trim();
              if (value.isNotEmpty && !options.contains(value)) {
                options.add(value);
              }
            }
          }
        }
        for (final e in _candidates.entries) {
          if (e.value.isNotEmpty) {
            _fields[e.key]!.text = e.value.first;
            _selected.add(e.key);
          }
        }
        _analyzed = true;
      });
      if (_lines.isEmpty) _error('ไม่พบข้อความ ลองครอบภาพหรือถ่ายใหม่');
      await _checkDuplicates();
    } catch (_) {
      _error('อ่านนามบัตรไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkDuplicates() async {
    try {
      final rows = await widget.get(
        '/api/company/ocr/business-cards/duplicates',
        {
          'target': widget.target,
          for (final key in ['name', 'phone', 'email'])
            key: _fields[key]!.text.trim(),
        },
      );
      if (mounted) {
        setState(
          () => _duplicates = List<Map<String, dynamic>>.from(rows as List),
        );
      }
    } catch (_) {
      _error('ตรวจข้อมูลซ้ำไม่สำเร็จ');
    }
  }

  InputDecoration _input(String label) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(t.radius),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: t.inputStyle,
      floatingLabelStyle: t.inputStyle.copyWith(
        fontSize: (t.inputStyle.fontSize ?? 14) / .75,
      ),
      border: border(t.borderColor),
      enabledBorder: border(t.borderColor),
      disabledBorder: border(t.borderColor),
      focusedBorder: border(t.primaryColor),
      errorBorder: border(Theme.of(context).colorScheme.error),
      focusedErrorBorder: border(Theme.of(context).colorScheme.error),
    );
  }

  Widget _picture() => LaooSurfaceCard(
    tokens: t,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('1. ภาพนามบัตร', style: t.sectionStyle),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < 2; i++)
              ChoiceChip(
                label: Text(i == 0 ? 'ด้านหน้า' : 'ด้านหลัง'),
                selected: _side == i,
                onSelected: _busy ? null : (_) => setState(() => _side = i),
              ),
          ],
        ),
        SizedBox(
          height: 240,
          child: _images[_side] == null
              ? Center(
                  child: Text(
                    'JPG / PNG / WebP ไม่เกิน ${widget.maxImageSizeMB} MB',
                  ),
                )
              : InteractiveViewer(
                  child: Image.memory(
                    _images[_side]!.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => const Center(
                      child: Text('ภาพไม่ถูกต้อง กรุณาเลือกใหม่'),
                    ),
                  ),
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(false),
              icon: const Icon(Icons.upload_file),
              label: const Text('เลือกภาพ'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(true),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('ถ่ายรูป'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _images[_side] == null
                  ? null
                  : () => _transform(true),
              icon: const Icon(Icons.rotate_right),
              label: const Text('หมุน'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _images[_side] == null
                  ? null
                  : () => _transform(false),
              icon: const Icon(Icons.crop),
              label: const Text('ครอบภาพ'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _images[_side] = null;
                      _invalidate();
                    }),
              child: const Text('นำภาพออก'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              _busy || !_images.any((e) => e != null) || !widget.engineAvailable
              ? null
              : _read,
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(_busy ? 'กำลังประมวลผล…' : 'อ่านนามบัตร'),
        ),
        if (!widget.engineAvailable)
          const Text(
            'เครื่องมือ OCR ยังไม่พร้อม ให้ผู้ดูแลติดตั้ง Tesseract และภาษาไทย/อังกฤษ',
          ),
        if (_lines.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('ข้อความต้นฉบับ → เลือกช่องที่จะใส่', style: t.sectionStyle),
          DropdownButtonFormField<String>(
            initialValue: _assign,
            isExpanded: true,
            decoration: _input('ช่องปลายทาง'),
            items: [
              for (final e in businessCardFields.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _assign = v!),
          ),
          for (final line in _lines)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _fields[_assign]!.text = line;
                      _selected.add(_assign);
                      _reviewed = false;
                    }),
              child: Align(alignment: Alignment.centerLeft, child: Text(line)),
            ),
        ],
      ],
    ),
  );
  Widget _review() => LaooSurfaceCard(
    tokens: t,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('2. ตรวจแก้และเลือกข้อมูลที่จะนำเข้า', style: t.sectionStyle),
        const Text('คำแนะนำอาจจับคู่ผิด กรุณาตรวจเทียบกับภาพก่อนใช้'),
        if (widget.target == 'customers') ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _slot,
            isExpanded: true,
            decoration: _input('ผู้ติดต่อที่จะรับข้อมูล'),
            items: [
              for (var i = 1; i <= 2; i++)
                DropdownMenuItem(value: i, child: Text('ผู้ติดต่อคนที่ $i')),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _slot = v!;
                    _reviewed = false;
                  }),
          ),
          const Text('LINE ID ไม่ถูกนำเข้า เพราะทะเบียนลูกค้ายังไม่มีช่องนี้'),
        ],
        if (widget.target == 'visitors')
          const Text(
            'นำเข้าเฉพาะชื่อและโทรศัพท์ ไม่สร้างรายการเข้าพบอัตโนมัติ',
          ),
        for (final e in businessCardFields.entries)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _selected.contains(e.key),
                  onChanged: !_analyzed || _busy
                      ? null
                      : (v) => setState(() {
                          v == true
                              ? _selected.add(e.key)
                              : _selected.remove(e.key);
                          _reviewed = false;
                        }),
                ),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _fields[e.key],
                        enabled: _analyzed && !_busy,
                        style: t.inputStyle,
                        maxLines: e.key == 'address' ? 3 : 1,
                        decoration: _input(e.value),
                        onChanged: (_) => setState(() => _reviewed = false),
                      ),
                      if ((_candidates[e.key]?.length ?? 0) > 1)
                        Wrap(
                          children: [
                            for (final value in _candidates[e.key]!)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _fields[e.key]!.text = value;
                                        _reviewed = false;
                                      }),
                                child: Text(value),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_analyzed) ...[
          TextButton(
            onPressed: _busy ? null : _checkDuplicates,
            child: const Text('ตรวจข้อมูลซ้ำอีกครั้ง'),
          ),
          for (final row in _duplicates)
            ListTile(
              leading: const Icon(Icons.person_search_outlined),
              title: Text((row['name'] ?? '').toString()),
              subtitle: Text([row['company'], row['phone']].join(' · ')),
            ),
          if (_duplicates.isNotEmpty)
            const Text(
              'พบข้อมูลคล้ายกัน ควรกลับไปเลือกรายการเดิมก่อนบันทึก เพื่อป้องกันทะเบียนซ้ำ',
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _reviewed,
            title: const Text('ตรวจเทียบภาพและเลือกช่องแล้ว'),
            onChanged: _busy
                ? null
                : (v) => setState(() => _reviewed = v == true),
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.radius),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: shape,
            minimumSize: Size(48, t.buttonHeight),
            textStyle: t.buttonStyle,
            backgroundColor: t.primaryColor,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: shape,
            minimumSize: Size(48, t.buttonHeight),
            textStyle: t.buttonStyle,
            foregroundColor: t.primaryColor,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: shape,
            minimumSize: Size(48, t.buttonHeight),
            textStyle: t.buttonStyle,
            foregroundColor: t.primaryColor,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: t.backgroundColor,
        appBar: AppBar(
          title: Text('อ่านนามบัตร • ตรวจสอบก่อนนำเข้า', style: t.captionStyle),
          backgroundColor: t.surfaceColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: t.contentMargin,
                    child: box.maxWidth >= t.compactBreakpoint
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _picture()),
                              SizedBox(width: t.sectionSpacing),
                              Expanded(child: _review()),
                            ],
                          )
                        : Column(
                            children: [
                              _picture(),
                              SizedBox(height: t.sectionSpacing),
                              _review(),
                            ],
                          ),
                  ),
                ),
              ),
              Divider(height: 1, color: t.borderColor),
              Container(
                color: t.surfaceColor,
                width: double.infinity,
                padding: t.cardPadding,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: !_reviewed || _busy || _selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              BusinessCardImport(
                                values: {
                                  for (final key in _selected)
                                    if (_fields[key]!.text.trim().isNotEmpty)
                                      key: _fields[key]!.text.trim(),
                                },
                                images: _images
                                    .whereType<BusinessCardImage>()
                                    .toList(),
                                contactSlot: _slot,
                              ),
                            ),
                      icon: const Icon(Icons.input),
                      label: const Text('นำเข้าแบบฟอร์ม'),
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
}

class _BusinessCardCrop extends StatefulWidget {
  const _BusinessCardCrop({required this.tokens, required this.bytes});
  final LaooWorkspaceUiTokens tokens;
  final Uint8List bytes;
  @override
  State<_BusinessCardCrop> createState() => _BusinessCardCropState();
}

class _BusinessCardCropState extends State<_BusinessCardCrop> {
  double left = 0, top = 0, right = 1, bottom = 1;
  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: widget.tokens,
    icon: Icons.crop,
    title: 'ครอบเฉพาะนามบัตร',
    content: Column(
      children: [
        LayoutBuilder(
          builder: (_, box) => SizedBox(
            height: 200,
            width: box.maxWidth,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.bytes, fit: BoxFit.fill),
                Positioned(
                  left: left * box.maxWidth,
                  top: top * 200,
                  right: (1 - right) * box.maxWidth,
                  bottom: (1 - bottom) * 200,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.tokens.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Text('ขอบซ้าย'),
        Slider(
          value: left,
          max: right - .05,
          onChanged: (v) => setState(() => left = v),
        ),
        const Text('ขอบขวา'),
        Slider(
          value: right,
          min: left + .05,
          onChanged: (v) => setState(() => right = v),
        ),
        const Text('ขอบบน'),
        Slider(
          value: top,
          max: bottom - .05,
          onChanged: (v) => setState(() => top = v),
        ),
        const Text('ขอบล่าง'),
        Slider(
          value: bottom,
          min: top + .05,
          onChanged: (v) => setState(() => bottom = v),
        ),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, Rect.fromLTRB(left, top, right, bottom)),
        child: const Text('ใช้ภาพที่ครอบ'),
      ),
    ],
  );
}
