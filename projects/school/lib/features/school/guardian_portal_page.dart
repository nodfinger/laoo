import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'school_feature_host.dart';

class GuardianPortalPage extends StatefulWidget {
  const GuardianPortalPage({super.key});
  @override
  State<GuardianPortalPage> createState() => _GuardianPortalPageState();
}

class _GuardianPortalPageState extends State<GuardianPortalPage> {
  final company = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false, obscure = true;
  String? error, token;
  Map<String, dynamic>? portal;

  @override
  void dispose() {
    company.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    if (company.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      setState(() => error = 'กรุณากรอกรหัสโรงเรียน Email และรหัสผ่าน');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = Map<String, dynamic>.from(
        await schoolGuardianLogin({
              'companyCode': company.text.trim(),
              'email': email.text.trim(),
              'password': password.text,
            })
            as Map,
      );
      token = result['accessToken']?.toString();
      if (token == null) throw StateError('ไม่พบ Token สำหรับเข้าใช้งาน');
      portal = Map<String, dynamic>.from(
        await schoolGuardianPortal(token!) as Map,
      );
    } catch (exception) {
      error = exception.toString().replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff4f7f6),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.school_outlined, color: schoolTokens.primaryColor),
          const SizedBox(width: 10),
          const Text(
            'LAOO School · มุมผู้ปกครอง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        if (portal != null)
          TextButton.icon(
            onPressed: () => setState(() {
              token = null;
              portal = null;
              password.clear();
            }),
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
          ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(child: portal == null ? _login() : _dashboard()),
  );

  Widget _login() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.family_restroom_outlined,
                  color: schoolTokens.primaryColor,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'ตรวจสอบข้อมูลบุตรหลาน',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'เวลาเข้า–ออก การเข้าเรียนรายวิชา และข่าวสารจากโรงเรียน',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                _field(company, 'รหัสโรงเรียน', Icons.apartment_outlined),
                const SizedBox(height: 16),
                _field(
                  email,
                  'Email ผู้ปกครอง',
                  Icons.alternate_email,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _field(
                  password,
                  'รหัสผ่าน',
                  Icons.lock_outline,
                  secret: obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  submit: (_) => loading ? null : login(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffffeeee),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xffb42318),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: schoolTokens.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: loading ? null : login,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text(
                      'เข้าสู่ระบบ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _dashboard() {
    final guardian = _map(portal?['guardian']);
    final children = _list(portal?['children']);
    final attendance = _list(portal?['attendance']);
    final news = _list(portal?['news']);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'สวัสดี ${guardian['name']?.toString() ?? ''}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const Text('ข้อมูลล่าสุดของบุตรหลานในช่วง 30 วัน'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: token == null
              ? null
              : () => context.push('/school/guardian/food', extra: token),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(100, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          icon: const Icon(Icons.restaurant_outlined),
          label: const Text('อาหารและ Wallet ของบุตรหลาน'),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (_, box) {
            final width = box.maxWidth < 700
                ? box.maxWidth
                : (box.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _panel(
                    Icons.badge_outlined,
                    'บุตรหลาน',
                    children.isEmpty
                        ? const Text('ยังไม่พบข้อมูลที่เชื่อมโยง')
                        : Column(
                            children: children
                                .map(
                                  (row) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(row['name']?.toString() ?? ''),
                                    subtitle: Text(
                                      '${row['code']?.toString() ?? ''} · ${row['classroom']?.toString() ?? ''}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _panel(
                    Icons.schedule_outlined,
                    'เวลาเข้า–ออกล่าสุด',
                    attendance.isEmpty
                        ? const Text('ยังไม่มีข้อมูลลงเวลา')
                        : Column(
                            children: attendance
                                .take(12)
                                .map(
                                  (row) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      row['attendanceDate']?.toString() ?? '',
                                    ),
                                    subtitle: Text(
                                      'เข้า ${_time(row['checkInAt'])} · ออก ${_time(row['checkOutAt'])}',
                                    ),
                                    trailing: _status(row['status']),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          Icons.campaign_outlined,
          'ข่าวสารจากโรงเรียน',
          news.isEmpty
              ? const Text('ยังไม่มีข่าวสาร')
              : Column(
                  children: news
                      .map(
                        (row) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            row['title']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            row['summary']?.toString() ??
                                row['body']?.toString() ??
                                '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool secret = false,
    Widget? suffix,
    ValueChanged<String>? submit,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    obscureText: secret,
    onSubmitted: submit,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xffd7ddda)),
      ),
    ),
  );

  Widget _panel(IconData icon, String title, Widget child) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: schoolTokens.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    ),
  );

  Widget _status(dynamic value) {
    final status = value?.toString() ?? '-';
    final color = status == 'ABSENT'
        ? const Color(0xffd92d20)
        : status == 'LATE'
        ? const Color(0xffb54708)
        : const Color(0xff067647);
    return Text(status, style: TextStyle(color: color, fontSize: 12));
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : [];
}
