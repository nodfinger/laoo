import 'package:flutter/material.dart';

import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/global_settings_api.dart';

class GlobalSettingsPage extends StatefulWidget {
  const GlobalSettingsPage({super.key});

  @override
  State<GlobalSettingsPage> createState() => _GlobalSettingsPageState();
}

class _GlobalSettingsPageState extends State<GlobalSettingsPage> {
  final _api = GlobalSettingsApi();
  final _item = TextEditingController();
  final _card = TextEditingController();
  final _itemDescription = TextEditingController();
  final _cardDescription = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _item.dispose();
    _card.dispose();
    _itemDescription.dispose();
    _cardDescription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await _api.get();
      _item.text = '${values['maxItemImageSizeMB'] ?? 10}';
      _card.text = '${values['maxBusinessCardImageSizeMB'] ?? 10}';
      _itemDescription.text = '${values['descriptionItemImage'] ?? ''}';
      _cardDescription.text = '${values['descriptionBusinessCardImage'] ?? ''}';
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final item = double.tryParse(_item.text.trim());
    final card = double.tryParse(_card.text.trim());
    if (item == null || card == null || item <= 0 || card <= 0) {
      showTimedSnackBar(
        context,
        message: 'กรุณาระบุขนาดไฟล์ให้ถูกต้องมากกว่า 0 MB',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.save(itemMB: item, cardMB: card, itemDescription: _itemDescription.text, cardDescription: _cardDescription.text);
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกกำหนดค่าส่วนกลางสำเร็จ',
        );
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: 'กำหนดค่าส่วนกลาง',
      activeMenu: 'globalSettings',
      menuScope: WorkspaceMenuScope.support,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'กำหนดค่าส่วนกลาง',
                        style: TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
                      ),
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ขนาดไฟล์รูปภาพ',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _item,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'รูปสินค้าห้ามเกิน (MB)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _card,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'รูปนามบัตรห้ามเกิน (MB)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _itemDescription,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'คำอธิบายรูปสินค้า'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _cardDescription,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'คำอธิบายรูปนามบัตร'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
