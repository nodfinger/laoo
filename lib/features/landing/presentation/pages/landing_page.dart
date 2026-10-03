import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../core/api/api_client.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final api = ApiClient(), search = TextEditingController();
  List<Map<String, dynamic>> services = [],
      provinces = [],
      districts = [],
      subdistricts = [],
      providers = [];
  int? service, province, district, subdistrict;
  bool loading = true, gpsLoading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    api.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([
        api.get('/api/public/providers/service-types', authenticated: false),
        api.get('/api/public/providers/locations', authenticated: false),
        api.get('/api/public/providers', authenticated: false),
      ]);
      if (mounted)
        setState(() {
          services = _rows(r[0]);
          provinces = _rows(r[1]);
          providers = _map(r[2])['items'] is List
              ? _rows(_map(r[2])['items'])
              : [];
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = 'โหลดข้อมูลผู้ให้บริการไม่สำเร็จ';
          loading = false;
        });
    }
  }

  Future<List<Map<String, dynamic>>> children(int id) async => _rows(
    await api.get(
      '/api/public/providers/locations',
      query: {'parentId': id.toString()},
      authenticated: false,
    ),
  );
  Future<void> find({double? lat, double? lng}) async {
    setState(() => loading = true);
    try {
      final q = <String, String>{
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        if (service != null) 'serviceTypeId': service.toString(),
        if ((subdistrict ?? district ?? province) != null)
          'locationId': (subdistrict ?? district ?? province).toString(),
        if (lat != null) 'latitude': lat.toString(),
        if (lng != null) 'longitude': lng.toString(),
      };
      final r = _map(
        await api.get('/api/public/providers', query: q, authenticated: false),
      );
      if (mounted)
        setState(() {
          providers = _rows(r['items']);
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = 'ค้นหาไม่สำเร็จ';
          loading = false;
        });
    }
  }

  Future<void> nearby() async {
    setState(() => gpsLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception();
      final p = await Geolocator.getCurrentPosition();
      await find(lat: p.latitude, lng: p.longitude);
    } catch (e) {
      if (mounted)
        setState(
          () => error =
              'ไม่สามารถใช้ตำแหน่งปัจจุบันได้ กรุณาอนุญาต GPS หรือเลือกพื้นที่เอง',
        );
    } finally {
      if (mounted) setState(() => gpsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f6),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _hero()),
                    SliverToBoxAdapter(child: _serviceSection()),
                    SliverToBoxAdapter(child: _filters()),
                    if (error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _state(Icons.error_outline, error!, load),
                        ),
                      ),
                    if (loading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (providers.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _state(
                          Icons.search_off_outlined,
                          'ยังไม่พบผู้ให้บริการตามเงื่อนไข',
                          find,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                        sliver: SliverLayoutBuilder(
                          builder: (context, c) {
                            final count = c.crossAxisExtent >= 1180
                                ? 3
                                : c.crossAxisExtent >= 720
                                ? 2
                                : 1;
                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: count,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 250,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _providerCard(providers[i]),
                                childCount: providers.length,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final compact = MediaQuery.sizeOf(context).width < 500;
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LaooColors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'L',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Laoo Provider',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (!compact)
                  const Text(
                    'ค้นหาช่างและผู้ให้บริการที่ไว้ใจได้',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (compact)
            IconButton.outlined(
              onPressed: () => context.goNamed(RouteNames.login),
              tooltip: 'เข้าสู่ระบบ',
              icon: const Icon(Icons.login),
            )
          else
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => context.goNamed(RouteNames.login),
                icon: const Icon(Icons.login),
                label: const Text('เข้าสู่ระบบ'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero() => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.sizeOf(context).width < 600 ? 32 : 42,
      20,
      26,
    ),
    decoration: const BoxDecoration(color: Color(0xff123d35)),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          children: [
            Text(
              'งานช่างใกล้คุณ เริ่มได้ง่ายกว่าที่เคย',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.sizeOf(context).width < 600 ? 28 : 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'เลือกประเภทบริการและพื้นที่ แล้วเปรียบเทียบผู้ให้บริการจากคะแนนจริง',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xffd5e9e3), fontSize: 16),
            ),
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: TextField(
                controller: search,
                onSubmitted: (_) => find(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'ค้นหาชื่อบริษัทหรือบริการ',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: find,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _serviceSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ประเภทบริการ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 154,
              child: services.isEmpty
                  ? const Center(child: Text('ยังไม่มีประเภทบริการ'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: services.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final s = services[i],
                            selected = service == (s['id'] as num).toInt();
                        return InkWell(
                          onTap: () {
                            setState(
                              () => service = selected
                                  ? null
                                  : (s['id'] as num).toInt(),
                            );
                            find();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: MediaQuery.sizeOf(context).width < 600
                                ? (MediaQuery.sizeOf(context).width - 50) / 2
                                : 178,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected
                                    ? LaooColors.green
                                    : LaooColors.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: s['coverImagePath'] == null
                                      ? Container(
                                          color: const Color(0xffe6f4ef),
                                          child: const Center(
                                            child: Icon(
                                              Icons
                                                  .home_repair_service_outlined,
                                              size: 34,
                                              color: LaooColors.green,
                                            ),
                                          ),
                                        )
                                      : Image.network(
                                          '/api/public/providers/service-types/${s['id']}/cover',
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Text(
                                        s['name'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${s['providerCount'] ?? 0} ผู้ให้บริการ',
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Card(
            shape: _shape,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: c.maxWidth < 600 ? c.maxWidth : 220,
                      child: _drop('จังหวัด', province, provinces, (v) async {
                        setState(() {
                          province = v;
                          district = null;
                          subdistrict = null;
                          districts = [];
                          subdistricts = [];
                        });
                        if (v != null) {
                          districts = await children(v);
                          if (mounted) setState(() {});
                        }
                      }),
                    ),
                    SizedBox(
                      width: c.maxWidth < 600 ? c.maxWidth : 220,
                      child: _drop('อำเภอ/เขต', district, districts, (v) async {
                        setState(() {
                          district = v;
                          subdistrict = null;
                          subdistricts = [];
                        });
                        if (v != null) {
                          subdistricts = await children(v);
                          if (mounted) setState(() {});
                        }
                      }),
                    ),
                    SizedBox(
                      width: c.maxWidth < 600 ? c.maxWidth : 220,
                      child: _drop(
                        'ตำบล/แขวง',
                        subdistrict,
                        subdistricts,
                        (v) => setState(() => subdistrict = v),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: find,
                        icon: const Icon(Icons.search),
                        label: const Text('ค้นหา'),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: gpsLoading ? null : nearby,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          gpsLoading ? 'กำลังค้นหา' : 'ผู้ให้บริการใกล้ฉัน',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drop(
    String label,
    int? value,
    List<Map<String, dynamic>> items,
    ValueChanged<int?> changed,
  ) => DropdownButtonFormField<int>(
    initialValue: items.any((x) => (x['id'] as num).toInt() == value)
        ? value
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    ),
    items: items
        .map(
          (x) => DropdownMenuItem(
            value: (x['id'] as num).toInt(),
            child: Text(x['name'].toString(), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: changed,
  );
  Widget _providerCard(Map<String, dynamic> p) => Card(
    shape: _shape,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go('/providers/' + p['slug'].toString()),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffe6f4ef),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: '${p['memberCoverImagePath'] ?? ''}'.isEmpty
                      ? const Icon(
                          Icons.business_outlined,
                          color: LaooColors.green,
                        )
                      : Image.network(
                          '/api/public/providers/profiles/${p['id']}/cover',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.business_outlined,
                            color: LaooColors.green,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p['name'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              (p['summary'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _rows(p['services'])
                  .take(3)
                  .map(
                    (s) => Chip(
                      label: Text(s['name'].toString()),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                Text(
                  ' ' +
                      p['averageRating'].toString() +
                      ' (' +
                      p['reviewCount'].toString() +
                      ')',
                ),
                const Spacer(),
                if (p['distanceKm'] != null)
                  Text(
                    p['distanceKm'].toString() + ' กม.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                else
                  Expanded(
                    child: Text(
                      (p['nearestBranch'] ?? '').toString(),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _state(IconData icon, String text, Future<void> Function() retry) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.black45),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.replay),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
}

final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
    ? v.map((k, x) => MapEntry(k.toString(), x))
    : <String, dynamic>{};
List<Map<String, dynamic>> _rows(dynamic v) =>
    v is List ? v.map(_map).toList() : [];
