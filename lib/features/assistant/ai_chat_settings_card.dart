import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/timed_snack_bar.dart';
import 'ai_image_picker.dart';
import 'assistant_greeting.dart';

final ValueNotifier<int> aiChatSettingsRevision = ValueNotifier<int>(0);

class AiChatSettingsCard extends StatefulWidget {
  const AiChatSettingsCard({
    super.key,
    required this.canEdit,
    this.busy = false,
    this.initiallyExpanded = false,
  });
  final bool canEdit;
  final bool busy;
  final bool initiallyExpanded;
  @override
  AiChatSettingsCardState createState() => AiChatSettingsCardState();
}

class AiChatSettingsCardState extends State<AiChatSettingsCard> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _loading = true, _enabled = false, _saving = false;
  bool _expanded = false, _dirty = false;
  bool _showUser = false, _showAi = false;
  int _mode = 1;
  Uint8List? _image;
  String? _pendingImageName;
  Uint8List? _pendingImageBytes;
  String? _error;
  static const _periods = <(String, String)>[
    ('morning', 'เช้า'),
    ('lateMorning', 'สาย'),
    ('afternoon', 'บ่าย'),
    ('evening', 'เย็น'),
    ('night', 'ค่ำ'),
  ];

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _load();
  }

  TextEditingController _field(String key) =>
      _fields.putIfAbsent(key, () => TextEditingController());

  Future<void> _load() async {
    try {
      final result = await _api.get('/api/company-setup/ai-chat');
      if (result is! Map || result['settings'] is! Map) {
        throw StateError('Invalid settings');
      }
      if (!mounted) return;
      final settings = result['settings'] as Map;
      for (final key in [
        'name',
        'pronoun',
        'retentionDays',
        'frequentCommandLimit',
        'recentCommandLimit',
        for (final p in _periods) ...[
          '${p.$1}Start',
          '${p.$1}End',
          '${p.$1}Text',
        ],
      ]) {
        _field(key).text = '${settings[key] ?? ''}';
      }
      Uint8List? image;
      if (settings['enabled'] == true && result['hasImage'] == true) {
        try {
          image = Uint8List.fromList(
            await _api.getBytes('/api/assistant/image'),
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _enabled = settings['enabled'] == true;
        _mode = settings['greetingMode'] == 2 ? 2 : 1;
        _showUser = settings['showUserImage'] == true;
        _showAi = settings['showAiImage'] == true;
        _image = image;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'ไม่สามารถโหลดการตั้งค่า AI Chat';
        });
      }
    }
  }

  /// Return an error before any of the parent form's API requests are sent.
  String? validateForSave() {
    if (_loading || _saving) return 'กรุณารอโหลดหรือเลือกรูป AI ให้เสร็จก่อน';
    if (_error != null) return 'ไม่สามารถตรวจสอบการตั้งค่า AI Chat ได้';
    if (!_enabled || !widget.canEdit) return null;
    if (!(_form.currentState?.validate() ?? false)) {
      setState(() => _expanded = true);
      return 'กรุณาตรวจสอบข้อมูล AI Chat';
    }
    final occupied = List<bool>.filled(1440, false);
    for (final period in _periods) {
      if (period.$1 == 'night' &&
          _field('nightStart').text.trim().isEmpty &&
          _field('nightEnd').text.trim().isEmpty) {
        continue;
      }
      final start = AssistantGreetingPeriod.parseTime(
        _field('${period.$1}Start').text,
      );
      final end = AssistantGreetingPeriod.parseTime(
        _field('${period.$1}End').text,
      );
      if (start == null || end == null || start == end) {
        setState(() => _expanded = true);
        return 'เวลาเริ่มและสิ้นสุดของแต่ละช่วงต้องถูกต้องและต่างกัน';
      }
      for (var minute = start; minute != end; minute = (minute + 1) % 1440) {
        if (occupied[minute]) {
          setState(() => _expanded = true);
          return 'ช่วงเวลาทักทาย AI Chat ต้องไม่ทับซ้อนกัน';
        }
        occupied[minute] = true;
      }
    }
    return null;
  }

  /// The parent invokes this only after validating and saving company data.
  Future<void> savePending() async {
    if (!_enabled ||
        !widget.canEdit ||
        (!_dirty && _pendingImageBytes == null)) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_dirty) {
        await _api.put(
          '/api/company-setup/ai-chat',
          body: {
            for (final e in _fields.entries)
              if (!{
                'retentionDays',
                'frequentCommandLimit',
                'recentCommandLimit',
              }.contains(e.key))
                e.key: e.value.text.trim(),
            'retentionDays': int.parse(_field('retentionDays').text.trim()),
            'frequentCommandLimit': int.parse(
              _field('frequentCommandLimit').text.trim(),
            ),
            'recentCommandLimit': int.parse(
              _field('recentCommandLimit').text.trim(),
            ),
            'greetingMode': _mode,
            'showUserImage': _showUser,
            'showAiImage': _showAi,
          },
        );
        _dirty = false;
        aiChatSettingsRevision.value++;
      }
      if (_pendingImageBytes != null && _pendingImageName != null) {
        await _api.upload(
          '/api/company-setup/ai-chat/image',
          fileName: _pendingImageName!,
          bytes: _pendingImageBytes!,
        );
        _pendingImageBytes = null;
        _pendingImageName = null;
        aiChatSettingsRevision.value++;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    if (_saving || widget.busy) return;
    try {
      setState(() => _saving = true);
      final result = await pickAiImage();
      if (result == null || result.files.single.bytes == null) return;
      if (!mounted) return;
      final file = result.files.single;
      if (file.bytes!.length > 1024 * 1024) {
        if (mounted) {
          showTimedSnackBar(
            context,
            message: 'รูปต้องมีขนาดไม่เกิน 1 MB',
            error: true,
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _image = file.bytes;
          _pendingImageBytes = file.bytes;
          _pendingImageName = file.name;
        });
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ไม่สามารถเลือกรูป AI',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  Widget _input(String key, String label, {int max = 200, bool time = false}) =>
      TextFormField(
        controller: _field(key),
        onChanged: (_) => _dirty = true,
        enabled: widget.canEdit && !_saving && !widget.busy,
        maxLength: max,
        keyboardType:
            {
              'retentionDays',
              'frequentCommandLimit',
              'recentCommandLimit',
            }.contains(key)
            ? TextInputType.number
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: time ? 'HH:mm' : null,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          final text = (v ?? '').trim();
          if ((key == 'name' ||
                  key == 'pronoun' ||
                  (time && !key.startsWith('night'))) &&
              text.isEmpty) {
            return 'กรุณาระบุข้อมูล';
          }
          if (key == 'retentionDays' &&
              (int.tryParse(text) == null ||
                  int.parse(text) < 1 ||
                  int.parse(text) > 3650)) {
            return 'กำหนดจำนวนวันตั้งแต่ 1 ถึง 3650';
          }
          if ((key == 'frequentCommandLimit' || key == 'recentCommandLimit') &&
              (int.tryParse(text) == null ||
                  int.parse(text) < 0 ||
                  int.parse(text) > 10000)) {
            return 'กำหนดจำนวนตั้งแต่ 0 ถึง 10000';
          }
          if (time &&
              text.isNotEmpty &&
              !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) {
            return 'ระบุเวลา HH:mm';
          }
          return null;
        },
      );

  Widget _settingsSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: ExpansionTile(
      initiallyExpanded: false,
      maintainState: true,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );

  Widget _separateSections(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _settingsSection(context, 'ข้อมูล AI Chat', [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: width,
                    child: _input(
                      'retentionDays',
                      'จำนวนวันเก็บข้อความ Chat',
                      max: 4,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _input(
                      'frequentCommandLimit',
                      'จำนวนคำสั่งใช้บ่อยสูงสุด',
                      max: 5,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _input(
                      'recentCommandLimit',
                      'จำนวนคำสั่งใช้ล่าสุด',
                      max: 5,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _input('name', 'ชื่อ AI Chat', max: 100),
                  ),
                  SizedBox(
                    width: width,
                    child: _input('pronoun', 'คำเรียกแทนตัวเอง', max: 50),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<int>(
                      initialValue: _mode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'รูปแบบข้อความต้อนรับ',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'ทักทายตามช่วงเวลาและชื่อเล่น',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('เรียกคุณเท่านั้น'),
                        ),
                      ],
                      onChanged: widget.canEdit && !_saving && !widget.busy
                          ? (value) => setState(() {
                              _mode = value ?? 1;
                              _dirty = true;
                            })
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ]),
        _settingsSection(context, 'ช่วงเวลาและข้อความทักทาย', [
          for (final period in _periods) ...[
            Text(
              period.$2,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final start = _input(
                  '${period.$1}Start',
                  'เวลาเริ่ม',
                  max: 5,
                  time: true,
                );
                final end = _input(
                  '${period.$1}End',
                  'เวลาสิ้นสุด',
                  max: 5,
                  time: true,
                );
                final greeting = _input('${period.$1}Text', 'ข้อความทักทาย');
                return constraints.maxWidth < 600
                    ? Column(
                        children: [
                          start,
                          const SizedBox(height: 14),
                          end,
                          const SizedBox(height: 14),
                          greeting,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: start),
                          const SizedBox(width: 12),
                          Expanded(child: end),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: greeting),
                        ],
                      );
              },
            ),
            const SizedBox(height: 14),
          ],
        ]),
        _settingsSection(context, 'รูปภาพใน Chat', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('แสดงรูปผู้ใช้งานใน Chat'),
            value: _showUser,
            onChanged: widget.canEdit && !_saving && !widget.busy
                ? (value) => setState(() {
                    _showUser = value;
                    _dirty = true;
                  })
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('แสดงรูป AI ใน Chat'),
            value: _showAi,
            onChanged: widget.canEdit && !_saving && !widget.busy
                ? (value) => setState(() {
                    _showAi = value;
                    _dirty = true;
                  })
                : null,
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_image != null)
                Image.memory(_image!, width: 64, height: 64, fit: BoxFit.cover),
              OutlinedButton.icon(
                onPressed: widget.canEdit && !_saving && !widget.busy
                    ? _pickImage
                    : null,
                icon: const Icon(Icons.image_outlined),
                label: const Text('เลือกรูป AI'),
              ),
              const Text('JPG, PNG, WEBP ไม่เกิน 1 MB'),
            ],
          ),
        ]),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_error != null) {
      return Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (!_enabled) return const SizedBox.shrink();
    if (widget.initiallyExpanded) return _separateSections(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'ตั้งค่า AI Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded
                        ? 'ย่อการตั้งค่า AI Chat'
                        : 'ขยายการตั้งค่า AI Chat',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
              Visibility(
                visible: _expanded,
                maintainState: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _input('name', 'ชื่อ AI Chat', max: 100),
                    const SizedBox(height: 14),
                    _input('pronoun', 'คำเรียกแทนตัวเอง', max: 50),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _mode,
                      decoration: const InputDecoration(
                        labelText: 'รูปแบบข้อความต้อนรับ',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('ทักทายตามช่วงเวลาและชื่อเล่น'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('เรียกคุณเท่านั้น'),
                        ),
                      ],
                      onChanged: widget.canEdit && !_saving && !widget.busy
                          ? (v) => setState(() {
                              _mode = v ?? 1;
                              _dirty = true;
                            })
                          : null,
                    ),
                    const SizedBox(height: 14),
                    for (final period in _periods) ...[
                      Text(
                        period.$2,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final start = _input(
                            '${period.$1}Start',
                            'เวลาเริ่ม',
                            max: 5,
                            time: true,
                          );
                          final end = _input(
                            '${period.$1}End',
                            'เวลาสิ้นสุด',
                            max: 5,
                            time: true,
                          );
                          final greeting = _input(
                            '${period.$1}Text',
                            'ข้อความทักทาย',
                          );
                          return constraints.maxWidth < 600
                              ? Column(
                                  children: [
                                    start,
                                    const SizedBox(height: 14),
                                    end,
                                    const SizedBox(height: 14),
                                    greeting,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: start),
                                    const SizedBox(width: 12),
                                    Expanded(child: end),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: greeting),
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('แสดงรูปผู้ใช้งานใน Chat'),
                      value: _showUser,
                      onChanged: widget.canEdit && !_saving && !widget.busy
                          ? (v) => setState(() {
                              _showUser = v;
                              _dirty = true;
                            })
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('แสดงรูป AI ใน Chat'),
                      value: _showAi,
                      onChanged: widget.canEdit && !_saving && !widget.busy
                          ? (v) => setState(() {
                              _showAi = v;
                              _dirty = true;
                            })
                          : null,
                    ),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_image != null)
                          Image.memory(
                            _image!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        OutlinedButton.icon(
                          onPressed: widget.canEdit && !_saving && !widget.busy
                              ? _pickImage
                              : null,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('เลือกรูป AI'),
                        ),
                        const Text('JPG, PNG, WEBP ไม่เกิน 1 MB'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
