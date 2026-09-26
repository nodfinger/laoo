import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';
import 'visitor_inside_repository.dart';
import 'visitor_visit_detail_dialog.dart';

class VisitorInsidePage extends StatefulWidget {
  const VisitorInsidePage({super.key});

  @override
  State<VisitorInsidePage> createState() => _VisitorInsidePageState();
}

class _CheckoutDecision {
  const _CheckoutDecision({
    required this.outcome,
    required this.reason,
    required this.note,
    required this.vehicleImages,
    required this.otherImages,
  });

  final String outcome;
  final String reason;
  final String note;
  final List<Uint8List> vehicleImages;
  final List<Uint8List> otherImages;
}

class _CheckoutForm extends StatefulWidget {
  const _CheckoutForm({
    required this.visitorName,
    required this.onCancel,
    required this.onSubmit,
  });

  final String visitorName;
  final VoidCallback onCancel;
  final ValueChanged<_CheckoutDecision> onSubmit;

  @override
  State<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<_CheckoutForm> {
  final _note = TextEditingController();
  final _picker = ImagePicker();
  final _vehicleImages = <Uint8List>[];
  final _otherImages = <Uint8List>[];
  String _outcome = 'MET';
  String _reason = 'NORMAL';
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_reason == 'OTHER' && _note.text.trim().isEmpty) {
      setState(() => _error = 'กรุณาระบุหมายเหตุเมื่อเลือกประเภทอื่น ๆ');
      return;
    }
    widget.onSubmit(
      _CheckoutDecision(
        outcome: _outcome,
        reason: _reason,
        note: _note.text.trim(),
        vehicleImages: List.unmodifiable(_vehicleImages),
        otherImages: List.unmodifiable(_otherImages),
      ),
    );
  }

  Future<Uint8List?> _prepare(XFile file) async {
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return null;
    var quality = 85;
    var width = decoded.width > 1600 ? 1600 : decoded.width;
    Uint8List output = Uint8List.fromList(
      img.encodeJpg(decoded, quality: quality),
    );
    while (output.length > 1_000_000 && width >= 640) {
      final resized = img.copyResize(decoded, width: width);
      output = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (output.length <= 1_000_000) break;
      if (quality > 35) {
        quality -= 10;
      } else {
        width = (width * .8).round();
        quality = 85;
      }
    }
    return output.length <= 1_000_000 ? output : null;
  }

  Future<void> _pickImages(List<Uint8List> target) async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    final images = <Uint8List>[];
    for (final file in files) {
      final bytes = await _prepare(file);
      if (bytes == null) {
        setState(() => _error = 'มีรูปที่ลดขนาดให้ไม่เกิน 1 MB ไม่สำเร็จ');
        return;
      }
      images.add(bytes);
    }
    setState(() {
      target.addAll(images);
      _error = null;
    });
  }

  Future<void> _takeImage(List<Uint8List> target) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await _prepare(file);
    if (bytes == null) {
      setState(() => _error = 'ลดขนาดรูปให้ไม่เกิน 1 MB ไม่สำเร็จ');
      return;
    }
    setState(() {
      target.add(bytes);
      _error = null;
    });
  }

  Widget _evidenceSection(String title, List<Uint8List> images) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickImages(images),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('เลือกรูป'),
          ),
          OutlinedButton.icon(
            onPressed: () => _takeImage(images),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('ถ่ายรูป'),
          ),
        ],
      ),
      if (images.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            images.length,
            (index) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    images[index],
                    width: 96,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton.filledTonal(
                    tooltip: 'ลบรูปก่อนบันทึก',
                    onPressed: () => setState(() => images.removeAt(index)),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ผลการเข้าพบและ Check-out'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ผู้มาติดต่อ: ${widget.visitorName}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_outcome),
            initialValue: _outcome,
            decoration: const InputDecoration(labelText: 'ผลการเข้าพบ'),
            items: const [
              DropdownMenuItem(value: 'MET', child: Text('เข้าพบสำเร็จ')),
              DropdownMenuItem(value: 'NOT_MET', child: Text('ไม่ได้เข้าพบ')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
            ],
            onChanged: (value) => setState(() => _outcome = value ?? 'MET'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_reason),
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'ประเภท Check-out'),
            items: const [
              DropdownMenuItem(value: 'NORMAL', child: Text('ออกตามปกติ')),
              DropdownMenuItem(
                value: 'HOST_ABSENT',
                child: Text('ไม่พบผู้รับรอง'),
              ),
              DropdownMenuItem(
                value: 'VISITOR_LEFT',
                child: Text('ผู้มาติดต่อออกก่อน'),
              ),
              DropdownMenuItem(
                value: 'FORGOT_MEETING_CONFIRMATION',
                child: Text('ลืมยืนยันการเข้าพบ'),
              ),
              DropdownMenuItem(value: 'OTHER', child: Text('อื่น ๆ')),
            ],
            onChanged: (value) => setState(() => _reason = value ?? 'NORMAL'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _reason == 'OTHER' ? 'หมายเหตุ *' : 'หมายเหตุ',
              hintText: 'บันทึกข้อความขาออกหรือข้อความของ รปภ',
            ),
          ),
          const SizedBox(height: 16),
          _evidenceSection('รูปรถขาออก', _vehicleImages),
          const SizedBox(height: 16),
          _evidenceSection('รูปอื่นขาออก', _otherImages),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: widget.onCancel, child: const Text('ยกเลิก')),
      FilledButton(onPressed: _submit, child: const Text('ยืนยัน Check-out')),
    ],
  );
}

