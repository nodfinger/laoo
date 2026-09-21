import 'package:flutter/material.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';
import 'visitor_settings_repository.dart';

class VisitorSystemSettingsPage extends StatefulWidget {
  const VisitorSystemSettingsPage({super.key});

  @override
  State<VisitorSystemSettingsPage> createState() => _VisitorSystemSettingsPageState();
}

class _VisitorSystemSettingsPageState extends State<VisitorSystemSettingsPage> {
  final _reason = TextEditingController();
  late final VisitorApiClient _api;
  late final VisitorSettingsRepository _repository;
  VisitorSettingsActions? _actions;
  VisitorSettings? _settings;
  VisitorCompanyContext? _companyContext;
  DateTime _effectiveFrom = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _messageError = false;

  bool _manual = true;
  bool _camera = true;
  bool _phone = false;
  bool _host = true;
  bool _purpose = true;
  bool _image = true;
  bool _idNumber = false;
  bool _idExpiry = false;
  bool _checkOut = true;
  String _retention = 'COMPANY_POLICY';

  @override
  void initState() {
    super.initState();
    _api = VisitorApiClient();
    _repository = VisitorSettingsRepository(_api);
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final actions = await _repository.actions();
      if (!actions.canView) throw const VisitorApiException(403, 'ไม่มีสิทธิ์ดูหน้ากำหนดค่าระบบ Visitor');
      final settings = await _repository.get();
      final companyContext = await _repository.context();
      if (!mounted) return;
      setState(() {
        _actions = actions;
        _settings = settings;
        _companyContext = companyContext;
        _effectiveFrom = settings.effectiveFrom;
        _manual = settings.allowManualEntry;
        _camera = settings.allowCameraCapture;
        _phone = settings.requireVisitorPhone;
        _host = settings.requireHostEmployee;
        _purpose = settings.requireVisitPurpose;
        _image = settings.requireCardImage;
        _idNumber = settings.requireNationalIdNumber;
        _idExpiry = settings.requireNationalIdExpiry;
        _checkOut = settings.requireCheckOut;
        _retention = settings.retentionPolicyCode;
        _message = null;
      });
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final settings = _settings;
    final actions = _actions;
    if (settings == null || actions?.canEdit != true || _saving) return;
    if (!_manual && !_camera) {
      _show('ต้องเปิดวิธีบันทึกอย่างน้อย 1 วิธี', error: true);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      _show('กรุณาระบุเหตุผลในการแก้ไข', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final next = VisitorSettings(
        versionId: settings.versionId,
        versionNo: settings.versionNo,
        effectiveFrom: _effectiveFrom,
        allowManualEntry: _manual,
        allowCameraCapture: _camera,
        allowNationalIdReader: false,
        requireVisitorPhone: _phone,
        requireHostEmployee: _host,
        requireVisitPurpose: _purpose,
        requireCardImage: _image,
        requireNationalIdNumber: _idNumber,
        requireNationalIdExpiry: _idExpiry,
        requireCheckOut: _checkOut,
        retentionPolicyCode: _retention,
        stateToken: settings.stateToken,
      );
      await _repository.update(VisitorSettingsUpdate(
        effectiveFrom: _effectiveFrom,
        source: next,
        reason: _reason.text,
      ));
      await _load();
      if (mounted) _show('บันทึกกำหนดค่าระบบ Visitor สำเร็จ', error: false);
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked != null && mounted) setState(() => _effectiveFrom = picked);
  }

  void _show(String value, {required bool error}) => setState(() {
        _message = value;
        _messageError = error;
      });

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
        pageTitle: _actions?.caption ?? 'กำหนดค่าระบบ Visitor',
        activeMenu: '36004',
        child: Stack(
          children: [
            Positioned.fill(child: _content(context)),
            if (_message != null)
              Positioned(
                top: 12,
                right: 12,
                child: _messageCard(context),
              ),
          ],
        ),
      );

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final settings = _settings;
    if (settings == null) {
      return Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('ลองใหม่')));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _captionCard(context),
        const SizedBox(height: 6),
        if (_companyContext != null) _companyTypeCard(context, _companyContext!),
        if (_companyContext != null) const SizedBox(height: 6),
        _section(
          context,
          title: 'วิธีบันทึกผู้มาติดต่อ',
          description: 'กำหนดวิธีที่หน้ารับผู้มาติดต่ออนุญาตให้ใช้งาน',
          children: [
            _switch('คีย์อิสระ', 'ให้ผู้ปฏิบัติงานกรอกข้อมูลเอง', _manual, (v) => setState(() => _manual = v)),
            _switch('ถ่ายบัตรจากกล้อง', 'ถ่ายภาพบัตรแล้วให้ยืนยันข้อมูลด้วยผู้ใช้', _camera, (v) => setState(() => _camera = v)),
            _switch('อ่านบัตรด้วยเครื่องอ่าน', 'เตรียมไว้สำหรับอนาคต ยังไม่เปิดใช้งาน', false, null),
          ],
        ),
        const SizedBox(height: 6),
        _section(
          context,
          title: 'ข้อมูลที่ต้องกรอก',
          description: 'ใช้กับรายการใหม่เท่านั้น รายการเดิมมี Snapshot ของค่าขณะบันทึก',
          children: [
            _switch('เบอร์โทรศัพท์', 'บังคับระบุช่องทางติดต่อ', _phone, (v) => setState(() => _phone = v)),
            _switch('ผู้รับรอง', 'บังคับเลือกพนักงานผู้รับรอง', _host, (v) => setState(() => _host = v)),
            _switch('วัตถุประสงค์', 'บังคับระบุวัตถุประสงค์การเข้าพบ', _purpose, (v) => setState(() => _purpose = v)),
            _switch('เลขบัตรประชาชน', 'บังคับกรอกเลขบัตรเมื่อใช้กล้อง', _idNumber, (v) => setState(() => _idNumber = v)),
            _switch('วันหมดอายุบัตร', 'บังคับกรอกวันหมดอายุเมื่อใช้กล้อง', _idExpiry, (v) => setState(() => _idExpiry = v)),
          ],
        ),
        const SizedBox(height: 6),
        _section(
          context,
          title: 'กติกา Check-in และ Check-out',
          description: 'ควบคุมหลักฐานและสถานะผู้มาติดต่อภายใน',
          children: [
            _switch('ต้องมีภาพบัตร', 'ถ่ายอย่างน้อย 1 ด้านก่อน Check-in สำเร็จ', _image, (v) => setState(() => _image = v)),
            _switch('ต้องบันทึกออก', 'ใช้ติดตามผู้มาติดต่อที่ยังอยู่ภายใน', _checkOut, (v) => setState(() => _checkOut = v)),
          ],
        ),
        const SizedBox(height: 6),
        _section(
          context,
          title: 'การเก็บหลักฐานและ Audit',
          description: 'ภาพบัตรเก็บเป็นไฟล์ตามนโยบายบริษัท และบันทึกการแก้ไขทุกครั้ง',
          children: [
            DropdownButtonFormField<String>(
              value: _retention,
              decoration: const InputDecoration(labelText: 'นโยบายเก็บภาพ'),
              items: const [
                DropdownMenuItem(value: 'COMPANY_POLICY', child: Text('ตามนโยบายบริษัท')),
                DropdownMenuItem(value: '90_DAYS', child: Text('90 วัน')),
              ],
              onChanged: _actions?.canEdit == true ? (value) => setState(() => _retention = value ?? _retention) : null,
            ),
            InkWell(
              onTap: _actions?.canEdit == true ? _pickDate : null,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'วันที่เริ่มใช้', suffixIcon: Icon(Icons.calendar_month_outlined)),
                child: Text('${_effectiveFrom.day.toString().padLeft(2, '0')}/${_effectiveFrom.month.toString().padLeft(2, '0')}/${_effectiveFrom.year}'),
              ),
            ),
            TextField(
              controller: _reason,
              enabled: _actions?.canEdit == true,
              maxLines: 1,
              decoration: const InputDecoration(labelText: 'เหตุผลในการแก้ไข *'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _actions?.canEdit == true && !_saving ? _save : null,
            icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
        ),
      ],
    );
  }

  Widget _captionCard(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(Icons.star_border_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(_actions?.caption ?? 'กำหนดค่าระบบ Visitor', style: Theme.of(context).textTheme.titleLarge)),
          ]),
        ),
      );

  Widget _companyTypeCard(BuildContext context, VisitorCompanyContext value) => Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.business_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.isDormitory
                      ? 'ประเภทธุรกิจ: หอพัก — ติดต่อได้ทั้งผู้พักอาศัยและพนักงาน'
                      : 'ประเภทธุรกิจ: บริษัททั่วไป — ติดต่อพนักงานภายใน',
                ),
              ),
            ],
          ),
        ),
      );

  Widget _section(BuildContext context, {required String title, required String description, required List<Widget> children}) => Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: children.map((child) => SizedBox(width: constraints.maxWidth < 650 ? constraints.maxWidth : 340, child: child)).toList(),
            )),
          ]),
        ),
      );

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );

  Widget _messageCard(BuildContext context) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        color: _messageError ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Text(_message ?? '')),
              IconButton(onPressed: () => setState(() => _message = null), icon: const Icon(Icons.close)),
            ]),
          ),
        ),
      );
}
