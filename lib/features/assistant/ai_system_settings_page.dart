import 'package:flutter/material.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/shared/registry_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';
import 'ai_chat_settings_card.dart';
import 'ai_agents_page.dart';

class AiSystemSettingsPage extends StatefulWidget {
  const AiSystemSettingsPage({super.key});
  @override
  State<AiSystemSettingsPage> createState() => _AiSystemSettingsPageState();
}

class _AiSystemSettingsPageState extends State<AiSystemSettingsPage> {
  final _api = ApiClient();
  final _settings = GlobalKey<AiChatSettingsCardState>();
  final _agents = GlobalKey<AiAgentsPageState>();
  String _caption = '';
  bool _loading = true, _canEdit = false, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final menu = await NavigationMenuRepository().findMenu(menuCode: '64002');
      final result = await _api.get('/api/company-setup/ai-chat');
      if (!mounted) return;
      setState(() {
        _caption = menu?.name ?? '';
        _canEdit = result is Map && result['canEdit'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'ไม่สามารถโหลดการตั้งค่าระบบ AI กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _save() async {
    final settings = _settings.currentState;
    final agents = _agents.currentState;
    final error = settings?.validateForSave() ?? agents?.validateForSave();
    if (settings == null || agents == null || error != null) {
      showTimedSnackBar(
        context,
        message: error ?? 'กรุณารอโหลดการตั้งค่า',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await settings.savePending();
      await agents.savePending();
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกการตั้งค่าระบบ AI แล้ว');
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกการตั้งค่าไม่ครบ บางส่วนอาจบันทึกแล้ว กรุณาตรวจสอบและลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'companyAiSettings',
    menuScope: WorkspaceMenuScope.company,
    child: ColoredBox(
      color: LaooColors.background,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              children: [
                registrySurface(
                  Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _caption,
                          favoriteKey: 'companyAiSettings',
                        ),
                      ),
                      if (_canEdit)
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  registrySurface(
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  )
                else ...[
                  AiChatSettingsCard(
                    key: _settings,
                    canEdit: _canEdit,
                    busy: _saving,
                    initiallyExpanded: true,
                  ),
                  AiAgentsPage(key: _agents, embedded: true, busy: _saving),
                ],
              ],
            ),
    ),
  );
}
