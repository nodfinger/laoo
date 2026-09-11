import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/meeting_popup.dart';
import 'package:image/image.dart' as img;

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_storage.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../profile/pages/user_profile_dialog.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_repository.dart';
import '../meeting_feature_host.dart';
import '../widgets/meeting_pagination_card.dart';

String _foodImageUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri != null && uri.hasScheme) return uri.toString();
  return Uri.parse(ApiConfig.baseUrl).resolve(value.trim()).toString();
}

String _foodImageEndpoint(Map<String, dynamic> item, String fallback) {
  final foodId = (item['foodId'] as num?)?.toInt();
  if (foodId == null) return _foodImageUrl(fallback);
  return Uri.parse(ApiConfig.baseUrl)
      .resolve('/api/company/meeting-foods/$foodId/image')
      .replace(queryParameters: {'version': fallback})
      .toString();
}

Future<Uint8List> _compressFoodImage(Uint8List source) async {
  const maximumBytes = 70 * 1024;
  var decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('ไม่สามารถอ่านไฟล์รูปภาพได้');
  }
  decoded = img.bakeOrientation(decoded);
  if (decoded.width > 800 || decoded.height > 800) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: 800)
        : img.copyResize(decoded, height: 800);
  }
  var working = decoded;
  while (true) {
    for (final quality in [80, 60, 40]) {
      if (kIsWeb) await Future<void>.delayed(const Duration(milliseconds: 16));
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
  String? _accessToken;
  Map<String, String> get _imageHeaders => {
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };
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
      _accessToken = await AuthStorage().readAccessToken();
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
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(Icons.restaurant_menu_outlined, color: preset.primary),
        ),
      );
    }
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      child: Image.network(
        _foodImageEndpoint(item, url),
        headers: _imageHeaders,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: preset.primary),
          ),
        ),
      ),
    );
    return InkWell(
      onTap: () => _showFoodImagePreview(item, preset),
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      child: image,
    );
  }

  Future<void> _showFoodImagePreview(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) async {
    final url = item['imageUrl']?.toString().trim() ?? '';
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MeetingPopup(
        title: MeetingPopupTitle(
          icon: Icons.image_outlined,
          text: '${item['nameTh'] ?? 'รูปอาหาร'}',
        ),
        content: InteractiveViewer(
          child: Image.network(
            _foodImageEndpoint(item, url),
            headers: _imageHeaders,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 360,
              height: 240,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    WorkspaceThemePreset preset, {
    String? errorText,
    Color? labelColor,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: preset.border),
    );
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: TextStyle(
        color: labelColor ?? preset.primary,
        fontSize: LaooTypography.inputLabel,
      ),
      floatingLabelStyle: TextStyle(
        color: labelColor ?? preset.primary,
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
                color: LaooColors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                  side: BorderSide.none,
                ),
                child: ListTile(
                  leading: _foodImage(item, preset, size: 52),
                  title: Text(
                    '${item['foodTypeName'] ?? '-'} | ${item['nameTh']}',
                  ),
                  trailing: _actionsFor(item, preset),
                ),
              );
            },
          );
        }
        return WorkspaceSectionCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: LaooDataTable.horizontalMargin,
                columnSpacing: LaooDataTable.columnSpacing,
                dividerThickness: LaooDataTable.dividerThickness,
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
                    headingRowAlignment: MainAxisAlignment.center,
                    label: Text('ID'),
                  ),
                  DataColumn(
                    headingRowAlignment: MainAxisAlignment.center,
                    label: Text('Action'),
                  ),
                  DataColumn(label: Text('รูป')),
                  DataColumn(label: Text('ประเภทอาหาร')),
                  DataColumn(label: Text('ชื่อรายการอาหาร')),
                ],
                rows: _visibleItems.asMap().entries.map((entry) {
                  final item = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(
                        Center(
                          child: Text(
                            '${_currentPage * _pageSize + entry.key + 1}',
                          ),
                        ),
                      ),
                      DataCell(Center(child: _actionsFor(item, preset))),
                      DataCell(_foodImage(item, preset, size: 44)),
                      DataCell(Text('${item['foodTypeName'] ?? '-'}')),
                      DataCell(Text('${item['nameTh']}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pagination(WorkspaceThemePreset preset) {
    final total = _filtered.length;
    return MeetingPaginationCard(
      total: total,
      pageIndex: _currentPage,
      pageSize: _pageSize,
      primary: preset.primary,
      onPrevious: _currentPage > 0
          ? () => setState(() => _currentPage--)
          : null,
      onNext: _currentPage < _pageCount - 1
          ? () => setState(() => _currentPage++)
          : null,
    );
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final preset = workspaceThemeController.value;
    final name = TextEditingController(text: item?['nameTh'] as String? ?? '');
    String? selectedType = item?['foodTypeCode'] as String?;
    String? nameError;
    String? typeError;
    Uint8List? selectedImage;
    String? selectedImageName;
    String? imageError;
    var imageBusy = false;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: LaooColors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
          titlePadding: const EdgeInsets.fromLTRB(
            LaooLayout.cardPadding,
            LaooLayout.cardPadding,
            LaooLayout.cardPadding,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            LaooLayout.cardPadding,
            LaooLayout.cardPadding,
            LaooLayout.cardPadding,
            0,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            LaooLayout.cardPadding,
            0,
            LaooLayout.cardPadding,
            LaooLayout.cardPadding,
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
              const SizedBox(height: LaooLayout.cardSpacing),
              const Divider(height: 1, color: LaooColors.border),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: name,
                    onChanged: (_) => refresh(() => nameError = null),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: LaooTypography.inputText,
                    ),
                    decoration: _inputDecoration(
                      'ชื่อรายการอาหาร *',
                      preset,
                      errorText: nameError,
                      labelColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        _foodTypes.any((type) => type['code'] == selectedType)
                        ? selectedType
                        : null,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: LaooTypography.comboBox,
                    ),
                    decoration: _inputDecoration(
                      'ประเภทอาหาร *',
                      preset,
                      errorText: typeError,
                      labelColor: Colors.black,
                    ),
                    items: _foodTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: '${type['code']}',
                            child: Text(
                              '${type['name']}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
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
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 88,
                              height: 72,
                              child: Center(
                                child: Text(
                                  'เปิดรูปไม่ได้ กรุณาเลือก JPG หรือ PNG',
                                ),
                              ),
                            ),
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
                          minimumSize: const Size(
                            0,
                            LaooTypography.buttonHeight,
                          ),
                          visualDensity: VisualDensity.standard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        onPressed: imageBusy || saving
                            ? null
                            : () async {
                                refresh(() {
                                  imageBusy = true;
                                  imageError = null;
                                });
                                try {
                                  final picked = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.image,
                                        withData: true,
                                      );
                                  if (picked == null || !context.mounted) {
                                    return;
                                  }
                                  final file = picked.files.single;
                                  final source =
                                      file.bytes ??
                                      await file.xFile.readAsBytes();
                                  if (!context.mounted) return;
                                  if (source.isEmpty) {
                                    throw const FormatException('ไฟล์รูปว่าง');
                                  }
                                  final sourceBytes = Uint8List.fromList(
                                    source,
                                  );
                                  refresh(() {
                                    selectedImage = sourceBytes;
                                    selectedImageName = file.name;
                                    imageBusy = true;
                                    imageError = null;
                                  });
                                } catch (error) {
                                  if (!context.mounted) return;
                                  refresh(
                                    () => imageError =
                                        'เลือกรูปอาหารไม่สำเร็จ กรุณาเลือกไฟล์ JPG, PNG หรือ WebP ที่เปิดดูได้แล้วลองใหม่',
                                  );
                                } finally {
                                  if (context.mounted) {
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
                          imageBusy ? 'กำลังอ่านรูป...' : 'เลือกรูปอาหาร',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    imageError ??
                        (selectedImageName == null
                            ? 'ระบบจะปรับรูปเป็น JPG ขนาดไม่เกิน 70 KB เมื่อบันทึก'
                            : 'เลือกแล้ว: $selectedImageName — จะปรับขนาดเมื่อบันทึก'),
                    style: TextStyle(
                      color: imageError == null
                          ? preset.textSecondary
                          : LaooColors.error,
                      fontSize: LaooTypography.inputHint,
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  const Divider(height: 1, color: LaooColors.border),
                  const SizedBox(height: LaooLayout.cardSpacing),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: preset.primary,
                side: BorderSide(color: preset.primary),
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                visualDensity: VisualDensity.standard,
                maximumSize: const Size(
                  double.infinity,
                  LaooTypography.buttonHeight,
                ),
                textStyle: const TextStyle(fontSize: LaooTypography.button),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: preset.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                visualDensity: VisualDensity.standard,
                maximumSize: const Size(
                  double.infinity,
                  LaooTypography.buttonHeight,
                ),
                textStyle: const TextStyle(fontSize: LaooTypography.button),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: imageBusy || saving || imageError != null
                  ? null
                  : () {
                      if (name.text.trim().isEmpty) {
                        nameError = 'กรุณากรอกชื่อรายการอาหาร';
                      }
                      if (selectedType == null) {
                        typeError = 'กรุณาเลือกประเภทอาหาร';
                      }
                      if (nameError != null || typeError != null) {
                        refresh(() {});
                        return;
                      }
                      _saveFoodForm(
                        dialogContext,
                        item: item,
                        name: name,
                        selectedType: selectedType!,
                        selectedImage: selectedImage,
                        selectedImageName: selectedImageName,
                        setSaving: (value) => refresh(() => saving = value),
                        resetForm: item == null
                            ? () => refresh(() {
                                name.clear();
                                selectedType = null;
                                selectedImage = null;
                                selectedImageName = null;
                                imageError = null;
                              })
                            : null,
                      );
                    },
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  Future<void> _saveFoodForm(
    BuildContext dialogContext, {
    required Map<String, dynamic>? item,
    required TextEditingController name,
    required String selectedType,
    required Uint8List? selectedImage,
    required String? selectedImageName,
    required void Function(bool value) setSaving,
    required VoidCallback? resetForm,
  }) async {
    setSaving(true);
    try {
      final uploadBytes = selectedImage == null
          ? null
          : await compute(_compressFoodImage, selectedImage);
      if (!dialogContext.mounted) return;
      final savedId = await _repository.save({
        if (item?['code'] != null) 'code': item!['code'],
        'nameTh': name.text.trim(),
        'foodTypeCode': selectedType,
      }, id: (item?['foodId'] as num?)?.toInt());
      if (uploadBytes != null) {
        final uploadedUrl = await _repository.uploadImage(
          savedId,
          uploadBytes,
          'food.jpg',
        );
        if (item != null) item['imageUrl'] = uploadedUrl;
      }
      if (!mounted) return;
      if (item != null) {
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        _showMessage('บันทึกรายการอาหารสำเร็จ');
        await _load();
      } else {
        _showMessage('บันทึกรายการอาหารสำเร็จ');
        await _load();
        if (dialogContext.mounted) resetForm?.call();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_errorText(error, 'บันทึกข้อมูลไม่สำเร็จ'), true);
      }
    } finally {
      if (dialogContext.mounted) setSaving(false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          MeetingDeletePopup(record: '${item['code']} | ${item['nameTh']}'),
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
    return buildMeetingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: '23004',
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: LayoutBuilder(
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
                ),
                const SizedBox(height: LaooLayout.captionFilterSpacing),
                WorkspaceSectionCard(
                  child: LayoutBuilder(
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
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                if (_loading) const LinearProgressIndicator(),
                Expanded(child: _dataList(preset)),
                const SizedBox(height: LaooLayout.cardSpacing),
                _pagination(preset),
              ],
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
