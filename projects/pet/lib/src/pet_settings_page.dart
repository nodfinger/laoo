import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'pet_host.dart';

class PetSettingsPage extends StatefulWidget {
  const PetSettingsPage({super.key});

  @override
  State<PetSettingsPage> createState() => _PetSettingsPageState();
}

class _PetSettingsPageState extends State<PetSettingsPage> {
  static const base = '/api/company/pet';
  late final api = petApi();
  Map<String, dynamic> metadata = {}, settings = {}, actions = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    petDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = Map<String, dynamic>.from(
        await api.get('$base/actions/62001') as Map,
      );
      metadata = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูการตั้งค่านี้');
      }
      settings = Map<String, dynamic>.from(
        await api.get('$base/settings') as Map,
      );
      if (mounted) setState(() => loading = false);
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(exception, 'โหลดการตั้งค่าสัตว์เลี้ยง');
        });
      }
    }
  }

  Future<void> edit() async {
    if (actions['edit'] != true) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SettingsForm(
        title: metadata['MenuName']?.toString() ?? '',
        icon: petMenuIcon(metadata['IconName']?.toString()),
        data: settings,
        api: api,
      ),
    );
    if (saved == true && mounted) {
      petMessage(context, message: 'บันทึกการตั้งค่าแล้ว', error: false);
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = petTokens();
    final title = metadata['MenuName']?.toString() ?? 'ตั้งค่าระบบสัตว์เลี้ยง';
    return petShell(
      pageTitle: title,
      activeMenu: 'pet-settings',
      child: ColoredBox(
        color: tokens.backgroundColor,
        child: SingleChildScrollView(
          padding: tokens.contentMargin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LaooCaptionCard(
                tokens: tokens,
                caption: title,
                favoriteKey: 'pet-settings',
                leading: Icon(
                  petMenuIcon(metadata['IconName']?.toString()),
                  color: tokens.primaryColor,
                ),
                trailing: !loading && error == null && actions['edit'] == true
                    ? FilledButton.icon(
                        onPressed: edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('แก้ไข'),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(0, tokens.buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radius),
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(height: tokens.sectionSpacing),
              LaooSurfaceCard(
                tokens: tokens,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(error!),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองอีกครั้ง'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('การให้บริการ', style: tokens.sectionStyle),
                          const SizedBox(height: 16),
                          Text(
                            'แจ้งเตือนล่วงหน้า ${settings['reminderHours'] ?? 24} ชั่วโมง',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เช็กอินได้ตั้งแต่ ${settings['checkInStart'] ?? '09:00'} ถึง ${settings['checkInEnd'] ?? '18:00'}',
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

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    required this.title,
    required this.icon,
    required this.data,
    required this.api,
  });
  final String title;
  final IconData icon;
  final Map<String, dynamic> data;
  final JsonApiClient api;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final key = GlobalKey<FormState>();
  late final reminder = TextEditingController(
    text: '${widget.data['reminderHours'] ?? 24}',
  );
  late final start = TextEditingController(
    text: '${widget.data['checkInStart'] ?? '09:00'}'.substring(0, 5),
  );
  late final end = TextEditingController(
    text: '${widget.data['checkInEnd'] ?? '18:00'}'.substring(0, 5),
  );
  bool saving = false;

  @override
  void dispose() {
    reminder.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller,
    String? Function(String?) validate,
  ) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: '$label *',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(petTokens().radius),
      ),
    ),
    validator: validate,
  );

  Future<void> save() async {
    if (saving || !key.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.api.put(
        '/api/company/pet/settings',
        body: {
          'reminderHours': int.parse(reminder.text.trim()),
          'checkInStart': '${start.text.trim()}:00',
          'checkInEnd': '${end.text.trim()}:00',
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'บันทึกการตั้งค่า'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: petTokens(),
    icon: widget.icon,
    title: '${widget.title} > แก้ไข',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field('แจ้งเตือนล่วงหน้า (ชั่วโมง)', reminder, (value) {
            final hours = int.tryParse(value?.trim() ?? '');
            return hours == null || hours < 0 || hours > 720
                ? 'ระบุ 0–720 ชั่วโมง'
                : null;
          }),
          const SizedBox(height: 16),
          field(
            'เริ่มเช็กอิน (HH:mm)',
            start,
            (value) =>
                RegExp(
                  r'^([01]\d|2[0-3]):[0-5]\d$',
                ).hasMatch(value?.trim() ?? '')
                ? null
                : 'ระบุเวลา HH:mm',
          ),
          const SizedBox(height: 16),
          field('สิ้นสุดเช็กอิน (HH:mm)', end, (value) {
            final time = value?.trim() ?? '';
            if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
              return 'ระบุเวลา HH:mm';
            }
            return time.compareTo(start.text.trim()) > 0
                ? null
                : 'เวลาสิ้นสุดต้องหลังเวลาเริ่ม';
          }),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: saving ? null : save,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}
