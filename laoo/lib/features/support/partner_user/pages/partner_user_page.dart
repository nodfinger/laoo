import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/partner_user_repository.dart';

class PartnerUserPage extends StatefulWidget {
  const PartnerUserPage({super.key});

  @override
  State<PartnerUserPage> createState() => _PartnerUserPageState();
}

class _PartnerUserPageState extends State<PartnerUserPage> {
  final _api = ApiClient();
  final _users = PartnerUserRepository();
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _items = [];
  int? _partnerId;
  bool _loading = true;
  String? _error;
  bool _messageError = true;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    try {
      final values = await _api.get('/api/support/partners') as List;
      if (!mounted) return;
      _partners = values.whereType<Map<String, dynamic>>().toList();
      _partnerId = _partners.isEmpty
          ? null
          : (_partners.first['partnerId'] as num).toInt();
      setState(() {});
      if (_partnerId != null) await _loadUsers();
    } catch (error) {
      if (mounted) _showMessage(_message(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    final id = _partnerId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _users.list(id);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) _showMessage(_message(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final id = _partnerId;
    if (id == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PartnerUserDialog(),
    );
    if (result == null) return;
    try {
      await _users.create(id, result);
      await _loadUsers();
      if (mounted) {
        _showMessage('สร้างบัญชี Partner สำเร็จ', error: false);
      }
    } catch (error) {
      if (mounted) _showMessage(_message(error), error: true);
    }
  }

  void _showMessage(String message, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _messageError = error;
    });
  }

  void _dismissMessage() {
    if (mounted) setState(() => _error = null);
  }

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: 'ผู้ใช้งาน Partner',
      activeMenu: 'partnerUser',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: WorkspacePageTitle(
                    title: 'ผู้ใช้งาน Partner',
                    favoriteKey: 'partnerUser',
                  ),
                ),
                if (_partnerId != null)
                  FilledButton.icon(
                    onPressed: _loading ? null : _create,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _partnerId,
              decoration: const InputDecoration(labelText: 'Partner'),
              items: _partners
                  .map(
                    (partner) => DropdownMenuItem<int>(
                      value: (partner['partnerId'] as num).toInt(),
                      child: Text(
                        '${partner['partnerCode']} - ${partner['partnerNameTh']}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _partnerId = value);
                _loadUsers();
              },
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              AutoDismissMessage(
                key: ValueKey((_error, _messageError)),
                message: _error!,
                error: _messageError,
                onClose: _dismissMessage,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('ยังไม่มีบัญชี Partner'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        final active = item['isActive'] == true;
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            '${item['username']} — ${item['displayName']}',
                          ),
                          subtitle: Text(
                            item['isPartnerAdmin'] == true
                                ? 'Partner Admin'
                                : 'ผู้ใช้งาน',
                          ),
                          trailing: Icon(
                            active ? Icons.check_circle : Icons.block,
                            color: active ? Colors.green : Colors.red,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerUserDialog extends StatefulWidget {
  const _PartnerUserDialog();

  @override
  State<_PartnerUserDialog> createState() => _PartnerUserDialogState();
}

class _PartnerUserDialogState extends State<_PartnerUserDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _display = TextEditingController();
  bool _admin = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มผู้ใช้งาน Partner'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _display,
              decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้งาน'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Partner Admin'),
              value: _admin,
              onChanged: (value) => setState(() => _admin = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () {
            if (_username.text.trim().isEmpty ||
                _password.text.isEmpty ||
                _display.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'username': _username.text.trim(),
              'password': _password.text,
              'displayName': _display.text.trim(),
              'isPartnerAdmin': _admin,
              'isActive': true,
            });
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
