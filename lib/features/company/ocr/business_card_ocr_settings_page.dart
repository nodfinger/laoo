import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import 'business_card_ocr_api.dart';
import 'business_card_ocr_ui.dart';
import 'business_card_review_settings.dart';

class BusinessCardOcrSettingsPage extends StatefulWidget {
  const BusinessCardOcrSettingsPage({super.key});
  @override
  State<BusinessCardOcrSettingsPage> createState() =>
      _BusinessCardOcrSettingsPageState();
}

class _BusinessCardOcrSettingsPageState
    extends State<BusinessCardOcrSettingsPage> {
  final _api = BusinessCardOcrApi(),
      _size = TextEditingController(),
      _timeout = TextEditingController();
  final _reviewKey = GlobalKey<BusinessCardReviewSettingsState>();
  String _caption = '';
  bool _enabled = true,
      _engine = false,
      _loading = true,
      _saving = false,
      _canEdit = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _size.dispose();
    _timeout.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        NavigationMenuRepository().resolveMenuName(
          menuCode: '55001',
          routeName: 'companyBusinessCardOcrSettings',
        ),
        _api.actions(),
        _api.settings(),
      ]);
      final actions = result[1] as Map<String, dynamic>,
          values = result[2] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _caption = result[0] as String;
        _canEdit = actions['edit'] == true;
        _enabled = values['isEnabled'] == true;
        _engine = values['engineAvailable'] == true;
        _size.text = values['maxImageSizeMB'].toString();
        _timeout.text = values['timeoutSeconds'].toString();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: 'โหลดค่าระบบ OCR ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error',
          error: true,
        );
      }
    }
  }

  Future<void> _save() async {
    final size = int.tryParse(_size.text),
        timeout = int.tryParse(_timeout.text);
    if (size == null ||
        size < 1 ||
        size > 10 ||
        timeout == null ||
        timeout < 5 ||
        timeout > 120) {
      showTimedSnackBar(
        context,
        message:
            'ค่าตั้งค่าไม่ถูกต้อง\nรายละเอียดเพิ่มเติม: ขนาดภาพ 1–10 MB และเวลา 5–120 วินาที',
        error: true,
      );
      return;
    }
    final review = _reviewKey.currentState;
    final reviewError =
        review?.validationError() ??
        (review == null ? 'กรุณารอให้โหลดการตั้งค่าผู้ตรวจสอบสำเร็จ' : null);
    if (reviewError != null) {
      showTimedSnackBar(
        context,
        message: 'บันทึกการตั้งค่าไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $reviewError',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.saveCombinedSettings(
        _enabled,
        size,
        timeout,
        review!.settings(),
      );
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกค่าระบบ OCR แล้ว');
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'บันทึกค่าระบบ OCR ไม่สำเร็จ';
        final detail = error is ApiException
            ? error.description
            : 'กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';
        showTimedSnackBar(
          context,
          message: detail == null
              ? message
              : '$message\nรายละเอียดเพิ่มเติม: $detail',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, _, _) {
        final t = businessCardOcrUi(context);
        return SupportWorkspaceShell(
          pageTitle: _caption,
          activeMenu: 'companyBusinessCardOcrSettings',
          menuScope: WorkspaceMenuScope.company,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ColoredBox(
                  color: t.backgroundColor,
                  child: Padding(
                    padding: t.contentMargin,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LaooCaptionCard(
                          tokens: t,
                          caption: _caption,
                          favoriteKey: '55001',
                          leading: Icon(
                            Icons.document_scanner_outlined,
                            color: t.primaryColor,
                          ),
                          trailing: _canEdit
                              ? FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size(100, t.buttonHeight),
                                    backgroundColor: t.primaryColor,
                                    foregroundColor: Colors.white,
                                    textStyle: t.buttonStyle,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        t.radius,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.save_outlined),
                                  label: Text(
                                    _saving ? 'กำลังบันทึก…' : 'บันทึก',
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: LaooLayout.cardSpacing),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LaooSurfaceCard(
                                  tokens: t,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'ค่าการทำงานปัจจุบัน',
                                        style: t.sectionStyle,
                                      ),
                                      const SizedBox(
                                        height: LaooLayout.popupFieldSpacing,
                                      ),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          Widget field(
                                            TextEditingController controller,
                                            String label,
                                          ) => TextField(
                                            controller: controller,
                                            style: t.inputStyle,
                                            enabled: _canEdit && !_saving,
                                            keyboardType: TextInputType.number,
                                            decoration: ocrInput(
                                              context,
                                              label,
                                            ),
                                          );
                                          if (constraints.maxWidth > 600) {
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: field(
                                                    _size,
                                                    'ขนาดภาพสูงสุด (MB)',
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: field(
                                                    _timeout,
                                                    'เวลาประมวลผลสูงสุด (วินาที)',
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                          return Column(
                                            children: [
                                              field(
                                                _size,
                                                'ขนาดภาพสูงสุด (MB)',
                                              ),
                                              const SizedBox(
                                                height: LaooLayout
                                                    .popupFieldSpacing,
                                              ),
                                              field(
                                                _timeout,
                                                'เวลาประมวลผลสูงสุด (วินาที)',
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Icon(
                                            _engine
                                                ? Icons.check_circle_outline
                                                : Icons.error_outline,
                                            color: _engine
                                                ? t.primaryColor
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _engine
                                                  ? 'Tesseract ภาษาไทยและอังกฤษพร้อมใช้งาน'
                                                  : 'Tesseract หรือโมเดลภาษาไทย/อังกฤษยังไม่พร้อม',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: LaooLayout.cardSpacing),
                                BusinessCardReviewSettings(
                                  key: _reviewKey,
                                  canEdit: _canEdit,
                                  saving: _saving,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
