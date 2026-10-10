import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';

class VatSettingsPage extends StatefulWidget {
  const VatSettingsPage({super.key});

  @override
  State<VatSettingsPage> createState() => _VatSettingsPageState();
}

class _VatSettingsPageState extends State<VatSettingsPage> {
  final _api = ApiClient();
  final _reason = TextEditingController();
  String _caption = 'ตั้งค่าระบบภาษี';
  String? _error;
  bool? _registered;
  bool _canEdit = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolveCaption();
    _load();
  }

  Future<void> _resolveCaption() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: 'companyVatSettings',
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = name);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = Map<String, dynamic>.from(
        await _api.get('/api/company/vat-settings') as Map,
      );
      if (!mounted) return;
      setState(() {
        _registered = value['isVatRegistered'] as bool?;
        _canEdit = value['canEdit'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_canEdit) return;
    if (_registered == null) {
      showTimedSnackBar(
        context,
        message: 'เลือกสถานะจดทะเบียน VAT ก่อนบันทึก',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.put(
        '/api/company/vat-settings',
        body: {'isVatRegistered': _registered, 'reason': _reason.text.trim()},
      );
      if (!mounted) return;
      _reason.clear();
      showTimedSnackBar(context, message: 'บันทึกสถานะจดทะเบียน VAT แล้ว');
      await _load();
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกสถานะ VAT ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    const route = 'companyVatSettings';
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: route,
      menuScope: WorkspaceMenuScope.company,
      child: ListView(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: WorkspacePageTitle(
              title: _caption,
              favoriteKey: route,
              titleColor: LaooColors.pageCaption,
            ),
          ),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('โหลดการตั้งค่าภาษีไม่สำเร็จ'),
                      Text('รายละเอียดเพิ่มเติม: $_error'),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองอีกครั้ง'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('สถานะจดทะเบียนภาษีมูลค่าเพิ่ม'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<bool>(
                        initialValue: _registered,
                        decoration: InputDecoration(
                          labelText: 'สถานะจด VAT *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                            borderSide: const BorderSide(
                              color: LaooColors.border,
                            ),
                          ),
                        ),
                        hint: const Text('เลือกสถานะ'),
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text('จดทะเบียน VAT แล้ว'),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text('ยังไม่จดทะเบียน VAT'),
                          ),
                        ],
                        onChanged: _canEdit && !_saving
                            ? (value) => setState(() => _registered = value)
                            : null,
                      ),
                      const SizedBox(height: LaooLayout.popupFieldSpacing),
                      TextField(
                        controller: _reason,
                        enabled: _canEdit && !_saving,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'เหตุผลการเปลี่ยนแปลง',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                            borderSide: const BorderSide(
                              color: LaooColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'หากยังไม่จดทะเบียนหรือยังไม่ระบุสถานะ ระบบจะไม่ให้ออกใบกำกับภาษีใหม่ เอกสารเดิมไม่เปลี่ยน',
                        style: TextStyle(color: accent),
                      ),
                      if (_canEdit) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(100, 48),
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
