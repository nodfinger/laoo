import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_equipment_request_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';

class MeetingSystemSettingsPage extends StatefulWidget {
  const MeetingSystemSettingsPage({super.key});

  @override
  State<MeetingSystemSettingsPage> createState() =>
      _MeetingSystemSettingsPageState();
}

class _MeetingSystemSettingsPageState extends State<MeetingSystemSettingsPage> {
  final _repository = MeetingEquipmentRequestRepository();
  String _caption = 'กำหนดค่าระบบ Meeting';
  String? _message;
  bool _loading = true;
  bool _saving = false;
  bool _requireReview = false;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: MeetingMenuCodes.systemSettings,
      routeName: MeetingRouteNames.systemSettings,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.settings();
      if (!mounted) return;
      setState(() {
        _requireReview = settings['requireEquipmentRequestReview'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = _error(error, 'ไม่สามารถโหลดการตั้งค่า Meeting ได้');
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.saveSettings(_requireReview);
      if (!mounted) return;
      setState(() => _message = 'บันทึกการตั้งค่า Meeting แล้ว');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _error(error, 'บันทึกการตั้งค่าไม่สำเร็จ'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\n$error';

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return buildMeetingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: MeetingRouteNames.systemSettings,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: Stack(
          children: [
            WorkspaceSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _caption,
                          favoriteKey: MeetingMenuCodes.systemSettings,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _loading || _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ],
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: preset.primary.withValues(alpha: .24),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                LaooLayout.cardSpacing,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'คำขออุปกรณ์เพิ่มเติม',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('ต้องตรวจสอบก่อนส่งแผนก'),
                                    subtitle: Text(
                                      _requireReview
                                          ? 'คำขอใหม่จะรอเจ้าของประชุม, Admin ห้อง หรือ Company Admin ตรวจสอบก่อน'
                                          : 'คำขอใหม่จะส่งถึงแผนกรับผิดชอบทันที',
                                    ),
                                    value: _requireReview,
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(
                                            () => _requireReview = value,
                                          ),
                                  ),
                                  const Divider(),
                                  Text(
                                    'การเปลี่ยนค่านี้มีผลเฉพาะคำขอที่สร้างใหม่ คำขอเดิมจะใช้ Flow เดิมที่บันทึกไว้',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_message != null)
              AutoDismissMessage(
                message: _message!,
                error:
                    _message!.contains('ไม่สำเร็จ') ||
                    _message!.contains('ไม่สามารถ'),
                onClose: () => setState(() => _message = null),
              ),
          ],
        ),
      ),
    );
  }
}
