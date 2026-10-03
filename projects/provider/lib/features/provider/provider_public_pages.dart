import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'provider_feature_host.dart';

List<GoRoute> buildProviderPublicRoutes() => [
  GoRoute(
    path: '/providers/review/:token',
    name: 'providerPublicReview',
    builder: (_, s) => ProviderReviewPage(token: s.pathParameters['token']!),
  ),
  GoRoute(
    path: '/providers/:slug',
    name: 'providerPublicDetail',
    builder: (_, s) => ProviderDetailPage(slug: s.pathParameters['slug']!),
  ),
];

class ProviderDetailPage extends StatefulWidget {
  const ProviderDetailPage({super.key, required this.slug});
  final String slug;
  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  late final JsonApiClient api = createProviderApi();
  dynamic data;
  Object? error;
  @override
  void initState() {
    super.initState();
    api
        .get('/api/public/providers/' + widget.slug, authenticated: false)
        .then((v) {
          if (mounted) setState(() => data = v);
        })
        .catchError((e) {
          if (mounted) setState(() => error = e);
        });
  }

  @override
  void dispose() {
    disposeProviderApi(api);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _publicMap(data);
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f6),
      appBar: AppBar(
        title: const Text('LAOO ผู้ให้บริการ'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login),
            label: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
      body: error != null
          ? const Center(child: Text('โหลดข้อมูลไม่สำเร็จ'))
          : data == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        shape: _publicShape,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox.square(
                                      dimension: 104,
                                      child:
                                          '${m['memberCoverImagePath'] ?? ''}'
                                              .isEmpty
                                          ? const ColoredBox(
                                              color: Color(0xffe6f4ef),
                                              child: Icon(
                                                Icons.business_outlined,
                                                size: 42,
                                              ),
                                            )
                                          : Image.network(
                                              '/api/public/providers/profiles/${m['id']}/cover',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.business_outlined,
                                                  ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      m['name'].toString(),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text((m['summary'] ?? '').toString()),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _pill(
                                    Icons.star,
                                    'คะแนน ' + m['averageRating'].toString(),
                                  ),
                                  _pill(
                                    Icons.rate_review_outlined,
                                    m['reviewCount'].toString() + ' รีวิว',
                                  ),
                                  ...(_list(m['services']).map(
                                    (x) => _pill(
                                      Icons.build_outlined,
                                      _publicMap(x)['name'].toString(),
                                    ),
                                  )),
                                ],
                              ),
                              const Divider(height: 32),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  if (m['telephone'] != null)
                                    _contact(
                                      Icons.phone,
                                      m['telephone'],
                                      'tel:${m['telephone']}',
                                    ),
                                  if (m['email'] != null)
                                    _contact(
                                      Icons.email_outlined,
                                      m['email'],
                                      'mailto:${m['email']}',
                                    ),
                                  if (m['lineUrl'] != null)
                                    _contact(
                                      Icons.chat_outlined,
                                      'Line ' + (m['lineId'] ?? '').toString(),
                                      m['lineUrl'].toString(),
                                    ),
                                  if (m['websiteUrl'] != null)
                                    _contact(
                                      Icons.language,
                                      m['websiteUrl'],
                                      m['websiteUrl'].toString(),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'สาขาและพื้นที่ให้บริการ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ..._list(m['branches']).map((x) {
                        final b = _publicMap(x);
                        return Card(
                          shape: _publicShape,
                          child: ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(b['name'].toString()),
                            subtitle: Text((b['address'] ?? '-').toString()),
                          ),
                        );
                      }),
                      if (_list(m['productCategories']).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'หมวดหมู่สินค้า',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _list(m['productCategories']).map((x) {
                            final category = _publicMap(x);
                            return _pill(
                              Icons.inventory_2_outlined,
                              category['groupCode'].toString() +
                                  ' / ' +
                                  category['typeCode'].toString() +
                                  ' (' +
                                  category['itemCount'].toString() +
                                  ')',
                            );
                          }).toList(),
                        ),
                      ],
                      if (_list(m['portfolio']).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'ผลงานที่ผ่านมา',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 3
                                : constraints.maxWidth >= 560
                                ? 2
                                : 1;
                            final width =
                                (constraints.maxWidth - ((columns - 1) * 12)) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _list(m['portfolio']).map((value) {
                                final portfolio = _publicMap(value);
                                return SizedBox(
                                  width: width,
                                  child: Card(
                                    shape: _publicShape,
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () =>
                                          _openPortfolio(context, portfolio),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: Image.network(
                                              '/api/public/providers/portfolio/${portfolio['id']}/cover',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.broken_image_outlined,
                                                  ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${portfolio['title']}',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  '${portfolio['serviceDate']}'
                                                      .split('T')
                                                      .first,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  '${_list(portfolio['photos']).length} รูป • กดดูอัลบั้ม',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'รีวิวล่าสุด',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ..._list(m['reviews']).map((x) {
                        final r = _publicMap(x);
                        return Card(
                          shape: _publicShape,
                          child: ListTile(
                            leading: const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            title: Text(
                              (((_num(r['quality']) +
                                              _num(r['punctuality']) +
                                              _num(r['service']) +
                                              _num(r['value'])) /
                                          4)
                                      .toStringAsFixed(1)) +
                                  ' / 5',
                            ),
                            subtitle: Text(
                              (r['comment'] ?? 'ไม่มีความคิดเห็น').toString(),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _openPortfolio(
    BuildContext context,
    Map<String, dynamic> portfolio,
  ) async {
    final photos = <Map<String, dynamic>>[
      {'id': portfolio['id'], 'cover': true},
      ..._list(portfolio['photos']),
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.collections_outlined,
                      color: Color(0xff00845f),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${portfolio['title']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: photos
                        .map(
                          (photo) => SizedBox(
                            width: 250,
                            height: 180,
                            child: Image.network(
                              photo['cover'] == true
                                  ? '/api/public/providers/portfolio/${photo['id']}/cover'
                                  : '/api/public/providers/portfolio/photos/${photo['id']}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('ปิด'),
                    ),
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

Widget _pill(IconData icon, String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  decoration: BoxDecoration(
    color: const Color(0xffe6f4ef),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 17), const SizedBox(width: 5), Text(text)],
  ),
);
Widget _contact(IconData icon, dynamic text, String url) => OutlinedButton.icon(
  onPressed: () async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  },
  icon: Icon(icon),
  label: Text(text.toString(), overflow: TextOverflow.ellipsis),
);
num _num(dynamic v) => v is num ? v : 0;

class ProviderReviewPage extends StatefulWidget {
  const ProviderReviewPage({super.key, required this.token});
  final String token;
  @override
  State<ProviderReviewPage> createState() => _ProviderReviewPageState();
}

class _ProviderReviewPageState extends State<ProviderReviewPage> {
  late final JsonApiClient api = createProviderApi();
  dynamic data;
  Object? error;
  bool sent = false, saving = false;
  final scores = [5, 5, 5, 5];
  final comment = TextEditingController();
  @override
  void initState() {
    super.initState();
    api
        .get(
          '/api/public/providers/review/' + widget.token,
          authenticated: false,
        )
        .then((v) {
          if (mounted) setState(() => data = v);
        })
        .catchError((e) {
          if (mounted) setState(() => error = e);
        });
  }

  @override
  void dispose() {
    comment.dispose();
    disposeProviderApi(api);
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => saving = true);
    try {
      await api.post(
        '/api/public/providers/review/' + widget.token,
        authenticated: false,
        body: {
          'quality': scores[0],
          'punctuality': scores[1],
          'service': scores[2],
          'value': scores[3],
          'comment': comment.text,
        },
      );
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _publicMap(data);
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f6),
      appBar: AppBar(title: const Text('ประเมินผู้ให้บริการ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: sent
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 56),
                        SizedBox(height: 12),
                        Text(
                          'ขอบคุณสำหรับการประเมิน',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : error != null
              ? const Text('ลิงก์ไม่ถูกต้อง ถูกใช้ หรือหมดอายุแล้ว')
              : data == null
              ? const CircularProgressIndicator()
              : Card(
                  shape: _publicShape,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['providerName'].toString(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(m['serviceName'].toString()),
                        const Divider(height: 28),
                        for (var i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<int>(
                              initialValue: scores[i],
                              decoration: InputDecoration(
                                labelText: const [
                                  'คุณภาพงาน',
                                  'ความตรงเวลา',
                                  'การบริการ',
                                  'ความคุ้มค่า',
                                ][i],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              items: [1, 2, 3, 4, 5]
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v.toString() + ' ดาว'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => scores[i] = v!,
                            ),
                          ),
                        TextField(
                          controller: comment,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'ความคิดเห็น',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: saving ? null : submit,
                            icon: const Icon(Icons.send_outlined),
                            label: Text(saving ? 'กำลังส่ง' : 'ส่งแบบประเมิน'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

final _publicShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(4),
);
Map<String, dynamic> _publicMap(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
    ? v.map((k, x) => MapEntry(k.toString(), x))
    : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : <dynamic>[];
