import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/widgets/auto_dismiss_message.dart';

class BookingMemberPortalPage extends StatefulWidget {
  const BookingMemberPortalPage({super.key});

  @override
  State<BookingMemberPortalPage> createState() =>
      _BookingMemberPortalPageState();
}

class _BookingMemberPortalPageState extends State<BookingMemberPortalPage> {
  final company = TextEditingController();
  final member = TextEditingController();
  final password = TextEditingController();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final client = http.Client();
  String? token, error;
  bool alertIsError = true;
  int alertSeconds = 3;
  Map<String, dynamic> profile = {};
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> pets = [];
  List<Map<String, dynamic>> petHistory = [];
  String? petError;
  bool busy = false, mustChange = false;
  int page = 1, total = 0;

  @override
  void dispose() {
    company.dispose();
    member.dispose();
    password.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    client.close();
    super.dispose();
  }

  Uri uri(String path, [Map<String, String>? query]) => Uri.parse(
    AppConfig.apiBaseUrl,
  ).resolve(path).replace(queryParameters: query);

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final target = uri(path, query);
    switch (method) {
      case 'POST':
        return client.post(target, headers: headers, body: jsonEncode(body));
      default:
        return client.get(target, headers: headers);
    }
  }

  Map<String, dynamic> payload(http.Response response) {
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = result is Map ? result['message'] : null;
      throw StateError(message?.toString() ?? 'ไม่สามารถเชื่อมต่อได้');
    }
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> login() async {
    if (company.text.trim().isEmpty ||
        member.text.trim().isEmpty ||
        password.text.isEmpty) {
      setState(() {
        alertIsError = true;
        error = 'กรอกรหัสบริษัท รหัสสมาชิก และรหัสผ่าน';
      });
      return;
    }
    setState(() {
      busy = true;
      alertIsError = true;
      error = null;
    });
    try {
      final data = payload(
        await request(
          'POST',
          '/api/booking/member/login',
          body: {
            'companyCode': company.text.trim(),
            'memberCode': member.text.trim(),
            'password': password.text,
          },
        ),
      );
      token = data['accessToken'] as String;
      mustChange = data['mustChangePassword'] == true;
      currentPassword.text = password.text;
      password.clear();
      await load();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError ? e.message : 'เชื่อมต่อไม่สำเร็จ',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      alertIsError = true;
      error = null;
    });
    try {
      final me = payload(await request('GET', '/api/booking/member/me'));
      final needsChange = me['mustChangePassword'] == true;
      final data = needsChange
          ? <String, dynamic>{'items': <dynamic>[], 'total': 0}
          : payload(
              await request(
                'GET',
                '/api/booking/member/history',
                query: {'page': '$page', 'pageSize': '20'},
              ),
            );
      List<Map<String, dynamic>> loadedPets = [];
      List<Map<String, dynamic>> loadedPetHistory = [];
      String? loadedPetError;
      if (!needsChange) {
        try {
          final petResponse = await request('GET', '/api/pet/owner/pets');
          if (petResponse.statusCode == 200) {
            loadedPets =
                (jsonDecode(utf8.decode(petResponse.bodyBytes)) as List)
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
            final petHistoryResponse = await request(
              'GET',
              '/api/pet/owner/history',
              query: {'page': '1', 'pageSize': '20'},
            );
            if (petHistoryResponse.statusCode == 200) {
              final petData = payload(petHistoryResponse);
              loadedPetHistory = (petData['items'] as List? ?? [])
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            } else {
              loadedPetError =
                  'ไม่สามารถโหลดประวัติสัตว์เลี้ยงได้ กรุณาลองใหม่';
            }
          } else if (petResponse.statusCode != 403 &&
              petResponse.statusCode != 404) {
            loadedPetError = 'ไม่สามารถโหลดข้อมูลสัตว์เลี้ยงได้ กรุณาลองใหม่';
          }
        } catch (_) {
          loadedPetError = 'ไม่สามารถโหลดข้อมูลสัตว์เลี้ยงได้ กรุณาลองใหม่';
        }
      }
      if (!mounted) return;
      setState(() {
        profile = me;
        alertSeconds = ((me['timeAlert'] as num?)?.toInt() ?? 3).clamp(1, 3600);
        history = (data['items'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        total = (data['total'] as num).toInt();
        mustChange = needsChange;
        pets = loadedPets;
        petHistory = loadedPetHistory;
        petError = loadedPetError;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError ? e.message : 'โหลดข้อมูลไม่สำเร็จ',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePassword() async {
    if (newPassword.text.length < 12) {
      setState(() {
        alertIsError = true;
        error = 'รหัสผ่านใหม่ต้องมีอย่างน้อย 12 ตัวอักษร';
      });
      return;
    }
    setState(() {
      busy = true;
      alertIsError = true;
      error = null;
    });
    try {
      payload(
        await request(
          'POST',
          '/api/booking/member/change-password',
          body: {
            'currentPassword': currentPassword.text,
            'newPassword': newPassword.text,
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        token = null;
        profile = {};
        history = [];
        pets = [];
        petHistory = [];
        petError = null;
        mustChange = false;
        currentPassword.clear();
        newPassword.clear();
        alertIsError = false;
        error = 'เปลี่ยนรหัสผ่านแล้ว กรุณาเข้าสู่ระบบใหม่';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error = e is StateError ? e.message : 'เปลี่ยนรหัสผ่านไม่สำเร็จ',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '-';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('สมาชิก · ประวัติบริการ'),
        actions: token == null
            ? null
            : [
                TextButton.icon(
                  onPressed: () => setState(() {
                    token = null;
                    profile = {};
                    history = [];
                    pets = [];
                    petHistory = [];
                    petError = null;
                    page = 1;
                  }),
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกจากระบบ'),
                ),
              ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (token == null) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 40,
                              color: primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'เข้าสู่ระบบสมาชิก',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: company,
                              decoration: const InputDecoration(
                                labelText: 'รหัสบริษัท *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: member,
                              decoration: const InputDecoration(
                                labelText: 'รหัสสมาชิก *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: password,
                              obscureText: true,
                              onSubmitted: (_) => busy ? null : login(),
                              decoration: const InputDecoration(
                                labelText: 'รหัสผ่าน *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: busy ? null : login,
                                child: const Text('เข้าสู่ระบบ'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            Text(
                              '${profile['name'] ?? ''}',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text('รหัส ${profile['code'] ?? ''}'),
                            Text('ระดับ ${profile['tierCode'] ?? ''}'),
                          ],
                        ),
                      ),
                    ),
                    if (mustChange)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('กรุณาเปลี่ยนรหัสผ่านเริ่มต้น'),
                              const SizedBox(height: 16),
                              TextField(
                                controller: currentPassword,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'รหัสผ่านปัจจุบัน *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: newPassword,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'รหัสผ่านใหม่ *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  onPressed: busy ? null : changePassword,
                                  child: const Text('เปลี่ยนรหัสผ่าน'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 12),
                      Text(
                        'สัตว์เลี้ยงของฉัน',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (petError != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(petError!),
                          ),
                        ),
                      if (pets.isEmpty && petError == null)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'ยังไม่มีสัตว์เลี้ยงที่ผูกกับบัญชีสมาชิกนี้',
                            ),
                          ),
                        ),
                      for (final pet in pets)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet['name']?.toString() ?? '',
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  'รหัส ${pet['code'] ?? '—'} · ชนิด ${pet['species'] ?? '—'}',
                                ),
                                if (pet['breed'] != null)
                                  Text('พันธุ์ ${pet['breed']}'),
                              ],
                            ),
                          ),
                        ),
                      if (petHistory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'ประวัติบริการสัตว์เลี้ยง',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final item in petHistory)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['petName']?.toString() ?? '',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text('นัดหมาย ${item['bookingNo'] ?? '—'}'),
                                  Text('เริ่ม ${date(item['startsAt'])}'),
                                  Text('สถานะ ${item['status'] ?? '—'}'),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      const SizedBox(height: 12),
                      Text(
                        'ประวัติการจองและใช้บริการ',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (busy)
                        const Center(child: CircularProgressIndicator()),
                      if (!busy && history.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('ยังไม่มีประวัติการใช้บริการ'),
                          ),
                        ),
                      for (final item in history)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['number']}',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text('${item['services'] ?? ''}'),
                                Text('นัดหมาย: ${date(item['startsAt'])}'),
                                Text('สถานะ: ${item['status']}'),
                                Text(
                                  'ใช้บริการ: ${item['usedAt'] == null ? 'ยังไม่ใช้' : date(item['usedAt'])}',
                                ),
                                Text('ยอด ${item['amount']} บาท'),
                              ],
                            ),
                          ),
                        ),
                      if (total > 20)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: page <= 1 || busy
                                  ? null
                                  : () {
                                      setState(() => page--);
                                      load();
                                    },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('$page / ${(total / 20).ceil()}'),
                            IconButton(
                              onPressed: page * 20 >= total || busy
                                  ? null
                                  : () {
                                      setState(() => page++);
                                      load();
                                    },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (error != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: AutoDismissMessage(
                key: ValueKey(error),
                message: error!,
                error: alertIsError,
                duration: Duration(seconds: alertSeconds),
                onClose: () {
                  if (mounted) setState(() => error = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}
