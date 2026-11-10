import 'package:flutter/material.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../app/theme/laoo_typography.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/shared/registry_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

/// A classification-only preview; it never executes the predicted capability.
class AiIntentTestPage extends StatefulWidget {
  const AiIntentTestPage({
    super.key,
    this.api,
    this.captionLoader,
    this.wrapper,
  });
  final ApiClient? api;
  final Future<String> Function()? captionLoader;
  final Widget Function(Widget child)? wrapper;
  @override
  State<AiIntentTestPage> createState() => _AiIntentTestPageState();
}

class _AiIntentTestPageState extends State<AiIntentTestPage> {
  late final _api = widget.api ?? ApiClient();
  final _text = TextEditingController();
  final Map<String, String> _labels = {
    'repair.create_own': 'แจ้งงานซ่อมใหม่',
    'meeting.availability': 'ค้นหาห้องประชุมว่าง',
    'meeting.own_bookings': 'การจองห้องประชุมของฉัน',
    'meeting.invitations': 'คำเชิญประชุมของฉัน',
    'repair.track_own': 'ติดตามงานซ่อมของฉัน',
    'repair.parts_cost': 'สรุปต้นทุนอะไหล่',
    'unknown': 'ไม่รองรับหรือไม่เข้าใจ',
    'ambiguous': 'คำถามตรงกับหลายความสามารถ กรุณาระบุเพิ่มเติม',
  };
  List<String> _allowed = [];
  String _caption = '';
  final Set<String> _expected = {};
  Set<String> _detected = {};
  String? _result, _error, _agentName;
  String? _testedQuestion, _approvalMessage;
  String? _approvalProof;
  List<Map<String, String>> _choices = [];
  final Set<String> _selectedChoices = {};
  bool _canApprove = false;
  bool _duplicate = false;
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final caption = widget.captionLoader != null
          ? await widget.captionLoader!()
          : (await NavigationMenuRepository().findMenu(
                  menuCode: '64001',
                ))?.name ??
                '';
      final data = await _api.get('/api/assistant/capabilities');
      var canApprove = false;
      try {
        final registry = await _api.get('/api/assistant/registry');
        canApprove = registry is Map && registry['canEdit'] == true;
        if (registry is Map && registry['rows'] is List) {
          for (final row in (registry['rows'] as List).whereType<Map>()) {
            if (row['code'] is String && row['name'] is String) {
              _labels[row['code'] as String] = row['name'] as String;
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _caption = caption;
        _allowed = data is Map && data['capabilities'] is List
            ? (data['capabilities'] as List)
                  .whereType<String>()
                  .where(_labels.containsKey)
                  .toList()
            : [];
        if (_allowed.isNotEmpty) _expected.add(_allowed.first);
        _loading = false;
        _canApprove = canApprove;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'ไม่สามารถโหลดข้อมูล AI ได้ กรุณาตรวจสอบสิทธิ์แล้วลองใหม่';
        });
      }
    }
  }

  Future<void> _test() async {
    final question = _text.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'กรุณากรอกคำถาม');
      return;
    }
    if (_expected.isEmpty) {
      setState(() => _error = 'กรุณาเลือกคำตอบที่คาดหวังอย่างน้อยหนึ่งรายการ');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _agentName = null;
      _testedQuestion = null;
      _approvalProof = null;
      _approvalMessage = null;
      _duplicate = false;
      _choices = [];
      _detected = {};
      _selectedChoices.clear();
    });
    try {
      final result = await _api.post(
        '/api/assistant/intent-test',
        body: {'text': question, 'expectedCapabilities': _expected.toList()},
        timeout: const Duration(seconds: 100),
      );
      if (mounted) {
        setState(() {
          _result = '${result['intent'] ?? 'unknown'}';
          final agent = result is Map ? result['agent'] : null;
          _agentName = agent is Map ? agent['name'] as String? : null;
          _testedQuestion = question;
          _approvalProof = result is Map
              ? result['approvalProof'] as String?
              : null;
          _duplicate = result is Map && result['duplicate'] == true;
          final choices = result is Map ? result['choices'] : null;
          _choices = choices is List
              ? choices
                    .whereType<Map>()
                    .where(
                      (item) =>
                          item['code'] is String && item['name'] is String,
                    )
                    .map(
                      (item) => {
                        'code': item['code'] as String,
                        'name': item['name'] as String,
                      },
                    )
                    .toList()
              : [];
          _detected = _choices.map((choice) => choice['code']!).toSet();
          if (!_duplicate) {
            _choices = _expected
                .map((code) => {'code': code, 'name': _labels[code] ?? code})
                .toList();
            _selectedChoices.addAll(_expected);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'ทดลองไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และบริการ AI ภายใน แล้วลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final question = _testedQuestion;
    if (question == null ||
        _text.text.trim() != question ||
        _selectedChoices.isEmpty ||
        _approvalProof == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: workspaceThemeController.value.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ยืนยันความสามารถที่เลือก',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(thickness: 0.6),
                Text('คำถาม: $question'),
                const SizedBox(height: 10),
                for (final entry
                    in _choices
                        .where(
                          (item) => _selectedChoices.contains(item['code']),
                        )
                        .toList()
                        .asMap()
                        .entries) ...[
                  Text('${entry.key + 1}. ${entry.value['name']}'),
                  const Divider(thickness: 0.6),
                ],
                const Text(
                  'รายการที่เลือกอาจต่างจากผล AI กรุณาตรวจสอบก่อนยืนยัน หากมีคำถามอยู่แล้วระบบจะไม่เพิ่มซ้ำ',
                ),
              ],
            ),
          ),
        ),
        actions: [
          const Divider(thickness: 0.6),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: workspaceThemeController.value.primary,
              minimumSize: const Size(84, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: workspaceThemeController.value.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _approvalMessage = null;
    });
    try {
      final result = await _api.post(
        '/api/assistant/chat-review/confirm-test-matches',
        body: {
          'text': question,
          'capabilities': _selectedChoices.toList(),
          'approvalProof': _approvalProof,
        },
      );
      if (mounted) {
        final message = result is Map
            ? '${result['message'] ?? 'อนุมัติและเพิ่มตัวอย่างคำถามแล้ว'}'
            : 'อนุมัติและเพิ่มตัวอย่างคำถามแล้ว';
        setState(() {
          _approvalMessage = message;
          _choices = [];
          _approvalProof = null;
        });
        showTimedSnackBar(context, message: message);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'ยืนยันไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และทดลองอีกครั้ง',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickExpected() async {
    final selected = Set<String>.of(_expected);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: Row(
            children: [
              Icon(
                Icons.checklist,
                color: workspaceThemeController.value.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'เลือกคำตอบที่คาดหวัง',
                  style: LaooTypography.popupTitleStyle,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            height: MediaQuery.sizeOf(context).height * .45,
            child: Column(
              children: [
                const Divider(thickness: 0.6),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in _allowed.asMap().entries) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: workspaceThemeController.value.primary,
                          checkColor: Colors.white,
                          title: Text(
                            '${entry.key + 1}. ${_labels[entry.value] ?? entry.value}',
                          ),
                          value: selected.contains(entry.value),
                          onChanged: (checked) => refresh(() {
                            if (checked == true) {
                              selected.add(entry.value);
                            } else {
                              selected.remove(entry.value);
                            }
                          }),
                        ),
                        const Divider(height: 1, thickness: 0.6),
                      ],
                    ],
                  ),
                ),
                const Divider(thickness: 0.6),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: workspaceThemeController.value.primary,
                minimumSize: const Size(84, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: workspaceThemeController.value.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('เลือก'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _expected
        ..clear()
        ..addAll(result);
      _result = null;
      _testedQuestion = null;
      _approvalProof = null;
      _choices = [];
      _selectedChoices.clear();
      _approvalMessage = null;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  InputDecoration _standardInput(
    BuildContext context,
    String label, {
    required bool hasValue,
  }) {
    final theme = Theme.of(context);
    return registryInput(context, label: label).copyWith(
      labelStyle: const TextStyle(fontSize: LaooTypography.inputLabel),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontSize: LaooTypography.materialFloatingLabelSource,
          color: states.contains(WidgetState.error)
              ? theme.colorScheme.error
              : states.contains(WidgetState.disabled)
              ? theme.disabledColor
              : states.contains(WidgetState.focused) || hasValue
              ? workspaceThemeController.value.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = workspaceThemeController.value.primary;
    final content = ColoredBox(
      color: LaooColors.background,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              children: [
                registrySurface(
                  WorkspacePageTitle(
                    title: _caption,
                    favoriteKey: 'companyAiIntentTest',
                  ),
                ),
                const SizedBox(height: 8),
                registrySurface(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ทดลองจำแนกคำถาม โดยไม่สร้างรายการหรือส่งอีเมล',
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _text,
                        builder: (context, value, _) => TextField(
                          controller: _text,
                          enabled: !_busy,
                          onChanged: (_) {
                            if (_testedQuestion != null) {
                              setState(() {
                                _result = null;
                                _testedQuestion = null;
                                _approvalProof = null;
                                _choices = [];
                                _selectedChoices.clear();
                                _approvalMessage = null;
                              });
                            }
                          },
                          maxLength: 300,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                          cursorColor: primary,
                          decoration: _standardInput(
                            context,
                            'คำถาม',
                            hasValue: value.text.isNotEmpty,
                          ).copyWith(counterText: ''),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _busy || _allowed.isEmpty ? null : _pickExpected,
                        child: InputDecorator(
                          decoration:
                              _standardInput(
                                context,
                                'คำตอบที่คาดหวัง (เลือกได้หลายรายการ)',
                                hasValue: _expected.isNotEmpty,
                              ).copyWith(
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                              ),
                          child: Text(
                            _expected.isEmpty
                                ? 'เลือกความสามารถ'
                                : _expected
                                      .map((code) => _labels[code] ?? code)
                                      .join(', '),
                            style: TextStyle(
                              fontSize: LaooTypography.comboBox,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _busy ? null : _test,
                            icon: const Icon(Icons.science_outlined),
                            label: const Text('ทดลอง'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                            ),
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _text.clear();
                                    _result = null;
                                    _agentName = null;
                                    _error = null;
                                    _testedQuestion = null;
                                    _approvalProof = null;
                                    _choices = [];
                                    _selectedChoices.clear();
                                    _approvalMessage = null;
                                  }),
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้าง'),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 8),
                  registrySurface(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ผลการทดลอง',
                          style: TextStyle(
                            fontSize: LaooTypography.sectionTitle,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_agentName != null) Text('Agent: $_agentName'),
                        Text(
                          'AI ตีความ: ${_labels[_result] ?? 'ไม่มีสิทธิ์หรือไม่พร้อมใช้งาน'}',
                        ),
                        if (_detected.isNotEmpty)
                          Text(
                            'AI พบ: ${_detected.map((code) => _labels[code] ?? code).join(', ')}',
                          ),
                        if (_duplicate) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ซ้ำ: คำถามนี้มีอยู่ในตัวอย่างคำถามแล้ว',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (!_duplicate && _choices.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          if (_choices.length > 1)
                            const Text('เลือกความสามารถที่ต้องการอนุมัติ'),
                          if (_choices.length > 1)
                            for (final entry in _choices.asMap().entries)
                              Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: primary,
                                  checkColor: Colors.white,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    '${entry.key + 1}. ${entry.value['name']}',
                                  ),
                                  value: _selectedChoices.contains(
                                    entry.value['code'],
                                  ),
                                  onChanged: _busy || _duplicate
                                      ? null
                                      : (checked) => setState(() {
                                          if (checked == true) {
                                            _selectedChoices.add(
                                              entry.value['code']!,
                                            );
                                          } else {
                                            _selectedChoices.remove(
                                              entry.value['code'],
                                            );
                                          }
                                          _approvalMessage = null;
                                        }),
                                ),
                              ),
                          if (_canApprove && !_duplicate)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _busy || _selectedChoices.isEmpty
                                  ? null
                                  : _approve,
                              icon: const Icon(Icons.check),
                              label: const Text('อนุมัติ'),
                            )
                          else if (!_canApprove && !_duplicate)
                            const Text(
                              'ต้องมีสิทธิ์แก้ไขหน้าจัดการความสามารถ AI เพื่ออนุมัติ',
                            ),
                        ],
                        if (_approvalMessage != null) Text(_approvalMessage!),
                        Text(
                          'คาดหวัง: ${_expected.map((code) => _labels[code] ?? code).join(', ')}',
                        ),
                        Text(
                          _detected.length == _expected.length &&
                                  _detected.containsAll(_expected)
                              ? 'ผลตรงกับที่คาดหวัง'
                              : 'ผลไม่ตรงกับที่คาดหวัง',
                        ),
                        const Text('ผลอาจแตกต่างกันได้ ควรทดลองหลายรูปแบบ'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
    return widget.wrapper?.call(content) ??
        SupportWorkspaceShell(
          pageTitle: _caption,
          activeMenu: 'companyAiIntentTest',
          menuScope: WorkspaceMenuScope.company,
          child: content,
        );
  }
}
