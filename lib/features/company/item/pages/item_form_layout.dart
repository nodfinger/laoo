// ignore_for_file: dead_code

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../data/item_api.dart';
import '../../../support/master_data/data/master_data_api.dart';
import '../../../support/master_data/pages/master_data_page.dart';
import '../../../support/master_data/pages/simple_master_search_dialog.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';

class _UsageHelp extends StatefulWidget {
  const _UsageHelp({required this.label, required this.message});

  final String label;
  final String message;

  @override
  State<_UsageHelp> createState() => _UsageHelpState();
}

class _UsageHelpState extends State<_UsageHelp> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tooltipKey,
    message: widget.message,
    triggerMode: TooltipTriggerMode.manual,
    child: IconButton(
      onPressed: () => _tooltipKey.currentState?.ensureTooltipVisible(),
      icon: Icon(
        Icons.info_outline,
        size: 20,
        semanticLabel: 'คำอธิบาย${widget.label}',
      ),
      color: workspaceThemeController.value.primary,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      iconSize: 20,
    ),
  );
}

// The item lookup exposes only the three dependencies already authorized for
// the product screen. Mutations still use MasterDataApi and its own permissions.
class _ItemMasterLookupApi extends MasterDataApi {
  _ItemMasterLookupApi(this.groupCode, this.groupName, this.itemApi);
  final String groupCode;
  final String groupName;
  final ItemApi itemApi;

  @override
  Future<List<Map<String, dynamic>>> groups() async => [
    {'code': groupCode, 'name': groupName},
  ];

  @override
  Future<List<Map<String, dynamic>>> list(
    String groupCode, {
    String? search,
  }) async {
    final rows = await itemApi.masterOptions(groupCode);
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return rows;
    return rows
        .where(
          (item) => '${item['name'] ?? ''} ${item['code'] ?? ''}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    itemApi.dispose();
    super.dispose();
  }
}

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
    required this.responsibleDepartments,
    required this.codeSettings,
    required this.maxItemImageSizeMB,
    this.defaultReceiveStockPriceModeCode = 'CUSTOM',
    required this.onCancel,
    required this.onSaved,
    this.caption = 'ข้อมูลสินค้า',
    this.canEditItem = true,
    this.apiFactory,
  });

  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> responsibleDepartments;
  final Map<String, dynamic> codeSettings;
  final double maxItemImageSizeMB;
  final String defaultReceiveStockPriceModeCode;
  final VoidCallback onCancel;
  final VoidCallback onSaved;
  final String caption;
  final bool canEditItem;
  final ItemApi Function()? apiFactory;

  @override
  State<ItemFormLayout> createState() => _ItemFormLayoutState();
}

