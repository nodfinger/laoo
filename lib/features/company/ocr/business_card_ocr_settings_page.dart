import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import 'business_card_ocr_api.dart';
import 'business_card_ocr_ui.dart';

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
    setState(() => _saving = true);
    try {
      await _api.saveSettings(_enabled, size, timeout);
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกค่าระบบ OCR แล้ว');
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกค่าระบบ OCR ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: LaooSurfaceCard(
                        tokens: t,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'ค่าการทำงานปัจจุบัน',
                                style: t.sectionStyle,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('เปิดใช้งาน OCR นามบัตร'),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: _enabled,
                                    onChanged: _canEdit && !_saving
                                        ? (v) => setState(() => _enabled = v)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _size,
                                enabled: _canEdit && !_saving,
                                keyboardType: TextInputType.number,
                                decoration: ocrInput(
                                  context,
                                  'ขนาดภาพสูงสุด (MB)',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _timeout,
                                enabled: _canEdit && !_saving,
                                keyboardType: TextInputType.number,
                                decoration: ocrInput(
                                  context,
                                  'เวลาประมวลผลสูงสุด (วินาที)',
                                ),
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
                                        : Theme.of(context).colorScheme.error,
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
                              if (_canEdit) ...[
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _save,
                                    style: FilledButton.styleFrom(
                                      minimumSize: Size(100, t.buttonHeight),
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
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
