import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_room_issue_repository.dart';
import '../data/meeting_room_repository.dart';
import '../meeting_feature_host.dart';

class MeetingRoomIssuePage extends StatefulWidget {
  const MeetingRoomIssuePage({super.key});

  @override
  State<MeetingRoomIssuePage> createState() => _MeetingRoomIssuePageState();
}

class _MeetingRoomIssuePageState extends State<MeetingRoomIssuePage> {
  final _issues = MeetingRoomIssueRepository();
  final _rooms = MeetingRoomRepository();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _roomsData = [];
  Map<String, bool> _actions = {};
  String _caption = 'แจ้งส่งซ่อมอุปกรณ์';
  String? _message;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '22003',
      routeName: 'roomIssues',
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        _issues.get(),
        _issues.actions(),
        _rooms.get(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(result[0] as List);
        _actions = Map<String, bool>.from(result[1] as Map);
        _roomsData = List<Map<String, dynamic>>.from(result[2] as List);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = _error(error, 'โหลดรายการแจ้งซ่อมไม่สำเร็จ');
        });
      }
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\n$error';

  Future<void> _createIssue() async {
    final rooms = _roomsData
        .where((room) => (room['itemItems'] as List? ?? const []).isNotEmpty)
        .toList();
    if (rooms.isEmpty) {
      setState(() => _message = 'ยังไม่มีสินค้าอุปกรณ์ที่กำหนดให้ห้อง');
      return;
    }
    int? roomId = (rooms.first['roomId'] as num).toInt();
    int? itemId = ((rooms.first['itemItems'] as List).first['itemId'] as num)
        .toInt();
    final description = TextEditingController();
    final value = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(
            'แจ้งส่งซ่อมอุปกรณ์',
            style: LaooTypography.popupTitleStyle,
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: roomId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ห้องประชุม'),
                  items: rooms
                      .map(
                        (room) => DropdownMenuItem<int>(
                          value: (room['roomId'] as num).toInt(),
                          child: Text('${room['code']} | ${room['nameTh']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final selected = rooms.firstWhere(
                      (room) => room['roomId'] == value,
                    );
                    final available = List<Map<String, dynamic>>.from(
                      selected['itemItems'] as List? ?? const [],
                    );
                    refresh(() {
                      roomId = value;
                      itemId = available.isEmpty
                          ? null
                          : (available.first['itemId'] as num).toInt();
                    });
                  },
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                DropdownButtonFormField<int>(
                  initialValue: itemId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'สินค้าอุปกรณ์'),
                  items: () {
                    final selected = rooms.firstWhere(
                      (room) => room['roomId'] == roomId,
                    );
                    return List<Map<String, dynamic>>.from(
                          selected['itemItems'] as List? ?? const [],
                        )
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: (item['itemId'] as num).toInt(),
                            child: Text('${item['code']} | ${item['nameTh']}'),
                          ),
                        )
                        .toList();
                  }(),
                  onChanged: (value) => refresh(() => itemId = value),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'อาการหรือรายละเอียดปัญหา *',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (roomId == null ||
                    itemId == null ||
                    description.text.trim().isEmpty)
                  return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('แจ้งส่งซ่อม'),
            ),
          ],
        ),
      ),
    );
    final text = description.text.trim();
    description.dispose();
    if (value != true || roomId == null || itemId == null || text.isEmpty)
      return;
    try {
      await _issues.create(roomId: roomId!, itemId: itemId!, description: text);
      if (mounted) {
        setState(() => _message = 'แจ้งส่งซ่อมสำเร็จ');
        await _load();
      }
    } catch (error) {
      if (mounted)
        setState(() => _message = _error(error, 'แจ้งส่งซ่อมไม่สำเร็จ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return buildMeetingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: '22003',
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: WorkspaceSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: WorkspacePageTitle(
                      title: _caption,
                      favoriteKey: '22003',
                    ),
                  ),
                  if (_actions['create'] == true)
                    FilledButton.icon(
                      onPressed: _createIssue,
                      icon: const Icon(Icons.build_outlined),
                      label: const Text('แจ้งส่งซ่อม'),
                    ),
                ],
              ),
              const SizedBox(height: LaooLayout.cardSpacing),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: _items.isEmpty
                    ? const Center(child: Text('ยังไม่มีรายการแจ้งซ่อม'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            tileColor: preset.primary.withValues(alpha: .06),
                            title: Text(
                              '${item['itemName']} (${item['itemCode']})',
                            ),
                            subtitle: Text(
                              '${item['roomCode']} | ${item['roomNameTh']}\n${item['description']}',
                            ),
                            trailing: Text('${item['statusCode']}'),
                          );
                        },
                      ),
              ),
              if (_message != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: AutoDismissMessage(
                    message: _message!,
                    onClose: () => setState(() => _message = null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
