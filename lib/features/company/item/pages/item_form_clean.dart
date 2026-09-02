import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../data/item_api.dart';

class ItemForm extends StatefulWidget {
  const ItemForm({
    super.key,
    this.initial,
    required this.groups,
    required this.types,
    required this.units,
    required this.onCancel,
    required this.onSaved,
  });
  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> units;
  final VoidCallback onCancel;
  final VoidCallback onSaved;
  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _data;
  late final TextEditingController _code, _name, _price, _cost, _min, _purchase;
  String? _group, _type, _unit;
  bool _active = true, _saving = false;
  List<Map<String, dynamic>> _packs = [], _images = [];

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
    _group = _data['itemGroupCode'];
    _type = _data['itemTypeCode'];
    _unit = _data['unitCode'];
    _active = _data['isActive'] != false;
    _packs = List<Map<String, dynamic>>.from(_data['packUnits'] ?? []);
    _images = List<Map<String, dynamic>>.from(_data['images'] ?? []);
  }

  @override
  void dispose() {
    for (final controller in [_code, _name, _price, _cost, _min, _purchase]) {
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
    setState(
      () => _images.add({
        'contentType': file!.extension == 'png' ? 'image/png' : 'image/jpeg',
        'fileName': file.name,
        'isCover': _images.isEmpty,
        'sortOrder': _images.length + 1,
        'imageDataBase64': base64Encode(file.bytes!),
      }),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'itemCode': _code.text.trim(),
      'itemName': _name.text.trim(),
      'itemGroupCode': _group,
      'itemTypeCode': _type,
      'unitPrice': double.tryParse(_price.text) ?? 0,
      'unitCode': _unit,
      'costPrice': double.tryParse(_cost.text) ?? 0,
      'minStock': double.tryParse(_min.text) ?? 0,
      'purchaseQuantity': double.tryParse(_purchase.text) ?? 0,
      'isActive': _active,
      'packUnits': _packs,
      'images': _images,
    };
    try {
      final api = ItemApi();
      if (_data['itemID'] == null) {
        await api.create(body);
      } else {
        await api.update((_data['itemID'] as num).toInt(), body);
      }
      api.dispose();
      widget.onSaved();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          WorkspaceActionHeader(
            title:
                'ข้อมูลสินค้า > ${_data['itemID'] == null ? 'เพิ่ม' : 'แก้ไข'}',
            actions: [
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
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('บันทึก'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _drop(
            'กลุ่มสินค้า',
            _group,
            widget.groups,
            (value) => setState(() => _group = value),
          ),
          _drop(
            'ประเภทสินค้า',
            _type,
            widget.types,
            (value) => setState(() => _type = value),
          ),
          _text(_code, 'รหัสสินค้า', required: true),
          _text(_name, 'ชื่อสินค้า', required: true),
          _text(_price, 'ราคาขายมาตรฐาน', number: true),
          _drop(
            'หน่วยบรรจุ',
            _unit,
            widget.units,
            (value) => setState(() => _unit = value),
          ),
          _text(_cost, 'ราคาต้นทุนมาตรฐาน', number: true),
          _text(_min, 'สต๊อกขั้นต่ำ', number: true),
          _text(_purchase, 'จำนวนซื้อเพิ่ม', number: true),
          SwitchListTile(
            title: const Text('สถานะใช้งาน'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          const SizedBox(height: 12),
          Text(
            'หน่วยบรรจุและอัตราแปลง',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ..._packs.map(
            (pack) => ListTile(
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
          const SizedBox(height: 12),
          Text(
            'รูปภาพสินค้า (สูงสุด 5 รูป)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: [
              ..._images.map(
                (image) => Image.memory(
                  base64Decode(image['imageDataBase64']),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'กรุณาระบุ$label' : null
          : null,
    );
  }

  Widget _drop(
    String label,
    String? value,
    List<Map<String, dynamic>> values,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: LaooTypography.tableBody,
        height: 1.35,
      ),
      validator: (current) => current == null ? 'กรุณาเลือก$label' : null,
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: '${item['code']}',
              child: Text(
                '${item['name']}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: LaooTypography.tableBody,
                  height: 1.35,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class ItemAlert extends StatelessWidget {
  const ItemAlert({super.key, required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary.withValues(alpha: .62),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: scheme.onPrimary),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: scheme.onPrimary)),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close, color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
