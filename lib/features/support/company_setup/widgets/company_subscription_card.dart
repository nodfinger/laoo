import 'package:flutter/material.dart';

import '../../../../../core/api/api_client.dart';

class CompanySubscriptionCard extends StatefulWidget {
  const CompanySubscriptionCard({super.key});

  @override
  State<CompanySubscriptionCard> createState() =>
      _CompanySubscriptionCardState();
}

class _CompanySubscriptionCardState extends State<CompanySubscriptionCard> {
  late final Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await ApiClient().get('/api/company/subscriptions');
    return (data as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'แพ็กเกจระบบที่ใช้งาน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Text(
                'อ่านอย่างเดียว',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return const Text(
                  'ไม่สามารถโหลดข้อมูลแพ็กเกจได้',
                  style: TextStyle(color: Colors.red),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const Text('ยังไม่มีแพ็กเกจระบบธุรกิจ');
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => Container(
                        width: 300,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['projectNameTh']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['packageNameTh']} • ${_mode(item['accessMode'])}',
                            ),
                            Text(
                              _period(item),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            if ((item['quotas'] as List? ?? const [])
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                (item['quotas'] as List)
                                    .map(
                                      (q) =>
                                          '${q['quotaNameTh']}: ${q['limitValue']} ${q['unitCode']}',
                                    )
                                    .join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  static String _mode(dynamic value) => switch ('$value') {
    'FULL' => 'ใช้งาน',
    'READ_ONLY' => 'อ่านอย่างเดียว',
    _ => 'ระงับ',
  };
  static String _period(Map<String, dynamic> item) {
    final start = '${item['startDate'] ?? '-'}'.split('T').first;
    final end = '${item['expireDate'] ?? 'ไม่หมดอายุ'}'.split('T').first;
    return '$start ถึง $end';
  }
}
