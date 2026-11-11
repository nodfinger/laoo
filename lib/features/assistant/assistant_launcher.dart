import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'assistant_attachment_picker.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/app_auth_controller.dart';
import '../profile/pages/user_profile_dialog.dart';
import 'ai_chat_settings_card.dart';
import 'assistant_greeting.dart';
import 'assistant_report.dart';

/// Local, session-only assistant. All data operations still use authorized APIs.
class AssistantLauncher extends StatefulWidget {
  const AssistantLauncher({super.key, required this.child, this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<AssistantLauncher> createState() => _AssistantLauncherState();
}

class _AssistantLauncherState extends State<AssistantLauncher> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => AnimatedBuilder(
      animation: Listenable.merge([
        appAuthController,
        workspaceThemeController,
        userProfileAvatarNotifier,
      ]),
      builder: (context, _) => _AssistantDialogScope(
        navigatorKey:
            widget.navigatorKey ?? appRouter.routerDelegate.navigatorKey,
        child: Stack(
          children: [
            widget.child,
            if (appAuthController.isAuthenticated &&
                appAuthController.isCompanyUser)
              _AssistantOverlay(
                key: ValueKey(
                  '${appAuthController.session?.companyId}:${appAuthController.session?.userId}',
                ),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant AssistantLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

class _AssistantDialogScope extends InheritedWidget {
  const _AssistantDialogScope({
    required this.navigatorKey,
    required super.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  bool updateShouldNotify(_AssistantDialogScope oldWidget) =>
      navigatorKey != oldWidget.navigatorKey;
}

/// Opens dialogs on the app navigator, even when the assistant is in an overlay.
Future<T?> showAssistantDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final scope = context
      .dependOnInheritedWidgetOfExactType<_AssistantDialogScope>();
  final navigatorContext = scope?.navigatorKey.currentContext;
  if (navigatorContext == null) {
    return Future.error(StateError('Assistant navigator is not available'));
  }
  return showDialog<T>(context: navigatorContext, builder: builder);
}

class _AssistantOverlay extends StatefulWidget {
  const _AssistantOverlay({super.key});
  @override
  State<_AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends State<_AssistantOverlay> {
  final _api = ApiClient();
  final _text = TextEditingController();
  final _messages = <String>[];
  final _menuGuideResults = <int, List<Map<String, dynamic>>>{};
  String? _guideStage;
  List<Map<String, dynamic>> _guideChoices = [];
  String _pronoun = 'ผู้ช่วย';

  Future<void> _askGuideSystems({bool notFound = false}) async {
    final response = await _api.get('/api/assistant/menu-guide/systems');
    if (!mounted) return;
    final systems = response is Map && response['items'] is List
        ? (response['items'] as List)
              .whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x))
              .toList()
        : <Map<String, dynamic>>[];
    setState(() {
      _guideChoices = systems;
      _guideStage = systems.isEmpty ? null : 'systems';
      _choiceOptions = systems.map((x) => '${x['projectName']}').toList();
      _messages.add(
        systems.isEmpty
            ? '$_pronoun ไม่พบระบบที่คุณมีสิทธิ์เข้าถึง กรุณาติดต่อผู้ดูแลระบบ'
            : '${notFound ? '$_pronoun ไม่พบเมนูที่ตรงกับคำถาม\n' : ''}กรุณาเลือกระบบที่ต้องการให้ $_pronoun ช่วยแนะนำ หรือพิมพ์ ยกเลิก\n${_numbered(_choiceOptions)}',
      );
      _choiceMessageIndex = systems.isEmpty ? null : _messages.length - 1;
    });
  }

  Future<void> _showGuideMenus(String projectCode) async {
    final response = await _api.get(
      '/api/assistant/menu-guide/systems/${Uri.encodeComponent(projectCode)}',
    );
    if (!mounted) return;
    final menus = response is Map && response['items'] is List
        ? (response['items'] as List)
              .whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x))
              .toList()
        : <Map<String, dynamic>>[];
    setState(() {
      _guideChoices = menus;
      _guideStage = menus.isEmpty ? null : 'menus';
      _choiceOptions = menus
          .map((x) => '${x['groupName']} → ${x['menuName']}')
          .toList();
      _messages.add(
        menus.isEmpty
            ? '$_pronoun ไม่พบเมนูที่คุณมีสิทธิ์ใช้งานในระบบนี้'
            : 'กรุณาเลือกเมนูที่ต้องการให้ $_pronoun เปิด หรือพิมพ์ ยกเลิก\n${_numbered(_choiceOptions)}',
      );
      _choiceMessageIndex = menus.isEmpty ? null : _messages.length - 1;
    });
  }

  Future<void> _openGuidedMenu(Map<String, dynamic> menu) async {
    final project = Uri.encodeComponent('${menu['projectCode'] ?? ''}');
    final code = Uri.encodeComponent('${menu['menuCode'] ?? ''}');
    try {
      final result = await _api.get('/api/assistant/menu-guide/$project/$code');
      if (!mounted) return;
      final path = result is Map ? result['routePath'] : null;
      if (path is! String || !path.startsWith('/') || path.startsWith('//')) {
        throw StateError('invalid route');
      }
      appRouter.go(path);
    } catch (_) {
      if (mounted)
        setState(
          () => _messages.add(
            'ไม่สามารถเปิดเมนูนี้ได้ สิทธิ์หรือสถานะการใช้งานอาจเปลี่ยน กรุณาตรวจสอบแล้วลองใหม่',
          ),
        );
    }
  }

  String? _activeAgentId;
  final _userMessageIndices = <int>{};
  final _messageAgentImages = <int, Uint8List>{};
  Uint8List? _activeAgentImage;
  bool _open = false;
  bool _busy = false;
  bool _waitingForSerial = false;
  bool _serialForHistory = false;
  bool _serialCombined = false;
  bool _showCreateLink = false;
  bool _waitingMeetingAvailability = false;
  String? _draftSubject, _draftDetail, _draftKey;
  List<String> _subjectOptions = [];
  List<String> _choiceOptions = [];
  int? _choiceMessageIndex;
  String? _pendingCapabilityQuestion;
  List<String> _pendingCapabilityCodes = [];
  final Map<String, int> _equipmentOptions = {};
  bool _requireEquipment = false;
  int? _draftEquipment;
  String? _draftEquipmentSerial;
  bool _serialAnswered = false;
  bool _equipmentAnswered = false,
      _photoAnswered = false,
      _requirePhoto = false;
  String _nickname = '';
  final List<PlatformFile> _draftImages = [];
  Map<String, String>? _reportQuery;
  Map<String, dynamic> _reportOptions = {};
  bool _reportReady = false;
  String _reportCode = 'repair.parts_cost';
  int? _reportRequestId;
  bool _enabled = false, _showUserImage = false, _showAiImage = false;
  String _name = 'ผู้ช่วย AI';
  Uint8List? _aiImage;
  Timer? _settingsTimer;
  int _settingsRequest = 0;
  List<Map<String, dynamic>> _favoriteCommands = [];
  List<Map<String, dynamic>> _recentCommands = [];
  int _favoriteLimit = 0;
  int _recentLimit = 0;
  bool? _commandListFavorites;
  String? _deleteFavoriteId;
  final Map<int, Map<String, String>> _favoritePrompts = {};

  Future<void> _loadCommands() async {
    try {
      final result = await _api.get('/api/assistant/user-commands');
      if (!mounted || result is! Map) return;
      setState(() {
        _favoriteCommands = (result['favorite'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _recentCommands = (result['recent'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _favoriteLimit = (result['favoriteLimit'] as num?)?.toInt() ?? 0;
        _recentLimit = (result['recentLimit'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _favoriteCommands = [];
          _recentCommands = [];
        });
      }
    }
  }

  Future<void> _recordCommand(String text, String capability) async {
    try {
      await _api.post(
        '/api/assistant/user-commands/recent',
        body: {'text': text, 'capability': capability},
      );
      await _loadCommands();
      if (!mounted) return;
      final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (_favoriteLimit <= 0 ||
          _favoriteCommands.length >= _favoriteLimit ||
          _favoriteCommands.any(
            (item) =>
                '${item['text']}'.toLowerCase().replaceAll(
                  RegExp(r'\s+'),
                  '',
                ) ==
                normalized,
          )) {
        return;
      }
      if (_favoritePrompts.values.any(
        (item) =>
            item['text']!.toLowerCase().replaceAll(RegExp(r'\s+'), '') ==
            normalized,
      )) {
        return;
      }
      setState(() {
        final index = _messages.length;
        _messages.add(
          'ต้องการเก็บคำสั่ง “$text” ไว้ใช้บ่อยหรือไม่? (${_favoriteCommands.length}/$_favoriteLimit)',
        );
        _favoritePrompts[index] = {'text': text, 'capability': capability};
      });
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add('ไม่สามารถบันทึกคำสั่งได้ กรุณาลองใหม่'));
      }
    }
  }

  void _showCommands(bool favorites) {
    setState(() {
      _commandListFavorites = _commandListFavorites == favorites
          ? null
          : favorites;
      _deleteFavoriteId = null;
    });
  }

  Future<void> _answerFavoritePrompt(int index, bool save) async {
    final item = _favoritePrompts.remove(index);
    if (item == null) return;
    setState(() {});
    if (!save) {
      setState(() => _messages.add('ไม่เก็บคำสั่งนี้เป็นคำสั่งใช้บ่อย'));
      return;
    }
    try {
      await _api.post('/api/assistant/user-commands/favorite', body: item);
      await _loadCommands();
      if (mounted) setState(() => _messages.add('บันทึกคำสั่งใช้บ่อยแล้ว'));
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            'บันทึกคำสั่งใช้บ่อยไม่สำเร็จ กรุณาตรวจสอบจำนวนที่เก็บและลองใหม่',
          ),
        );
      }
    }
  }

  Future<void> _deleteFavorite(String id) async {
    setState(() => _deleteFavoriteId = null);
    try {
      await _api.delete('/api/assistant/user-commands/favorite/$id');
      await _loadCommands();
      if (mounted) setState(() => _messages.add('ลบคำสั่งใช้บ่อยแล้ว'));
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add('ลบคำสั่งไม่สำเร็จ กรุณาลองใหม่'));
      }
    }
  }

  List<String> _matchingSubjects(String text) {
    final query = text.toLowerCase().trim();
    final matches = _subjectOptions
        .where(
          (s) =>
              query.contains(s.toLowerCase()) ||
              s.toLowerCase().contains(query),
        )
        .toList();
    if (matches.isNotEmpty) return matches;
    const terms = {
      'ไฟฟ้า': ['ไฟ', 'ไฟฟ้า', 'ปลั๊ก', 'หลอด'],
      'ประปา': ['น้ำ', 'ท่อ', 'ก๊อก', 'ประปา'],
      'ปรับอากาศ': ['แอร์', 'เครื่องปรับอากาศ'],
      'สะอาด': ['สกปรก', 'ทำความสะอาด'],
      'ชำรุด': [
        'คอม',
        'โน้ตบุ๊ก',
        'notebook',
        'เสีย',
        'ชำรุด',
        'เปิดไม่ติด',
        'จอ',
      ],
    };
    return _subjectOptions
        .where(
          (subject) => terms.entries.any(
            (entry) =>
                subject.contains(entry.key) && entry.value.any(query.contains),
          ),
        )
        .toList();
  }

  String _choiceLabel(String option) {
    if (!_equipmentOptions.containsKey(option)) return option;
    final separator = option.indexOf(' | ');
    return separator < 0 ? option : option.substring(separator + 3);
  }

  String _numbered(List<String> options) => [
    for (var i = 0; i < options.length; i++)
      '${i + 1}. ${_choiceLabel(options[i])}',
  ].join('\n');

  String? _selectedChoice(String text) {
    final number = int.tryParse(text.trim());
    if (number != null && number > 0 && number <= _choiceOptions.length) {
      return _choiceOptions[number - 1];
    }
    if (_choiceOptions.contains(text)) return text;
    final matches = _choiceOptions
        .where((option) => _choiceLabel(option) == text)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  @override
  void initState() {
    super.initState();
    aiChatSettingsRevision.addListener(_loadSettings);
    _loadSettings();
    _settingsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadSettings(),
    );
  }

  Future<void> _loadSettings() async {
    final request = ++_settingsRequest;
    try {
      final result = await _api.get('/api/assistant/settings');
      if (result is! Map || result['settings'] is! Map) {
        throw StateError('Invalid settings');
      }
      final s = result['settings'] as Map;
      Uint8List? image;
      if (s['enabled'] == true && result['hasImage'] == true) {
        try {
          image = Uint8List.fromList(
            await _api.getBytes('/api/assistant/image'),
          );
        } catch (_) {}
      }
      if (!mounted || request != _settingsRequest) return;
      final periods = <AssistantGreetingPeriod>[];
      for (final key in [
        'morning',
        'lateMorning',
        'afternoon',
        'evening',
        'night',
      ]) {
        final start = AssistantGreetingPeriod.parseTime(
          '${s['${key}Start'] ?? ''}',
        );
        final end = AssistantGreetingPeriod.parseTime(
          '${s['${key}End'] ?? ''}',
        );
        if (start != null && end != null) {
          periods.add(
            AssistantGreetingPeriod(
              startMinute: start,
              endMinute: end,
              text: '${s['${key}Text'] ?? ''}',
            ),
          );
        }
      }
      final greeting = assistantGreeting(
        mode: s['greetingMode'] == 2 ? 2 : 1,
        now: DateTime.now(),
        nickname: '${s['nickname'] ?? ''}',
        pronoun: '${s['pronoun'] ?? ''}',
        periods: periods,
      );
      setState(() {
        _enabled = s['enabled'] == true;
        _pronoun = '${s['pronoun'] ?? ''}'.trim().isEmpty
            ? 'ผู้ช่วย'
            : '${s['pronoun']}'.trim();
        _nickname = '${s['nickname'] ?? ''}'.trim();
        _name = '${s['name'] ?? 'ผู้ช่วย AI'}';
        _showUserImage = s['showUserImage'] == true;
        _showAiImage = s['showAiImage'] == true;
        _aiImage = image;
        if (_messages.isEmpty) {
          _messages.add(greeting);
        } else {
          _messages[0] = greeting;
        }
        if (!_enabled) {
          _open = false;
        }
      });
    } catch (_) {
      if (mounted && request == _settingsRequest) {
        setState(() {
          _enabled = false;
          _open = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _settingsTimer?.cancel();
    aiChatSettingsRevision.removeListener(_loadSettings);
    _api.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _lookupSerial(String serial) async {
    final result = await _api.get(
      '/api/assistant/stock/serial',
      query: {'serial': serial.trim()},
    );
    if (!mounted) return;
    final items = result is Map && result['items'] is List
        ? result['items'] as List
        : const [];
    if (items.isEmpty) {
      setState(() {
        _waitingForSerial = true;
        _messages.add(
          'ไม่พบ Serial ที่ระบุในข้อมูลที่คุณมีสิทธิ์ กรุณาตรวจสอบและพิมพ์ใหม่ หรือพิมพ์ ยกเลิก',
        );
      });
      return;
    }
    String date(dynamic value) {
      final d = DateTime.tryParse('$value');
      return d == null
          ? '-'
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    String serialStatus(dynamic value) => switch ('$value') {
      'IN_STOCK' => 'อยู่ในสต๊อก',
      'RESERVED' => 'จองแล้ว',
      'ISSUED' => 'เบิกจ่ายแล้ว',
      'SOLD' => 'ขายแล้ว',
      'INSTALLED' => 'ติดตั้งแล้ว',
      'REPAIR' => 'อยู่ระหว่างซ่อม',
      'RETIRED' => 'เลิกใช้งาน',
      _ => '$value',
    };

    final messages = items
        .whereType<Map>()
        .map((item) {
          final warranties = item['warranties'] is List
              ? item['warranties'] as List
              : const [];
          final details = warranties
              .whereType<Map>()
              .map((w) {
                final type = w['coverage'] == 'CUSTOMER'
                    ? 'ประกันลูกค้า'
                    : w['coverage'] == 'SUPPLIER'
                    ? 'ประกันผู้ขาย'
                    : 'ประกัน ${w['coverage']}';
                final mode = '${w['mode']}';
                if (mode == 'NONE') return '$type: ไม่มีประกัน';
                if (mode == 'LIFETIME') return '$type: ตลอดอายุ';
                if (w['expires'] == null) return '$type: ไม่พบวันหมดประกัน';
                final expiry = DateTime.tryParse('${w['expires']}');
                final today = DateTime.now();
                final expired =
                    expiry != null &&
                    DateTime(
                      expiry.year,
                      expiry.month,
                      expiry.day,
                    ).isBefore(DateTime(today.year, today.month, today.day));
                return '$type: ${expired ? 'หมดประกัน' : 'ถึงวันที่'} ${date(w['expires'])}';
              })
              .join('\n');
          final history = item['history'] is List
              ? item['history'] as List
              : const [];
          final events = history
              .whereType<Map>()
              .map(
                (event) =>
                    '${date(event['date'])} • ${serialStatus(event['status'] ?? '-')}',
              )
              .join('\n');
          return 'อุปกรณ์: ${item['name']}\nSerial: ${item['serial']}\nสถานะ: ${serialStatus(item['status'] ?? '-')}\n${details.isEmpty ? 'ไม่พบข้อมูลประกันที่ใช้งาน' : details}\nประวัติ Serial (ล่าสุดไม่เกิน 20 รายการ):\n${events.isEmpty ? 'ไม่พบประวัติ' : events}';
        })
        .join('\n\n');
    setState(() {
      _waitingForSerial = false;
      _messages.add(messages);
    });
  }

  Future<void> _lookupSerialHistory(String serial) async {
    final result = await _api.get(
      '/api/service/requests/assistant/serial-history',
      query: {'serial': serial.trim()},
    );
    if (!mounted) return;
    final items = result is Map && result['items'] is List
        ? result['items'] as List
        : const [];
    final rows = items
        .whereType<Map>()
        .map(
          (r) =>
              '${r['requestNo']} • ${r['subject']} • ${_status(r['statusCode']?.toString())}',
        )
        .join('\n');
    setState(() {
      _waitingForSerial = false;
      _messages.add(
        rows.isEmpty
            ? 'ไม่พบงานซ่อมสำหรับ Serial นี้ในขอบเขตที่คุณมีสิทธิ์ ใบงานเก่าที่ไม่ได้ระบุ Serial จะไม่ปรากฏ'
            : 'งานซ่อมตามสิทธิ์ของคุณ (ไม่เกิน 20 รายการ):\n$rows',
      );
    });
  }

  Future<void> _send() async {
    final userText = _text.text.trim();
    if (userText.isEmpty || _busy) return;
    var text = userText;
    setState(() {
      _busy = true;
      _userMessageIndices.add(_messages.length);
      _messages.add('คุณ: $userText');
      _text.clear();
      _showCreateLink = false;
      _reportReady = false;
    });
    final firstReplyIndex = _messages.length;
    try {
      if (_guideStage != null) {
        if (userText == 'ยกเลิก') {
          setState(() {
            _guideStage = null;
            _guideChoices = [];
            _choiceOptions = [];
            _choiceMessageIndex = null;
            _messages.add('ยกเลิกการแนะนำเมนูแล้ว');
          });
          return;
        }
        final number = int.tryParse(userText);
        var chosen =
            number != null && number > 0 && number <= _choiceOptions.length
            ? number - 1
            : _choiceOptions.indexOf(userText);
        if (chosen < 0) {
          final matching = <int>[
            for (var i = 0; i < _choiceOptions.length; i++)
              if (_choiceOptions[i].toLowerCase().contains(
                userText.toLowerCase(),
              ))
                i,
          ];
          if (matching.length == 1) chosen = matching.first;
        }
        if (chosen < 0 || chosen >= _guideChoices.length) {
          setState(() {
            _messages.add(
              '$_pronoun ไม่พบหรือไม่เข้าใจรายการที่พิมพ์\nกรุณาเลือกหรือพิมพ์หมายเลขอีกครั้ง หรือพิมพ์ ยกเลิก\n${_numbered(_choiceOptions)}',
            );
            _choiceMessageIndex = _messages.length - 1;
          });
          return;
        }
        final choice = _guideChoices[chosen];
        if (_guideStage == 'systems') {
          await _showGuideMenus('${choice['projectCode']}');
        } else {
          setState(() {
            _guideStage = null;
            _guideChoices = [];
            _choiceOptions = [];
            _choiceMessageIndex = null;
          });
          await _openGuidedMenu(choice);
        }
        return;
      }
      if (_waitingMeetingAvailability) {
        if (userText == 'ยกเลิก') {
          setState(() {
            _waitingMeetingAvailability = false;
            _messages.add('ยกเลิกการค้นหาห้องว่างแล้ว');
          });
          return;
        }
        final m = RegExp(
          r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2})\s*[-–]\s*(\d{2}):(\d{2})$',
        ).firstMatch(userText);
        if (m == null) {
          setState(
            () => _messages.add(
              'กรุณาระบุวันและเวลา เช่น 15/11/2026 09:00-10:00 หรือพิมพ์ ยกเลิก',
            ),
          );
          return;
        }
        final day = int.parse(m[1]!),
            month = int.parse(m[2]!),
            year = int.parse(m[3]!);
        final sh = int.parse(m[4]!),
            sm = int.parse(m[5]!),
            eh = int.parse(m[6]!),
            em = int.parse(m[7]!);
        final start = DateTime(year, month, day, sh, sm),
            end = DateTime(year, month, day, eh, em);
        if (start.year != year ||
            start.month != month ||
            start.day != day ||
            sh > 23 ||
            eh > 23 ||
            sm > 59 ||
            em > 59 ||
            !end.isAfter(start)) {
          setState(() => _messages.add('วันหรือเวลาไม่ถูกต้อง กรุณาระบุใหม่'));
          return;
        }
        final result = await _api.post(
          '/api/assistant/meeting/availability',
          body: {
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
          },
        );
        if (!mounted) return;
        final items = result is Map && result['items'] is List
            ? result['items'] as List
            : const [];
        final names = items
            .whereType<Map>()
            .map((x) => '• ${x['roomName']}')
            .join('\n');
        setState(() {
          _waitingMeetingAvailability = false;
          _messages.add(
            names.isEmpty
                ? 'ไม่พบห้องว่างในช่วงเวลาที่เลือก'
                : 'ห้องที่ว่าง (ไม่เกิน 20 ห้อง):\n$names',
          );
        });
        return;
      }
      if (_waitingForSerial) {
        if (userText == 'ยกเลิก') {
          setState(() {
            _waitingForSerial = false;
            _messages.add('ยกเลิกการค้นหา Serial แล้ว');
          });
          return;
        }
        if (_serialCombined) {
          await _lookupSerial(userText);
          if (!_waitingForSerial) {
            await _lookupSerialHistory(userText);
          }
        } else if (_serialForHistory) {
          await _lookupSerialHistory(userText);
        } else {
          await _lookupSerial(userText);
        }
        return;
      }
      String? selectedCapability;
      if (_pendingCapabilityQuestion != null) {
        if (userText == 'ยกเลิก') {
          setState(() {
            _pendingCapabilityQuestion = null;
            _pendingCapabilityCodes = [];
            _choiceOptions = [];
            _choiceMessageIndex = null;
            _messages.add('ยกเลิกการเลือกความสามารถแล้ว');
          });
          return;
        }
        final choice = _selectedChoice(userText);
        final number = int.tryParse(userText);
        final index =
            number != null && number > 0 && number <= _choiceOptions.length
            ? number - 1
            : choice == null ||
                  _choiceOptions.where((option) => option == choice).length != 1
            ? -1
            : _choiceOptions.indexOf(choice);
        if (index < 0 || index >= _pendingCapabilityCodes.length) {
          setState(() {
            _messages.add(
              'ไม่พบหรือไม่เข้าใจรายการที่พิมพ์\nกรุณาเลือกรายการด้านล่าง หรือพิมพ์หมายเลขอีกครั้ง (พิมพ์ ยกเลิก เพื่อออก)\n${_numbered(_choiceOptions)}',
            );
            _choiceMessageIndex = _messages.length - 1;
          });
          return;
        }
        selectedCapability = _pendingCapabilityCodes[index];
        text = _pendingCapabilityQuestion!;
        setState(() {
          _pendingCapabilityQuestion = null;
          _pendingCapabilityCodes = [];
          _choiceOptions = [];
          _choiceMessageIndex = null;
        });
      }
      if (_draftKey != null && _draftSubject == null) {
        final selected = _selectedChoice(text);
        if (selected == null) {
          final matching = _matchingSubjects(text);
          if (matching.isEmpty) {
            try {
              await _api.post(
                '/api/assistant/repair/unmatched-subject',
                body: {'text': text},
                timeout: const Duration(seconds: 3),
              );
            } catch (_) {
              // Recording is best-effort and must not interrupt the repair flow.
            }
            if (!mounted) return;
          }
          setState(() {
            if (matching.isNotEmpty) _choiceOptions = matching;
            _messages.add(
              matching.isEmpty
                  ? 'ไม่พบหรือไม่เข้าใจหัวข้อที่พิมพ์\nกรุณาเลือกรายการด้านล่าง หรือพิมพ์อาการอีกครั้ง:\n${_numbered(_choiceOptions)}'
                  : 'เลือกหัวข้อที่ใกล้เคียง โดยกดรายการหรือพิมพ์หมายเลข:\n${_numbered(matching)}',
            );
            _choiceMessageIndex = _choiceOptions.isEmpty
                ? null
                : _messages.length - 1;
          });
          return;
        }
        setState(() {
          _draftSubject = selected;
          _choiceOptions = _equipmentOptions.keys.toList();
          _messages.add(
            'ต้องการอ้างอิงอุปกรณ์หรือไม่? ${_requireEquipment ? 'กรุณาเลือกอุปกรณ์' : 'เลือกอุปกรณ์ หรือกดปุ่ม ไม่ระบุอุปกรณ์'}\n${_numbered(_choiceOptions)}',
          );
          _choiceMessageIndex = _choiceOptions.isEmpty
              ? null
              : _messages.length - 1;
        });
        return;
      }
      if (_draftKey != null && _draftSubject != null && !_equipmentAnswered) {
        final item = _equipmentOptions[_selectedChoice(text) ?? text];
        if (item == null &&
            !(!_requireEquipment && (text == 'ไม่ระบุ' || text == 'ไม่มี'))) {
          final matching = _equipmentOptions.keys
              .where((name) => name.toLowerCase().contains(text.toLowerCase()))
              .toList();
          setState(() {
            if (matching.isNotEmpty) _choiceOptions = matching;
            _messages.add(
              matching.isEmpty
                  ? 'ไม่พบหรือไม่เข้าใจอุปกรณ์ที่พิมพ์\nกรุณาเลือกรายการด้านล่าง หรือพิมพ์ชื่ออีกครั้ง:\n${_numbered(_choiceOptions)}'
                  : 'เลือกอุปกรณ์โดยกดรายการหรือพิมพ์หมายเลข:\n${_numbered(matching)}',
            );
            _choiceMessageIndex = _choiceOptions.isEmpty
                ? null
                : _messages.length - 1;
          });
          return;
        }
        setState(() {
          _draftEquipment = item;
          _equipmentAnswered = true;
          _serialAnswered = item == null;
          _choiceOptions = [];
          _choiceMessageIndex = null;
          _messages.add(
            item == null
                ? 'กรุณาระบุรายละเอียดงานซ่อม'
                : 'ระบุ Serial ของอุปกรณ์ หรือกดปุ่ม ไม่ระบุ Serial',
          );
        });
        return;
      }
      if (_draftKey != null && _equipmentAnswered && !_serialAnswered) {
        setState(() {
          _draftEquipmentSerial = text == 'ไม่ระบุ' || text == 'ไม่มี'
              ? null
              : text.trim();
          _serialAnswered = true;
          _messages.add('กรุณาระบุรายละเอียดงานซ่อม');
        });
        return;
      }
      if (_draftKey != null && _draftDetail == null) {
        setState(() {
          _draftDetail = text;
          _messages.add(
            _requirePhoto
                ? 'บริษัทกำหนดให้แนบรูป กรุณากดแนบรูป'
                : 'มีรูปถ่ายที่ต้องการแนบหรือไม่?',
          );
        });
        return;
      }
      if (_draftKey != null && !_photoAnswered) {
        setState(
          () => _messages.add('กรุณาเลือกแนบรูป หรือเลือกไม่มีรูปด้านล่าง'),
        );
        return;
      }
      if (_draftKey != null) {
        setState(
          () => _messages.add(
            'กรุณาตรวจสอบข้อมูล แล้วกดยืนยันหรือยกเลิกการแจ้งซ่อม',
          ),
        );
        return;
      }
      final response = await _api.post(
        '/api/assistant/message',
        body: {'text': text, 'selectedCapability': selectedCapability},
      );
      if (!mounted) return;
      final intent = response is Map ? response['intent'] : null;
      if (intent == 'ambiguous' &&
          response is Map &&
          response['choices'] is List) {
        final choices = (response['choices'] as List)
            .whereType<Map>()
            .where(
              (entry) => entry['code'] is String && entry['name'] is String,
            )
            .toList();
        if (choices.length >= 2) {
          setState(() {
            _pendingCapabilityQuestion = text;
            _pendingCapabilityCodes = choices
                .map((entry) => entry['code'] as String)
                .toList();
            _choiceOptions = choices
                .map((entry) => entry['name'] as String)
                .toList();
            _messages.add(
              'คำถามนี้ตรงกับหลายความสามารถ กรุณาเลือกโดยกดรายการหรือพิมพ์หมายเลข:\n${_numbered(_choiceOptions)}',
            );
            _choiceMessageIndex = _messages.length - 1;
          });
          return;
        }
      }
      if (intent is String &&
          !{
            'unknown',
            'none',
            'denied',
            'ambiguous',
            'unavailable',
          }.contains(intent)) {
        await _recordCommand(text, intent);
        if (!mounted) return;
      }
      final agent = response is Map ? response['agent'] : null;
      if (agent is Map &&
          agent['id'] is String &&
          agent['greeting'] is String &&
          _activeAgentId != agent['id']) {
        Uint8List? image;
        try {
          image = Uint8List.fromList(
            await _api.getBytes('/api/assistant/agents/${agent['id']}/image'),
          );
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _activeAgentId = agent['id'] as String;
          _activeAgentImage = image;
          if (image != null) _messageAgentImages[_messages.length] = image;
          _messages.add(agent['greeting'] as String);
        });
      }
      if (intent == 'core.menu_guide') {
        if (RegExp(
          r'^(จะใช้งาน|ใช้งาน|คีย์ข้อมูล|ทำงาน)$',
        ).hasMatch(text.replaceAll(RegExp(r'\s+'), ''))) {
          await _askGuideSystems();
          return;
        }
        final result = await _api.get(
          '/api/assistant/menu-guide',
          query: {'query': text},
        );
        if (!mounted) return;
        final menus = result is Map && result['items'] is List
            ? (result['items'] as List)
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList()
            : <Map<String, dynamic>>[];
        if (menus.isEmpty) {
          await _askGuideSystems(notFound: true);
          return;
        }
        setState(() {
          final index = _messages.length;
          _messages.add(
            menus.isEmpty
                ? 'ไม่พบเมนูที่ตรงกับคำถามและสิทธิ์ของคุณ กรุณาระบุชื่อข้อมูลให้ชัดเจนอีกครั้ง'
                : '$_pronoun พบเมนูที่คุณสามารถเข้าใช้งาน กดชื่อเมนูเพื่อเปิดหน้าจอได้เลย',
          );
          if (menus.isNotEmpty) _menuGuideResults[index] = menus;
        });
        return;
      }
      if (intent == 'meeting.availability') {
        setState(() {
          _waitingMeetingAvailability = true;
          _messages.add(
            'กรุณาระบุวันและเวลาที่ต้องการ เช่น 15/11/2026 09:00-10:00 หรือพิมพ์ ยกเลิก',
          );
        });
        return;
      }
      if (intent == 'meeting.own_bookings' || intent == 'meeting.invitations') {
        final result = await _api.get(
          intent == 'meeting.own_bookings'
              ? '/api/assistant/meeting/bookings'
              : '/api/assistant/meeting/invitations',
        );
        if (!mounted) return;
        final items = result is Map && result['items'] is List
            ? result['items'] as List
            : const [];
        final now = DateTime.now();
        final filtered = items.whereType<Map>().where((x) {
          if (!text.contains('วันนี้')) return true;
          final date = DateTime.tryParse('${x['startDateTime'] ?? ''}');
          return date != null &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        });
        String displayDate(Object? value) {
          final d = DateTime.tryParse('$value');
          if (d == null) return '-';
          return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        }

        final rows = filtered
            .map(
              (x) =>
                  '${x['subject'] ?? '-'} • ${x['roomName'] ?? x['roomNameTh'] ?? '-'} • ${displayDate(x['startDateTime'])} • ${x['status'] ?? x['invitationStatus'] ?? '-'}',
            )
            .join('\n');
        setState(
          () => _messages.add(
            rows.isEmpty
                ? 'ไม่พบรายการของคุณ'
                : 'รายการที่จะมาถึงของคุณ (ไม่เกิน 20 รายการ):\n$rows',
          ),
        );
        return;
      }
      if (intent == 'stock.serial_lookup' ||
          intent == 'repair.serial_history' ||
          intent == 'repair.serial_combined') {
        _serialCombined = intent == 'repair.serial_combined';
        _serialForHistory = intent == 'repair.serial_history';
        final match = RegExp(
          r'(?:serial|s/n|ซีเรียล)\s*[:#-]?\s*([a-zA-Z0-9][a-zA-Z0-9._/-]*)',
          caseSensitive: false,
        ).firstMatch(text);
        if (match != null) {
          if (_serialCombined) {
            await _lookupSerial(match.group(1)!);
            if (!_waitingForSerial) {
              await _lookupSerialHistory(match.group(1)!);
            }
          } else if (_serialForHistory) {
            await _lookupSerialHistory(match.group(1)!);
          } else {
            await _lookupSerial(match.group(1)!);
          }
        } else {
          setState(() {
            _waitingForSerial = true;
            _messages.add(
              'กรุณาระบุหมายเลข Serial ของอุปกรณ์ หรือพิมพ์ ยกเลิก',
            );
          });
        }
        return;
      }
      if (intent == 'repair.parts_cost') {
        final dates = RegExp(
          r'\b(\d{2})/(\d{2})/(\d{4})\b',
        ).allMatches(text).toList();
        if ((RegExp(r'\d').hasMatch(text) && dates.length != 2) ||
            dates.length > 2) {
          setState(
            () => _messages.add(
              'กรุณาระบุวันที่เริ่มและสิ้นสุดรูปแบบ dd/MM/yyyy หรือระบุ “เดือนนี้” / “ยอดสะสม”',
            ),
          );
          return;
        }
        final now = DateTime.now();
        final month = text.contains('เดือนนี้');
        var query = month
            ? {
                'from':
                    '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01',
                'to':
                    '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
              }
            : <String, String>{};
        if (dates.length == 2) {
          String? parse(RegExpMatch m) {
            final day = int.parse(m[1]!),
                mon = int.parse(m[2]!),
                year = int.parse(m[3]!);
            if (year < 1 || year > 9998) return null;
            final date = DateTime(year, mon, day);
            if (date.year != year || date.month != mon || date.day != day) {
              return null;
            }
            return '${m[3]}-${m[2]}-${m[1]}';
          }

          final from = parse(dates[0]), to = parse(dates[1]);
          if (from == null || to == null || from.compareTo(to) > 0) {
            setState(() => _messages.add('ช่วงวันที่ไม่ถูกต้อง กรุณาระบุใหม่'));
            return;
          }
          query = {'from': from, 'to': to};
        }
        final result = await _api.get(
          '/api/service/requests/assistant/parts-cost',
          query: query,
        );
        final options = await _api.get(
          '/api/assistant/registry/repair.parts_cost/options',
        );
        if (mounted && result is Map && options is Map) {
          setState(() {
            _reportCode = 'repair.parts_cost';
            _reportQuery = query;
            _reportOptions = Map<String, dynamic>.from(options);
            _reportReady = true;
            _messages.add(
              'ต้นทุนอะไหล่${dates.length == 2
                  ? 'ตามช่วงวันที่'
                  : month
                  ? 'เดือนนี้'
                  : 'สะสม'} ${result['partsTotal']} บาท (${result['count']} งาน)\nไม่รวมค่าแรงและค่าบริการอื่น',
            );
          });
        }
        return;
      }
      if (intent == 'repair.pending') {
        final result = await _api.get(
          '/api/service/requests/assistant/pending',
        );
        if (!mounted) return;
        final items = result is Map && result['items'] is List
            ? result['items'] as List
            : const [];
        final rows = items
            .whereType<Map>()
            .map(
              (r) =>
                  '${r['requestNo']} • ${r['subject']} • ${_status(r['statusCode']?.toString())}',
            )
            .join('\n');
        setState(
          () => _messages.add(
            rows.isEmpty
                ? 'ไม่พบงานซ่อมรอรับ'
                : 'งานซ่อมรอรับ (ล่าสุดไม่เกิน 20 รายการ):\n$rows',
          ),
        );
        return;
      }
      if (intent == 'repair.track_own') {
        final result = await _api.get('/api/service/requests/assistant/self');
        final options = await _api.get(
          '/api/assistant/registry/repair.track_own/options',
        );
        if (!mounted) return;
        final items = result is Map && result['items'] is List
            ? result['items'] as List
            : const [];
        final rows = items
            .whereType<Map>()
            .map(
              (r) =>
                  '${r['requestNo']} • ${r['subject']} • ${_status(r['statusCode']?.toString())}',
            )
            .join('\n');
        setState(() {
          _reportCode = 'repair.track_own';
          _reportOptions = options is Map
              ? Map<String, dynamic>.from(options)
              : {};
          _reportReady = true;
          _messages.add(
            rows.isEmpty
                ? 'ไม่พบงานซ่อมที่คุณสร้าง'
                : 'งานซ่อมของคุณ (ล่าสุดไม่เกิน 20 รายการ):\n$rows',
          );
        });
      } else {
        if (intent == 'repair.create_own') {
          final lookup = await _api.get(
            '/api/service/requests/lookup',
            query: {'self': 'true'},
          );
          if (!mounted) return;
          if (lookup is! Map || lookup['subjects'] is! List) {
            throw StateError('ไม่พบหัวข้องานซ่อม');
          }
          _requirePhoto = lookup['attachmentRequired'] == true;
          _subjectOptions = (lookup['subjects'] as List)
              .whereType<Map>()
              .map((s) => '${s['name']}')
              .toList();
          _requireEquipment = lookup['requireEquipment'] == true;
          _equipmentOptions.clear();
          if (lookup['equipment'] is List) {
            for (final item in (lookup['equipment'] as List).whereType<Map>()) {
              final id = item['itemID'];
              if (id is int) {
                _equipmentOptions['${item['itemCode']} | ${item['itemName']}'] =
                    id;
              }
            }
          }
          if (_requireEquipment && _equipmentOptions.isEmpty) {
            setState(() {
              _messages.add('ไม่พบอุปกรณ์ กรุณาใช้หน้าแจ้งซ่อมปกติ');
              _showCreateLink = true;
            });
            return;
          }
          if (_subjectOptions.isEmpty) {
            setState(() {
              _messages.add('ไม่พบหัวข้องานซ่อม กรุณาใช้หน้าแจ้งซ่อมปกติ');
              _showCreateLink = true;
            });
            return;
          }
        }
        setState(() {
          if (intent == 'repair.create_own') {
            _draftKey = _newKey();
            _draftSubject = null;
            _choiceOptions = _matchingSubjects(text);
            _draftDetail = null;
            _draftEquipment = null;
            _draftEquipmentSerial = null;
            _serialAnswered = false;
            _equipmentAnswered = false;
            _photoAnswered = false;
            _draftImages.clear();
          }
          _messages.add(switch (intent) {
            'repair.create_own' =>
              _choiceOptions.isEmpty
                  ? 'กรุณาอธิบายอาการ เพื่อค้นหาหัวข้องานซ่อมที่ใกล้เคียง'
                  : 'เลือกหัวข้อที่ใกล้เคียง โดยกดรายการหรือพิมพ์หมายเลข:\n${_numbered(_choiceOptions)}',
            'denied' || 'none' =>
              'บัญชีหรือแพ็กเกจของคุณไม่มีสิทธิ์ใช้งานส่วนนี้ กรุณาติดต่อผู้ดูแลระบบ',
            'ambiguous' =>
              'คำถามนี้ตรงกับหลายความสามารถ กรุณาระบุว่าต้องการแจ้งซ่อม ติดตามงาน หรือสอบถามต้นทุนอะไหล่',
            _ =>
              'ขออภัย ยังไม่เข้าใจ ลองพิมพ์ว่า “ติดตามงานซ่อมของฉัน” หรือ “แจ้งซ่อม”',
          });
          _choiceMessageIndex =
              intent == 'repair.create_own' && _choiceOptions.isNotEmpty
              ? _messages.length - 1
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            'ไม่สามารถใช้บริการ AI หรือโหลดงานซ่อมได้ กรุณาลองใหม่หรือใช้หน้าจอปกติ',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (_activeAgentImage != null) {
            for (var i = firstReplyIndex; i < _messages.length; i++) {
              if (!_userMessageIndices.contains(i)) {
                _messageAgentImages.putIfAbsent(i, () => _activeAgentImage!);
              }
            }
          }
          _busy = false;
        });
      }
    }
  }

  Future<void> _exportReport(String format) async {
    try {
      final options = await _api.get(
        '/api/assistant/registry/$_reportCode/options',
      );
      final key = {
        'pdf': 'allowPdf',
        'png': 'allowPng',
        'html': 'allowHtml',
      }[format];
      if (options is! Map || options[key] != true) {
        throw StateError('ไม่ได้รับสิทธิ์');
      }
      final path = switch (_reportCode) {
        'repair.track_own' => '/api/service/requests/assistant/self',
        'repair.create_own' =>
          '/api/service/requests/assistant/created/$_reportRequestId',
        _ => '/api/service/requests/assistant/parts-cost',
      };
      final result = await _api.get(
        path,
        query: _reportCode == 'repair.parts_cost' ? _reportQuery : null,
      );
      if (result is! Map) throw StateError('ไม่พบข้อมูล');
      if (_reportCode == 'repair.track_own') {
        final items = result['items'] is List
            ? result['items'] as List
            : const [];
        final rows = items
            .whereType<Map>()
            .map(
              (r) =>
                  '${r['requestNo']} • ${r['subject']} • ${_status(r['statusCode']?.toString())}',
            )
            .join('\n');
        await exportAssistantReport(
          format,
          'งานซ่อมของคุณ (ล่าสุดไม่เกิน 20 รายการ)\n${rows.isEmpty ? 'ไม่พบข้อมูล' : rows}',
        );
        return;
      }
      if (_reportCode == 'repair.create_own') {
        await exportAssistantReport(
          format,
          'แจ้งซ่อมสำเร็จ\nเลขที่: ${result['requestNo']}\nหัวข้อ: ${result['subject']}\nรายละเอียด: ${result['detail']}\nสถานะ: ${_status(result['statusCode']?.toString())}',
        );
        return;
      }
      String displayDate(String? value) {
        final date = DateTime.tryParse(value ?? '');
        if (date == null) return '-';
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().padLeft(4, '0')}';
      }

      final period = _reportQuery == null || _reportQuery!.isEmpty
          ? 'ยอดสะสม'
          : '${displayDate(_reportQuery!['from'])} - ${displayDate(_reportQuery!['to'])}';
      await exportAssistantReport(
        format,
        'สรุปต้นทุนอะไหล่งานซ่อม\nช่วงเวลา: $period\nขอบเขต: ${result['scope'] == 'company' ? 'ทั้งบริษัท' : 'ตามขอบเขตบริการตนเอง'}\nจำนวนงาน: ${result['count']}\nต้นทุนอะไหล่: ${result['partsTotal']} บาท\nไม่รวมค่าแรงและค่าบริการอื่น',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            'ไม่สามารถส่งออกรายงานได้ กรุณาตรวจสอบสิทธิ์แล้วลองใหม่',
          ),
        );
      }
    }
  }

  Future<void> _emailReport() async {
    final input = TextEditingController();
    final address = await showAssistantDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ส่งรายงานทางอีเมล'),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'อีเมลผู้รับ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text.trim()),
            child: const Text('ตรวจสอบ'),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || address == null || address.isEmpty) return;
    final confirmed = await showAssistantDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันส่งอีเมล'),
        content: Text('ส่งข้อมูลรายการนี้ไปที่ $address หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ยืนยันส่ง'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.post(
        '/api/service/requests/assistant/report/email',
        body: {
          'email': address,
          'confirmed': true,
          'from': _reportQuery?['from'],
          'to': _reportQuery?['to'],
          'capabilityCode': _reportCode,
          'requestId': _reportRequestId,
        },
      );
      if (mounted) setState(() => _messages.add('ส่งรายงานทางอีเมลแล้ว'));
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            'ส่งอีเมลไม่สำเร็จ กรุณาตรวจสอบอีเมล สิทธิ์ และการตั้งค่าอีเมลของบริษัท',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _confirmDraft() async {
    if (_draftKey == null ||
        _draftSubject == null ||
        _draftDetail == null ||
        !_photoAnswered ||
        (_requirePhoto && _draftImages.isEmpty) ||
        _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _api.post(
        '/api/service/requests/assistant/self',
        body: {
          'subject': _draftSubject,
          'detail': _draftDetail,
          'requestKey': _draftKey,
          'equipmentItemId': _draftEquipment,
          'equipmentSerial': _draftEquipmentSerial,
          'images': _draftImages
              .map(
                (f) => {
                  'fileName': f.name,
                  'dataBase64': base64Encode(f.bytes!),
                },
              )
              .toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        final date = DateTime.tryParse(
          '${result['requestDate'] ?? ''}',
        )?.toLocal();
        final formatted = date == null
            ? 'ไม่พบวันเวลาแจ้ง'
            : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        _messages.add(
          'แจ้งซ่อมสำเร็จ\nเลขที่ ${result['requestNo']}\nวันที่-เวลาแจ้ง: $formatted\nทางเราจะเร่งดำเนินการตามที่คุณ${_nickname.isEmpty ? '' : ' $_nickname'} แจ้งงานเข้ามา',
        );
        _draftKey = null;
        _draftSubject = null;
        _draftDetail = null;
        _draftImages.clear();
      });
      try {
        final options = await _api.get(
          '/api/assistant/registry/repair.create_own/options',
        );
        if (mounted && options is Map && result['requestId'] is int) {
          setState(() {
            _reportCode = 'repair.create_own';
            _reportRequestId = result['requestId'] as int;
            _reportOptions = Map<String, dynamic>.from(options);
            _reportReady = true;
          });
        }
      } catch (_) {
        /* The saved request remains successful even when report options cannot be loaded. */
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(
            'ไม่สามารถบันทึกได้ หากบริษัทบังคับแนบรูปหรือเลือกอุปกรณ์ กรุณาใช้หน้าแจ้งซ่อมปกติ',
          );
          _showCreateLink = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDraftImages() async {
    try {
      final result = await pickAssistantImages();
      if (!mounted || result == null) return;
      final files = result.files;
      final size = [
        ..._draftImages,
        ...files,
      ].fold<int>(0, (sum, f) => sum + f.size);
      if (files.any((f) => f.bytes == null || f.bytes!.isEmpty) ||
          _draftImages.length + files.length > 10 ||
          size > 25000000) {
        setState(
          () => _messages.add(
            'เลือกรูป JPG, PNG หรือ WEBP ได้ไม่เกิน 10 รูป และขนาดรวมไม่เกิน 25 MB',
          ),
        );
        return;
      }
      setState(() {
        _draftImages.addAll(files);
        _photoAnswered = true;
        _messages.add(
          'แนบรูปแล้ว ${_draftImages.length} รูป: ${_draftImages.map((f) => f.name).join(', ')}\n${_draftSummary()}',
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add('เลือกรูปไม่สำเร็จ กรุณาลองอีกครั้ง'));
      }
    }
  }

  String _draftSummary() {
    final equipment = _draftEquipment == null
        ? 'ไม่ระบุ'
        : _equipmentOptions.entries
              .firstWhere((e) => e.value == _draftEquipment)
              .key;
    return 'กรุณาตรวจสอบก่อนยืนยัน\nหัวข้อ: $_draftSubject\nอุปกรณ์: ${_choiceLabel(equipment)}\nSerial: ${_draftEquipmentSerial ?? 'ไม่ระบุ'}\nรายละเอียด: $_draftDetail\nรูปภาพ: ${_draftImages.length} รูป';
  }

  String _status(String? value) => switch (value) {
    'NEW' => 'สร้างใหม่',
    'RECEIVED' => 'รับงานแล้ว',
    'IN_PROGRESS' => 'กำลังดำเนินการ',
    'COMPLETED' => 'เสร็จแล้ว',
    'CANCELLED' => 'ยกเลิก',
    _ => value ?? '-',
  };

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    final primary = workspaceThemeController.value.primary;
    return Positioned(
      right: 16,
      bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      child: Theme(
        data: workspaceThemeController.value.toThemeData(),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_open)
                Container(
                  width: MediaQuery.sizeOf(context).width < 420
                      ? MediaQuery.sizeOf(context).width - 32
                      : 390,
                  height:
                      ((MediaQuery.sizeOf(context).height -
                                  MediaQuery.viewInsetsOf(context).bottom) *
                              .65)
                          .clamp(160.0, 520.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(blurRadius: 8, color: Colors.black26),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.smart_toy_outlined, color: primary),
                        title: Text(
                          _name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'ปิด',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _open = false),
                        ),
                      ),
                      const Divider(height: 1),
                      if (_favoriteCommands.isNotEmpty ||
                          _recentCommands.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Wrap(
                            children: [
                              if (_favoriteCommands.isNotEmpty)
                                TextButton.icon(
                                  onPressed:
                                      _busy ||
                                          _draftKey != null ||
                                          _waitingForSerial ||
                                          _waitingMeetingAvailability ||
                                          _pendingCapabilityQuestion != null
                                      ? null
                                      : () => _showCommands(true),
                                  icon: const Icon(Icons.star_outline),
                                  label: Text(
                                    'ใช้บ่อย ${_favoriteCommands.length}/$_favoriteLimit',
                                  ),
                                ),
                              if (_recentCommands.isNotEmpty)
                                TextButton.icon(
                                  onPressed:
                                      _busy ||
                                          _draftKey != null ||
                                          _waitingForSerial ||
                                          _waitingMeetingAvailability ||
                                          _pendingCapabilityQuestion != null
                                      ? null
                                      : () => _showCommands(false),
                                  icon: const Icon(Icons.history),
                                  label: Text(
                                    'ล่าสุด ${_recentCommands.length}/$_recentLimit',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_commandListFavorites != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final item
                                  in (_commandListFavorites!
                                      ? _favoriteCommands
                                      : _recentCommands))
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () {
                                                    setState(
                                                      () =>
                                                          _commandListFavorites =
                                                              null,
                                                    );
                                                    _text.text =
                                                        '${item['text']}';
                                                    _send();
                                                  },
                                            style: TextButton.styleFrom(
                                              alignment: Alignment.centerLeft,
                                            ),
                                            child: Text('${item['text']}'),
                                          ),
                                        ),
                                        if (_commandListFavorites!)
                                          IconButton(
                                            tooltip: 'ลบคำสั่งใช้บ่อย',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () => setState(
                                              () => _deleteFavoriteId =
                                                  '${item['id']}',
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_deleteFavoriteId == '${item['id']}' &&
                                        _commandListFavorites!)
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Text('ลบคำสั่งนี้หรือไม่?'),
                                          TextButton(
                                            onPressed: () => setState(
                                              () => _deleteFavoriteId = null,
                                            ),
                                            child: const Text('ยกเลิก'),
                                          ),
                                          TextButton(
                                            onPressed: () => _deleteFavorite(
                                              '${item['id']}',
                                            ),
                                            child: const Text('ยืนยันลบ'),
                                          ),
                                        ],
                                      ),
                                    const Divider(height: 1),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final index = _messages.length - 1 - i;
                            final isUser = _userMessageIndices.contains(index);
                            final agentImage = _messageAgentImages[index];
                            final isChoiceMessage =
                                (_guideStage != null ||
                                    _draftKey != null ||
                                    _pendingCapabilityQuestion != null) &&
                                index == _choiceMessageIndex;
                            final messageText = isChoiceMessage
                                ? _messages[index]
                                      .split('\n')
                                      .takeWhile(
                                        (line) =>
                                            !RegExp(r'^\d+\. ').hasMatch(line),
                                      )
                                      .join('\n')
                                : _messages[index];
                            const cancelPrompt = 'พิมพ์ ยกเลิก';
                            final cancelPosition = messageText.indexOf(
                              cancelPrompt,
                            );
                            final canCancel =
                                !isUser &&
                                index == _messages.length - 1 &&
                                (_guideStage != null ||
                                    _waitingForSerial ||
                                    _pendingCapabilityQuestion != null) &&
                                cancelPosition >= 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isUser
                                      ? _showUserImage
                                      : _showAiImage) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: isUser
                                          ? (userProfileAvatarNotifier.value ==
                                                    null
                                                ? null
                                                : MemoryImage(
                                                    userProfileAvatarNotifier
                                                        .value!,
                                                  ))
                                          : ((agentImage ?? _aiImage) == null
                                                ? null
                                                : MemoryImage(
                                                    (agentImage ?? _aiImage)!,
                                                  )),
                                      child:
                                          (isUser
                                                  ? userProfileAvatarNotifier
                                                        .value
                                                  : (agentImage ?? _aiImage)) ==
                                              null
                                          ? Icon(
                                              isUser
                                                  ? Icons.person_outline
                                                  : Icons.smart_toy_outlined,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (canCancel)
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: messageText.substring(
                                                    0,
                                                    cancelPosition,
                                                  ),
                                                ),
                                                WidgetSpan(
                                                  alignment:
                                                      PlaceholderAlignment
                                                          .middle,
                                                  child: InkWell(
                                                    onTap: _busy
                                                        ? null
                                                        : () {
                                                            _text.text =
                                                                'ยกเลิก';
                                                            _send();
                                                          },
                                                    child: Text(
                                                      'ยกเลิก',
                                                      style: TextStyle(
                                                        color: primary,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: messageText.substring(
                                                    cancelPosition +
                                                        cancelPrompt.length,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          SelectableText(
                                            messageText,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: isUser
                                                      ? primary
                                                      : workspaceThemeController
                                                            .value
                                                            .textPrimary,
                                                  fontWeight: isUser
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                          ),
                                        if (_menuGuideResults.containsKey(
                                          index,
                                        ))
                                          for (final entry
                                              in _menuGuideResults[index]!
                                                  .asMap()
                                                  .entries)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                onPressed: () =>
                                                    _openGuidedMenu(
                                                      entry.value,
                                                    ),
                                                icon: const Icon(
                                                  Icons.open_in_new,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  '${entry.key + 1}. ${entry.value['projectName']} → ${entry.value['groupName']} → ${entry.value['menuName']}${entry.value['canCreate'] == true ? ' (เพิ่มข้อมูลได้)' : ' (ไม่มีสิทธิ์เพิ่ม)'}',
                                                ),
                                              ),
                                            ),
                                        if (_favoritePrompts.containsKey(index))
                                          Wrap(
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _answerFavoritePrompt(
                                                      index,
                                                      true,
                                                    ),
                                                child: const Text('เก็บคำสั่ง'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _answerFavoritePrompt(
                                                      index,
                                                      false,
                                                    ),
                                                child: const Text('ไม่เก็บ'),
                                              ),
                                            ],
                                          ),
                                        if (isChoiceMessage)
                                          for (
                                            var option = 0;
                                            option < _choiceOptions.length;
                                            option++
                                          )
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () {
                                                      _text.text =
                                                          '${option + 1}';
                                                      _send();
                                                    },
                                              child: Text(
                                                '${option + 1}. ${_choiceLabel(_choiceOptions[option])}',
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (_showCreateLink)
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _open = false);
                            appRouter.go('/portal/request');
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('ไปหน้าแจ้งซ่อม'),
                        ),
                      if (_reportReady)
                        Wrap(
                          spacing: 8,
                          children: [
                            if (_reportOptions['allowPdf'] == true)
                              TextButton(
                                onPressed: () => _exportReport('pdf'),
                                child: const Text('PDF'),
                              ),
                            if (_reportOptions['allowPng'] == true)
                              TextButton(
                                onPressed: () => _exportReport('png'),
                                child: const Text('รูปภาพ'),
                              ),
                            if (_reportOptions['allowHtml'] == true)
                              TextButton(
                                onPressed: () => _exportReport('html'),
                                child: const Text('HTML'),
                              ),
                            if (_reportOptions['allowEmail'] == true)
                              TextButton(
                                onPressed: _busy ? null : _emailReport,
                                child: const Text('ส่งอีเมล'),
                              ),
                          ],
                        ),
                      if (_draftKey != null &&
                          _draftSubject != null &&
                          !_equipmentAnswered &&
                          !_requireEquipment)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _text.text = 'ไม่ระบุ';
                                  _send();
                                },
                          child: const Text('ไม่ระบุอุปกรณ์'),
                        ),
                      if (_draftKey != null &&
                          _equipmentAnswered &&
                          !_serialAnswered)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _text.text = 'ไม่ระบุ';
                                  _send();
                                },
                          child: const Text('ไม่ระบุ Serial'),
                        ),
                      if (_draftKey != null && _draftDetail == null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _draftKey = null;
                                  _draftSubject = null;
                                  _messages.add('ยกเลิกการแจ้งซ่อมแล้ว');
                                }),
                          child: const Text('ยกเลิกการแจ้งซ่อม'),
                        ),
                      if (_draftDetail != null && _draftImages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final file in _draftImages)
                                Stack(
                                  children: [
                                    InkWell(
                                      onTap: () => showAssistantDialog<void>(
                                        context: context,
                                        builder: (context) => Dialog(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Expanded(
                                                child: InteractiveViewer(
                                                  child: Image.memory(
                                                    file.bytes!,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('ปิด'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      child: Image.memory(
                                        file.bytes!,
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Material(
                                        color: Colors.white,
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          tooltip: 'ลบรูปที่แนบ',
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () => setState(() {
                                                  _draftImages.remove(file);
                                                  if (_requirePhoto &&
                                                      _draftImages.isEmpty) {
                                                    _photoAnswered = false;
                                                  }
                                                }),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      if (_draftDetail != null)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: _busy ? null : _pickDraftImages,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('แนบรูป'),
                            ),
                            if (!_requirePhoto && !_photoAnswered)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _photoAnswered = true;
                                        _messages.add(_draftSummary());
                                      }),
                                child: const Text('ไม่มีรูป'),
                              ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _draftKey = null;
                                      _draftSubject = null;
                                      _draftDetail = null;
                                      _draftImages.clear();
                                      _messages.add('ยกเลิกการแจ้งซ่อมแล้ว');
                                    }),
                              child: const Text('ยกเลิก'),
                            ),
                            FilledButton(
                              onPressed: _busy || !_photoAnswered
                                  ? null
                                  : _confirmDraft,
                              child: const Text('ยืนยันแจ้งซ่อม'),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _text,
                                enabled: !_busy,
                                maxLength: 1000,
                                decoration: const InputDecoration(
                                  labelText: 'ข้อความ',
                                  counterText: '',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'ส่งข้อความ',
                              onPressed: _busy ? null : _send,
                              icon: _busy
                                  ? const CircularProgressIndicator()
                                  : Icon(Icons.send, color: primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              FloatingActionButton(
                backgroundColor: Colors.white,
                foregroundColor: primary,
                tooltip: 'ผู้ช่วย AI',
                onPressed: () {
                  setState(() => _open = !_open);
                  if (_open) _loadCommands();
                },
                child: _open
                    ? const Icon(Icons.close)
                    : _aiImage == null
                    ? const Icon(Icons.smart_toy_outlined)
                    : ClipOval(
                        child: Image.memory(
                          _aiImage!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
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
