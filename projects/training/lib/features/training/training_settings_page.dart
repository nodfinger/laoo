import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'training_feature_host.dart';
import 'training_route_contract.dart';

class TrainingSettingsPage extends StatefulWidget {
  const TrainingSettingsPage({super.key});

  @override
  State<TrainingSettingsPage> createState() => _TrainingSettingsPageState();
}

class _TrainingSettingsPageState extends State<TrainingSettingsPage> {
  late final dynamic _api;
  bool _loading = true;
  String _caption = 'ตั้งค่าระบบอบรม';
  String? _message;
  bool _messageError = false;
  Map<String, dynamic> _settings = const {};

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _loadCaption();
    _load();
  }

  @override
  void dispose() {
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await resolveTrainingMenuCaption(
      menuCode: TrainingMenuCodes.settings,
      routeName: TrainingRouteNames.settings,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = Map<String, dynamic>.from(
        await _api.get('/api/company/training/settings') as Map,
      );
      if (mounted) setState(() => _settings = value);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message =
              'ไม่สามารถโหลดการตั้งค่าระบบอบรมได้\\nรายละเอียดเพิ่มเติม: ${trainingErrorText(error)}';
          _messageError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    final enabled = _settings['trainingEnabled'] == true;
    final configurable = _settings['hasConfigurableSettings'] == true;
    return buildTrainingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: TrainingMenuCodes.settings,
      child: Stack(
        children: [
          Padding(
            padding: tokens.workspace.contentMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LaooCaptionCard(
                  tokens: tokens.workspace,
                  caption: _caption,
                  leading: Icon(
                    Icons.settings_outlined,
                    color: tokens.primaryColor,
                  ),
                ),
                SizedBox(height: tokens.workspace.sectionSpacing),
                Expanded(
                  child: LaooSurfaceCard(
                    tokens: tokens.workspace,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _content(tokens, enabled, configurable),
                  ),
                ),
              ],
            ),
          ),
          if (_message != null)
            Positioned(
              top: 16,
              right: 16,
              child: buildTrainingMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(TrainingUiTokens tokens, bool enabled, bool configurable) =>
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 42,
                  color: tokens.primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  enabled ? 'ระบบอบรมพร้อมใช้งาน' : 'ระบบอบรมยังไม่พร้อมใช้งาน',
                  textAlign: TextAlign.center,
                  style: tokens.workspace.sectionStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  configurable
                      ? 'การตั้งค่าที่แก้ไขได้จะแสดงในหน้านี้'
                      : 'เวอร์ชันนี้ยังไม่มีค่าระบบที่อนุญาตให้แก้ไข',
                  textAlign: TextAlign.center,
                  style: tokens.workspace.tableStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Project: ${_settings['projectCode'] ?? '-'}',
                  textAlign: TextAlign.center,
                  style: tokens.workspace.tableStyle,
                ),
              ],
            ),
          ),
        ),
      );
}
