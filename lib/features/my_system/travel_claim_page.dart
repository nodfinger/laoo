import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
import 'travel_attachment_open.dart';
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
      attachments = [],
      organizations = [];
  final pendingFiles = <PlatformFile>[];
  final savedImageBytes = <String, Future<Uint8List>>{};
  Uint8List? attachmentPreview;
  String? attachmentPreviewName;
  int attachmentPreviewRevision = 0;
  ListDisplayPreferences preferences = const ListDisplayPreferences();
  String title = '', query = '';
  String? filterDivision, filterDepartment, filterClaimant, filterDate;
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
  double? lodgingRate, ownerLodging, savedRate, savedFlat, savedLodging;
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
        organizations = maps(data['organizations']);
        if (filterDivision != null &&
            !organizations.any(
              (r) => '${r['id']}' == filterDivision && r['type'] == 'DIV',
            )) {
          filterDivision = null;
        }
        if (filterDepartment != null &&
            !organizations.any(
              (r) =>
                  '${r['id']}' == filterDepartment &&
                  r['type'] == 'DEP' &&
                  (filterDivision == null ||
                      '${r['parentId']}' == filterDivision),
            )) {
          filterDepartment = null;
        }
        if (filterClaimant != null &&
            !items.any(
              (r) =>
                  '${r['claimantId']}' == filterClaimant &&
                  (filterDivision == null ||
                      '${r['divisionId']}' == filterDivision) &&
                  (filterDepartment == null ||
                      '${r['departmentId']}' == filterDepartment),
            )) {
          filterClaimant = null;
        }
        if (filterDate != null &&
            !items.any((r) => '${r['date']}' == filterDate)) {
          filterDate = null;
        }
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
    if (value is String && value.trim().isEmpty) return '-';
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
      : (claimId == null ? lodgingRate : ownerLodging);
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
    savedImageBytes.clear();
    attachmentPreviewRevision++;
    attachmentPreview = null;
    attachmentPreviewName = null;
    claimId = null;
    routeId = null;
    requestKey = newRequestKey();
    readOnly = false;
    isInterbranch = false;
    vehicle = null;
    savedRate = savedFlat = savedLodging = null;
    ownerLodging = null;
    savedRoute = savedNights = null;
    savedVehicle = null;
    number = '';
    claimDate = DateTime.now();
    start = DateTime.now();
    end = DateTime.now();
  }

  Future<void> open([Map<String, dynamic>? row]) async {
    resetForm();
    readOnly = row != null && row['canEdit'] != true;
    if (row == null) {
      try {
        final defaults = await api.get(
          '/api/company/travel-claims/vehicle-default',
        );
        if (defaults is Map) {
          final code = defaults['vehicle']?.toString().trim();
          if (code != null &&
              code.isNotEmpty &&
              vehicles.any((v) => '${v['code']}' == code)) {
            vehicle = code;
          }
          fields['registration']!.text =
              defaults['registration']?.toString() ?? '';
        }
      } catch (_) {
        if (mounted) {
          showTimedSnackBar(
            context,
            message: 'ไม่สามารถโหลดข้อมูลรถเริ่มต้น กรุณาระบุข้อมูลรถ',
            error: true,
          );
        }
      }
    } else {
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
        ownerLodging = (d['ownerLodging'] as num?)?.toDouble();
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
          f.size <= 2000000 &&
          bytes + f.size <= 20000000) {
        valid.add(f);
        bytes += f.size;
      }
    }
    setState(() {
      pendingFiles.addAll(valid);
      final firstImage = valid
          .where((f) => isImageAttachment(f.name) && f.bytes != null)
          .firstOrNull;
      if (firstImage != null) {
        attachmentPreviewRevision++;
        attachmentPreview = firstImage.bytes;
        attachmentPreviewName = firstImage.name;
      }
    });
    if (valid.length != result.files.length) {
      showTimedSnackBar(
        context,
        message: 'บางไฟล์อ่านไม่ได้ เกิน 2 MB ต่อไฟล์ หรือเกิน 20 MB รวม',
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
      try {
        final refreshed = await api.get('/api/company/travel-claims/$claimId');
        if (refreshed is Map) attachments = maps(refreshed['attachments']);
      } catch (_) {
        // The document is already saved; attachment refresh can be retried.
      }
      if (mounted) setState(() {});
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
      await openTravelPdf(
        '${f['name']}',
        () async => Uint8List.fromList(
          await api.getBytes(
            '/api/company/travel-claims/$claimId/attachments/${f['id']}',
          ),
        ),
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

  bool isImageAttachment(String name) =>
      RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(name);

  Future<Uint8List> savedImage(Map<String, dynamic> file) {
    final documentId = claimId;
    final fileId = file['id'];
    return savedImageBytes.putIfAbsent('$documentId:$fileId', () async {
      final bytes = await api.getBytes(
        '/api/company/travel-claims/$documentId/attachments/$fileId',
      );
      return Uint8List.fromList(bytes);
    });
  }

  Future<void> previewSavedAttachment(Map<String, dynamic> file) async {
    final revision = ++attachmentPreviewRevision;
    try {
      final bytes = await savedImage(file);
      if (!mounted || revision != attachmentPreviewRevision) return;
      showAttachmentImage(Uint8List.fromList(bytes), '${file['name']}');
    } catch (_) {
      if (mounted && revision == attachmentPreviewRevision) {
        showTimedSnackBar(
          context,
          message: 'ไม่สามารถแสดงรูปภาพได้ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  void showAttachmentImage(Uint8List bytes, String name) {
    final accent = businessCardOcrUi(context).primaryColor;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Row(
          children: [
            Icon(Icons.image_outlined, color: accent),
            const SizedBox(width: 8),
            Expanded(child: Text(name)),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: min(500.0, MediaQuery.sizeOf(dialogContext).height * 0.6),
          child: Column(
            children: [
              const Divider(thickness: 0.6),
              Expanded(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              const Divider(thickness: 0.6),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
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
        setState(() {
          attachments.remove(attachment);
          savedImageBytes.remove('$claimId:${attachment['id']}');
          attachmentPreviewRevision++;
          attachmentPreview = null;
          attachmentPreviewName = null;
        });
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

  Future<void> printClaim() async {
    if (claimId == null) return;
    try {
      final result = await api.get('/api/company/travel-claims/$claimId');
      if (result is! Map || result['item'] is! Map)
        throw StateError('missing claim');
      final item = Map<String, dynamic>.from(result['item'] as Map);
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Variable.ttf',
      );
      final font = pw.Font.ttf(fontData.buffer.asByteData());
      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: font, bold: font),
      );
      String date(String key) {
        final d = DateTime.tryParse('${item[key] ?? ''}');
        return d == null ? '-' : displayDate(d);
      }

      String money(String key) => (item[key] as num? ?? 0).toStringAsFixed(2);
      doc.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              '????????????????',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            for (final line in <String>[
              '????????????: ${item['number']}',
              '????????????: ${date('date')}',
              '??????: ${item['origin']}   ???????: ${item['destination']}',
              '????????????: ${item['purpose']}',
              '?????????????????: ${item['workPlace']}',
              '?????????????: ${date('start')} - ${date('end')}',
              '?????????: ${item['registration']}   ???????: ${item['distance']} ??.',
              '?????????: ${money('fuel')} ???   ?????????: ${money('lodging')} ???',
              '??????????: ${money('toll')} ???   ???????????: ${money('parking')} ???',
              '??????????????????: ${money('transport')} ???',
              '??????????: ${money('total')} ???',
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(line),
              ),
          ],
        ),
      );
      await Printing.layoutPdf(
        name: 'travel-claim-${item['number']}.pdf',
        onLayout: (_) => doc.save(),
      );
    } catch (_) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: '??????????????????????? ????????????????????????????',
          error: true,
        );
    }
  }

  Widget rowActions(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (row['canEdit'] != true)
        IconButton(
          onPressed: () => open(row),
          icon: Icon(
            Icons.visibility_outlined,
            color: businessCardOcrUi(context).primaryColor,
          ),
          tooltip: 'ดูข้อมูล',
        ),
      if (row['canEdit'] == true)
        IconButton(
          onPressed: () => open(row),
          icon: Icon(
            Icons.edit_outlined,
            color: businessCardOcrUi(context).primaryColor,
          ),
          tooltip: 'แก้ไข',
        ),
      if (row['canDelete'] == true)
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
  Widget fieldRow(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 600
          ? 1
          : children.length > 2 && constraints.maxWidth < 1000
          ? 2
          : children.length;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
  Widget block(
    BuildContext context,
    String label,
    List<Widget> children, {
    Widget? trailing,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              ?trailing,
            ],
          ),
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
          LaooSurfaceCard(
            tokens: t,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actions = Wrap(
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
                );
                final caption = WorkspacePageTitle(
                  title:
                      '$title > ${claimId == null
                          ? 'เพิ่ม'
                          : readOnly
                          ? 'ดูข้อมูล'
                          : 'แก้ไข'}',
                  favoriteKey: '66001',
                );
                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      caption,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: caption),
                    const SizedBox(width: 8),
                    actions,
                  ],
                );
              },
            ),
          ),
          gap(),
          IgnorePointer(
            ignoring: readOnly,
            child: block(context, 'ข้อมูลการเดินทาง', [
              fieldRow([
                InputDecorator(
                  decoration: ocrInput(context, 'เลขที่เอกสาร'),
                  child: Text(
                    number.isEmpty ? 'สร้างอัตโนมัติเมื่อบันทึก' : number,
                    style: t.inputStyle,
                  ),
                ),
                dateInput(
                  context,
                  'วันที่บันทึกเอกสาร',
                  claimDate,
                  (d) => claimDate = d,
                ),
                dateInput(
                  context,
                  'วันที่เริ่มเดินทาง',
                  start,
                  (d) => start = d,
                ),
                dateInput(context, 'วันที่สิ้นสุด', end, (d) => end = d),
                Card(
                  margin: EdgeInsets.zero,
                  color: t.primaryColor.withValues(alpha: 0.10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ยอดเบิกรวม', style: t.tableStyle),
                        Text(
                          '฿${total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: t.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'จำนวนวัน ${days < 0 ? 0 : days} วัน',
                          style: t.tableStyle.copyWith(color: t.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              gap(),
              fieldRow([
                DropdownButtonFormField<int>(
                  initialValue: routeId,
                  decoration: ocrInput(context, 'เส้นทางเหมาจ่าย (ถ้ามี)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                    if (routeId != null &&
                        !routes.any((r) => r['id'] == routeId))
                      DropdownMenuItem(
                        value: routeId,
                        child: const Text(
                          'เส้นทางเดิม (ไม่มีในรายการปัจจุบัน)',
                        ),
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
                      fields['workPlace']!.text = '${r['destination']}';
                      fields['distance']!.text = '${r['distance']}';
                    }
                  }),
                ),
                input(context, 'origin', 'สถานที่ต้นทาง *', required: true),
                input(
                  context,
                  'destination',
                  'สถานที่ปลายทาง *',
                  required: true,
                ),
              ]),
              gap(),
              fieldRow([
                input(
                  context,
                  'purpose',
                  'วัตถุประสงค์ปฏิบัติงาน *',
                  required: true,
                ),
                input(
                  context,
                  'workPlace',
                  'สถานที่ปฏิบัติงาน *',
                  required: true,
                ),
              ]),
              gap(),
              input(context, 'mapUrl', 'Link Map (ถ้ามี)'),
              gap(),
              fieldRow([
                DropdownButtonFormField<String>(
                  initialValue: vehicle,
                  decoration: ocrInput(context, 'ประเภทรถ *'),
                  items: [
                    if (vehicle != null &&
                        !vehicles.any((v) => v['code'] == vehicle))
                      DropdownMenuItem(
                        value: vehicle,
                        child: const Text(
                          'ประเภทรถเดิม (ไม่มีในรายการปัจจุบัน)',
                        ),
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
                input(context, 'registration', 'ทะเบียนรถ *', required: true),
                input(
                  context,
                  'distance',
                  'ระยะทาง (กม.) ต่อวัน *',
                  required: true,
                  numeric: true,
                ),
              ]),
              gap(),
              Text(
                'อัตราต่อกิโลเมตร: ${rate?.toStringAsFixed(2) ?? 'ไม่กำหนด'}   ค่าเหมาจ่าย: ${flat?.toStringAsFixed(2) ?? 'ไม่มี'}   รวมค่าน้ำมัน: ${fuel.toStringAsFixed(2)} บาท',
              ),
              const SizedBox(height: 6),
              const Text(
                'ข้อมูลรถ: 1. อ่านจากการเบิกล่าสุด  2. อ่านจากข้อมูลพนักงาน',
              ),
            ]),
          ),
          gap(),
          IgnorePointer(
            ignoring: readOnly,
            child: block(context, 'ข้อมูลการเบิกจ่าย', [
              fieldRow([
                input(context, 'toll', 'ค่าทางด่วน (บาท)', numeric: true),
                input(context, 'parking', 'ค่าที่จอดรถ (บาท)', numeric: true),
                input(
                  context,
                  'transport',
                  'ค่ายานพาหนะสาธารณะ (บาท)',
                  numeric: true,
                ),
              ]),
              gap(),
              fieldRow([
                InputDecorator(
                  decoration: ocrInput(context, 'ค่าที่พักต่อคืน (บาท)'),
                  child: Text(
                    effectiveLodging?.toStringAsFixed(2) ?? 'ไม่กำหนด',
                    style: t.inputStyle,
                  ),
                ),
                input(context, 'nights', 'จำนวนคืนที่พัก', numeric: true),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'รวมค่าที่พัก (บาท)',
                        style: t.tableStyle.copyWith(color: t.primaryColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ((effectiveLodging ?? 0) * amount('nights'))
                            .toStringAsFixed(2),
                        style: t.inputStyle.copyWith(
                          color: t.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ]),
          ),
          gap(),
          block(context, 'ไฟล์ประกอบ', [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 700;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!readOnly)
                      OutlinedButton.icon(
                        onPressed: saving ? null : chooseFiles,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('เลือกไฟล์รูปหรือ PDF'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'รองรับ JPG, PNG, WEBP และ PDF ไม่เกิน 2 MB ต่อไฟล์ รวมไม่เกิน 20 MB',
                    ),
                  ],
                );
                final right = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pendingFiles.isEmpty && attachments.isEmpty)
                      const Text('ยังไม่มีไฟล์ประกอบ'),
                    for (final f in pendingFiles)
                      ListTile(
                        leading: isImageAttachment(f.name) && f.bytes != null
                            ? InkWell(
                                onTap: () =>
                                    showAttachmentImage(f.bytes!, f.name),
                                child: Image.memory(
                                  f.bytes!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        title: Text(f.name),
                        onTap: f.bytes == null
                            ? null
                            : () async {
                                if (isImageAttachment(f.name)) {
                                  showAttachmentImage(f.bytes!, f.name);
                                } else {
                                  try {
                                    await openTravelPdf(
                                      f.name,
                                      () async => f.bytes!,
                                    );
                                  } catch (_) {
                                    if (mounted)
                                      showTimedSnackBar(
                                        context,
                                        message:
                                            'เปิดไฟล์ไม่สำเร็จ กรุณาลองใหม่',
                                        error: true,
                                      );
                                  }
                                }
                              },
                        trailing: IconButton(
                          tooltip: 'ลบไฟล์ที่เลือก',
                          onPressed: saving || readOnly
                              ? null
                              : () => setState(() {
                                  pendingFiles.remove(f);
                                  attachmentPreviewRevision++;
                                  attachmentPreview = null;
                                  attachmentPreviewName = null;
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    for (final f in attachments)
                      ListTile(
                        leading: isImageAttachment('${f['name']}')
                            ? FutureBuilder<Uint8List>(
                                future: savedImage(f),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return const Icon(
                                      Icons.broken_image_outlined,
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return const SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return Image.memory(
                                    snapshot.data!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  );
                                },
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        title: Text('${f['name']}'),
                        onTap: () => isImageAttachment('${f['name']}')
                            ? previewSavedAttachment(f)
                            : download(f),
                        trailing: !readOnly && canEdit
                            ? IconButton(
                                onPressed: saving
                                    ? null
                                    : () => removeAttachment(f),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                tooltip: 'ลบไฟล์',
                              )
                            : null,
                      ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [left, const SizedBox(height: 16), right],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 24),
                    Expanded(child: right),
                  ],
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = businessCardOcrUi(context);
    Map<String, String> options(
      String idKey,
      String nameKey,
      Iterable<Map<String, dynamic>> source,
    ) {
      final result = <String, String>{};
      for (final row in source) {
        final id = row[idKey];
        final name = '${row[nameKey] ?? ''}'.trim();
        if (id != null && name.isNotEmpty) result['$id'] = name;
      }
      final entries = result.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      return Map.fromEntries(entries);
    }

    final divisions = options(
      'id',
      'name',
      organizations.where((r) => r['type'] == 'DIV'),
    );
    final departments = options(
      'id',
      'name',
      organizations.where(
        (r) =>
            r['type'] == 'DEP' &&
            (filterDivision == null || '${r['parentId']}' == filterDivision),
      ),
    );
    final claimants = options(
      'claimantId',
      'claimant',
      items.where(
        (r) =>
            (filterDivision == null ||
                '${r['divisionId']}' == filterDivision) &&
            (filterDepartment == null ||
                '${r['departmentId']}' == filterDepartment),
      ),
    );
    final dates =
        items
            .map((r) => '${r['date'] ?? ''}')
            .where((s) => DateTime.tryParse(s) != null)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final visible = items
        .where(
          (r) =>
              '${r['number']} ${r['origin']} ${r['destination']}'
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (filterDivision == null ||
                  '${r['divisionId']}' == filterDivision) &&
              (filterDepartment == null ||
                  '${r['departmentId']}' == filterDepartment) &&
              (filterClaimant == null ||
                  '${r['claimantId']}' == filterClaimant) &&
              (filterDate == null || '${r['date']}' == filterDate),
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
          : LayoutBuilder(
              builder: (context, constraints) {
                // Include room for the visible columns, ID and action buttons.
                final minimumTableWidth = 200.0 + cols.length * 150.0;
                final forcedCard =
                    constraints.maxWidth < 600 ||
                    constraints.maxWidth < minimumTableWidth;
                return LaooListWorkspace(
                  tokens: t,
                  caption: LaooSurfaceCard(
                    tokens: t,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final buttons = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!forcedCard)
                              LaooListCardToggle(
                                tokens: t,
                                cards: cards,
                                onChanged: (v) => setState(() => cards = v),
                              ),
                            if (canCreate && !forcedCard)
                              const SizedBox(width: 8),
                            if (canCreate)
                              FilledButton.icon(
                                onPressed: () => open(),
                                icon: const Icon(Icons.add),
                                label: const Text('เพิ่ม'),
                              ),
                          ],
                        );
                        final caption = WorkspacePageTitle(
                          title: title,
                          favoriteKey: '66001',
                        );
                        if (constraints.maxWidth < 420) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              caption,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: buttons,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: caption),
                            const SizedBox(width: 8),
                            buttons,
                          ],
                        );
                      },
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
                            filterDivision = filterDepartment = filterClaimant =
                                filterDate = null;
                            page = 1;
                          }),
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('ล้าง Filter'),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('division:$filterDivision'),
                            initialValue: filterDivision ?? '',
                            isExpanded: true,
                            decoration: ocrInput(context, 'ฝ่าย'),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('ทั้งหมด'),
                              ),
                              for (final e in divisions.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              filterDivision = v == null || v.isEmpty
                                  ? null
                                  : v;
                              filterDepartment = filterClaimant = null;
                              page = 1;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('department:$filterDepartment'),
                            initialValue: filterDepartment ?? '',
                            isExpanded: true,
                            decoration: ocrInput(context, 'แผนก'),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('ทั้งหมด'),
                              ),
                              for (final e in departments.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              filterDepartment = v == null || v.isEmpty
                                  ? null
                                  : v;
                              filterClaimant = null;
                              page = 1;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('claimant:$filterClaimant'),
                            initialValue: filterClaimant ?? '',
                            isExpanded: true,
                            decoration: ocrInput(context, 'ชื่อผู้ทำรายการ'),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('ทั้งหมด'),
                              ),
                              for (final e in claimants.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              filterClaimant = v == null || v.isEmpty
                                  ? null
                                  : v;
                              page = 1;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('date:$filterDate'),
                            initialValue: filterDate ?? '',
                            isExpanded: true,
                            decoration: ocrInput(context, 'วันที่บันทึก'),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('ทั้งหมด'),
                              ),
                              for (final d in dates)
                                DropdownMenuItem(
                                  value: d,
                                  child: Text(displayDate(DateTime.parse(d))),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              filterDate = v == null || v.isEmpty ? null : v;
                              page = 1;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  table: loading
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                      ? const Center(child: Text('ไม่พบข้อมูล'))
                      : (forcedCard || cards)
                      ? ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = rows[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final c in cols)
                                      Text(
                                        '${c.label}: ${displayField(r, c.key)}',
                                      ),
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
                                        dividerThickness: .6,
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
                                            const DataColumn(
                                              label: Text('Action'),
                                            ),
                                          for (final c in cols)
                                            DataColumn(label: Text(c.label)),
                                          if (preferences.actionOnRight)
                                            const DataColumn(
                                              label: Text('Action'),
                                            ),
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
                                                      displayField(
                                                        rows[i],
                                                        c.key,
                                                      ),
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
                );
              },
            ),
    );
  }
}
