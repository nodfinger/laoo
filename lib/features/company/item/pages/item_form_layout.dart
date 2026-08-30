// ignore_for_file: dead_code

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../data/item_api.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}

class _DecimalTextFormatter extends TextInputFormatter {
  final _pattern = RegExp(r'^\d*(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

class ItemFormLayout extends StatefulWidget {
  const ItemFormLayout({
    super.key,
    this.initial,
    required this.groups,
    required this.types,
    required this.units,
    required this.codeSettings,
    required this.maxItemImageSizeMB,
    required this.onCancel,
    required this.onSaved,
  });

  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> units;
  final Map<String, dynamic> codeSettings;
  final double maxItemImageSizeMB;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<ItemFormLayout> createState() => _ItemFormLayoutState();
}

class _ItemFormLayoutState extends State<ItemFormLayout> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _data;
  late final TextEditingController _code, _name, _price, _cost, _min, _purchase;
  late final TextEditingController _orderCode, _orderLink1, _orderLink2;
  late final TextEditingController _remarkItem1,
      _note1,
      _note2,
      _note3,
      _note4,
      _note5;
  String? _group, _type, _unit;
  bool _active = true, _showShop = false, _saving = false;
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _images = [];

  int get _maxImageBytes => (widget.maxItemImageSizeMB * 1024 * 1024).ceil();

  String get _runItem => '${widget.codeSettings['runItem'] ?? '0'}';
  bool get _manualCode => _runItem == '0';
  int _previewSequence = 0;

  Future<void> _previewCode() async {
    if (_manualCode || _data['itemID'] != null) return;
    final needsType = _runItem == '1';
    final selected = needsType ? _type : _group;
    if (selected == null || selected.isEmpty) {
      _code.clear();
      return;
    }
    final sequence = ++_previewSequence;
    final api = ItemApi();
    try {
      final code = await api.previewCode(groupCode: _group, typeCode: _type);
      if (mounted && sequence == _previewSequence) {
        _code.value = _code.value.copyWith(
          text: code ?? '',
          selection: TextSelection.collapsed(offset: (code ?? '').length),
        );
      }
    } finally {
      api.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _data = widget.initial ?? {};
    _code = TextEditingController(text: '${_data['itemCode'] ?? ''}');
    _name = TextEditingController(text: '${_data['itemName'] ?? ''}');
    _price = TextEditingController(text: '${_data['unitPrice'] ?? 0}');
    _cost = TextEditingController(text: '${_data['costPrice'] ?? 0}');
    _min = TextEditingController(text: '${_data['minStock'] ?? 0}');
    _purchase = TextEditingController(
      text: '${_data['purchaseQuantity'] ?? 0}',
    );
    _orderCode = TextEditingController(text: '${_data['orderCode'] ?? ''}');
    _orderLink1 = TextEditingController(text: '${_data['orderLink1'] ?? ''}');
    _orderLink2 = TextEditingController(text: '${_data['orderLink2'] ?? ''}');
    _remarkItem1 = TextEditingController(text: '${_data['remarkItem1'] ?? ''}');
    _note1 = TextEditingController(text: '${_data['note1'] ?? ''}');
    _note2 = TextEditingController(text: '${_data['note2'] ?? ''}');
    _note3 = TextEditingController(text: '${_data['note3'] ?? ''}');
    _note4 = TextEditingController(text: '${_data['note4'] ?? ''}');
    _note5 = TextEditingController(text: '${_data['note5'] ?? ''}');
    _group = _data['itemGroupCode'];
    _type = _data['itemTypeCode'];
    _unit = _data['unitCode'];
    if (_data['itemID'] == null) {
      _group ??= _firstCode(widget.groups);
      _type ??= _firstCode(widget.types);
      _unit ??= _firstCode(widget.units);
    }
    _active = _data['isActive'] != false;
    _showShop = _data['showShop'] == true;
    _packs = List<Map<String, dynamic>>.from(_data['packUnits'] ?? []);
    _images = List<Map<String, dynamic>>.from(_data['images'] ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) => _previewCode());
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _price,
      _cost,
      _min,
      _purchase,
      _orderCode,
      _orderLink1,
      _orderLink2,
      _remarkItem1,
      _note1,
      _note2,
      _note3,
      _note4,
      _note5,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    final prepared = _prepareImage(file!.bytes!, file.extension);
    if (prepared.bytes.length > _maxImageBytes) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถลดขนาดรูปภาพให้เหลือไม่เกิน ${widget.maxItemImageSizeMB.toStringAsFixed(2)} MB ได้',
          error: true,
        );
      }
      return;
    }
    setState(
      () => _images.add({
        'contentType': prepared.contentType,
        'fileName': file.name,
        'isCover': _images.isEmpty,
        'sortOrder': _images.length + 1,
        'imageDataBase64': base64Encode(prepared.bytes),
      }),
    );
  }

  ({List<int> bytes, String contentType}) _prepareImage(
    List<int> source,
    String? extension,
  ) {
    if (source.length <= _maxImageBytes) {
      return (
        bytes: source,
        contentType: extension?.toLowerCase() == 'png'
            ? 'image/png'
            : 'image/jpeg',
      );
    }
    final decoded = img.decodeImage(Uint8List.fromList(source));
    if (decoded == null) {
      return (bytes: source, contentType: 'image/jpeg');
    }
    var current = decoded;
    for (var pass = 0; pass < 4; pass++) {
      if (current.width > 1600) current = img.copyResize(current, width: 1600);
      for (var quality = 85; quality >= 35; quality -= 10) {
        final bytes = img.encodeJpg(current, quality: quality);
        if (bytes.length <= _maxImageBytes)
          return (bytes: bytes, contentType: 'image/jpeg');
      }
      current = img.copyResize(current, width: (current.width * .8).round());
    }
    return (
      bytes: img.encodeJpg(current, quality: 30),
      contentType: 'image/jpeg',
    );
  }

  void _removeImage(int index) {
    setState(() {
      final wasCover = _images[index]['isCover'] == true;
      _images.removeAt(index);
      for (var i = 0; i < _images.length; i++) {
        _images[i]['sortOrder'] = i + 1;
      }
      if (wasCover && _images.isNotEmpty) _images.first['isCover'] = true;
    });
  }

  void _setCover(int index) {
    setState(() {
      for (var i = 0; i < _images.length; i++) {
        _images[i]['isCover'] = i == index;
      }
    });
  }

  void _viewImage(Map<String, dynamic> image) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(base64Decode(image['imageDataBase64'] as String)),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final normalizedCode = _code.text.trim().toUpperCase();
    _code.value = _code.value.copyWith(
      text: normalizedCode,
      selection: TextSelection.collapsed(offset: normalizedCode.length),
    );
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'itemCode': normalizedCode,
      'itemName': _name.text.trim(),
      'itemGroupCode': _group,
      'itemTypeCode': _type,
      'unitPrice': double.tryParse(_price.text) ?? 0,
      'unitCode': _unit,
      'costPrice': double.tryParse(_cost.text) ?? 0,
      'minStock': double.tryParse(_min.text) ?? 0,
      'purchaseQuantity': double.tryParse(_purchase.text) ?? 0,
      'orderCode': _orderCode.text.trim(),
      'orderLink1': _orderLink1.text.trim(),
      'orderLink2': _orderLink2.text.trim(),
      'remarkItem1': _remarkItem1.text.trim(),

      'note1': _note1.text.trim(),
      'note2': _note2.text.trim(),
      'note3': _note3.text.trim(),
      'note4': _note4.text.trim(),
      'note5': _note5.text.trim(),
      'isActive': _active,
      'showShop': _showShop,
      'packUnits': _packs,
      'images': _images,
    };
    final creating = _data['itemID'] == null;
    try {
      final api = ItemApi();
      if (_data['itemID'] == null) {
        await api.create(body);
      } else {
        await api.update((_data['itemID'] as num).toInt(), body);
      }
      api.dispose();
      if (creating && mounted) {
        setState(() {
          _code.clear();
          _name.clear();
          _price.text = '0';
          _cost.text = '0';
          _min.text = '0';
          _purchase.text = '0';
          _orderCode.clear();
          _orderLink1.clear();
          _orderLink2.clear();
          _remarkItem1.clear();
          _note1.clear();
          _note2.clear();
          _note3.clear();
          _note4.clear();
          _note5.clear();
          _group = _firstCode(widget.groups);
          _type = _firstCode(widget.types);
          _unit = _firstCode(widget.units);
          _packs = [];
          _images = [];
          _active = true;
          _showShop = false;
          _saving = false;
        });
      }
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTimedSnackBar(context, message: error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final title =
        'ข้อมูลสินค้า > ${_data['itemID'] == null ? 'เพิ่ม' : 'แก้ไข'}';
    return Form(
      key: _form,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        color: const Color(0xFFF8F9FB),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final contentWidth = (constraints.maxWidth - 32)
                .clamp(0.0, double.infinity)
                .toDouble();
            return ListView(
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: (constraints.maxWidth - 16)
                            .clamp(0.0, double.infinity)
                            .toDouble(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: WorkspacePageTitle(
                                title: title,
                                titleColor: Colors.black,
                              ),
                            ),
                            const Text('สถานะใช้งาน'),
                            const SizedBox(width: 6),
                            Switch(
                              value: _active,
                              onChanged: (v) => setState(() => _active = v),
                            ),
                            const SizedBox(width: 12),
                            const Text('แสดงหน้า Online'),
                            const SizedBox(width: 6),
                            Switch(
                              value: _showShop,
                              onChanged: (v) => setState(() => _showShop = v),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: widget.onCancel,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              icon: const Icon(Icons.close),
                              label: const Text('ยกเลิก'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('บันทึก'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      textDirection: TextDirection.rtl,
                      spacing: wide ? contentWidth * .02 : 0,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: wide ? contentWidth * .75 : contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _row(wide, [
                                _drop('กลุ่มสินค้า', _group, widget.groups, (
                                  v,
                                ) {
                                  setState(() => _group = v);
                                  _previewCode();
                                }),
                                _drop('ประเภทสินค้า', _type, widget.types, (v) {
                                  setState(() => _type = v);
                                  _previewCode();
                                }),
                              ]),
                              const SizedBox(height: 16),
                              _compactFields(wide),
                              const SizedBox(height: 16),
                              _row(wide, [
                                _text(_orderCode, 'อ้างอิงเลขที่เอกสารซื้อ'),
                              ]),
                              const SizedBox(height: 16),
                              _row(wide, [
                                _text(_orderLink1, 'อ้างอิง Link 1'),
                              ]),
                              const SizedBox(height: 16),
                              _row(wide, [
                                _text(_orderLink2, 'อ้างอิง Link 2'),
                              ]),
                              const SizedBox(height: 16),
                              _detailsSection(accent, wide),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: wide ? contentWidth * .23 : contentWidth,
                          child: _imageCard(accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detailsSection(Color accent, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFF5F6F7))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'รายละเอียดสินค้า',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFF5F6F7))),
          ],
        ),
        const SizedBox(height: 12),
        _row(wide, [_multiline(_remarkItem1, 'รายละเอียด 1')]),
        const SizedBox(height: 12),
        _text(_note1, 'อธิบายเพิ่มเติม 1'),
        const SizedBox(height: 12),
        _text(_note2, 'อธิบายเพิ่มเติม 2'),
        const SizedBox(height: 12),
        _text(_note3, 'อธิบายเพิ่มเติม 3'),
        const SizedBox(height: 12),
        _text(_note4, 'อธิบายเพิ่มเติม 4'),
        const SizedBox(height: 12),
        _text(_note5, 'อธิบายเพิ่มเติม 5'),
      ],
    );
  }

  Widget _detailsCard(Color accent, bool wide) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'รายละเอียดสินค้า',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _row(wide, [_multiline(_remarkItem1, 'รายละเอียด 1')]),
            const SizedBox(height: 12),
            _text(_note1, 'อธิบายเพิ่มเติม 1'),
            const SizedBox(height: 12),
            _text(_note2, 'อธิบายเพิ่มเติม 2'),
            const SizedBox(height: 12),
            _text(_note3, 'อธิบายเพิ่มเติม 3'),
            const SizedBox(height: 12),
            _text(_note4, 'อธิบายเพิ่มเติม 4'),
            const SizedBox(height: 12),
            _text(_note5, 'อธิบายเพิ่มเติม 5'),
          ],
        ),
      ),
    );
  }

  Widget _packCard(Color accent) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'หน่วยบรรจุและอัตราแปลง',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            ..._packs.map(
              (pack) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${pack['unitCode']} = ${pack['conversionQuantity']} ${pack['parentUnitCode'] ?? _unit}',
                ),
                subtitle: Text('เทียบหน่วยหลัก ${pack['baseQuantity']}'),
                trailing: IconButton(
                  onPressed: () => setState(() => _packs.remove(pack)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(
                () => _packs.add({
                  'unitCode': _unit ?? '',
                  'parentUnitCode': _unit,
                  'conversionQuantity': 1,
                  'baseQuantity': 1,
                  'isDefault': false,
                  'isActive': true,
                  'sortOrder': _packs.length + 1,
                }),
              ),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มหน่วยบรรจุ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageCard(Color accent) {
    final coverIndex = _images.indexWhere((x) => x['isCover'] == true);
    final cover = _images.isEmpty
        ? null
        : _images[coverIndex >= 0 ? coverIndex : 0];
    final coverPosition = cover == null ? -1 : _images.indexOf(cover);
    final others = _images
        .asMap()
        .entries
        .where((entry) => entry.key != coverPosition)
        .take(4)
        .toList();

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'รูปสินค้า',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'เพิ่มรูปสินค้า',
                onPressed: _images.length >= 5 ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
          const Text(
            'สูงสุด 5 รูป | ไม่เกิน 1 MB ต่อรูป',
            style: const TextStyle(fontSize: 0, color: Colors.transparent),
          ),
          Text(
            'สูงสุด 5 รูป | ไม่เกิน ${widget.maxItemImageSizeMB.toStringAsFixed(2)} MB ต่อรูป | ถ้าเกินระบบจะลดขนาดให้อัตโนมัติ',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          if (cover == null)
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('เพิ่มรูปหน้าปก'),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _imageTile(cover, coverPosition, accent, large: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: others
                        .map(
                          (entry) => _imageTile(
                            entry.value,
                            entry.key,
                            accent,
                            large: false,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _imageTile(
    Map<String, dynamic> image,
    int index,
    Color accent, {
    required bool large,
  }) {
    final isCover = image['isCover'] == true;
    final size = large ? 130.0 : 54.0;
    return SizedBox(
      width: large ? double.infinity : size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _viewImage(image),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.memory(
                base64Decode(image['imageDataBase64'] as String),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (large)
            Text(
              isCover ? 'รูปหน้าปก' : 'รูปสินค้า',
              style: TextStyle(color: accent, fontSize: 11),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCover)
                IconButton(
                  tooltip: 'ตั้งเป็นหน้าปก',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _setCover(index),
                  icon: Icon(Icons.star_border, color: accent, size: 17),
                ),
              IconButton(
                tooltip: 'ลบรูปภาพ',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeImage(index),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactFields(bool wide) {
    final accent = workspaceThemeController.value.primary;
    final stock = _readOnlyStockField(accent);
    final code = _text(
      _code,
      'รหัสสินค้า',
      required: _manualCode,
      readOnly: !_manualCode,
    );
    final name = _text(_name, 'ชื่อสินค้า', required: true);
    final unit = _drop(
      'หน่วยนับมาตรฐาน',
      _unit,
      widget.units,
      (v) => setState(() => _unit = v),
    );
    final price = _text(_price, 'ราคาขายมาตรฐาน', number: true);
    final cost = _text(_cost, 'ราคาต้นทุน', number: true);
    final min = _text(_min, 'สต๊อกขั้นต่ำ', number: true);
    final purchase = _text(_purchase, 'จำนวนซื้อเพิ่ม', number: true);
    if (!wide) {
      return Column(
        children: [
          code,
          const SizedBox(height: 16),
          name,
          const SizedBox(height: 16),
          stock,
          const SizedBox(height: 16),
          unit,
          const SizedBox(height: 16),
          price,
          const SizedBox(height: 16),
          cost,
          const SizedBox(height: 16),
          min,
          const SizedBox(height: 16),
          purchase,
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 150, child: code),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: name),
            const SizedBox(width: 12),
            SizedBox(width: 160, child: stock),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: unit),
            const SizedBox(width: 12),
            SizedBox(width: 150, child: price),
            const SizedBox(width: 12),
            Expanded(child: cost),
            const SizedBox(width: 12),
            Expanded(child: min),
            const SizedBox(width: 12),
            Expanded(child: purchase),
          ],
        ),
      ],
    );
  }

  Widget _readOnlyStockField(Color accent) {
    final value = _data['stockBalance'] ?? 0;
    return TextFormField(
      initialValue: '$value',
      readOnly: true,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12),
        labelText:
            '\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d',
        filled: true,
        fillColor: accent.withValues(alpha: .08),
      ),
    );
  }

  Widget _readOnlyStock(Color accent) {
    final value = _data['stockBalance'] ?? 0;
    return TextFormField(
      initialValue: '$value',
      readOnly: true,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12),
        labelText: 'เธชเธ•เนเธญเธเธเน€เธซเธฅเธทเธญ',
        filled: true,
        fillColor: accent.withValues(alpha: .08),
      ),
    );
  }

  Widget _row(bool wide, List<Widget> fields) {
    if (!wide) return Column(children: fields);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: fields[i]),
        ],
      ],
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool required = false,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: number ? TextInputType.number : null,
      inputFormatters: number
          ? [_DecimalTextFormatter()]
          : controller == _code
          ? [_UpperCaseTextFormatter()]
          : null,
      decoration: InputDecoration(labelText: required ? '* $label' : label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุ$label' : null
          : null,
    );
  }

  Widget _multiline(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      minLines: 3,
      maxLines: 3,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
    );
  }

  Widget _drop(
    String label,
    String? value,
    List<Map<String, dynamic>> values,
    ValueChanged<String?> onChanged,
  ) {
    final comboStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: LaooTypography.tableBody,
      height: 1.35,
    );
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: '* $label'),
      style: comboStyle,
      validator: (v) => v == null ? 'กรุณาเลือก$label' : null,
      items: values
          .map(
            (x) => DropdownMenuItem(
              value: '${x['code']}',
              child: Text('${x['name']}', style: comboStyle),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  String? _firstCode(List<Map<String, dynamic>> values) {
    if (values.isEmpty) return null;
    final code = values.first['code'];
    final value = code?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
