import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../profile/pages/user_profile_dialog.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_repository.dart';

String _foodImageUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri != null && uri.hasScheme) return uri.toString();
  return Uri.parse(ApiConfig.baseUrl).resolve(value.trim()).toString();
}

Uint8List _compressFoodImage(Uint8List source) {
  const maximumBytes = 70 * 1024;
  var decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('ไม่สามารถอ่านไฟล์รูปภาพได้');
  }
  decoded = img.bakeOrientation(decoded);
  if (decoded.width > 1280 || decoded.height > 1280) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: 1280)
        : img.copyResize(decoded, height: 1280);
  }
  var working = decoded;
  while (true) {
    for (var quality = 88; quality >= 28; quality -= 10) {
      final compressed = Uint8List.fromList(
        img.encodeJpg(working, quality: quality),
      );
      if (compressed.length <= maximumBytes) return compressed;
    }
    if (working.width <= 240 && working.height <= 240) break;
    final width = (working.width * .78).round().clamp(1, working.width - 1);
    final height = (working.height * .78).round().clamp(1, working.height - 1);
    working = img.copyResize(working, width: width, height: height);
  }
  throw const FormatException('ไม่สามารถลดขนาดรูปให้ไม่เกิน 70 KB ได้');
}

class MeetingFoodPage extends StatefulWidget {
  const MeetingFoodPage({super.key});

  @override
  State<MeetingFoodPage> createState() => _MeetingFoodPageState();
}

