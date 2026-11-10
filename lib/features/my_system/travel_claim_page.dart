import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/company_setup/company_date_formatter.dart';
import '../../core/company_setup/company_setup_controller.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/list_display_preferences.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../assistant/assistant_download.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class TravelClaimPage extends StatefulWidget {
  const TravelClaimPage({super.key});
  @override
  State<TravelClaimPage> createState() => _TravelClaimPageState();
}

class _TravelClaimPageState extends State<TravelClaimPage> {
  final api = ApiClient(), search = TextEditingController();
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final k in [
      'origin',
      'destination',
      'purpose',
      'workPlace',
      'mapUrl',
      'distance',
      'registration',
      'nights',
      'toll',
      'parking',
      'transport',
    ])
      k: TextEditingController(),
  };
  List<Map<String, dynamic>> items = [],
      vehicles = [],
      routes = [],
      rates = [],
      fares = [],
      attachments = [];
  final pendingFiles = <PlatformFile>[];
  ListDisplayPreferences preferences = const ListDisplayPreferences();
  String title = '', query = '';
  bool loading = true,
      cards = false,
      editing = false,
      saving = false,
      canCreate = false,
      canEdit = false,
      canDelete = false;
  int page = 1;
  int? claimId, routeId;
  String? vehicle;
  String number = '';
  DateTime claimDate = DateTime.now(),
      start = DateTime.now(),
      end = DateTime.now();
  double? lodgingRate, savedRate, savedFlat, savedLodging;
  int? savedRoute, savedNights;
  String? savedVehicle;
  bool isInterbranch = false;
  bool readOnly = false;
  String requestKey = '';

  String newRequestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    listDisplayPreferencesRevision.addListener(loadPreferences);
    load();
  }

  @override
  void dispose() {
    listDisplayPreferencesRevision.removeListener(loadPreferences);
    for (final c in fields.values) {
      c.dispose();
    }
    search.dispose();
    api.dispose();
    super.dispose();
  }

  Future<void> loadPreferences() async {
    try {
      final x = await api.get('/api/user-list-display/66001');
      if (mounted && x is Map) {
        setState(
          () => preferences = ListDisplayPreferences.fromJson(
            Map<String, dynamic>.from(x),
          ),
        );
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> maps(dynamic x) => x is List
      ? x.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  Future<void> load() async {
    try {
      final menu = await NavigationMenuRepository().findMenu(menuCode: '66001');
      final data = await api.get('/api/company/travel-claims');
      if (data is! Map) throw StateError('response');
      if (!mounted) return;
      setState(() {
        title = menu?.name ?? '';
        items = maps(data['items']);
        vehicles = maps(data['vehicles']);
        routes = maps(data['routes']);
        rates = maps(data['rates']);
        fares = maps(data['fares']);
        lodgingRate = (data['lodging'] as num?)?.toDouble();
        canCreate = data['create'] == true;
        canEdit = data['edit'] == true;
        canDelete = data['delete'] == true;
        loading = false;
      });
      await loadPreferences();
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        showTimedSnackBar(
          context,
          message: 'โหลดใบเบิกค่าเดินทางไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  String displayDate(DateTime d) => CompanyDateFormatter.formatDateByYearFormat(
    d,
    companySetupController.current?.yearFormat ?? 'AD',
  );

  String displayField(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (key == 'date' && value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return displayDate(parsed);
    }
    if (key == 'total' && value is num) return value.toStringAsFixed(2);
    return '${value ?? '-'}';
  }

  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  double amount(String key) => double.tryParse(fields[key]!.text.trim()) ?? 0;
  bool get samePricing =>
      claimId != null && routeId == savedRoute && vehicle == savedVehicle;
  double? get effectiveLodging =>
      claimId != null && ((savedNights ?? 0) > 0 || amount('nights') == 0)
      ? savedLodging
      : lodgingRate;
  double? get rate {
    if (samePricing) return savedRate;
    for (final r in rates) {
      if (r['code'] == vehicle) return (r['rate'] as num).toDouble();
    }
    return null;
  }

  double? get flat {
    if (samePricing) return savedFlat;
    for (final r in fares) {
      if (r['routeId'] == routeId && r['code'] == vehicle) {
        return (r['amount'] as num).toDouble();
      }
    }
    return null;
  }

  int get days => end.difference(start).inDays + 1;
  double get fuel =>
      flat ?? (amount('distance') * (days < 0 ? 0 : days) * (rate ?? 0));
  double get total =>
      fuel +
      (effectiveLodging ?? 0) * amount('nights') +
      amount('toll') +
      amount('parking') +
      amount('transport');
  void resetForm() {
    for (final c in fields.values) {
      c.clear();
    }
    for (final k in ['distance', 'nights', 'toll', 'parking', 'transport']) {
      fields[k]!.text = '0';
    }
    pendingFiles.clear();
    attachments = [];
    claimId = null;
    routeId = null;
    requestKey = newRequestKey();
    readOnly = false;
    isInterbranch = false;
    vehicle = null;
    savedRate = savedFlat = savedLodging = null;
    savedRoute = savedNights = null;
    savedVehicle = null;
    number = '';
    claimDate = DateTime.now();
    start = DateTime.now();
    end = DateTime.now();
  }

  Future<void> open([Map<String, dynamic>? row]) async {
    resetForm();
    readOnly = row != null && !canEdit;
    if (row != null) {
      try {
        final d = await api.get('/api/company/travel-claims/${row['id']}');
        if (d is! Map || d['item'] is! Map) throw StateError('response');
        final x = Map<String, dynamic>.from(d['item']);
        claimId = x['id'] as int;
        number = '${x['number']}';
        claimDate = DateTime.parse(x['date']);
        start = DateTime.parse(x['start']);
        end = DateTime.parse(x['end']);
        routeId = x['routeId'] as int?;
        isInterbranch = x['isInterbranch'] == true;
        vehicle = x['vehicle'] as String?;
        savedRoute = routeId;
        savedVehicle = vehicle;
        savedRate = (x['rate'] as num?)?.toDouble();
        savedFlat = (x['flat'] as num?)?.toDouble();
        savedLodging = (x['lodgingRate'] as num?)?.toDouble();
        savedNights = x['nights'] as int?;
        for (final k in fields.keys) {
          fields[k]!.text = '${x[k] ?? ''}';
        }
        attachments = maps(d['attachments']);
      } catch (_) {
        if (mounted) {
          showTimedSnackBar(
            context,
            message: 'โหลดใบเบิกไม่สำเร็จ กรุณาลองใหม่',
            error: true,
          );
        }
        return;
      }
    }
    if (mounted) setState(() => editing = true);
  }

  Future<void> chooseFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    if (!mounted) return;
    var bytes = pendingFiles.fold<int>(0, (sum, file) => sum + file.size);
    final valid = <PlatformFile>[];
    for (final f in result.files) {
      if (f.bytes != null &&
          f.size > 0 &&
          f.size <= 10000000 &&
          bytes + f.size <= 20000000) {
        valid.add(f);
        bytes += f.size;
      }
    }
    setState(() => pendingFiles.addAll(valid));
    if (valid.length != result.files.length) {
      showTimedSnackBar(
        context,
        message: 'บางไฟล์อ่านไม่ได้ เกิน 10 MB ต่อไฟล์ หรือเกิน 20 MB รวม',
        error: true,
      );
    }
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    if (end.isBefore(start)) {
      showTimedSnackBar(
        context,
        message: 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่มเดินทาง',
        error: true,
      );
      return;
    }
    if (vehicle == null || (flat == null && rate == null)) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกประเภทรถที่มีอัตราค่าเดินทาง',
        error: true,
      );
      return;
    }
    if (amount('nights') > 0 && effectiveLodging == null) {
      showTimedSnackBar(
        context,
        message: 'ไม่พบอัตราค่าที่พักตามระดับตำแหน่ง กรุณาติดต่อผู้ดูแล',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final body = {
        'claimDate': iso(claimDate),
        'routeId': routeId,
        'origin': fields['origin']!.text.trim(),
        'destination': fields['destination']!.text.trim(),
        'purpose': fields['purpose']!.text.trim(),
        'workPlace': fields['workPlace']!.text.trim(),
        'mapUrl': fields['mapUrl']!.text.trim(),
        'distanceKm': amount('distance'),
        'startDate': iso(start),
        'endDate': iso(end),
        'vehicleTypeCode': vehicle,
        'vehicleRegistration': fields['registration']!.text.trim(),
        'nights': int.tryParse(fields['nights']!.text) ?? 0,
        'toll': amount('toll'),
        'parking': amount('parking'),
        'publicTransport': amount('transport'),
        'isInterbranch': isInterbranch,
        'requestKey': requestKey,
        'attachments': pendingFiles
            .map((f) => {'name': f.name, 'base64': base64Encode(f.bytes!)})
            .toList(),
      };
      final response = claimId == null
          ? await api.post('/api/company/travel-claims', body: body)
          : await api.put('/api/company/travel-claims/$claimId', body: body);
      if (response is! Map || response['id'] == null) {
        throw StateError('response');
      }
      claimId = (response['id'] as num).toInt();
      number = '${response['number']}';
      pendingFiles.clear();
      if (!mounted) return;
      showTimedSnackBar(
        context,
        message: 'บันทึกใบเบิกค่าเดินทางเรียบร้อยแล้ว',
      );
      setState(() => editing = false);
      await load();
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? error.message
              : 'บันทึกใบเบิกและไฟล์แนบไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบข้อมูลและการเชื่อมต่อแล้วลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> download(Map<String, dynamic> f) async {
    try {
      final bytes = await api.getBytes(
        '/api/company/travel-claims/$claimId/attachments/${f['id']}',
      );
      await saveAssistantFile(
        '${f['name']}',
        'application/octet-stream',
        Uint8List.fromList(bytes),
      );
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'เปิดไฟล์ไม่สำเร็จ กรุณาลองใหม่',
          error: true,
        );
      }
    }
  }

  Future<bool> confirmDelete(String name) async {
    final danger = Theme.of(context).colorScheme.error;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: danger),
            ),
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยืนยันการลบข้อมูล',
                    style: TextStyle(
                      color: danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: danger.withValues(alpha: .1),
                  child: Text(name),
                ),
                const SizedBox(height: 12),
                const Text('ข้อมูลที่ลบไม่สามารถเรียกคืนได้'),
                const Divider(thickness: .6),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: danger),
                onPressed: () => Navigator.pop(dialog, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> removeClaim(Map<String, dynamic> row) async {
    if (!await confirmDelete('${row['number']}') || !mounted) return;
    try {
      await api.delete('/api/company/travel-claims/${row['id']}');
      if (mounted) {
        showTimedSnackBar(context, message: 'ลบใบเบิกเรียบร้อยแล้ว');
        await load();
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ลบใบเบิกไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  Future<void> removeAttachment(Map<String, dynamic> attachment) async {
    if (!await confirmDelete('${attachment['name']}') || !mounted) return;
    try {
      await api.delete(
        '/api/company/travel-claims/$claimId/attachments/${attachment['id']}',
      );
      if (mounted) {
        setState(() => attachments.remove(attachment));
        showTimedSnackBar(context, message: 'ลบไฟล์แนบเรียบร้อยแล้ว');
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ลบไฟล์แนบไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  Widget rowActions(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!canEdit)
        IconButton(
          onPressed: () => open(row),
          icon: Icon(
            Icons.visibility_outlined,
            color: businessCardOcrUi(context).primaryColor,
          ),
          tooltip: 'ดูข้อมูล',
        ),
      if (canEdit)
        IconButton(
          onPressed: () => open(row),
          icon: Icon(
            Icons.edit_outlined,
            color: businessCardOcrUi(context).primaryColor,
          ),
          tooltip: 'แก้ไข',
        ),
      if (canDelete)
        IconButton(
          onPressed: () => removeClaim(row),
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          tooltip: 'ลบ',
        ),
    ],
  );

  Widget input(
    BuildContext context,
    String key,
    String label, {
    bool required = false,
    bool numeric = false,
  }) => TextFormField(
    controller: fields[key],
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: ocrInput(context, label),
    style: businessCardOcrUi(context).inputStyle,
    onChanged: (_) => setState(() {
      if ((key == 'origin' || key == 'destination') && routeId != null) {
        final route = routes.where((r) => r['id'] == routeId).firstOrNull;
        if (route != null &&
            (fields['origin']!.text != '${route['origin']}' ||
                fields['destination']!.text != '${route['destination']}')) {
          routeId = null;
        }
      }
    }),
    validator: (v) {
      if (required && (v == null || v.trim().isEmpty)) return 'กรุณาระบุ$label';
      if (numeric) {
        final n = double.tryParse(v ?? '');
        if (n == null ||
            n < 0 ||
            !RegExp(
              key == 'nights' ? r'^\d+$' : r'^\d+(\.\d{1,2})?$',
            ).hasMatch(v ?? '')) {
          return 'กรุณาระบุตัวเลขที่ถูกต้อง';
        }
      }
      return null;
    },
  );
  Widget dateInput(
    BuildContext context,
    String label,
    DateTime value,
    ValueChanged<DateTime> change,
  ) => OutlinedButton.icon(
    onPressed: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (d != null) setState(() => change(d));
    },
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text('$label ${displayDate(value)}'),
  );
  Widget block(BuildContext context, String label, List<Widget> children) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      );
  Widget gap() => const SizedBox(height: 14);
  Widget editor(BuildContext context) {
    final t = businessCardOcrUi(context);
    return Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        children: [
          LaooCaptionCard(
            tokens: t,
            caption:
                '$title > ${claimId == null
                    ? 'เพิ่ม'
                    : readOnly
                    ? 'ดูข้อมูล'
                    : 'แก้ไข'}',
            favoriteKey: '66001',
            leading: Icon(Icons.receipt_long_outlined, color: t.primaryColor),
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => setState(() => editing = false),
                  child: const Text('ยกเลิก'),
                ),
                if (!readOnly)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
              ],
            ),
          ),
          gap(),
          IgnorePointer(
            ignoring: readOnly,
            child: block(context, 'ข้อมูลการเดินทาง', [
              DropdownButtonFormField<bool>(
                initialValue: isInterbranch,
                decoration: ocrInput(context, 'เดินทางระหว่างสาขา'),
                items: const [
                  DropdownMenuItem(
                    value: false,
                    child: Text('ไม่ได้เดินทางระหว่างสาขา'),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text('เดินทางระหว่างสาขา'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => isInterbranch = value ?? false),
              ),
              gap(),
              Text('เลขที่: ${number.isEmpty ? 'สร้างอัตโนมัติ' : number}'),
              dateInput(
                context,
                'วันที่บันทึก',
                claimDate,
                (d) => claimDate = d,
              ),
              gap(),
              DropdownButtonFormField<int>(
                initialValue: routeId,
                decoration: ocrInput(context, 'เส้นทางเหมาจ่าย (ถ้ามี)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                  if (routeId != null && !routes.any((r) => r['id'] == routeId))
                    DropdownMenuItem(
                      value: routeId,
                      child: const Text('??????????? (?????????????????????)'),
                    ),
                  for (final r in routes)
                    DropdownMenuItem(
                      value: r['id'] as int,
                      child: Text('${r['origin']} → ${r['destination']}'),
                    ),
                ],
                onChanged: (id) => setState(() {
                  routeId = id;
                  if (id != null) {
                    final r = routes.firstWhere((x) => x['id'] == id);
                    fields['origin']!.text = '${r['origin']}';
                    fields['destination']!.text = '${r['destination']}';
                    fields['distance']!.text = '${r['distance']}';
                  }
                }),
              ),
              gap(),
              input(context, 'origin', 'สถานที่ต้นทาง *', required: true),
              gap(),
              input(context, 'destination', 'สถานที่ปลายทาง *', required: true),
              gap(),
              input(
                context,
                'purpose',
                'วัตถุประสงค์ปฏิบัติงาน *',
                required: true,
              ),
              gap(),
              input(
                context,
                'workPlace',
                'สถานที่ปฏิบัติงาน *',
                required: true,
              ),
              gap(),
              input(context, 'mapUrl', 'Link Map (ถ้ามี)'),
              gap(),
              input(
                context,
                'distance',
                'ระยะทาง (กม.) ต่อวัน *',
                required: true,
                numeric: true,
              ),
              gap(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  dateInput(
                    context,
                    'วันที่เริ่มเดินทาง',
                    start,
                    (d) => start = d,
                  ),
                  dateInput(context, 'วันที่สิ้นสุด', end, (d) => end = d),
                  Text('จำนวนวัน ${days < 0 ? 0 : days} วัน'),
                ],
              ),
              gap(),
              DropdownButtonFormField<String>(
                initialValue: vehicle,
                decoration: ocrInput(context, 'ประเภทรถ *'),
                items: [
                  if (vehicle != null &&
                      !vehicles.any((v) => v['code'] == vehicle))
                    DropdownMenuItem(
                      value: vehicle,
                      child: const Text('???????????? (?????????????????????)'),
                    ),
                  for (final v in vehicles)
                    DropdownMenuItem(
                      value: '${v['code']}',
                      child: Text('${v['name']}'),
                    ),
                ],
                onChanged: (v) => setState(() => vehicle = v),
                validator: (v) => v == null ? 'กรุณาเลือกประเภทรถ' : null,
              ),
              gap(),
              input(context, 'registration', 'ทะเบียนรถ *', required: true),
              gap(),
              Text(
                'อัตราต่อกิโลเมตร: ${rate?.toStringAsFixed(2) ?? 'ไม่กำหนด'}   ค่าเหมาจ่าย: ${flat?.toStringAsFixed(2) ?? 'ไม่มี'}   รวมค่าน้ำมัน: ${fuel.toStringAsFixed(2)} บาท',
              ),
            ]),
          ),
          gap(),
          IgnorePointer(
            ignoring: readOnly,
            child: block(context, 'ข้อมูลการเบิกจ่าย', [
              input(context, 'toll', 'ค่าทางด่วน (บาท)', numeric: true),
              gap(),
              input(context, 'parking', 'ค่าที่จอดรถ (บาท)', numeric: true),
              gap(),
              input(
                context,
                'transport',
                'ค่ายานพาหนะสาธารณะ (บาท)',
                numeric: true,
              ),
              gap(),
              Text(
                'ค่าที่พักต่อคืน: ${lodgingRate?.toStringAsFixed(2) ?? 'ไม่กำหนด'} บาท',
              ),
              gap(),
              input(context, 'nights', 'จำนวนคืนที่พัก', numeric: true),
              gap(),
              Text(
                'รวมค่าที่พัก: ${((effectiveLodging ?? 0) * amount('nights')).toStringAsFixed(2)} บาท',
              ),
              gap(),
              Text(
                'ยอดเบิกรวม: ${total.toStringAsFixed(2)} บาท',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ]),
          ),
          gap(),
          block(context, 'ไฟล์ประกอบ', [
            if (!readOnly)
              OutlinedButton.icon(
                onPressed: saving ? null : chooseFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('เลือกไฟล์รูปหรือ PDF'),
              ),
            const Text(
              'รองรับ JPG, PNG, WEBP และ PDF ไม่เกิน 10 MB ต่อไฟล์ รวมไม่เกิน 20 MB',
            ),
            for (final f in pendingFiles)
              ListTile(
                title: Text(f.name),
                trailing: IconButton(
                  onPressed: saving
                      ? null
                      : () => setState(() => pendingFiles.remove(f)),
                  icon: const Icon(Icons.close),
                ),
              ),
            for (final f in attachments)
              ListTile(
                title: Text('${f['name']}'),
                onTap: () => download(f),
                trailing: canEdit
                    ? IconButton(
                        onPressed: saving ? null : () => removeAttachment(f),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'ลบไฟล์',
                      )
                    : null,
              ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = businessCardOcrUi(context);
    final visible = items
        .where(
          (r) => '${r['number']} ${r['origin']} ${r['destination']}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    final pageSize = companySetupController.pageSize > 0
        ? companySetupController.pageSize.clamp(1, 200)
        : 20;
    final pages = visible.isEmpty ? 1 : (visible.length / pageSize).ceil();
    final current = page.clamp(1, pages);
    final startAt = (current - 1) * pageSize;
    final rows = visible.skip(startAt).take(pageSize).toList();
    final cols = preferences
        .resolve(travelClaimDisplayFields)
        .where(preferences.isVisible)
        .toList();
    return SupportWorkspaceShell(
      pageTitle: title,
      activeMenu: 'mySystemTravel',
      menuScope: WorkspaceMenuScope.company,
      child: editing
          ? editor(context)
          : LaooListWorkspace(
              tokens: t,
              caption: LaooCaptionCard(
                tokens: t,
                caption: title,
                favoriteKey: '66001',
                leading: Icon(
                  Icons.receipt_long_outlined,
                  color: t.primaryColor,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LaooListCardToggle(
                      tokens: t,
                      cards: cards,
                      onChanged: (v) => setState(() => cards = v),
                    ),
                    if (canCreate)
                      FilledButton.icon(
                        onPressed: () => open(),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
              filter: FilterHeightSync(
                builder: (context, key, height) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        key: key,
                        controller: search,
                        decoration: ocrInput(
                          context,
                          'ค้นหาเลขที่ ต้นทาง หรือปลายทาง',
                          icon: Icons.search,
                        ),
                        onSubmitted: (_) => setState(() {
                          query = search.text;
                          page = 1;
                        }),
                      ),
                    ),
                    FilledButton.icon(
                      style: filterActionHeightStyle(height),
                      onPressed: () => setState(() {
                        query = search.text;
                        page = 1;
                      }),
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหา'),
                    ),
                    OutlinedButton.icon(
                      style: filterActionHeightStyle(height),
                      onPressed: () => setState(() {
                        search.clear();
                        query = '';
                        page = 1;
                      }),
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('ล้าง Filter'),
                    ),
                  ],
                ),
              ),
              table: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูล'))
                  : cards
                  ? ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return Card(
                          child: ListTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final c in cols)
                                  Text('${c.label}: ${displayField(r, c.key)}'),
                              ],
                            ),
                            leading: preferences.actionOnRight
                                ? null
                                : rowActions(r),
                            trailing: preferences.actionOnRight
                                ? rowActions(r)
                                : null,
                          ),
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingTextStyle: t.tableStyle.copyWith(
                                      color: t.primaryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    dataTextStyle: t.tableStyle,
                                    headingRowColor: WidgetStatePropertyAll(
                                      t.primaryColor.withValues(alpha: .12),
                                    ),
                                    columns: [
                                      const DataColumn(label: Text('ID')),
                                      if (!preferences.actionOnRight)
                                        const DataColumn(label: Text('Action')),
                                      for (final c in cols)
                                        DataColumn(label: Text(c.label)),
                                      if (preferences.actionOnRight)
                                        const DataColumn(label: Text('Action')),
                                    ],
                                    rows: [
                                      for (var i = 0; i < rows.length; i++)
                                        DataRow(
                                          cells: [
                                            DataCell(
                                              Text('${startAt + i + 1}'),
                                            ),
                                            if (!preferences.actionOnRight)
                                              DataCell(rowActions(rows[i])),
                                            for (final c in cols)
                                              DataCell(
                                                Text(
                                                  displayField(rows[i], c.key),
                                                ),
                                              ),
                                            if (preferences.actionOnRight)
                                              DataCell(rowActions(rows[i])),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
              pagination: LaooPaginationCard(
                tokens: t,
                borderless: true,
                page: current,
                pageCount: pages,
                pageSize: pageSize,
                total: visible.length,
                onPrevious: current > 1
                    ? () => setState(() => page = current - 1)
                    : null,
                onNext: current < pages
                    ? () => setState(() => page = current + 1)
                    : null,
              ),
            ),
    );
  }
}
