import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

import '../../../core/widgets/combo_box_text.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../data/meeting_company_directory_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../app/theme/laoo_typography.dart';
import '../data/meeting_structure_repository.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

String _buildingImageUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri != null && uri.hasScheme) return uri.toString();
  return Uri.parse(ApiConfig.baseUrl).resolve(value.trim()).toString();
}

class MeetingBuildingPage extends StatefulWidget {
  const MeetingBuildingPage({super.key});

  @override
  State<MeetingBuildingPage> createState() => _MeetingBuildingPageState();
}

class _MeetingBuildingPageState extends State<MeetingBuildingPage> {
  final _repo = MeetingStructureRepository();
  final _branchRepo = MeetingBranchDirectoryRepository();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _branches = [];
  Map<String, bool> _actions = {};
  int? _branchId;
  bool _loading = true;
  String? _message;
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _contactEmail = TextEditingController();
  List<int>? _imageBytes;
  String? _imageName;

  void _showBuildingImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: InteractiveViewer(
            child: Image.network(
              _buildingImageUrl(url),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('ไม่สามารถโหลดรูปอาคารได้'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorText(Object error, String fallback) {
    if (error is ApiException) {
      final detail = error.description;
      return detail == null ? error.message : '${error.message}\n$detail';
    }
    return '$fallback\n${error.toString()}';
  }

  @override
  void dispose() {
    _contactName.dispose();
    _contactPhone.dispose();
    _contactEmail.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.get(branchId: _branchId),
        _branchRepo.get(),
        _repo.actions(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(results[0] as List);
        _branches = List<Map<String, dynamic>>.from(results[1] as List);
        _actions = Map<String, bool>.from(results[2] as Map);
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = _errorText(error, 'ไม่สามารถโหลดข้อมูลหน้าอาคารได้'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBuilding({Map<String, dynamic>? item}) async {
    _imageBytes = null;
    _imageName = null;
    final code = TextEditingController(
      text: (item?['code'] as String? ?? '').toUpperCase(),
    );
    final name = TextEditingController(text: item?['nameTh'] as String? ?? '');
    final imageUrl = TextEditingController(
      text: item?['imageUrl'] as String? ?? '',
    );
    final selectedImage = ValueNotifier<List<int>?>(null);
    final imageError = ValueNotifier<String?>(null);
    Future<void> pickImage() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;
      final bytes = result.files.single.bytes!;
      if (img.decodeImage(Uint8List.fromList(bytes)) == null) {
        imageError.value =
            'ไฟล์ที่เลือกไม่ใช่รูปภาพที่อ่านได้ กรุณาเลือก JPG, PNG หรือ WebP';
        selectedImage.value = null;
        return;
      }
      imageError.value = null;
      _imageBytes = bytes;
      _imageName = result.files.single.name;
      selectedImage.value = _imageBytes;
    }

    _contactName.text = item?['contName'] as String? ?? '';
    _contactPhone.text = item?['contPhone'] as String? ?? '';
    _contactEmail.text = item?['contEmail'] as String? ?? '';
    var branch = item?['branchId'] as int? ?? _branchId;
    String? branchError;
    String? codeError;
    String? nameError;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          final preset = workspaceThemeController.value;
          return AlertDialog(
            backgroundColor: LaooColors.white,
            surfaceTintColor: Colors.transparent,
            titlePadding: EdgeInsets.zero,
            actionsPadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            titleTextStyle: LaooTypography.popupTitleStyle,
            title: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        item == null
                            ? Icons.add_business_outlined
                            : Icons.edit_outlined,
                        color: preset.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item == null ? 'เพิ่มอาคาร' : 'แก้ไขอาคาร',
                        style: LaooTypography.popupTitleStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(
                    color: LaooColors.border,
                    thickness: 1,
                    height: 1,
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 48)
                  .clamp(360.0, 720.0)
                  .toDouble(),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.copyWith(
                    bodyLarge: TextStyle(
                      fontSize: LaooTypography.inputText,
                      height: LaooTypography.inputLineHeight,
                      color: LaooColors.pageCaption,
                    ),
                  ),
                  inputDecorationTheme: Theme.of(context).inputDecorationTheme
                      .copyWith(
                        labelStyle: TextStyle(
                          color: preset.primary,
                          fontSize: LaooTypography.inputLabel,
                        ),
                        floatingLabelStyle: TextStyle(
                          color: preset.primary,
                          fontSize: LaooTypography.inputLabel,
                        ),
                        filled: true,
                        fillColor: preset.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: preset.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: preset.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: LaooColors.pageCaption,
                            width: 1.5,
                          ),
                        ),
                      ),
                ),
                child: SizedBox(
                  width: 620,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: branch,
                        decoration: InputDecoration(
                          labelText: 'สาขา *',
                          errorText: branchError,
                        ),
                        items: _branches
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item['branchId'] as int,
                                child: LaooComboBoxText(
                                  '${item['branchCode']} ${item['branchNameTh']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => refresh(() {
                          branch = value;
                          branchError = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 170,
                            child: TextField(
                              controller: code,
                              onChanged: (_) => refresh(() => codeError = null),
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [UpperCaseTextFormatter()],
                              decoration: InputDecoration(
                                labelText: 'รหัสอาคาร *',
                                errorText: codeError,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: name,
                              onChanged: (_) => refresh(() => nameError = null),
                              decoration: InputDecoration(
                                labelText: 'ชื่ออาคาร *',
                                errorText: nameError,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<List<int>?>(
                        valueListenable: selectedImage,
                        builder: (context, bytes, _) => Row(
                          children: [
                            if (bytes != null)
                              GestureDetector(
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 900,
                                        maxHeight: 700,
                                      ),
                                      child: InteractiveViewer(
                                        child: Image.memory(
                                          Uint8List.fromList(bytes),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Padding(
                                                padding: EdgeInsets.all(24),
                                                child: Text(
                                                  'ไม่สามารถอ่านไฟล์รูปนี้ได้ กรุณาเลือก JPG, PNG หรือ WebP',
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    Uint8List.fromList(bytes),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 72,
                                      height: 72,
                                      alignment: Alignment.center,
                                      color: preset.surface,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if ((item?['imageUrl'] as String?)
                                    ?.isNotEmpty ==
                                true)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _buildingImageUrl(
                                    item!['imageUrl'] as String,
                                  ),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            if (bytes != null ||
                                (item?['imageUrl'] as String?)?.isNotEmpty ==
                                    true)
                              const SizedBox(width: 12),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: preset.primary,
                                side: BorderSide(color: preset.primary),
                              ),
                              onPressed: pickImage,
                              child: const Text('เลือกรูป'),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: imageError,
                        builder: (context, error, _) => error == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'รูปขนาดไม่เกิน 1 MB ระบบจะลดขนาดรูปให้อัตโนมัติ',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _contactName,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อผู้ดูแล',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _contactPhone,
                              decoration: const InputDecoration(
                                labelText: 'โทรศัพท์',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _contactEmail,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: preset.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: preset.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                      ),
                      onPressed: () async {
                        final missing = <String>[];
                        if (branch == null) {
                          missing.add('สาขา');
                          branchError = 'กรุณาเลือกสาขา';
                        }
                        if (code.text.trim().isEmpty) {
                          missing.add('รหัสอาคาร');
                          codeError = 'กรุณากรอกรหัสอาคาร';
                        }
                        if (name.text.trim().isEmpty) {
                          missing.add('ชื่ออาคาร');
                          nameError = 'กรุณากรอกชื่ออาคาร';
                        }
                        if (missing.isNotEmpty) {
                          refresh(() {});
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context, {
                          'branchId': branch,
                          'code': code.text.trim(),
                          'nameTh': name.text.trim(),
                          'imageUrl': imageUrl.text.trim(),
                          'contName': _contactName.text.trim(),
                          'contPhone': _contactPhone.text.trim(),
                          'contEmail': _contactEmail.text.trim(),
                          'isActive': true,
                        });
                      },
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    imageUrl.dispose();
    selectedImage.dispose();
    imageError.dispose();
    if (value == null) return;
    try {
      final savedId = await _repo.saveBuilding(
        value,
        id: item?['buildingId'] as int?,
      );
      String? uploadedImageUrl;
      if (_imageBytes != null) {
        uploadedImageUrl = await _repo.uploadBuildingImage(
          savedId,
          _imageBytes!,
          _imageName ?? 'building.jpg',
        );
      }
      if (mounted) {
        setState(() {
          if (item != null && uploadedImageUrl != null) {
            item['imageUrl'] = uploadedImageUrl;
          }
          _message = 'บันทึกข้อมูลอาคารสำเร็จ';
        });
        await _load();
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _message = _errorText(error, 'บันทึกข้อมูลอาคารไม่สำเร็จ'),
        );
    }
  }

  Future<void> _saveFloor(
    Map<String, dynamic> building, {
    Map<String, dynamic>? item,
  }) async {
    final code = TextEditingController(text: item?['code'] as String? ?? '');
    final name = TextEditingController(text: item?['nameTh'] as String? ?? '');
    final number = TextEditingController(text: '${item?['number'] ?? ''}');
    String? codeError;
    String? nameError;
    String? numberError;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          final preset = workspaceThemeController.value;
          final selectedBranch = _branches
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (branch) => branch?['branchId'] == building['branchId'],
                orElse: () => null,
              );
          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            actionsPadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            title: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        item == null
                            ? Icons.add_box_outlined
                            : Icons.edit_outlined,
                        color: preset.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item == null ? 'เพิ่มชั้น' : 'แก้ไขชั้น',
                        style: LaooTypography.popupTitleStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: preset.primary, thickness: 1, height: 1),
                ],
              ),
            ),
            content: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 48)
                  .clamp(360.0, 720.0)
                  .toDouble(),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.copyWith(
                    bodyLarge: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: LaooTypography.inputText,
                      height: LaooTypography.inputLineHeight,
                    ),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    labelStyle: TextStyle(
                      color: preset.primary,
                      fontSize: LaooTypography.inputLabel,
                      height: 1.4,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: preset.primary,
                      fontSize: LaooTypography.inputLabel,
                      fontWeight: FontWeight.w600,
                    ),
                    helperStyle: const TextStyle(
                      fontSize: LaooTypography.inputHint,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: preset.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: preset.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: preset.primary, width: 1.5),
                    ),
                    isDense: false,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: preset.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'สถานที่: ${selectedBranch?['branchCode'] ?? '-'} ${selectedBranch?['branchNameTh'] ?? '-'}\n'
                        'อาคาร: ${building['code'] ?? ''} ${building['nameTh'] ?? ''}',
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: code,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      onChanged: (_) => refresh(() => codeError = null),
                      decoration: InputDecoration(
                        labelText: 'รหัสชั้น *',
                        errorText: codeError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      onChanged: (_) => refresh(() => nameError = null),
                      decoration: InputDecoration(
                        labelText: 'ชื่อชั้น *',
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: number,
                      onChanged: (_) => refresh(() => numberError = null),
                      decoration: InputDecoration(
                        labelText: 'เลขชั้น *',
                        errorText: numberError,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: preset.primary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: preset.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        if (code.text.trim().isEmpty)
                          codeError = 'กรุณากรอกรหัสชั้น';
                        if (name.text.trim().isEmpty)
                          nameError = 'กรุณากรอกชื่อชั้น';
                        if (number.text.trim().isEmpty)
                          numberError = 'กรุณากรอกเลขชั้น';
                        final parsedNumber = int.tryParse(number.text.trim());
                        if (number.text.trim().isNotEmpty &&
                            parsedNumber == null) {
                          numberError = 'เลขชั้นต้องเป็นตัวเลข';
                        }
                        if (codeError != null ||
                            nameError != null ||
                            numberError != null) {
                          refresh(() {});
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context, {
                          'buildingId': building['buildingId'],
                          'code': code.text.trim(),
                          'nameTh': name.text.trim(),
                          'number': parsedNumber,
                          'isActive': true,
                        });
                      },
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    number.dispose();
    if (value == null) return;
    try {
      await _repo.saveFloor(value, id: item?['floorId'] as int?);
      if (mounted) {
        setState(() => _message = 'บันทึกข้อมูลชั้นสำเร็จ');
        _load();
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _message = _errorText(error, 'บันทึกข้อมูลชั้นไม่สำเร็จ'),
        );
    }
  }

  Future<void> _confirmDeleteFloor(Map<String, dynamic> floor) async {
    final preset = workspaceThemeController.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: preset.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: preset.primary),
            ),
            const SizedBox(width: 12),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: preset.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ ${floor['code']} - ${floor['nameTh']} หรือไม่?',
                textAlign: TextAlign.center,
              ),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deleteFloor(floor['floorId'] as int);
      await _load();
    } catch (error) {
      if (mounted)
        setState(() => _message = _errorText(error, 'ลบข้อมูลชั้นไม่สำเร็จ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) => SupportWorkspaceShell(
        menuScope: WorkspaceMenuScope.company,
        pageTitle: 'อาคารและชั้น',
        activeMenu: '23001',
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceSectionCard(
                    child: Row(
                      children: [
                        const Expanded(
                          child: WorkspacePageTitle(
                            title: 'อาคารและชั้น',
                            favoriteKey: '23001',
                          ),
                        ),
                        if (_actions['create'] == true)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: preset.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            onPressed: _saveBuilding,
                            icon: Icon(
                              Icons.add,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            label: const Text('เพิ่มอาคาร'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  WorkspaceSectionCard(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _branchId,
                      decoration: InputDecoration(
                        labelText: 'กรองตามสาขา',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: LaooComboBoxText('ทุกสาขา'),
                        ),
                        ..._branches.map(
                          (item) => DropdownMenuItem<int?>(
                            value: item['branchId'] as int,
                            child: LaooComboBoxText(
                              '${item['branchCode']} ${item['branchNameTh']}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _branchId = value);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final building = _items[index];
                        final floors = List<Map<String, dynamic>>.from(
                          building['floors'] as List? ?? const [],
                        );
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.all(
                              LaooLayout.cardPadding,
                            ),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading:
                                (building['imageUrl'] as String?)?.isNotEmpty ==
                                    true
                                ? GestureDetector(
                                    onTap: () => _showBuildingImage(
                                      building['imageUrl'] as String,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _buildingImageUrl(
                                          building['imageUrl'] as String,
                                        ),
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.business),
                            title: Text(
                              '${building['code']} ${building['nameTh']}',
                            ),
                            subtitle: Text('ชั้น ${floors.length}'),
                            trailing: Wrap(
                              children: [
                                if (_actions['edit'] == true)
                                  IconButton(
                                    onPressed: () =>
                                        _saveBuilding(item: building),
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: preset.primary,
                                    ),
                                  ),
                                if (_actions['create'] == true)
                                  IconButton(
                                    onPressed: () => _saveFloor(building),
                                    icon: Icon(
                                      Icons.add,
                                      color: preset.primary,
                                    ),
                                  ),
                              ],
                            ),
                            children: floors
                                .map(
                                  (floor) => Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: preset.border,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        '${floor['code']} ${floor['nameTh']}',
                                      ),
                                      subtitle: Text(
                                        'เลขชั้น ${floor['number'] ?? '-'}',
                                      ),
                                      trailing: Wrap(
                                        children: [
                                          if (_actions['edit'] == true)
                                            IconButton(
                                              onPressed: () => _saveFloor(
                                                building,
                                                item: floor,
                                              ),
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                color: preset.primary,
                                              ),
                                            ),
                                          if (_actions['delete'] == true)
                                            IconButton(
                                              onPressed: () =>
                                                  _confirmDeleteFloor(floor),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null)
              Positioned(
                top: 12,
                right: 24,
                child: AutoDismissMessage(
                  message: _message!,
                  onClose: () => setState(() => _message = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