class _MeetingFoodPageState extends State<MeetingFoodPage> {
  final _repository = MeetingFoodRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _foodTypes = [];
  Map<String, bool> _actions = {};
  bool _loading = true;
  bool _showCards = false;
  bool _messageError = false;
  String? _message;
  String _caption = '';
  String? _filterFoodTypeCode;
  int _currentPage = 0;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _showCards = userDefaultViewModeNotifier.value == 'CARD';
    userDefaultViewModeNotifier.addListener(_syncDefaultViewMode);
    _resolveCaption();
    _load();
  }

  @override
  void dispose() {
    userDefaultViewModeNotifier.removeListener(_syncDefaultViewMode);
    _search.dispose();
    super.dispose();
  }

  void _syncDefaultViewMode() {
    if (mounted) {
      setState(() => _showCards = userDefaultViewModeNotifier.value == 'CARD');
    }
  }

  Future<void> _resolveCaption() async {
    final caption = await NavigationMenuRepository().resolveMenuName(
      menuCode: '23004',
      routeName: 'meetingFoods',
      fallback: 'รายการอาหาร',
    );
    if (mounted) setState(() => _caption = caption);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _currentPage = 0;
    });
    try {
      final result = await Future.wait([
        _repository.get(),
        _repository.types(),
        _repository.actions(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(result[0] as List);
        _foodTypes = List<Map<String, dynamic>>.from(result[1] as List);
        _actions = result[2] as Map<String, bool>;
      });
    } catch (error) {
      if (mounted) _showMessage(_errorText(error, 'โหลดข้อมูลไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorText(Object error, String fallback) =>
      error is ApiException && error.description != null
      ? '${error.message}\n${error.description}'
      : error is ApiException
      ? error.message
      : '$fallback\n$error';

  void _showMessage(String value, [bool error = false]) {
    setState(() {
      _message = value;
      _messageError = error;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final term = _search.text.trim().toLowerCase();
    return _items.where((item) {
      if (_filterFoodTypeCode != null &&
          item['foodTypeCode'] != _filterFoodTypeCode) {
        return false;
      }
      if (term.isEmpty) return true;
      return '${item['code']} ${item['nameTh']} ${item['foodTypeName'] ?? ''}'
          .toLowerCase()
          .contains(term);
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleItems {
    final start = _currentPage * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil();

  Widget _foodImage(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset, {
    double size = 48,
  }) {
    final url = item['imageUrl']?.toString().trim() ?? '';
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: preset.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: Icon(Icons.restaurant_menu_outlined, color: preset.primary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      child: Image.network(
        _foodImageUrl(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: preset.primary.withValues(alpha: .08),
          child: Icon(Icons.broken_image_outlined, color: preset.primary),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    WorkspaceThemePreset preset, {
    String? errorText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: preset.border),
    );
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: TextStyle(
        color: preset.primary,
        fontSize: LaooTypography.inputLabel,
      ),
      floatingLabelStyle: TextStyle(
        color: preset.primary,
        fontSize: LaooTypography.inputLabel,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: BorderSide(color: preset.primary, width: 1.5),
      ),
    );
  }

  Widget _actionsFor(Map<String, dynamic> item, WorkspaceThemePreset preset) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_actions['edit'] == true)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _openForm(item: item),
            icon: Icon(Icons.edit_outlined, color: preset.primary),
          ),
        if (_actions['delete'] == true)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => _delete(item),
            icon: const Icon(Icons.delete_outline, color: LaooColors.error),
          ),
      ],
    );
  }

  Widget _dataList(WorkspaceThemePreset preset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardMode = _showCards || constraints.maxWidth < 900;
        if (cardMode) {
          return ListView.separated(
            itemCount: _visibleItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = _visibleItems[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: _foodImage(item, preset, size: 52),
                  title: Text('${item['code']} | ${item['nameTh']}'),
                  subtitle: Text('ประเภท: ${item['foodTypeName'] ?? '-'}'),
                  trailing: _actionsFor(item, preset),
                ),
              );
            },
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                preset.primary.withValues(alpha: .10),
              ),
              headingTextStyle: TextStyle(
                color: preset.primary,
                fontSize: LaooTypography.tableHeader,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(
                fontSize: LaooTypography.tableBody,
              ),
              dataRowColor: LaooDataTable.rowColor(preset.primary),
              border: const TableBorder(
                horizontalInside: BorderSide(color: LaooColors.border),
              ),
              columns: const [
                DataColumn(
                  columnWidth: LaooDataTable.idColumnWidth,
                  numeric: true,
                  label: Align(
                    alignment: Alignment.centerRight,
                    child: Text('ID'),
                  ),
                ),
                DataColumn(
                  headingRowAlignment: MainAxisAlignment.center,
                  label: Text('Action'),
                ),
                DataColumn(label: Text('รูป')),
                DataColumn(label: Text('รหัส')),
                DataColumn(label: Text('ชื่อรายการอาหาร')),
                DataColumn(label: Text('ประเภทอาหาร')),
              ],
              rows: _visibleItems.asMap().entries.map((entry) {
                final item = entry.value;
                return DataRow(
                  cells: [
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_currentPage * _pageSize + entry.key + 1}',
                        ),
                      ),
                    ),
                    DataCell(Center(child: _actionsFor(item, preset))),
                    DataCell(_foodImage(item, preset, size: 44)),
                    DataCell(Text('${item['code']}')),
                    DataCell(Text('${item['nameTh']}')),
                    DataCell(Text('${item['foodTypeName'] ?? '-'}')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _pagination(WorkspaceThemePreset preset) {
    final total = _filtered.length;
    final start = total == 0 ? 0 : _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, total);
    final neutral = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: neutral,
            side: BorderSide.none,
          ),
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          child: const Icon(Icons.chevron_left),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: preset.primary,
            disabledBackgroundColor: preset.primary,
            disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: null,
          child: Text('${_pageCount == 0 ? 0 : _currentPage + 1}'),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: neutral,
            side: BorderSide.none,
          ),
          onPressed: _currentPage < _pageCount - 1
              ? () => setState(() => _currentPage++)
              : null,
          child: const Icon(Icons.chevron_right),
        ),
        Text('$start-$end จาก $total'),
      ],
    );
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final preset = workspaceThemeController.value;
    final code = TextEditingController(text: item?['code'] as String? ?? '');
    final name = TextEditingController(text: item?['nameTh'] as String? ?? '');
    String? selectedType = item?['foodTypeCode'] as String?;
    String? codeError;
    String? nameError;
    String? typeError;
    Uint8List? selectedImage;
    String? selectedImageName;
    String? imageError;
    var imageBusy = false;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.restaurant_menu_outlined, color: preset.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item == null ? 'เพิ่มรายการอาหาร' : 'แก้ไขรายการอาหาร',
                  style: LaooTypography.popupTitleStyle,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: LaooColors.border),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => refresh(() => codeError = null),
                    style: const TextStyle(fontSize: LaooTypography.inputText),
                    decoration: _inputDecoration(
                      'รหัสอาหาร *',
                      preset,
                      errorText: codeError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    onChanged: (_) => refresh(() => nameError = null),
                    style: const TextStyle(fontSize: LaooTypography.inputText),
                    decoration: _inputDecoration(
                      'ชื่อรายการอาหาร *',
                      preset,
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        _foodTypes.any((type) => type['code'] == selectedType)
                        ? selectedType
                        : null,
                    style: TextStyle(
                      color: preset.textPrimary,
                      fontSize: LaooTypography.comboBox,
                    ),
                    decoration: _inputDecoration(
                      'ประเภทอาหาร *',
                      preset,
                      errorText: typeError,
                    ),
                    items: _foodTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: '${type['code']}',
                            child: Text(
                              '${type['name']}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: LaooTypography.comboBox,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => refresh(() {
                      selectedType = value;
                      typeError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'รูปอาหาร',
                    style: TextStyle(
                      color: preset.primary,
                      fontSize: LaooTypography.inputLabel,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (selectedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                          child: Image.memory(
                            selectedImage!,
                            width: 88,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (item != null)
                        _foodImage(item, preset, size: 72)
                      else
                        Container(
                          width: 88,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: preset.primary.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                          child: Icon(
                            Icons.image_outlined,
                            color: preset.primary,
                          ),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: preset.primary,
                          side: BorderSide(color: preset.primary),
                        ),
                        onPressed: imageBusy
                            ? null
                            : () async {
                                final picked = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                final source = picked?.files.single.bytes;
                                if (source == null || !dialogContext.mounted) {
                                  return;
                                }
                                refresh(() {
                                  imageBusy = true;
                                  imageError = null;
                                });
                                try {
                                  final compressed = await compute(
                                    _compressFoodImage,
                                    Uint8List.fromList(source),
                                  );
                                  if (!dialogContext.mounted) return;
                                  refresh(() {
                                    selectedImage = compressed;
                                    selectedImageName = 'food.jpg';
                                  });
                                } catch (error) {
                                  if (!dialogContext.mounted) return;
                                  refresh(() => imageError = '$error');
                                } finally {
                                  if (dialogContext.mounted) {
                                    refresh(() => imageBusy = false);
                                  }
                                }
                              },
                        icon: imageBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          imageBusy ? 'กำลังปรับรูป...' : 'เลือกรูปอาหาร',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    imageError ?? 'ระบบจะปรับรูปเป็น JPG ขนาดไม่เกิน 70 KB',
                    style: TextStyle(
                      color: imageError == null
                          ? preset.textSecondary
                          : LaooColors.error,
                      fontSize: LaooTypography.inputHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: preset.primary,
                side: BorderSide(color: preset.primary),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: preset.primary),
              onPressed: imageBusy
                  ? null
                  : () {
                      if (code.text.trim().isEmpty) {
                        codeError = 'กรุณากรอกรหัสอาหาร';
                      }
                      if (name.text.trim().isEmpty) {
                        nameError = 'กรุณากรอกชื่อรายการอาหาร';
                      }
                      if (selectedType == null) {
                        typeError = 'กรุณาเลือกประเภทอาหาร';
                      }
                      if (codeError != null ||
                          nameError != null ||
                          typeError != null) {
                        refresh(() {});
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'code': code.text.trim(),
                        'nameTh': name.text.trim(),
                        'foodTypeCode': selectedType,
                      });
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    if (value == null) return;
    try {
      final savedId = await _repository.save(
        value,
        id: (item?['foodId'] as num?)?.toInt(),
      );
      if (selectedImage != null) {
        await _repository.uploadImage(
          savedId,
          selectedImage!,
          selectedImageName ?? 'food.jpg',
        );
      }
      if (!mounted) return;
      _showMessage('บันทึกรายการอาหารสำเร็จ');
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(_errorText(error, 'บันทึกข้อมูลไม่สำเร็จ'), true);
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final preset = workspaceThemeController.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, color: LaooColors.border),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LaooColors.error.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              child: Text('${item['code']} | ${item['nameTh']}'),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: preset.primary),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: LaooColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.delete((item['foodId'] as num).toInt());
      if (!mounted) return;
      _showMessage('ลบรายการอาหารสำเร็จ');
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_errorText(error, 'ลบข้อมูลไม่สำเร็จ'), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.company,
      pageTitle: _caption,
      activeMenu: '23004',
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: WorkspaceSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => WorkspaceActionHeader(
                      title: _caption,
                      favoriteKey: '23004',
                      actions: [
                        if (constraints.maxWidth >= 900)
                          IconButton(
                            tooltip: _showCards ? 'แสดง List' : 'แสดง Card',
                            style: IconButton.styleFrom(
                              foregroundColor: preset.primary,
                              side: BorderSide(color: preset.primary),
                            ),
                            onPressed: () =>
                                setState(() => _showCards = !_showCards),
                            icon: Icon(
                              _showCards
                                  ? Icons.table_rows_outlined
                                  : Icons.grid_view_outlined,
                            ),
                          ),
                        if (_actions['create'] == true)
                          FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่ม'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 17, color: LaooColors.border),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : 260,
                          child: TextField(
                            controller: _search,
                            onSubmitted: (_) =>
                                setState(() => _currentPage = 0),
                            style: const TextStyle(
                              fontSize: LaooTypography.inputText,
                            ),
                            decoration:
                                _inputDecoration(
                                  'ค้นหารหัส ชื่อ หรือประเภท',
                                  preset,
                                ).copyWith(
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: IconButton(
                                    tooltip: 'ค้นหา',
                                    onPressed: () =>
                                        setState(() => _currentPage = 0),
                                    icon: const Icon(Icons.arrow_forward),
                                  ),
                                ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => setState(() => _currentPage = 0),
                          icon: const Icon(Icons.search),
                          label: const Text('ค้นหา'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: preset.primary,
                            side: BorderSide(color: preset.primary),
                          ),
                          onPressed: () {
                            _search.clear();
                            setState(() {
                              _filterFoodTypeCode = null;
                              _currentPage = 0;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('ล้าง Filter'),
                        ),
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : 280,
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _filterFoodTypeCode,
                            style: TextStyle(
                              color: preset.textPrimary,
                              fontSize: LaooTypography.comboBox,
                            ),
                            decoration: _inputDecoration('ประเภทอาหาร', preset),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('ทั้งหมด'),
                              ),
                              ..._foodTypes.map(
                                (type) => DropdownMenuItem<String?>(
                                  value: '${type['code']}',
                                  child: Text(
                                    '${type['name']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _filterFoodTypeCode = value;
                              _currentPage = 0;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 17, color: LaooColors.border),
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(child: _dataList(preset)),
                  const Divider(height: 17, color: LaooColors.border),
                  _pagination(preset),
                ],
              ),
            ),
          ),
          if (_message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }
}
