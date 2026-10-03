import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'provider_feature_host.dart';

class ProviderPage extends StatefulWidget {
  const ProviderPage({
    super.key,
    required this.menuCode,
    required this.fallbackTitle,
  });
  final String menuCode, fallbackTitle;
  @override
  State<ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends State<ProviderPage> {
  late final JsonApiClient api = createProviderApi();
  String title = '';
  bool loading = true, saving = false, cards = false;
  Object? error;
  Map<String, dynamic> actions = {};
  dynamic data;
  final fields = <String, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    providerTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
    load();
  }

  @override
  void dispose() {
    for (final c in fields.values) c.dispose();
    disposeProviderApi(api);
    super.dispose();
  }

  String get endpoint => switch (widget.menuCode) {
    '51001' => 'settings',
    '51002' => 'locations',
    '51003' => 'service-types',
    '51004' => 'profile',
    '51005' => 'approvals',
    '51006' => 'review-links',
    '51007' => 'reviews',
    _ => 'dashboard',
  };
  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([
        api.get('/api/company/provider/actions/' + widget.menuCode),
        api.get('/api/company/provider/' + endpoint),
      ]);
      if (widget.menuCode == '51004' || widget.menuCode == '51006') {
        final optionResult = await Future.wait([
          api.get('/api/company/provider/service-types'),
          api.get('/api/company/provider/locations'),
        ]);
        serviceOptions = (optionResult[0] as List)
            .map(_map)
            .where((x) => x['active'] != false)
            .toList();
        locationOptions = (optionResult[1] as List)
            .map(_map)
            .where((x) => x['active'] != false)
            .toList();
      }
      if (mounted)
        setState(() {
          actions = _map(r[0]);
          data = r[1];
          loading = false;
          _seedFields();
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  void _seedFields() {
    if (data is! Map) return;
    final m = _map(data);
    for (final e in m.entries) {
      if (e.value is num || e.value is String) {
        fields.putIfAbsent(e.key, TextEditingController.new).text =
            (e.value ?? '').toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) => providerShell(
    title: title,
    menu: title,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) => LaooCaptionCard(
              tokens: providerTokens,
              caption: title,
              leading: Icon(_icon, color: providerTokens.primaryColor),
              favoriteKey: widget.menuCode,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_listCard && c.maxWidth >= 900)
                    LaooListCardToggle(
                      tokens: providerTokens,
                      cards: cards,
                      onChanged: (v) => setState(() => cards = v),
                    ),
                  if (_canCreate) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        style: _filled,
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: Text(_addLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            Expanded(child: _error())
          else
            Expanded(child: _content()),
        ],
      ),
    ),
  );
  IconData get _icon => switch (widget.menuCode) {
    '51001' => Icons.settings_outlined,
    '51002' => Icons.location_on_outlined,
    '51003' => Icons.home_repair_service_outlined,
    '51004' => Icons.business_outlined,
    '51005' => Icons.approval_outlined,
    '51006' => Icons.link_outlined,
    '51007' => Icons.rate_review_outlined,
    _ => Icons.insights_outlined,
  };
  bool get _listCard => const {
    '51002',
    '51003',
    '51005',
    '51006',
    '51007',
  }.contains(widget.menuCode);
  bool get _canCreate =>
      actions['create'] == true &&
      const {'51002', '51003', '51006'}.contains(widget.menuCode);
  String get _addLabel => widget.menuCode == '51002'
      ? 'เพิ่มพื้นที่'
      : widget.menuCode == '51003'
      ? 'เพิ่มประเภท'
      : 'สร้างลิงก์';
  ButtonStyle get _filled => FilledButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );
  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 44),
        const SizedBox(height: 8),
        const Text('โหลดข้อมูลไม่สำเร็จ'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: load,
          icon: const Icon(Icons.replay),
          label: const Text('ลองอีกครั้ง'),
        ),
      ],
    ),
  );
  Widget _content() => switch (widget.menuCode) {
    '51001' => _settings(),
    '51004' => _profile(),
    '51008' => _dashboard(),
    _ => _records(),
  };
  List<Map<String, dynamic>> get rows {
    if (data is List) return (data as List).map(_map).toList();
    if (data is Map && _map(data)['items'] is List)
      return (_map(data)['items'] as List).map(_map).toList();
    return [];
  }

  Widget _records() {
    if (rows.isEmpty) return const Center(child: Text('ยังไม่มีข้อมูล'));
    if (cards)
      return SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth < 600 ? c.maxWidth : (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: rows
                  .map((r) => SizedBox(width: width, child: _recordCard(r)))
                  .toList(),
            );
          },
        ),
      );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 280,
        ),
        child: SingleChildScrollView(
          child: DataTable(
            columns: _columns.map((x) => DataColumn(label: Text(x))).toList(),
            rows: rows.map(_row).toList(),
          ),
        ),
      ),
    );
  }

  List<String> get _columns => switch (widget.menuCode) {
    '51002' => [
      'รหัส',
      'ประเภท',
      'ชื่อพื้นที่',
      'พื้นที่แม่',
      'สถานะ',
      'จัดการ',
    ],
    '51003' => [
      'รูปปก',
      'รหัส',
      'ประเภทบริการ',
      'รายละเอียด',
      'สถานะ',
      'จัดการ',
    ],
    '51005' => ['บริษัท', 'ชื่อที่แสดง', 'สถานะ', 'วันที่ส่ง', 'จัดการ'],
    '51006' => [
      'บริการ',
      'สาขา',
      'วันที่ให้บริการ',
      'หมดอายุ',
      'สถานะ',
      'จัดการ',
    ],
    '51007' => ['บริการ', 'คะแนน', 'ความคิดเห็น', 'วันที่', 'สถานะ', 'จัดการ'],
    _ => ['ข้อมูล'],
  };
  DataRow _row(Map<String, dynamic> r) => DataRow(
    cells: switch (widget.menuCode) {
      '51002' => [
        _cell(r['code']),
        _cell(_locationType(r['type'])),
        _cell(r['name']),
        _cell(r['parentName']),
        _status(r['active'] == true ? 'ใช้งาน' : 'ปิด'),
        _actions(r),
      ],
      '51003' => [
        _cover(r),
        _cell(r['code']),
        _cell(r['name']),
        _cell(r['description']),
        _status(r['active'] == true ? 'ใช้งาน' : 'ปิด'),
        _actions(r),
      ],
      '51005' => [
        _cell(r['companyName']),
        _cell(r['displayName']),
        _status(r['status']),
        _cell(r['submittedAt']),
        _actions(r),
      ],
      '51006' => [
        _cell(r['serviceName']),
        _cell(r['branchName']),
        _cell(r['serviceDate']),
        _cell(r['expiresAt']),
        _status(r['status']),
        _actions(r),
      ],
      '51007' => [
        _cell(r['serviceName']),
        _cell(_rating(r)),
        _cell(r['comment']),
        _cell(r['createdAt']),
        _status(r['hidden'] == true ? 'ซ่อน' : 'แสดง'),
        _actions(r),
      ],
      _ => [_cell(r.values.join(' · '))],
    },
  );
  DataCell _cell(dynamic value) => DataCell(
    SizedBox(
      width: 180,
      child: Text(
        (value ?? '-').toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  DataCell _status(dynamic value) => DataCell(
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value.toString()),
    ),
  );
  DataCell _cover(Map<String, dynamic> r) => DataCell(
    SizedBox(
      width: 72,
      height: 44,
      child: r['coverImagePath'] == null
          ? const Icon(Icons.image_outlined)
          : Image.network(
              '/' + r['coverImagePath'].toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined),
            ),
    ),
  );
  DataCell _actions(Map<String, dynamic> r) => DataCell(
    Wrap(
      spacing: 4,
      children: [
        if (widget.menuCode == '51002' && actions['edit'] == true)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _locationDialog(r),
            icon: const Icon(Icons.edit_outlined),
          ),
        if (widget.menuCode == '51003' && actions['edit'] == true) ...[
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _serviceDialog(r),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'รูปปก',
            onPressed: () => _coverUpload(r),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
        if (widget.menuCode == '51005' && r['status'] == 'SUBMITTED') ...[
          if (actions['approve'] == true)
            IconButton(
              tooltip: 'อนุมัติ',
              onPressed: () => _decision(r, 'approve'),
              icon: const Icon(Icons.check_circle_outline),
            ),
          if (actions['return'] == true)
            IconButton(
              tooltip: 'ส่งกลับ',
              onPressed: () => _decision(r, 'return'),
              icon: const Icon(Icons.undo),
            ),
        ],
        if (widget.menuCode == '51005' &&
            actions['suspend'] == true &&
            r['status'] == 'APPROVED')
          IconButton(
            tooltip: 'ระงับ',
            onPressed: () => _decision(r, 'suspend'),
            icon: const Icon(Icons.block),
          ),
        if (widget.menuCode == '51006' &&
            r['status'] == 'ACTIVE' &&
            (actions['cancel'] == true || actions['delete'] == true))
          IconButton(
            tooltip: 'ยกเลิก',
            onPressed: () => _cancelLink(r),
            icon: const Icon(Icons.link_off),
          ),
        if (widget.menuCode == '51007' && actions['moderate'] == true)
          IconButton(
            tooltip: r['hidden'] == true ? 'แสดง' : 'ซ่อน',
            onPressed: () => _moderate(r),
            icon: Icon(
              r['hidden'] == true
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        if (const {'51002', '51003'}.contains(widget.menuCode) &&
            actions['delete'] == true)
          IconButton(
            tooltip: 'ลบ',
            color: Colors.red,
            onPressed: () => _delete(r),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
  );
  Widget _recordCard(Map<String, dynamic> r) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (r['name'] ??
                    r['displayName'] ??
                    r['serviceName'] ??
                    r['code'] ??
                    '-')
                .toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            (r['description'] ??
                    r['summary'] ??
                    r['comment'] ??
                    r['status'] ??
                    '')
                .toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: _actions(r).child),
        ],
      ),
    ),
  );
  String _locationType(dynamic v) => v == 'PROVINCE'
      ? 'จังหวัด'
      : v == 'DISTRICT'
      ? 'อำเภอ/เขต'
      : 'ตำบล/แขวง';
  String _rating(Map<String, dynamic> r) =>
      ((_n(r['quality']) +
                  _n(r['punctuality']) +
                  _n(r['service']) +
                  _n(r['value'])) /
              4)
          .toStringAsFixed(1);
  num _n(dynamic v) => v is num ? v : 0;
  void _add() {
    if (widget.menuCode == '51002')
      _locationDialog(null);
    else if (widget.menuCode == '51003')
      _serviceDialog(null);
    else
      _reviewLinkDialog();
  }

  Widget _settings() {
    final keys = [
      ('serviceCoverMaxMb', 'รูปปกสูงสุด (MB)'),
      ('reviewExpiryDays', 'อายุลิงก์ประเมิน (วัน)'),
      ('bayesianMinimumReviews', 'จำนวนรีวิวขั้นต่ำ'),
      ('ratingWeightNoGps', 'น้ำหนักคะแนนเมื่อไม่มี GPS'),
      ('recencyWeightNoGps', 'น้ำหนักความใหม่เมื่อไม่มี GPS'),
      ('ratingWeightGps', 'น้ำหนักคะแนนเมื่อใช้ GPS'),
      ('distanceWeightGps', 'น้ำหนักระยะทางเมื่อใช้ GPS'),
      ('recencyWeightGps', 'น้ำหนักความใหม่เมื่อใช้ GPS'),
      ('maxDistanceKm', 'ระยะค้นหาสูงสุด (กม.)'),
    ];
    return SingleChildScrollView(
      child: Card(
        shape: _shape,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ค่าการทำงานปัจจุบัน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Divider(),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: keys
                    .map(
                      (e) => SizedBox(
                        width: 280,
                        child: _text(
                          e.$2,
                          fields[e.$1] ?? TextEditingController(),
                          number: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (actions['edit'] == true) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: _filled,
                      onPressed: saving ? null : _saveSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => saving = true);
    try {
      double n(String k) => double.tryParse(fields[k]?.text ?? '') ?? 0;
      await api.put(
        '/api/company/provider/settings',
        body: {
          'serviceCoverMaxMb': n('serviceCoverMaxMb').round(),
          'reviewExpiryDays': n('reviewExpiryDays').round(),
          'bayesianMinimumReviews': n('bayesianMinimumReviews').round(),
          'ratingWeightNoGps': n('ratingWeightNoGps'),
          'recencyWeightNoGps': n('recencyWeightNoGps'),
          'ratingWeightGps': n('ratingWeightGps'),
          'distanceWeightGps': n('distanceWeightGps'),
          'recencyWeightGps': n('recencyWeightGps'),
          'maxDistanceKm': n('maxDistanceKm'),
        },
      );
      if (mounted) providerMessage(context, 'บันทึกการตั้งค่าแล้ว');
      await load();
    } catch (e) {
      if (mounted) providerMessage(context, 'บันทึกไม่สำเร็จ', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _profile() {
    final m = _map(data);
    if (m['status'] == 'NEW') {
      for (final k in [
        'slug',
        'displayName',
        'summary',
        'address',
        'telephone',
        'email',
        'lineId',
        'lineUrl',
        'websiteUrl',
      ]) {
        fields.putIfAbsent(k, TextEditingController.new);
      }
    }
    final readOnly = actions['edit'] != true || m['status'] == 'SUBMITTED';
    return SingleChildScrollView(
      child: Card(
        shape: _shape,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'สถานะ: ' + (m['status'] ?? 'NEW').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (m['status'] == 'SUBMITTED' && actions['withdraw'] == true)
                    OutlinedButton.icon(
                      onPressed: _withdraw,
                      icon: const Icon(Icons.undo),
                      label: const Text('ถอนคำขอ'),
                    ),
                  if (m['status'] != 'SUBMITTED' && actions['submit'] == true)
                    OutlinedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('ส่งอนุมัติ'),
                    ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 280,
                    child: _text('Slug *', fields['slug']!, enabled: !readOnly),
                  ),
                  SizedBox(
                    width: 420,
                    child: _text(
                      'ชื่อที่แสดง *',
                      fields['displayName']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: _text(
                      'โทรศัพท์สาธารณะ',
                      fields['telephone']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: _text(
                      'อีเมลสาธารณะ',
                      fields['email']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: _text(
                      'Line ID',
                      fields['lineId']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: _text(
                      'Line URL',
                      fields['lineUrl']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: _text(
                      'Website',
                      fields['websiteUrl']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 860,
                    child: _text(
                      'ที่อยู่สาธารณะ',
                      fields['address']!,
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 860,
                    child: _text(
                      'แนะนำผู้ให้บริการ',
                      fields['summary']!,
                      enabled: !readOnly,
                      lines: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'ประเภทบริการและพื้นที่',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('เลือกรายการจากข้อมูล Master ที่เปิดใช้งาน'),
              const SizedBox(height: 8),
              _profileSelections(m, readOnly),
              const SizedBox(height: 16),
              const Text(
                'สาขาหลักและพิกัด',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 300,
                    child: _text(
                      'ชื่อสาขา *',
                      fields.putIfAbsent(
                        'branchName',
                        () => TextEditingController(
                          text: _firstBranch(m, 'name'),
                        ),
                      ),
                      enabled: !readOnly,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: _text(
                      'ละติจูด',
                      fields.putIfAbsent(
                        'latitude',
                        () => TextEditingController(
                          text: _firstBranch(m, 'latitude'),
                        ),
                      ),
                      enabled: !readOnly,
                      number: true,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: _text(
                      'ลองจิจูด',
                      fields.putIfAbsent(
                        'longitude',
                        () => TextEditingController(
                          text: _firstBranch(m, 'longitude'),
                        ),
                      ),
                      enabled: !readOnly,
                      number: true,
                    ),
                  ),
                ],
              ),
              if (!readOnly) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: _filled,
                      onPressed: saving ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึกโปรไฟล์'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  final selectedServices = <int>{};
  final selectedAreas = <int>{};
  List<Map<String, dynamic>> serviceOptions = [], locationOptions = [];
  Widget _profileSelections(Map<String, dynamic> m, bool readOnly) {
    if (selectedServices.isEmpty && m['serviceTypeIds'] is List)
      selectedServices.addAll(
        (m['serviceTypeIds'] as List).map((x) => (x as num).toInt()),
      );
    if (selectedAreas.isEmpty && m['areaIds'] is List)
      selectedAreas.addAll(
        (m['areaIds'] as List).map((x) => (x as num).toInt()),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: serviceOptions
              .map(
                (x) => FilterChip(
                  label: Text(x['name'].toString()),
                  selected: selectedServices.contains((x['id'] as num).toInt()),
                  onSelected: readOnly
                      ? null
                      : (v) => setState(() {
                          final id = (x['id'] as num).toInt();
                          v
                              ? selectedServices.add(id)
                              : selectedServices.remove(id);
                        }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: locationOptions
              .map(
                (x) => FilterChip(
                  label: Text(x['name'].toString()),
                  selected: selectedAreas.contains((x['id'] as num).toInt()),
                  onSelected: readOnly
                      ? null
                      : (v) => setState(() {
                          final id = (x['id'] as num).toInt();
                          v ? selectedAreas.add(id) : selectedAreas.remove(id);
                        }),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _firstBranch(Map<String, dynamic> m, String key) {
    final b = m['branches'];
    if (b is List && b.isNotEmpty) return (_map(b.first)[key] ?? '').toString();
    return '';
  }

  Future<void> _saveProfile() async {
    if (selectedServices.isEmpty || selectedAreas.isEmpty) {
      providerMessage(
        context,
        'เลือกประเภทบริการและพื้นที่อย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      double? d(String k) => double.tryParse(fields[k]?.text ?? '');
      await api.put(
        '/api/company/provider/profile',
        body: {
          'slug': fields['slug']!.text,
          'displayName': fields['displayName']!.text,
          'summary': fields['summary']!.text,
          'address': fields['address']!.text,
          'telephone': fields['telephone']!.text,
          'email': fields['email']!.text,
          'lineId': fields['lineId']!.text,
          'lineUrl': fields['lineUrl']!.text,
          'websiteUrl': fields['websiteUrl']!.text,
          'serviceTypeIds': selectedServices.toList(),
          'areaIds': selectedAreas.toList(),
          'branches': [
            {
              'name': fields['branchName']!.text,
              'latitude': d('latitude'),
              'longitude': d('longitude'),
              'isPrimary': true,
            },
          ],
        },
      );
      if (mounted) providerMessage(context, 'บันทึกโปรไฟล์แล้ว');
      await load();
    } catch (e) {
      if (mounted)
        providerMessage(context, 'บันทึกโปรไฟล์ไม่สำเร็จ', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _submit() async {
    try {
      await api.post('/api/company/provider/profile/submit');
      if (mounted) providerMessage(context, 'ส่งโปรไฟล์เพื่ออนุมัติแล้ว');
      await load();
    } catch (e) {
      if (mounted) providerMessage(context, 'ส่งอนุมัติไม่สำเร็จ', error: true);
    }
  }

  Future<void> _withdraw() async {
    try {
      await api.post('/api/company/provider/profile/withdraw');
      if (mounted) providerMessage(context, 'ถอนคำขอแล้ว');
      await load();
    } catch (e) {
      if (mounted) providerMessage(context, 'ถอนคำขอไม่สำเร็จ', error: true);
    }
  }

  Widget _dashboard() {
    final m = _map(data), s = _map(m['summary']);
    final by = ((m['byService'] as List?) ?? []).map(_map).toList();
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(
                  'รีวิวทั้งหมด',
                  s['totalReviews'] ?? 0,
                  Icons.rate_review_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  'คะแนนเฉลี่ย',
                  s['averageRating'] ?? 0,
                  Icons.star_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  'รีวิวที่ซ่อน',
                  s['hiddenReviews'] ?? 0,
                  Icons.visibility_off_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Card(
              shape: _shape,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'คะแนนตามประเภทบริการ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Divider(),
                    ...by.map(
                      (x) => ListTile(
                        title: Text(x['name'].toString()),
                        subtitle: LinearProgressIndicator(
                          value: (_n(x['averageRating']) / 5).toDouble(),
                        ),
                        trailing: Text((x['averageRating'] ?? 0).toString()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, dynamic value, IconData icon) => Card(
    shape: _shape,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, color: providerTokens.primaryColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _locationDialog(Map<String, dynamic>? row) async {
    final code = TextEditingController(text: (row?['code'] ?? '').toString()),
        name = TextEditingController(text: (row?['name'] ?? '').toString()),
        nameEn = TextEditingController(text: (row?['nameEn'] ?? '').toString());
    String type = (row?['type'] ?? 'PROVINCE').toString();
    int? parent = (row?['parentId'] as num?)?.toInt();
    bool active = row?['active'] != false;
    await _dialog(
      title + ' > ' + (row == null ? 'เพิ่ม' : 'แก้ไข'),
      Icons.location_on_outlined,
      (set) => Column(
        children: [
          _text('รหัส *', code),
          const SizedBox(height: 16),
          _text('ชื่อพื้นที่ *', name),
          const SizedBox(height: 16),
          _text('ชื่อภาษาอังกฤษ', nameEn),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: _input('ประเภท *'),
            items: const [
              DropdownMenuItem(value: 'PROVINCE', child: Text('จังหวัด')),
              DropdownMenuItem(value: 'DISTRICT', child: Text('อำเภอ/เขต')),
              DropdownMenuItem(value: 'SUBDISTRICT', child: Text('ตำบล/แขวง')),
            ],
            onChanged: (v) => set(() => type = v!),
          ),
          if (type != 'PROVINCE') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: parent,
              decoration: _input('พื้นที่แม่ *'),
              isExpanded: true,
              items: rows
                  .where((x) => x['id'] != row?['id'])
                  .map(
                    (x) => DropdownMenuItem(
                      value: (x['id'] as num).toInt(),
                      child: Text(
                        x['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => set(() => parent = v),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('สถานะใช้งาน'),
            value: active,
            onChanged: (v) => set(() => active = v),
          ),
        ],
      ),
      () async {
        final body = {
          'code': code.text,
          'name': name.text,
          'nameEn': nameEn.text,
          'type': type,
          'parentId': type == 'PROVINCE' ? null : parent,
          'active': active,
        };
        row == null
            ? await api.post('/api/company/provider/locations', body: body)
            : await api.put(
                '/api/company/provider/locations/' + row['id'].toString(),
                body: body,
              );
      },
    );
  }

  Future<void> _serviceDialog(Map<String, dynamic>? row) async {
    final code = TextEditingController(text: (row?['code'] ?? '').toString()),
        name = TextEditingController(text: (row?['name'] ?? '').toString()),
        description = TextEditingController(
          text: (row?['description'] ?? '').toString(),
        ),
        icon = TextEditingController(
          text: (row?['iconName'] ?? 'home_repair_service_outlined').toString(),
        );
    bool active = row?['active'] != false;
    await _dialog(
      title + ' > ' + (row == null ? 'เพิ่ม' : 'แก้ไข'),
      Icons.home_repair_service_outlined,
      (set) => Column(
        children: [
          _text('รหัสประเภทบริการ *', code),
          const SizedBox(height: 16),
          _text('ชื่อประเภทบริการ *', name),
          const SizedBox(height: 16),
          _text('รายละเอียด', description, lines: 3),
          const SizedBox(height: 16),
          _text('ชื่อ Icon', icon),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('สถานะใช้งาน'),
            value: active,
            onChanged: (v) => set(() => active = v),
          ),
        ],
      ),
      () async {
        final body = {
          'code': code.text,
          'name': name.text,
          'description': description.text,
          'iconName': icon.text,
          'active': active,
        };
        row == null
            ? await api.post('/api/company/provider/service-types', body: body)
            : await api.put(
                '/api/company/provider/service-types/' + row['id'].toString(),
                body: body,
              );
      },
    );
  }

  Future<void> _reviewLinkDialog() async {
    if (serviceOptions.isEmpty) {
      providerMessage(context, 'ยังไม่มีประเภทบริการในโปรไฟล์', error: true);
      return;
    }
    int? service = (serviceOptions.first['id'] as num).toInt();
    final ref = TextEditingController(),
        date = TextEditingController(
          text: DateTime.now().toIso8601String().substring(0, 10),
        );
    await _dialog(
      title + ' > เพิ่ม',
      Icons.link_outlined,
      (set) => Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: service,
            decoration: _input('ประเภทบริการ *'),
            isExpanded: true,
            items: serviceOptions
                .map(
                  (x) => DropdownMenuItem(
                    value: (x['id'] as num).toInt(),
                    child: Text(x['name'].toString()),
                  ),
                )
                .toList(),
            onChanged: (v) => set(() => service = v),
          ),
          const SizedBox(height: 16),
          _text('วันที่ให้บริการ *', date),
          const SizedBox(height: 16),
          _text('เลขอ้างอิง', ref),
        ],
      ),
      () async {
        final r = _map(
          await api.post(
            '/api/company/provider/review-links',
            body: {
              'serviceTypeId': service,
              'serviceDate': date.text,
              'referenceNo': ref.text,
            },
          ),
        );
        if (mounted)
          providerMessage(
            context,
            'สร้างลิงก์แล้ว: ' + (r['url'] ?? '').toString(),
          );
      },
    );
  }

  Future<void> _coverUpload(Map<String, dynamic> row) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (pick == null || pick.files.single.bytes == null) return;
    try {
      await uploadProviderFile(
        '/api/company/provider/service-types/' +
            row['id'].toString() +
            '/cover',
        fileName: pick.files.single.name,
        bytes: pick.files.single.bytes!,
      );
      if (mounted) providerMessage(context, 'อัปโหลดรูปปกแล้ว');
      await load();
    } catch (e) {
      if (mounted)
        providerMessage(context, 'อัปโหลดรูปปกไม่สำเร็จ', error: true);
    }
  }

  Future<void> _decision(Map<String, dynamic> row, String action) async {
    final reason = TextEditingController();
    if (action != 'approve') {
      final ok = await _reasonDialog(
        action == 'return' ? 'เหตุผลที่ส่งกลับ' : 'เหตุผลที่ระงับ',
        reason,
      );
      if (!ok) return;
    }
    try {
      await api.post(
        '/api/company/provider/approvals/' +
            row['id'].toString() +
            '/' +
            action,
        body: {'reason': reason.text},
      );
      if (mounted)
        providerMessage(
          context,
          action == 'approve'
              ? 'อนุมัติแล้ว'
              : action == 'return'
              ? 'ส่งกลับแล้ว'
              : 'ระงับแล้ว',
        );
      await load();
    } catch (e) {
      if (mounted) providerMessage(context, 'ดำเนินการไม่สำเร็จ', error: true);
    }
  }

  Future<bool> _reasonDialog(
    String caption,
    TextEditingController reason,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: _shape,
          title: Text(caption),
          content: _text('เหตุผล *', reason, lines: 3),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: _filled,
                onPressed: () =>
                    Navigator.pop(context, reason.text.trim().isNotEmpty),
                child: const Text('ยืนยัน'),
              ),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _cancelLink(Map<String, dynamic> row) async {
    if (!await _confirm(
      'ยกเลิกลิงก์ประเมิน',
      'ลิงก์นี้จะไม่สามารถใช้ตอบแบบประเมินได้',
    ))
      return;
    try {
      await api.delete(
        '/api/company/provider/review-links/' + row['id'].toString(),
      );
      if (mounted) providerMessage(context, 'ยกเลิกลิงก์แล้ว');
      await load();
    } catch (e) {
      if (mounted) providerMessage(context, 'ยกเลิกไม่สำเร็จ', error: true);
    }
  }

  Future<void> _moderate(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    if (!await _reasonDialog(
      row['hidden'] == true ? 'เหตุผลที่นำกลับมาแสดง' : 'เหตุผลที่ซ่อนรีวิว',
      reason,
    ))
      return;
    try {
      await api.post(
        '/api/company/provider/reviews/' + row['id'].toString() + '/moderate',
        body: {'hidden': row['hidden'] != true, 'reason': reason.text},
      );
      if (mounted) providerMessage(context, 'บันทึกสถานะรีวิวแล้ว');
      await load();
    } catch (e) {
      if (mounted) providerMessage(context, 'ดำเนินการไม่สำเร็จ', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final name = (row['name'] ?? row['code']).toString();
    if (!await _confirm('ลบ ' + name, 'เมื่อลบแล้วไม่สามารถเรียกคืนได้'))
      return;
    final path = widget.menuCode == '51002' ? 'locations' : 'service-types';
    try {
      await api.delete(
        '/api/company/provider/' + path + '/' + row['id'].toString(),
      );
      if (mounted) providerMessage(context, 'ลบข้อมูลแล้ว');
      await load();
    } catch (e) {
      if (mounted)
        providerMessage(
          context,
          'ลบไม่สำเร็จ รายการอาจถูกใช้งานอยู่',
          error: true,
        );
    }
  }

  Future<bool> _confirm(String caption, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: _shape,
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 36),
          title: Text(caption, style: const TextStyle(color: Colors.red)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _dialog(
    String caption,
    IconData icon,
    Widget Function(StateSetter) content,
    Future<void> Function() save,
  ) async {
    bool busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, set) => Dialog(
          backgroundColor: Colors.white,
          shape: _shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(icon, color: providerTokens.primaryColor, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          caption,
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
                    padding: const EdgeInsets.all(10),
                    child: content(set),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 84,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onPressed: busy
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('ยกเลิก'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        height: 48,
                        child: FilledButton.icon(
                          style: _filled,
                          onPressed: busy
                              ? null
                              : () async {
                                  set(() => busy = true);
                                  try {
                                    await save();
                                    if (dialogContext.mounted)
                                      Navigator.pop(dialogContext);
                                    if (mounted)
                                      providerMessage(
                                        context,
                                        'บันทึกข้อมูลแล้ว',
                                      );
                                    await load();
                                  } catch (e) {
                                    if (mounted)
                                      providerMessage(
                                        context,
                                        'บันทึกไม่สำเร็จ',
                                        error: true,
                                      );
                                    set(() => busy = false);
                                  }
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: Text(busy ? '...' : 'บันทึก'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool number = false,
    int lines = 1,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    maxLines: lines,
    keyboardType: number ? TextInputType.number : null,
    style: const TextStyle(fontSize: 14),
    decoration: _input(label),
  );
  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 14),
    hintStyle: const TextStyle(fontSize: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: Theme.of(context).dividerColor),
    ),
  );
  RoundedRectangleBorder get _shape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.map((k, v) => MapEntry(k.toString(), v))
    : <String, dynamic>{};