class _VisitorInsidePageState extends State<VisitorInsidePage> {
  final _search = TextEditingController();
  late final VisitorApiClient _api;
  late final VisitorInsideRepository _repository;
  VisitorInsideActions? _actions;
  VisitorInsideList? _result;
  bool _loading = true;
  bool _working = false;
  String? _error;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _api = VisitorApiClient();
    _repository = VisitorInsideRepository(_api);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) {
      _page = 1;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = await _repository.actions();
      if (!actions.canView) {
        throw const VisitorApiException(403, 'ไม่มีสิทธิ์ดูผู้มาติดต่อภายใน');
      }
      final result = await _repository.list(
        search: _search.text.trim(),
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _actions = actions;
          _result = result;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkOutAdvanced(VisitorInside row) async {
    final value = await showDialog<_CheckoutDecision>(
      context: context,
      builder: (dialogContext) => _CheckoutForm(
        visitorName: row.name,
        onCancel: () => Navigator.pop(dialogContext),
        onSubmit: (result) => Navigator.pop(dialogContext, result),
      ),
    );
    if (value == null || !mounted || _working) return;
    setState(() => _working = true);
    try {
      for (final bytes in value.vehicleImages) {
        await _repository.uploadEvidence(
          row.id,
          bytes: bytes,
          fileName: 'checkout-vehicle.jpg',
          evidenceType: 'VEHICLE',
          captureStage: 'CHECKOUT',
        );
      }
      for (final bytes in value.otherImages) {
        await _repository.uploadEvidence(
          row.id,
          bytes: bytes,
          fileName: 'checkout-other.jpg',
          evidenceType: 'OTHER',
          captureStage: 'CHECKOUT',
        );
      }
      await _repository.checkOut(
        row.id,
        outcomeCode: value.outcome,
        reasonCode: value.reason,
        note: value.note,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: _actions?.caption ?? 'ผู้มาติดต่อภายใน',
    activeMenu: '31002',
    child: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _card(
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final title = Row(
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_outlined),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _actions?.caption ?? 'ผู้มาติดต่อภายใน',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_actions?.canCreate == true)
                    FilledButton.icon(
                      onPressed: () =>
                          context.go('/visitor/check-in?action=new'),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('รับผู้มาติดต่อ'),
                    ),
                  IconButton(
                    tooltip: 'รีเฟรช',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 8), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _card(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(resetPage: true),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'ค้นหาชื่อ / เบอร์โทร / เลขบัตร',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: 'CHECKED_IN',
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: const [
                    DropdownMenuItem(
                      value: 'CHECKED_IN',
                      child: Text('อยู่ภายใน'),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : () => _load(resetPage: true),
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        _search.clear();
                        _load(resetPage: true);
                      },
                child: const Text('ล้าง Filter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_error != null)
          _card(Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_error != null) const SizedBox(height: 6),
        _card(
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _table(),
        ),
        const SizedBox(height: 6),
        _pagination(),
      ],
    ),
  );

  Widget _table() {
    final rows = _result?.items ?? const <VisitorInside>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Column(
          children: [
            if (!compact) _headerRow(),
            ...rows.map((row) => compact ? _compactRow(row) : _dataRow(row)),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('ไม่พบผู้มาติดต่อที่อยู่ภายใน'),
              ),
          ],
        );
      },
    );
  }

  Widget _headerRow() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'ผู้มาติดต่อ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'ผู้รับรอง',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            'จุดติดต่อ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            'เวลาเข้า',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 110,
          child: Text(
            'การทำงาน',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _dataRow(VisitorInside row) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFD9DDE3))),
    ),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(flex: 2, child: Text('${row.name}\n#${row.id}')),
        Expanded(flex: 2, child: Text(row.host)),
        Expanded(child: Text(row.point)),
        Expanded(child: Text(_displayDate(row.timeIn))),
        _rowActions(row, compact: true),
      ],
    ),
  );

  Widget _compactRow(VisitorInside row) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFD9DDE3))),
    ),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${row.name}  #${row.id}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _rowActions(row, compact: false),
          ],
        ),
        const SizedBox(height: 6),
        _labelValue('ผู้รับรอง', row.host),
        _labelValue('จุดติดต่อ', row.point),
        _labelValue('เวลาเข้า', _displayDate(row.timeIn)),
      ],
    ),
  );

  Widget _labelValue(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text('$label: $value'),
  );

  Widget _rowActions(VisitorInside row, {required bool compact}) => Wrap(
    spacing: compact ? 0 : 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        tooltip: 'ดูรายละเอียด',
        onPressed: _working
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) => VisitorVisitDetailDialog(
                  repository: _repository,
                  visitId: row.id,
                  visitorName: row.name,
                  canEdit: _actions?.canEdit == true,
                ),
              ),
        icon: const Icon(Icons.visibility_outlined, size: 18),
      ),
      if (_actions?.canEdit == true)
        compact
            ? SizedBox(
                width: 110,
                child: OutlinedButton.icon(
                  onPressed: _working ? null : () => _checkOutAdvanced(row),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('ออก'),
                ),
              )
            : OutlinedButton.icon(
                onPressed: _working ? null : () => _checkOutAdvanced(row),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Check-out'),
              ),
    ],
  );

  Widget _pagination() {
    final result = _result;
    final total = result?.total ?? 0;
    final pageCount = total == 0 ? 1 : (total / _pageSize).ceil();
    return _card(
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('แสดง ${result?.items.length ?? 0} รายการจากทั้งหมด $total'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _page > 1 && !_loading
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$_page / $pageCount'),
              IconButton(
                onPressed: _page < pageCount && !_loading
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _displayDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _card(Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
}
