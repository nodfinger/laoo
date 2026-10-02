import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'evaluation_feature_host.dart';
import 'evaluation_popup_theme.dart';

const evaluationSourceLabels = <String, String>{
  'TRAINING_COURSE': 'หลักสูตรอบรม',
  'TRAINING_INSTRUCTOR': 'วิทยากร',
  'MEETING_ROOM': 'ห้องประชุม',
  'VENDOR': 'Vendor',
  'SERVICE': 'งานบริการ',
  'GENERAL': 'ทั่วไป',
};

class EvaluationSettingsPage extends StatefulWidget {
  const EvaluationSettingsPage({super.key, required this.title});

  final String title;

  @override
  State<EvaluationSettingsPage> createState() => _EvaluationSettingsPageState();
}

class _EvaluationSettingsPageState extends State<EvaluationSettingsPage> {
  late final JsonApiClient _api;
  final Map<String, _SettingDraft> _drafts = {};
  bool _loading = true;
  bool _saving = false;
  bool _canEdit = false;
  String? _loadError;
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _api = createEvaluationApiClient();
    _resolveTitle();
    _load();
  }

  Future<void> _resolveTitle() async {
    final title = await resolveEvaluationMenuTitle('47001', widget.title);
    if (mounted) setState(() => _title = title);
  }

  @override
  void dispose() {
    disposeEvaluationApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final raw = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/settings') as Map,
      );
      final settings = List<Map<String, dynamic>>.from(
        raw['items'] as List? ?? const [],
      );
      final permissions = Map<String, dynamic>.from(
        raw['permissions'] as Map? ?? const {},
      );
      final templateResults = await Future.wait(
        evaluationSourceLabels.keys.map(
          (source) => _api.get(
            '/api/company/evaluations/settings/templates',
            query: {'sourceType': source},
          ),
        ),
      );
      if (!mounted) return;
      final next = <String, _SettingDraft>{};
      for (final entry in evaluationSourceLabels.entries.indexed) {
        final source = entry.$2.key;
        final current = settings.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['sourceType'] == source,
          orElse: () => null,
        );
        final templateResponse = Map<String, dynamic>.from(
          templateResults[entry.$1] as Map,
        );
        next[source] = _SettingDraft(
          sourceType: source,
          isActive: current?['isActive'] == true,
          templateId: (current?['templateId'] as num?)?.toInt(),
          templates: List<Map<String, dynamic>>.from(
            templateResponse['items'] as List? ?? const [],
          ),
        );
      }
      setState(() {
        _drafts
          ..clear()
          ..addAll(next);
        _canEdit = permissions['edit'] == true;
      });
    } catch (error) {
      if (!mounted) return;
      final detail = evaluationErrorText(error);
      setState(() => _loadError = detail);
      showEvaluationMessage(
        context,
        message:
            'ไม่สามารถโหลดข้อมูลตั้งค่าระบบประเมินได้\\nรายละเอียดเพิ่มเติม: $detail',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final invalid = _drafts.values.where(
      (draft) => draft.isActive && draft.templateId == null,
    );
    if (invalid.isNotEmpty) {
      final labels = invalid
          .map((draft) => evaluationSourceLabels[draft.sourceType])
          .join(', ');
      showEvaluationMessage(
        context,
        message:
            'ข้อมูลตั้งค่าไม่ครบ\\nรายละเอียดเพิ่มเติม: กรุณาเลือกแบบประเมินเริ่มต้นสำหรับ $labels',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      for (final draft in _drafts.values) {
        await _api.put(
          '/api/company/evaluations/settings/source/${draft.sourceType}',
          body: {
            'sourceType': draft.sourceType,
            'templateId': draft.templateId,
            'isActive': draft.isActive,
          },
        );
      }
      if (!mounted) return;
      showEvaluationMessage(
        context,
        message: 'บันทึกการตั้งค่าระบบประเมินสำเร็จ',
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showEvaluationMessage(
        context,
        message:
            'บันทึกการตั้งค่าไม่สำเร็จ\\nรายละเอียดเพิ่มเติม: ${evaluationErrorText(error)}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = evaluationUiTokens;
    return buildEvaluationWorkspaceShell(
      pageTitle: _title,
      activeMenu: '47001',
      child: Theme(
        data: evaluationPopupTheme(context),
        child: ColoredBox(
          color: tokens.backgroundColor,
          child: Padding(
            padding: tokens.contentMargin,
            child: Column(
              children: [
                _CaptionCard(title: _title),
                SizedBox(height: tokens.sectionSpacing),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final tokens = evaluationUiTokens;
    if (_loading) {
      return Card(
        margin: EdgeInsets.zero,
        color: tokens.popupSurfaceColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Card(
        margin: EdgeInsets.zero,
        color: tokens.popupSurfaceColor,
        child: Center(
          child: Padding(
            padding: tokens.cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                SizedBox(height: tokens.itemSpacing),
                const Text('ไม่สามารถแสดงการตั้งค่าระบบประเมินได้'),
                SizedBox(height: tokens.itemSpacing),
                Text(
                  'รายละเอียดเพิ่มเติม: $_loadError',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.itemSpacing),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: tokens.popupSurfaceColor,
      child: Padding(
        padding: tokens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 700
                          ? 2
                          : 1;
                      final width = columns == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth -
                                    tokens.itemSpacing * (columns - 1)) /
                                columns;
                      return Wrap(
                        spacing: tokens.itemSpacing,
                        runSpacing: tokens.itemSpacing,
                        children: evaluationSourceLabels.keys
                            .map(
                              (source) => SizedBox(
                                width: width,
                                child: _SettingSourceCard(
                                  draft: _drafts[source]!,
                                  enabled: _canEdit && !_saving,
                                  onChanged: () => setState(() {}),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
            Divider(height: tokens.sectionSpacing * 2),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: tokens.buttonHeight,
                child: FilledButton.icon(
                  onPressed: _canEdit && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionCard extends StatelessWidget {
  const _CaptionCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = evaluationUiTokens;
    return Card(
      margin: EdgeInsets.zero,
      color: tokens.popupSurfaceColor,
      child: Padding(
        padding: tokens.cardPadding,
        child: Row(
          children: [
            Expanded(child: Text(title, style: tokens.captionStyle)),
            const LaooPageFavoriteButton(),
          ],
        ),
      ),
    );
  }
}

class _SettingSourceCard extends StatelessWidget {
  const _SettingSourceCard({
    required this.draft,
    required this.enabled,
    required this.onChanged,
  });

  final _SettingDraft draft;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = evaluationUiTokens;
    final selectedExists = draft.templates.any(
      (item) => (item['id'] as num?)?.toInt() == draft.templateId,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.popupSurfaceColor,
        border: Border.all(color: tokens.borderColor),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Padding(
        padding: tokens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    evaluationSourceLabels[draft.sourceType] ??
                        draft.sourceType,
                    style: tokens.sectionStyle,
                  ),
                ),
                Switch(
                  value: draft.isActive,
                  onChanged: enabled
                      ? (value) {
                          draft.isActive = value;
                          onChanged();
                        }
                      : null,
                ),
              ],
            ),
            SizedBox(height: tokens.itemSpacing),
            DropdownButtonFormField<int>(
              key: ValueKey(
                '${draft.sourceType}-${draft.templateId}-${draft.templates.length}',
              ),
              initialValue: selectedExists ? draft.templateId : null,
              isExpanded: true,
              style: tokens.inputStyle,
              decoration: InputDecoration(
                labelText: 'แบบประเมินเริ่มต้น',
                labelStyle: tokens.inputStyle.copyWith(
                  color: tokens.primaryColor,
                ),
                floatingLabelStyle: tokens.inputStyle.copyWith(
                  color: tokens.primaryColor,
                  fontSize: 14 / .75,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                  borderSide: BorderSide(color: tokens.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                  borderSide: BorderSide(color: tokens.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                  borderSide: BorderSide(color: tokens.primaryColor),
                ),
              ),
              items: draft.templates
                  .map(
                    (template) => DropdownMenuItem<int>(
                      value: (template['id'] as num).toInt(),
                      child: Text(
                        '${template['code']} | ${template['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (value) {
                      draft.templateId = value;
                      onChanged();
                    }
                  : null,
            ),
            if (draft.templates.isEmpty) ...[
              SizedBox(height: tokens.itemSpacing),
              Text(
                'ยังไม่มีแบบประเมินที่เปิดใช้งานสำหรับประเภทนี้',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingDraft {
  _SettingDraft({
    required this.sourceType,
    required this.isActive,
    required this.templateId,
    required this.templates,
  });

  final String sourceType;
  bool isActive;
  int? templateId;
  final List<Map<String, dynamic>> templates;
}
