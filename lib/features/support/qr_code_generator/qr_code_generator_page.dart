import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../presentation/widgets/support_workspace_shell.dart';
import 'qr_code_content.dart';
import 'qr_code_export.dart';

class QrCodeGeneratorPage extends StatefulWidget {
  const QrCodeGeneratorPage({super.key});

  @override
  State<QrCodeGeneratorPage> createState() => _QrCodeGeneratorPageState();
}

class _QrCodeGeneratorPageState extends State<QrCodeGeneratorPage> {
  static const _menuCode = '01008';
  static const _routeName = 'qrCodeGenerator';
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _caption = 'สร้าง QR Code';
  QrContentType _type = QrContentType.text;
  String? _qrData;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadCaption();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: _menuCode,
      routeName: _routeName,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = value);
  }

  void _changeType(QrContentType? value) {
    if (value == null || value == _type) return;
    setState(() {
      _type = value;
      _qrData = null;
    });
    _formKey.currentState?.reset();
  }

  void _generate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _qrData = normalizeQrContent(_contentController.text));
    showTimedSnackBar(context, message: 'สร้าง QR Code แล้ว');
  }

  void _reset() {
    _contentController.clear();
    _formKey.currentState?.reset();
    setState(() {
      _type = QrContentType.text;
      _qrData = null;
    });
  }

  Future<void> _copy() async {
    final value = _qrData;
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showTimedSnackBar(context, message: 'คัดลอกข้อมูล QR แล้ว');
  }

  Future<void> _download() async {
    final value = _qrData;
    if (value == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final image = await createQrPng(value);
      final now = DateTime.now();
      final stamp = <int>[
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ].map((part) => part.toString().padLeft(2, '0')).join();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'บันทึก QR Code',
        fileName: 'laoo-qr-$stamp.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: image,
      );
      if (mounted && (kIsWeb || path != null)) {
        showTimedSnackBar(context, message: 'ดาวน์โหลด QR Code แล้ว');
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ดาวน์โหลด QR Code ไม่สำเร็จ — รายละเอียดเพิ่มเติม: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  InputDecoration _inputDecoration(String label, String hint) {
    final primary = workspaceThemeController.value.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: const BorderSide(color: LaooColors.border),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: LaooTypography.inputLabel),
      floatingLabelStyle: TextStyle(
        fontSize: LaooTypography.materialFloatingLabelSource,
        color: primary,
      ),
      hintStyle: const TextStyle(fontSize: LaooTypography.inputHint),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: LaooColors.error),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: LaooColors.error, width: 1.5),
      ),
    );
  }

  ButtonStyle _buttonStyle({bool outlined = false}) {
    final primary = workspaceThemeController.value.primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    const textStyle = TextStyle(
      fontSize: LaooTypography.button,
      fontWeight: FontWeight.w700,
    );
    return outlined
        ? OutlinedButton.styleFrom(
            minimumSize: const Size(0, LaooTypography.buttonHeight),
            foregroundColor: primary,
            side: BorderSide(color: primary),
            shape: shape,
            textStyle: textStyle,
          )
        : FilledButton.styleFrom(
            minimumSize: const Size(0, LaooTypography.buttonHeight),
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: shape,
            textStyle: textStyle,
          );
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: _routeName,
      menuScope: WorkspaceMenuScope.support,
      child: ColoredBox(
        color: LaooColors.background,
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkspaceSectionCard(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: LaooLayout.popupHeaderMinHeight,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: WorkspacePageTitle(
                      title: _caption,
                      favoriteKey: _menuCode,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final form = _buildFormCard();
                    final preview = _buildPreviewCard();
                    if (constraints.maxWidth < 900) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            form,
                            const SizedBox(height: LaooLayout.cardSpacing),
                            SizedBox(height: 540, child: preview),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: form),
                        const SizedBox(width: LaooLayout.cardSpacing),
                        Expanded(flex: 6, child: preview),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final primary = workspaceThemeController.value.primary;
    return WorkspaceSectionCard(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('ข้อมูลที่ต้องการสร้าง', primary),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              DropdownButtonFormField<QrContentType>(
                initialValue: _type,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: LaooTypography.comboBox,
                  color: LaooColors.textPrimary,
                ),
                decoration: _inputDecoration(
                  'ประเภทเนื้อหา *',
                  'เลือกประเภทเนื้อหา',
                ),
                items: QrContentType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _changeType,
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              TextFormField(
                controller: _contentController,
                minLines: _type == QrContentType.text ? 5 : 1,
                maxLines: _type == QrContentType.text ? 8 : 3,
                keyboardType: _type == QrContentType.text
                    ? TextInputType.multiline
                    : TextInputType.url,
                style: const TextStyle(fontSize: LaooTypography.inputText),
                decoration: _inputDecoration(_type.fieldLabel, _type.hint),
                validator: (value) => validateQrContent(_type, value ?? ''),
                onChanged: (_) {
                  if (_qrData != null) setState(() => _qrData = null);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'ระบบสร้าง QR Code บนเครื่องนี้เท่านั้น และไม่บันทึกเนื้อหาหรือประวัติการสร้าง',
                style: TextStyle(
                  fontSize: LaooTypography.bodySmall,
                  color: LaooColors.textSecondary,
                ),
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _reset,
                    style: _buttonStyle(outlined: true),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('เริ่มรายการใหม่'),
                  ),
                  FilledButton.icon(
                    onPressed: _generate,
                    style: _buttonStyle(),
                    icon: const Icon(Icons.qr_code_2_outlined),
                    label: const Text('สร้าง QR Code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final data = _qrData;
    final primary = workspaceThemeController.value.primary;
    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('ตัวอย่าง QR Code', primary),
          const SizedBox(height: LaooLayout.popupFieldSpacing),
          Expanded(
            child: data == null
                ? const _EmptyPreview()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: LaooColors.border),
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: QrImageView(
                                    data: data,
                                    version: QrVersions.auto,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    backgroundColor: Colors.white,
                                    semanticsLabel: 'QR Code ${_type.label}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _type.label,
                          style: const TextStyle(
                            fontSize: LaooTypography.bodySmall,
                            color: LaooColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          data,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: LaooTypography.body,
                            height: LaooTypography.bodyLineHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (data != null) ...[
            const SizedBox(height: LaooLayout.popupFieldSpacing),
            const Divider(height: 1, color: LaooColors.border),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _copy,
                  style: _buttonStyle(outlined: true),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('คัดลอกข้อมูล'),
                ),
                FilledButton.icon(
                  onPressed: _downloading ? null : _download,
                  style: _buttonStyle(),
                  icon: _downloading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(
                    _downloading ? 'กำลังดาวน์โหลด…' : 'ดาวน์โหลด PNG',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Text(
    text,
    style: TextStyle(
      fontSize: LaooTypography.sectionTitle,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  );
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    final primary = workspaceThemeController.value.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_outlined, size: 72, color: primary),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่มี QR Code',
              style: TextStyle(
                fontSize: LaooTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'เลือกประเภท ระบุข้อมูล แล้วกด “สร้าง QR Code”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: LaooTypography.body,
                color: LaooColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
