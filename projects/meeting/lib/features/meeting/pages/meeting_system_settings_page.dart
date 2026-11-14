import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
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
  bool _loaded = false;
  bool _canEdit = false;
  bool _messageError = false;
  final _orientations = List<String>.filled(10, 'PORTRAIT');
  final _backgrounds = List<Uint8List?>.filled(10, null);
  final _changedBackgrounds = <int>{};
  final Map<String, bool> _visibility = {
    'privateSubject': false,
    'showRequester': false,
    'showDepartment': false,
    'showActivityType': false,
    'showAttendeeCount': false,
    'showSubject': false,
    'showDetails': false,
    'showRemark': false,
    'showWaitingList': false,
  };
  static const _visibilityLabels = {
    'showRequester': 'ชื่อผู้จอง',
    'showDepartment': 'แผนกผู้จอง',
    'showActivityType': 'ประเภทกิจกรรม',
    'showAttendeeCount': 'จำนวนผู้เข้าร่วม',
    'showSubject': 'หัวข้อกิจกรรม',
    'showDetails': 'รายละเอียด',
    'showRemark': 'หมายเหตุ',
    'showWaitingList': 'รายการรอใช้ห้อง',
  };

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
      final backgrounds = await _repository.backgrounds();
      final visibility = await _repository.displayVisibility();
      if (!mounted) return;
      setState(() {
        _requireReview = settings['requireEquipmentRequestReview'] == true;
        _canEdit = settings['canEdit'] == true;
        for (final key in _visibility.keys) {
          _visibility[key] = visibility[key] == true;
        }
        for (final background in backgrounds) {
          final index = (background['slot'] as num).toInt() - 1;
          if (index < 0 || index >= 10) continue;
          _orientations[index] = background['orientation'] as String;
          _backgrounds[index] = background['image'] == null
              ? null
              : base64Decode(background['image'] as String);
        }
        _changedBackgrounds.clear();
        _loaded = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loaded = false;
        _messageError = true;
        _message = _error(error, 'ไม่สามารถโหลดการตั้งค่า Meeting ได้');
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.saveSettings(_requireReview);
      await _repository.saveDisplayVisibility(_visibility);
      for (final index in _changedBackgrounds.toList()) {
        final image = _backgrounds[index];
        await _repository.saveBackground(
          index + 1,
          _orientations[index],
          image == null ? null : base64Encode(image),
        );
        _changedBackgrounds.remove(index);
      }
      if (!mounted) return;
      setState(() {
        _messageError = false;
        _message = 'บันทึกการตั้งค่า Meeting แล้ว';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messageError = true;
        _message = _error(error, 'บันทึกการตั้งค่าไม่สำเร็จ');
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\n$error';

  Future<void> _pickBackground(int index) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (!mounted || picked == null) return;
    final file = picked.files.single;
    if (file.bytes == null || file.size == 0 || file.size > 5 * 1024 * 1024) {
      setState(() {
        _messageError = true;
        _message = 'กรุณาเลือกรูปขนาดไม่เกิน 5 MB';
      });
      return;
    }
    setState(() {
      _backgrounds[index] = file.bytes;
      _changedBackgrounds.add(index);
    });
  }

  void _zoomBackground(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 800,
          height: 600,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(child: Image.memory(bytes)),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final title = WorkspacePageTitle(
                        title: _caption,
                        favoriteKey: MeetingMenuCodes.systemSettings,
                      );
                      final save = _loaded && _canEdit
                          ? SizedBox(
                              height: LaooTypography.buttonHeight,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('บันทึก'),
                              ),
                            )
                          : null;
                      if (constraints.maxWidth < 400) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            title,
                            if (save != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: save,
                              ),
                            ],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: title),
                          if (save != null) ...[const SizedBox(width: 8), save],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                Expanded(
                  child: WorkspaceSectionCard(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : !_loaded
                        ? Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() => _loading = true);
                                _load();
                              },
                              child: const Text('ลองโหลดอีกครั้ง'),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 720,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.inventory_2_outlined,
                                                color: preset.primary,
                                              ),
                                              const SizedBox(
                                                width: LaooLayout.cardSpacing,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'คำขออุปกรณ์เพิ่มเติม',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: LaooLayout.cardSpacing,
                                          ),
                                          SwitchListTile.adaptive(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                              'ต้องตรวจสอบก่อนส่งแผนก',
                                            ),
                                            subtitle: Text(
                                              _requireReview
                                                  ? 'คำขอใหม่จะรอเจ้าของประชุม, Admin ห้อง หรือ Company Admin ตรวจสอบก่อน'
                                                  : 'คำขอใหม่จะส่งถึงแผนกรับผิดชอบทันที',
                                            ),
                                            value: _requireReview,
                                            onChanged: _saving || !_canEdit
                                                ? null
                                                : (value) => setState(
                                                    () =>
                                                        _requireReview = value,
                                                  ),
                                          ),
                                          SwitchListTile.adaptive(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                              'แสดงหัวข้อประชุมเฉพาะผู้จอง และผู้ดูแลห้องประชุมเท่านั้น',
                                            ),
                                            value:
                                                _visibility['privateSubject']!,
                                            onChanged: _saving || !_canEdit
                                                ? null
                                                : (value) => setState(
                                                    () =>
                                                        _visibility['privateSubject'] =
                                                            value,
                                                  ),
                                          ),
                                          const SizedBox(height: 12),
                                          WorkspaceSectionCard(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  'กำหนดข้อมูลแสดงที่เครื่องหน้าห้องประชุม',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                LayoutBuilder(
                                                  builder: (context, constraints) => Wrap(
                                                    children: [
                                                      for (final item
                                                          in _visibilityLabels
                                                              .entries)
                                                        SizedBox(
                                                          width:
                                                              constraints
                                                                      .maxWidth <
                                                                  480
                                                              ? constraints
                                                                    .maxWidth
                                                              : constraints
                                                                        .maxWidth /
                                                                    2,
                                                          child: CheckboxListTile(
                                                            contentPadding:
                                                                EdgeInsets.zero,
                                                            controlAffinity:
                                                                ListTileControlAffinity
                                                                    .leading,
                                                            title: Text(
                                                              item.value,
                                                            ),
                                                            value:
                                                                _visibility[item
                                                                    .key],
                                                            onChanged:
                                                                _saving ||
                                                                    !_canEdit
                                                                ? null
                                                                : (
                                                                    value,
                                                                  ) => setState(
                                                                    () => _visibility[item.key] =
                                                                        value ??
                                                                        false,
                                                                  ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(
                                            color: LaooColors.border,
                                          ),
                                          Text(
                                            'การเปลี่ยนค่านี้มีผลเฉพาะคำขอที่สร้างใหม่ คำขอเดิมจะใช้ Flow เดิมที่บันทึกไว้',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'เพิ่มรูปพื้นหลังเครื่องติดหน้าห้องประชุม',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'รูป JPG, PNG หรือ WEBP ขนาดไม่เกิน 5 MB กดรูปเพื่อขยาย',
                                          ),
                                          for (
                                            var index = 0;
                                            index < 10;
                                            index++
                                          )
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 64,
                                                    child: Text(
                                                      'แบบที่ ${index + 1}',
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 150,
                                                    child: DropdownButtonFormField<String>(
                                                      initialValue:
                                                          _orientations[index],
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'รูปแบบ',
                                                          ),
                                                      items: const [
                                                        DropdownMenuItem(
                                                          value: 'PORTRAIT',
                                                          child: Text(
                                                            'แนวตั้ง',
                                                          ),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'LANDSCAPE',
                                                          child: Text('แนวนอน'),
                                                        ),
                                                      ],
                                                      onChanged:
                                                          !_canEdit || _saving
                                                          ? null
                                                          : (
                                                              value,
                                                            ) => setState(() {
                                                              _orientations[index] =
                                                                  value!;
                                                              _changedBackgrounds
                                                                  .add(index);
                                                            }),
                                                    ),
                                                  ),
                                                  if (_backgrounds[index] !=
                                                      null)
                                                    InkWell(
                                                      onTap: () =>
                                                          _zoomBackground(
                                                            _backgrounds[index]!,
                                                          ),
                                                      child: Image.memory(
                                                        _backgrounds[index]!,
                                                        width: 72,
                                                        height: 56,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  if (_canEdit)
                                                    OutlinedButton.icon(
                                                      onPressed: _saving
                                                          ? null
                                                          : () =>
                                                                _pickBackground(
                                                                  index,
                                                                ),
                                                      icon: const Icon(
                                                        Icons.image_outlined,
                                                      ),
                                                      label: const Text(
                                                        'เลือกไฟล์',
                                                      ),
                                                    ),
                                                  if (_canEdit &&
                                                      _backgrounds[index] !=
                                                          null)
                                                    IconButton(
                                                      tooltip: 'ลบรูป',
                                                      onPressed: _saving
                                                          ? null
                                                          : () => setState(() {
                                                              _backgrounds[index] =
                                                                  null;
                                                              _changedBackgrounds
                                                                  .add(index);
                                                            }),
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            if (_message != null)
              AutoDismissMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
          ],
        ),
      ),
    );
  }
}