class _ItemFormLayoutState extends State<ItemFormLayout> {
  bool _canChangeMasterData = false;
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
  late final TextEditingController _supplierWarrantyMonths,
      _customerWarrantyMonths;
  String? _group, _type, _unit, _responsibleDepartment;
  late List<Map<String, dynamic>> _groups = List.of(widget.groups);
  late List<Map<String, dynamic>> _types = List.of(widget.types);
  late List<Map<String, dynamic>> _units = List.of(widget.units);
  int _masterOptionsVersion = 0;
  String _receiveStockPriceModeCode = 'CUSTOM';
  static const _receiveStockPriceModes = [
    {'code': 'CUSTOM', 'name': 'กำหนดเอง'},
    {'code': 'LAST_RECEIPT', 'name': 'ราคารับเข้าล่าสุด'},
    {'code': 'AVERAGE', 'name': 'ราคาเฉลี่ย'},
  ];
  String _itemKind = 'GOODS', _stockTracking = 'QUANTITY';
  Set<String> _usageCodes = {'SALE'};
  String _projectMode = 'ALL';
  Set<int> _projectIds = {};
  List<Map<String, dynamic>> _projectOptions = [];
  bool _projectsLoading = true;
  String? _projectError;
  bool _active = true, _showShop = false, _saving = false;
  String _supplierWarrantyMode = 'NONE', _customerWarrantyMode = 'NONE';
  bool _additionalExpanded = true;
  int _additionalTab = 0;
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
    final api = widget.apiFactory?.call() ?? ItemApi();
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
    _data = Map<String, dynamic>.from(widget.initial ?? {});
    final access = _data['projectAccess'] as Map?;
    _projectMode = '${access?['accessModeCode'] ?? 'ALL'}';
    _projectIds = ((access?['projectIds'] as List?) ?? [])
        .map((v) => (v as num).toInt())
        .toSet();
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
    final policies = List<Map<String, dynamic>>.from(
      _data['warrantyPolicies'] as List? ?? const [],
    );
    Map policy(String coverage) => policies.firstWhere(
      (value) => '${value['coverageTypeCode']}'.toUpperCase() == coverage,
      orElse: () => const <String, dynamic>{},
    );
    final supplierPolicy = policy('SUPPLIER');
    final customerPolicy = policy('CUSTOMER');
    _supplierWarrantyMode = '${supplierPolicy['warrantyModeCode'] ?? 'NONE'}'
        .toUpperCase();
    _customerWarrantyMode = '${customerPolicy['warrantyModeCode'] ?? 'NONE'}'
        .toUpperCase();
    _supplierWarrantyMonths = TextEditingController(
      text: '${supplierPolicy['durationMonths'] ?? ''}',
    );
    _customerWarrantyMonths = TextEditingController(
      text: '${customerPolicy['durationMonths'] ?? ''}',
    );
    _group = _data['itemGroupCode'];
    _type = _data['itemTypeCode'];
    _unit = _data['unitCode'];
    _responsibleDepartment = _data['responsibleDepartmentOrgUnitID']
        ?.toString();
    _receiveStockPriceModeCode =
        '${_data['receiveStockPriceModeCode'] ?? widget.defaultReceiveStockPriceModeCode}'
            .toUpperCase();
    if (!_receiveStockPriceModes.any(
      (x) => x['code'] == _receiveStockPriceModeCode,
    )) {
      _receiveStockPriceModeCode = widget.defaultReceiveStockPriceModeCode;
    }
    _itemKind = '${_data['itemKindCode'] ?? 'GOODS'}'.toUpperCase();
    _stockTracking = '${_data['stockTrackingCode'] ?? 'QUANTITY'}'
        .toUpperCase();
    _usageCodes = Set<String>.from(
      (_data['usageCodes'] as List? ?? const ['SALE']).map(
        (value) => '$value'.toUpperCase(),
      ),
    );
    if (_data['itemID'] == null) {
      _group ??= _firstCode(_groups);
      _type ??= _firstCode(_types);
      _unit ??= _firstCode(_units);
    }
    _active = _data['isActive'] != false;
    _showShop = _data['showShop'] == true;
    _packs = List<Map<String, dynamic>>.from(_data['packUnits'] ?? []);
    _images = List<Map<String, dynamic>>.from(_data['images'] ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) => _previewCode());
    _loadProjects();
    _loadMasterActions();
    if (_data['itemID'] == null) _loadClassificationDefaults();
  }

  Future<void> _loadMasterActions() async {
    final api = MasterDataApi();
    try {
      final actions = await api.actions();
      if (!mounted) return;
      setState(
        () => _canChangeMasterData =
            actions['view'] == true &&
            (actions['create'] == true ||
                actions['edit'] == true ||
                actions['delete'] == true),
      );
    } catch (_) {
      // Keep search-only behavior if permissions cannot be verified.
    } finally {
      api.dispose();
    }
  }

  Future<void> _loadClassificationDefaults() async {
    final api = widget.apiFactory?.call() ?? ItemApi();
    try {
      final defaults = await api.classificationDefaults(_group, _type);
      if (!mounted || defaults['found'] != true) return;
      setState(() {
        _itemKind = '${defaults['itemKindCode'] ?? _itemKind}'.toUpperCase();
        _stockTracking = '${defaults['stockTrackingCode'] ?? _stockTracking}'
            .toUpperCase();
        final usage = defaults['usageCodes'];
        if (usage is List && usage.isNotEmpty) {
          _usageCodes = usage.map((value) => '$value'.toUpperCase()).toSet();
        }
      });
    } finally {
      api.dispose();
    }
  }

  Future<void> _loadProjects() async {
    final api = widget.apiFactory?.call() ?? ItemApi();
    try {
      final options = await api.projectOptions();
      if (mounted) {
        setState(() {
          _projectOptions = options;
          _projectError = null;
          _projectsLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _projectError = 'โหลด Project ไม่สำเร็จ: $error';
          _projectsLoading = false;
        });
      }
    } finally {
      api.dispose();
    }
  }

  Widget _projectPanel(Color accent) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      side: const BorderSide(color: LaooColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.apps_outlined, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Project ที่ใช้งานสินค้า',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: LaooColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_projectsLoading) const LinearProgressIndicator(),
          if (_projectError != null) ...[
            Text(_projectError!),
            TextButton(
              onPressed: _loadProjects,
              child: const Text('โหลด Project ใหม่'),
            ),
          ],
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: LaooTypography.comboBox),
            initialValue: _projectMode,
            decoration: const InputDecoration(labelText: 'ขอบเขตการใช้งาน'),
            items: const [
              DropdownMenuItem(
                value: 'ALL',
                child: Text('ทุก Project ที่บริษัทเปิดใช้'),
              ),
              DropdownMenuItem(
                value: 'SELECTED',
                child: Text('เฉพาะ Project ที่เลือก'),
              ),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() => _projectMode = v!),
          ),
          FormField<Set<int>>(
            validator: (_) => _projectMode == 'SELECTED' && _projectIds.isEmpty
                ? 'กรุณาเลือก Project อย่างน้อยหนึ่งรายการ'
                : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ..._projectOptions.map((project) {
                        final id = (project['projectId'] as num).toInt();
                        final allProjects = _projectMode == 'ALL';
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text('${project['projectName']}'),
                          value: allProjects || _projectIds.contains(id),
                          onChanged: _saving || allProjects
                              ? null
                              : (selected) {
                                  setState(() {
                                    selected == true
                                        ? _projectIds.add(id)
                                        : _projectIds.remove(id);
                                  });
                                  field.didChange(_projectIds);
                                },
                        );
                      }),
                      ..._projectIds
                          .where(
                            (id) => !_projectOptions.any(
                              (project) => project['projectId'] == id,
                            ),
                          )
                          .map(
                            (id) => CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Project $id ไม่ได้เปิดใช้งาน — ยกเลิกการเลือกเพื่อบันทึก',
                              ),
                              value: true,
                              onChanged: _saving
                                  ? null
                                  : (_) =>
                                        setState(() => _projectIds.remove(id)),
                            ),
                          ),
                    ],
                  ),
                ),
                if (field.hasError)
                  Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const Text(
            'การเลือก Project ไม่ทดแทนสิทธิ์เมนู สาขา หรือคลังของผู้ใช้',
          ),
          const Text('งานขาย ใบส่งของ และสต๊อก ใช้ Project ข้อมูลส่วนกลาง'),
        ],
      ),
    ),
  );

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
      _supplierWarrantyMonths,
      _customerWarrantyMonths,
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
        if (bytes.length <= _maxImageBytes) {
          return (bytes: bytes, contentType: 'image/jpeg');
        }
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
    if (_data['itemID'] != null && !widget.canEditItem) return;
    if (_saving || _projectsLoading || _projectError != null) return;
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
      'responsibleDepartmentOrgUnitID': int.tryParse(
        _responsibleDepartment ?? '',
      ),
      'receiveStockPriceModeCode': _receiveStockPriceModeCode,
      'itemKindCode': _itemKind,
      'stockTrackingCode': _stockTracking,
      'usageCodes': _usageCodes.toList()..sort(),
      'warrantyPolicies': [
        {
          'coverageTypeCode': 'SUPPLIER',
          'warrantyModeCode': _supplierWarrantyMode,
          'durationMonths': _supplierWarrantyMode == 'MONTHS'
              ? int.tryParse(_supplierWarrantyMonths.text)
              : null,
        },
        {
          'coverageTypeCode': 'CUSTOMER',
          'warrantyModeCode': _customerWarrantyMode,
          'durationMonths': _customerWarrantyMode == 'MONTHS'
              ? int.tryParse(_customerWarrantyMonths.text)
              : null,
        },
      ],
      'projectAccess': {
        'accessModeCode': _projectMode,
        'projectIds': _projectMode == 'ALL'
            ? <int>[]
            : (_projectIds.toList()..sort()),
      },
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
    final api = widget.apiFactory?.call() ?? ItemApi();
    try {
      if (creating) {
        await api.create(body);
      } else {
        await api.update((_data['itemID'] as num).toInt(), body);
      }
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
          _group = _firstCode(_groups);
          _type = _firstCode(_types);
          _unit = _firstCode(_units);
          _responsibleDepartment = null;
          _receiveStockPriceModeCode = widget.defaultReceiveStockPriceModeCode;
          _itemKind = 'GOODS';
          _stockTracking = 'QUANTITY';
          _usageCodes = {'SALE'};
          _projectMode = 'ALL';
          _projectIds = {};
          _supplierWarrantyMode = 'NONE';
          _customerWarrantyMode = 'NONE';
          _supplierWarrantyMonths.clear();
          _customerWarrantyMonths.clear();
          _packs = [];
          _images = [];
          _active = true;
          _showShop = false;
          _additionalExpanded = true;
          _additionalTab = 0;
          _saving = false;
        });
      }
      widget.onSaved();
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTimedSnackBar(context, message: error.toString(), error: true);
    } finally {
      api.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: const BorderSide(color: LaooColors.border),
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, LaooTypography.buttonHeight),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: LaooTypography.button, fontWeight: FontWeight.w600),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      ),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: accent)),
          errorBorder: border.copyWith(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
        ),
        textTheme: Theme.of(context).textTheme.copyWith(
          titleMedium: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: LaooTypography.inputText),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
        filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontSize: LaooTypography.button,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      child: Form(
        key: _form,
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.caption} > ${_data['itemID'] == null ? 'เพิ่ม' : 'แก้ไข'}',
                      style: LaooTypography.pageCaptionStyle,
                    ),
                  ),
                ],
              ),
              const Divider(color: LaooColors.border),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: _leftContent(true)),
                                const SizedBox(width: 12),
                                Expanded(flex: 3, child: _rightContent(accent)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _imagePanel(accent),
                                const SizedBox(height: 12),
                                _leftContent(false),
                                const SizedBox(height: 12),
                                _projectPanel(accent),
                              ],
                            ),
                    );
                  },
                ),
              ),
              const Divider(color: LaooColors.border),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : widget.onCancel,
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _saving ||
                            _projectsLoading ||
                            _projectError != null ||
                            (_data['itemID'] != null && !widget.canEditItem)
                        ? null
                        : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leftContent(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('สถานะใช้งาน'),
              Switch(
                value: _active,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _active = value),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('แสดงหน้า Online'),
              Switch(
                value: _showShop,
                onChanged: !_saving && _usageCodes.contains('SALE')
                    ? (value) => setState(() => _showShop = value)
                    : null,
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _inventoryClassification(wide),
      const SizedBox(height: 12),
      _compactFields(wide),
      const SizedBox(height: 12),
      _warrantyPanel(wide),
      const SizedBox(height: 12),
      _additionalPanel(workspaceThemeController.value.primary, wide),
    ],
  );

  Widget _rightContent(Color accent) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _imagePanel(accent),
      const SizedBox(height: 12),
      _projectPanel(accent),
    ],
  );

  Widget _imagePanel(Color accent) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      side: const BorderSide(color: LaooColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: _imageCard(accent),
    ),
  );

  bool get _hasAdditionalData => [
    _orderCode,
    _orderLink1,
    _orderLink2,
    _remarkItem1,
    _note1,
    _note2,
    _note3,
    _note4,
    _note5,
  ].any((controller) => controller.text.trim().isNotEmpty);

  Widget _additionalPanel(Color accent, bool wide) {
    final selectedColor = accent.withValues(alpha: .12);
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: const BorderSide(color: LaooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            onTap: () =>
                setState(() => _additionalExpanded = !_additionalExpanded),
            child: Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Row(
                children: [
                  Icon(Icons.article_outlined, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อมูลเพิ่มเติม',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: LaooColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_hasAdditionalData)
                    Text(
                      'มีข้อมูล',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: accent),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _additionalExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
          if (_additionalExpanded) ...[
            const Divider(height: 1, color: LaooColors.border),
            Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _additionalTabButton(
                          label: 'เอกสารอ้างอิง',
                          index: 0,
                          accent: accent,
                          selectedColor: selectedColor,
                        ),
                        const SizedBox(width: 8),
                        _additionalTabButton(
                          label: 'รายละเอียดเพิ่มเติม',
                          index: 1,
                          accent: accent,
                          selectedColor: selectedColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_additionalTab == 0)
                    _referenceFields(wide)
                  else
                    _detailAndNotesFields(wide),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _additionalTabButton({
    required String label,
    required int index,
    required Color accent,
    required Color selectedColor,
  }) {
    final selected = _additionalTab == index;
    return TextButton(
      onPressed: () => setState(() => _additionalTab = index),
      style: TextButton.styleFrom(
        foregroundColor: accent,
        backgroundColor: selected ? selectedColor : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _referenceFields(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row(wide, [_text(_orderCode, 'อ้างอิงเลขที่เอกสารซื้อ')]),
      const SizedBox(height: 12),
      _row(wide, [_text(_orderLink1, 'อ้างอิง Link 1')]),
      const SizedBox(height: 12),
      _row(wide, [_text(_orderLink2, 'อ้างอิง Link 2')]),
    ],
  );

  Widget _detailAndNotesFields(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row(wide, [_multiline(_remarkItem1, 'รายละเอียดสินค้า')]),
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
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ),
          Text(
            'สูงสุด 5 รูป | ไม่เกิน ${widget.maxItemImageSizeMB.toStringAsFixed(2)} MB ต่อรูป | ถ้าเกินระบบจะลดขนาดให้อัตโนมัติ',
            style: const TextStyle(fontSize: 14),
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
              style: TextStyle(color: accent, fontSize: 14),
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

  Widget _inventoryClassification(bool wide) {
    const kinds = {'GOODS': 'สินค้า/สิ่งของ', 'SERVICE': 'บริการ'};
    const tracking = {
      'NONE': 'ไม่ควบคุมสต็อก',
      'QUANTITY': 'ควบคุมตามจำนวน',
      'SERIAL': 'ควบคุมตาม Serial',
    };
    const usages = {
      'SALE': 'ขาย',
      'MATERIAL': 'วัสดุ',
      'EQUIPMENT': 'อุปกรณ์',
      'SPARE_PART': 'อะไหล่',
    };
    const usageHelp = {
      'SALE':
          'ใช้เลือกในเอกสารระบบขาย เช่น ใบเสนอราคาและใบส่งของ ทั้งนี้ขึ้นอยู่กับชนิดสินค้า แพ็กเกจ และสิทธิ์ผู้ใช้',
      'MATERIAL':
          'ใช้ในรายการเบิกจ่ายวัสดุและงานซ่อม โดยขึ้นอยู่กับชนิดสินค้า วิธีควบคุมสต็อก แพ็กเกจ และสิทธิ์ผู้ใช้',
      'EQUIPMENT':
          'ใช้เลือกอุปกรณ์ที่แจ้งซ่อมและจัดทำแผนบำรุงรักษา โดยขึ้นอยู่กับสถานะอุปกรณ์ แพ็กเกจ และสิทธิ์ผู้ใช้',
      'SPARE_PART':
          'ใช้ในรายการเบิกจ่ายและเลือกเป็นอะไหล่สำหรับงานซ่อม โดยขึ้นอยู่กับชนิดสินค้า วิธีควบคุมสต็อก แพ็กเกจ และสิทธิ์ผู้ใช้',
    };
    final kindField = DropdownButtonFormField<String>(
      isExpanded: true,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontSize: LaooTypography.comboBox),
      key: ValueKey(_itemKind),
      initialValue: _itemKind,
      decoration: const InputDecoration(labelText: '* ชนิดพื้นฐาน'),
      items: kinds.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) => setState(() {
        _itemKind = value ?? 'GOODS';
        if (_itemKind == 'SERVICE') _stockTracking = 'NONE';
      }),
    );
    final trackingField = DropdownButtonFormField<String>(
      isExpanded: true,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontSize: LaooTypography.comboBox),
      key: ValueKey('$_itemKind-$_stockTracking'),
      initialValue: _stockTracking,
      decoration: const InputDecoration(labelText: '* วิธีควบคุมสต็อก'),
      items: tracking.entries
          .where((entry) => _itemKind == 'GOODS' || entry.key == 'NONE')
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: _itemKind == 'SERVICE'
          ? null
          : (value) => setState(() {
              _stockTracking = value ?? 'NONE';
            }),
    );
    final groupField = _drop('กลุ่มสินค้า', _group, _groups, (value) {
      setState(() => _group = value);
      _previewCode();
    }, masterGroupCode: '006');
    final typeField = _drop('ประเภทสินค้า', _type, _types, (value) {
      setState(() => _type = value);
      _previewCode();
    }, masterGroupCode: '007');
    final departmentField = _dropOptional(
      'แผนกที่รับผิดชอบ',
      _responsibleDepartment,
      widget.responsibleDepartments,
      (value) => setState(() => _responsibleDepartment = value),
    );
    final priceModeField = _drop(
      'ราคาเริ่มต้นรับเข้าสต๊อก',
      _receiveStockPriceModeCode,
      _receiveStockPriceModes,
      (value) => setState(() => _receiveStockPriceModeCode = value ?? 'CUSTOM'),
    );
    final usageField = FormField<Set<String>>(
      initialValue: _usageCodes,
      validator: (_) => _usageCodes.isEmpty
          ? 'กรุณาเลือกวัตถุประสงค์อย่างน้อย 1 รายการ'
          : null,
      builder: (field) => InputDecorator(
        decoration: InputDecoration(
          labelText: '* วัตถุประสงค์',
          errorText: field.errorText,
          contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final codes in [
              const ['SALE', 'MATERIAL'],
              const ['EQUIPMENT', 'SPARE_PART'],
            ]) ...[
              if (codes.first == 'EQUIPMENT') const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: codes.map((code) {
                  final entry = MapEntry(code, usages[code]!);
                  final selected = _usageCodes.contains(entry.key);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilterChip(
                        label: Text(entry.value),
                        selected: selected,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        labelPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                        onSelected: (value) => setState(() {
                          value
                              ? _usageCodes.add(entry.key)
                              : _usageCodes.remove(entry.key);
                          if (!_usageCodes.contains('SALE')) _showShop = false;
                          field.didChange(Set<String>.from(_usageCodes));
                        }),
                      ),
                      _UsageHelp(
                        label: entry.value,
                        message: usageHelp[entry.key]!,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
    if (!wide) {
      return Column(
        children: [
          groupField,
          const SizedBox(height: 12),
          typeField,
          const SizedBox(height: 12),
          usageField,
          const SizedBox(height: 12),
          kindField,
          const SizedBox(height: 12),
          trackingField,
          const SizedBox(height: 12),
          departmentField,
          const SizedBox(height: 12),
          priceModeField,
        ],
      );
    }
    final fields = Column(
      children: [
        _row(true, [groupField, typeField]),
        const SizedBox(height: 12),
        _row(true, [kindField, trackingField]),
        const SizedBox(height: 12),
        _row(true, [departmentField, priceModeField]),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 740) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [fields, const SizedBox(height: 12), usageField],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: fields),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: usageField),
          ],
        );
      },
    );
  }

  Widget _warrantyPanel(bool wide) {
    Widget policy({
      required String label,
      required String value,
      required ValueChanged<String?> onChanged,
      required TextEditingController months,
      required bool fieldsInRow,
    }) {
      final mode = DropdownButtonFormField<String>(
        isExpanded: true,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontSize: LaooTypography.comboBox),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: 'NONE', child: Text('ไม่มีประกัน')),
          DropdownMenuItem(value: 'LIFETIME', child: Text('ตลอดอายุ')),
          DropdownMenuItem(value: 'MONTHS', child: Text('กำหนดจำนวนเดือน')),
        ],
        onChanged: _saving ? null : onChanged,
      );
      final duration = _text(
        months,
        'จำนวนเดือน',
        number: true,
        required: value == 'MONTHS',
        readOnly: value != 'MONTHS',
      );
      return fieldsInRow
          ? Row(
              children: [
                Expanded(flex: 3, child: mode),
                const SizedBox(width: 12),
                Expanded(child: duration),
              ],
            )
          : Column(children: [mode, const SizedBox(height: 12), duration]);
    }

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: const BorderSide(color: LaooColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = wide && constraints.maxWidth >= 680;
            Widget supplier({required bool compact}) => policy(
              label: 'ประกันผู้ขาย (เริ่มเมื่อรับเข้า)',
              value: _supplierWarrantyMode,
              months: _supplierWarrantyMonths,
              fieldsInRow: !compact && wide,
              onChanged: (next) =>
                  setState(() => _supplierWarrantyMode = next ?? 'NONE'),
            );
            Widget customer({required bool compact}) => policy(
              label: 'ประกันลูกค้า (เลือกเริ่มตอนส่งของ/ติดตั้ง)',
              value: _customerWarrantyMode,
              months: _customerWarrantyMonths,
              fieldsInRow: !compact && wide,
              onChanged: (next) =>
                  setState(() => _customerWarrantyMode = next ?? 'NONE'),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ค่าเริ่มต้นประกัน',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: LaooTypography.sectionTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (sideBySide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: supplier(compact: true)),
                      const SizedBox(width: 12),
                      Expanded(child: customer(compact: true)),
                    ],
                  )
                else ...[
                  supplier(compact: false),
                  const SizedBox(height: 12),
                  customer(compact: false),
                ],
              ],
            );
          },
        ),
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
      _units,
      (v) => setState(() => _unit = v),
      masterGroupCode: '002',
    );
    final price = _text(_price, 'ราคาขายมาตรฐาน', number: true);
    final cost = _text(_cost, 'ราคาต้นทุน', number: true);
    final min = _text(_min, 'สต๊อกขั้นต่ำ', number: true);
    final purchase = _text(_purchase, 'จำนวนซื้อเพิ่ม', number: true);
    if (!wide) {
      return Column(
        children: [
          code,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          name,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          stock,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          unit,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          price,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          cost,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          min,
          const SizedBox(height: LaooLayout.popupFieldSpacing),
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
        const SizedBox(height: LaooLayout.popupFieldSpacing),
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
        labelStyle: const TextStyle(fontSize: 14),
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
        labelStyle: const TextStyle(fontSize: 14),
        labelText: 'เธชเธ•เนเธญเธเธเน€เธซเธฅเธทเธญ',
        filled: true,
        fillColor: accent.withValues(alpha: .08),
      ),
    );
  }

  Widget _row(bool wide, List<Widget> fields) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            fields[i],
          ],
        ],
      );
    }
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

  Future<void> _manageMaster(String groupCode, String groupName) async {
    final lookupApi = _ItemMasterLookupApi(
      groupCode,
      groupName,
      widget.apiFactory?.call() ?? ItemApi(),
    );
    try {
      final actions = await lookupApi.actions().catchError(
        (_) => <String, bool>{},
      );
      final simple =
          actions['view'] != true ||
          !(actions['create'] == true ||
              actions['edit'] == true ||
              actions['delete'] == true);
      final rows = simple
          ? await lookupApi.list(groupCode)
          : <Map<String, dynamic>>[];
      if (simple) lookupApi.dispose();
      if (!mounted) return;
      final selectedCode = await showDialog<String>(
        context: context,
        builder: (dialogContext) => simple
            ? SimpleMasterSearchDialog(title: groupName, rows: rows)
            : Theme(
                data: workspaceThemeController.value.toThemeData(),
                child: Dialog(
                  insetPadding: const EdgeInsets.all(24),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  child: SizedBox(
                    width: 1000,
                    height: (MediaQuery.sizeOf(dialogContext).height - 48)
                        .clamp(0.0, 700.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'ปิด',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        Expanded(
                          child: MasterDataPage(
                            menuScope: WorkspaceMenuScope.company,
                            embedded: true,
                            masterGroupCode: groupCode,
                            simpleWhenReadOnly: true,
                            api: lookupApi,
                            onSelected: (code) =>
                                Navigator.of(dialogContext).pop(code),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
      // The dialog disposes its API; reload using a fresh product client.
      if (!mounted) return;
      final api = widget.apiFactory?.call() ?? ItemApi();
      try {
        final options = await api.masterOptions(groupCode);
        if (!mounted) return;
        final exists =
            selectedCode != null &&
            options.any((item) => item['code']?.toString() == selectedCode);
        setState(() {
          if (groupCode == '006') {
            _groups = options;
            if (exists) {
              _group = selectedCode;
            } else if (!options.any(
              (item) => item['code']?.toString() == _group,
            )) {
              _group = null;
            }
          } else if (groupCode == '007') {
            _types = options;
            if (exists) {
              _type = selectedCode;
            } else if (!options.any(
              (item) => item['code']?.toString() == _type,
            )) {
              _type = null;
            }
          } else {
            _units = options;
            if (exists) {
              _unit = selectedCode;
            } else if (!options.any(
              (item) => item['code']?.toString() == _unit,
            )) {
              _unit = null;
            }
          }
          _masterOptionsVersion++;
        });
        if (exists && groupCode != '002') _previewCode();
      } finally {
        api.dispose();
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ไม่สามารถโหลดรหัสพื้นฐานได้ กรุณาลองใหม่',
          error: true,
        );
      }
    }
  }

  Widget _drop(
    String label,
    String? value,
    List<Map<String, dynamic>> values,
    ValueChanged<String?> onChanged, {
    String? masterGroupCode,
  }) {
    final comboStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: LaooTypography.comboBox,
      height: 1.35,
    );
    return DropdownButtonFormField<String>(
      isExpanded: true,
      key: ValueKey('$label-$_masterOptionsVersion'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: '* $label',
        suffixIcon: masterGroupCode == null
            ? null
            : IconButton(
                tooltip: _canChangeMasterData
                    ? 'จัดการ $label'
                    : 'ค้นหา $label',
                onPressed: _saving
                    ? null
                    : () => _manageMaster(masterGroupCode, label),
                icon: Icon(
                  _canChangeMasterData
                      ? Icons.edit_note_outlined
                      : Icons.search,
                ),
              ),
      ),
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

  Future<void> _searchDepartment() async {
    var query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final rows = widget.responsibleDepartments.where((item) {
            final name = (item['name']?.toString() ?? '').toLowerCase();
            final code = (item['code']?.toString() ?? '').toLowerCase();
            return name.contains(query) || code.contains(query);
          }).toList();
          final colors = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            title: Row(
              children: [
                Icon(Icons.search, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ค้นหา แผนกที่รับผิดชอบ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: LaooTypography.workspaceCaption,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'ค้นหา',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => update(() {
                      query = value.trim().toLowerCase();
                    }),
                  ),
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูล'))
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) => ListTile(
                              title: Text(
                                rows[index]['name']?.toString() ?? '-',
                              ),
                              onTap: () => Navigator.pop(
                                dialogContext,
                                rows[index]['code'].toString(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _responsibleDepartment = selected);
  }

  Widget _dropOptional(
    String label,
    String? value,
    List<Map<String, dynamic>> values,
    ValueChanged<String?> onChanged,
  ) {
    final comboStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: LaooTypography.comboBox,
      height: 1.35,
    );
    return DropdownButtonFormField<String>(
      key: ValueKey((label, value)),
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: 'ค้นหา แผนกที่รับผิดชอบ',
          onPressed: _saving ? null : _searchDepartment,
          icon: const Icon(Icons.search),
        ),
      ),
      style: comboStyle,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('ไม่ระบุ', style: comboStyle),
        ),
        ...values.map(
          (item) => DropdownMenuItem(
            value: '${item['code']}',
            child: Text('${item['name']}', style: comboStyle),
          ),
        ),
      ],
      onChanged: _saving ? null : onChanged,
    );
  }

  String? _firstCode(List<Map<String, dynamic>> values) {
    if (values.isEmpty) return null;
    final code = values.first['code'];
    final value = code?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
