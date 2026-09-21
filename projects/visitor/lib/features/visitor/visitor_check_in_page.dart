import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';
import 'visitor_settings_repository.dart';

class VisitorCheckInPage extends StatefulWidget {
  const VisitorCheckInPage({super.key});

  @override
  State<VisitorCheckInPage> createState() => _VisitorCheckInPageState();
}

class _VisitorCheckInPageState extends State<VisitorCheckInPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  final _host = TextEditingController();
  final _purpose = TextEditingController();
  final _picker = ImagePicker();
  late final VisitorApiClient _api;
  VisitorSettings? _settings;
  VisitorCompanyContext? _companyContext;
  VisitorCheckInContext? _checkInContext;
  List<VisitorRoomOption> _roomOptions = const [];
  List<VisitorHostOption> _hostOptions = const [];
  List<Map<String, dynamic>> _rentalTenants = const [];
  List<Map<String, dynamic>> _rentalContacts = const [];
  List<Map<String, dynamic>> _villageLanes = const [];
  List<Map<String, dynamic>> _villageHouses = const [];
  List<Map<String, dynamic>> _villageResidents = const [];
  String _hostType = 'SERVICE_CUSTOMER';
  int? _roomId;
  int? _tenantId;
  int? _tenantContactId;
  int? _laneId;
  int? _houseId;
  DateTime? _expiry;
  XFile? _cardImage;
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _api = VisitorApiClient();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _nationalId, _host, _purpose]) {
      controller.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repository = VisitorSettingsRepository(_api);
      final settings = await repository.get();
      final companyContext = await repository.context();
      final checkInContext = await repository.checkInContext();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _companyContext = companyContext;
        _checkInContext = checkInContext;
        _hostType = companyContext.defaultHostType;
      });
      if (companyContext.isDormitory) {
        await _loadRooms();
      } else if (companyContext.businessTypeCode == 'RENTAL_OFFICE') {
        await _loadRental();
      } else if (companyContext.businessTypeCode == 'VILLAGE') {
        await _loadVillageLanes();
      } else {
        await _loadHostOptions();
      }
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRooms([String search = '']) async {
    try {
      final items = await VisitorSettingsRepository(
        _api,
      ).guarantorRooms(search: search);
      if (mounted) setState(() => _roomOptions = items);
    } catch (_) {
      if (mounted) setState(() => _roomOptions = const []);
    }
  }

  Future<void> _loadHostOptions([String search = '']) async {
    if (_companyContext?.isDormitory == true && _roomId == null) {
      if (mounted) setState(() => _hostOptions = const []);
      return;
    }
    try {
      final items = await VisitorSettingsRepository(
        _api,
      ).hostOptions(_hostType, search: search, roomId: _roomId);
      if (mounted) setState(() => _hostOptions = items);
    } catch (_) {
      if (mounted) setState(() => _hostOptions = const []);
    }
  }

  Future<void> _loadRental() async {
    final data = await VisitorSettingsRepository(_api).rentalHosts();
    if (mounted) setState(() { _rentalTenants = data.tenants; _rentalContacts = data.contacts; });
  }

  Future<void> _loadVillageLanes() async {
    final rows = await VisitorSettingsRepository(_api).businessLocationRows('/api/company/business-locations/village/lanes');
    if (mounted) setState(() => _villageLanes = rows);
  }

  Future<void> _loadVillageHouses(int laneId) async {
    final rows = await VisitorSettingsRepository(_api).businessLocationRows('/api/company/business-locations/village/houses', query: {'laneId': '$laneId'});
    if (mounted) setState(() => _villageHouses = rows);
  }

  Future<void> _loadVillageResidents(int houseId) async {
    final rows = await VisitorSettingsRepository(_api).businessLocationRows('/api/company/business-locations/village/residents', query: {'houseId': '$houseId'});
    if (mounted) setState(() => _villageResidents = rows);
  }

  Future<void> _capture() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image != null && mounted) setState(() => _cardImage = image);
  }

  Future<void> _pickExpiry() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 30, 12, 31),
    );
    if (value != null && mounted) setState(() => _expiry = value);
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null || _saving) return;
    final captureMethod = _cardImage == null
        ? 'MANUAL_ENTRY'
        : 'CAMERA_CAPTURE';
    if (_checkInContext == null || _name.text.trim().isEmpty) {
      _show('กรุณาระบุสาขาและชื่อผู้มาติดต่อ', error: true);
      return;
    }
    if (settings.requireVisitorPhone && _phone.text.trim().isEmpty ||
        _host.text.trim().isEmpty ||
        settings.requireVisitPurpose && _purpose.text.trim().isEmpty) {
      _show(
        'กรุณากรอกข้อมูลที่กำหนดเป็นข้อมูลบังคับในระบบ Visitor',
        error: true,
      );
      return;
    }
    if (settings.requireNationalIdNumber && _nationalId.text.trim().isEmpty ||
        settings.requireNationalIdExpiry && _expiry == null) {
      _show('กรุณากรอกข้อมูลบัตรประชาชนตามค่ากลางของระบบ', error: true);
      return;
    }
    if (captureMethod == 'MANUAL_ENTRY' && !settings.allowManualEntry) {
      _show('กรุณาแนบภาพบัตร เนื่องจากปิดการคีย์อิสระไว้', error: true);
      return;
    }
    if (captureMethod == 'CAMERA_CAPTURE' && !settings.allowCameraCapture) {
      _show('การถ่ายบัตรจากกล้องถูกปิดจากกำหนดค่าระบบ Visitor', error: true);
      return;
    }
    if (_companyContext?.isDormitory == true && _roomId == null) {
      _show('กรุณาเลือกห้องพักก่อนเลือกผู้รับรอง', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final response = Map<String, dynamic>.from(
        await _api.post(
              '/api/visitor/check-ins',
              body: {
                'visitorName': _name.text.trim(),
                'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                'nationalIdNumber': _nationalId.text.trim().isEmpty
                    ? null
                    : _nationalId.text.trim(),
                'nationalIdExpiryDate': _expiry == null
                    ? null
                    : _dateOnly(_expiry!),
                'hostType': _hostType,
                'hostEmployeeId': null,
                'hostResidentId':
                    (_hostType == 'RESIDENT' || _hostType == 'VILLAGE') && _host.text.trim().isNotEmpty
                    ? int.tryParse(_host.text.trim())
                    : null,
                'hostServiceCustomerId':
                    _hostType == 'SERVICE_CUSTOMER' &&
                        _host.text.trim().isNotEmpty
                    ? int.tryParse(_host.text.trim())
                    : null,
                'hostRoomId': _hostType == 'RESIDENT' ? _roomId : null,
                'hostTenantId': _hostType == 'RENTAL_OFFICE'
                    ? _tenantId
                    : null,
                'hostTenantContactId': _hostType == 'RENTAL_OFFICE'
                    ? _tenantContactId
                    : null,
                'visitPurpose': _purpose.text.trim().isEmpty
                    ? null
                    : _purpose.text.trim(),
                'captureMethod': captureMethod,
                'requestId': 'VIS-${DateTime.now().microsecondsSinceEpoch}',
              },
            )
            as Map,
      );
      final visitId = (response['visitorVisitId'] as num).toInt();
      if (captureMethod == 'CAMERA_CAPTURE' && _cardImage != null) {
        await _api.upload(
          '/api/visitor/check-ins/$visitId/images',
          bytes: await _cardImage!.readAsBytes(),
          fileName: _cardImage!.name,
          fields: {'side': 'FRONT'},
        );
      }
      if (mounted) {
        _show('บันทึกผู้มาติดต่อเข้าเรียบร้อย', error: false);
        _clearForm();
      }
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    _name.clear();
    _phone.clear();
    _nationalId.clear();
    _host.clear();
    _purpose.clear();
    setState(() {
      _expiry = null;
      _cardImage = null;
      _roomId = null;
      _hostOptions = const [];
    });
  }

  void _show(String value, {required bool error}) => setState(() {
    _message = value;
    _error = error;
  });

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: 'รับผู้มาติดต่อ',
    activeMenu: '31002',
    child: Stack(
      children: [
        Positioned.fill(child: _content(context)),
        if (_message != null)
          Positioned(top: 12, right: 12, child: _messageCard(context)),
      ],
    ),
  );

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final settings = _settings;
    if (settings == null)
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่'),
        ),
      );
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _card(
          context,
          'ข้อมูลผู้มาติดต่อ',
          Column(
            children: [
              _contactPointField(context),
              _field(_name, 'ชื่อผู้มาติดต่อ *'),
              _field(
                _phone,
                settings.requireVisitorPhone
                    ? 'เบอร์โทรศัพท์ *'
                    : 'เบอร์โทรศัพท์',
                keyboard: TextInputType.phone,
              ),
              if (_companyContext != null) _hostSelector(context, settings),
              _field(
                _nationalId,
                settings.requireNationalIdNumber
                    ? 'เลขบัตรประชาชน *'
                    : 'เลขบัตรประชาชน',
                keyboard: TextInputType.number,
              ),
              InkWell(
                onTap: _pickExpiry,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: settings.requireNationalIdExpiry
                        ? 'วันหมดอายุบัตร *'
                        : 'วันหมดอายุบัตร',
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _expiry == null ? 'เลือกวันที่' : _dateOnly(_expiry!),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _card(
          context,
          'ผู้รับรองและวัตถุประสงค์',
          Column(
            children: [
              _field(
                _host,
                settings.requireHostEmployee
                    ? 'รหัสพนักงานผู้รับรอง *'
                    : 'รหัสพนักงานผู้รับรอง',
                keyboard: TextInputType.number,
              ),
              _field(
                _purpose,
                settings.requireVisitPurpose
                    ? 'วัตถุประสงค์ *'
                    : 'วัตถุประสงค์',
              ),
            ],
          ),
        ),
        if (settings.allowCameraCapture) ...[
          const SizedBox(height: 6),
          _card(
            context,
            'หลักฐานภาพบัตร',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _capture,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _cardImage == null ? 'ถ่ายภาพบัตร' : 'ถ่ายภาพใหม่',
                  ),
                ),
                if (_cardImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('เลือกภาพแล้ว: ${_cardImage!.name}'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: !_saving ? _save : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('บันทึก Check-in'),
          ),
        ),
      ],
    );
  }

  Widget _hostSelector(
    BuildContext context,
    VisitorSettings settings,
  ) {
    if (_companyContext!.businessTypeCode == 'RENTAL_OFFICE') {
      final contacts = _rentalContacts.where((x) => (x['tenantId'] as num?)?.toInt() == _tenantId).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _mapSelect('บริษัทผู้เช่า', _tenantId, _rentalTenants, (x) => '${x['tenantCompanyName']} — ${x['roomCode']}', (v) => setState(() { _tenantId = v; _tenantContactId = null; })),
        const SizedBox(height: 12),
        _mapSelect('ผู้ติดต่อ', _tenantContactId, contacts, (x) => '${x['contactName']} — ${x['phone'] ?? ''}', (v) => setState(() { _tenantContactId = v; _host.text = v?.toString() ?? ''; })),
      ]);
    }
    if (_companyContext!.businessTypeCode == 'VILLAGE') {
      final houses = _villageHouses.where((x) => (x['laneId'] as num?)?.toInt() == _laneId).toList();
      final residents = _villageResidents.where((x) => (x['houseId'] as num?)?.toInt() == _houseId).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _mapSelect('ซอย/แยก', _laneId, _villageLanes, (x) => '${x['code']} — ${x['name']}', (v) { setState(() { _laneId = v; _houseId = null; _host.clear(); _villageHouses = const []; _villageResidents = const []; }); if (v != null) _loadVillageHouses(v); }),
        const SizedBox(height: 12),
        _mapSelect('บ้านเลขที่', _houseId, houses, (x) => '${x['houseNo']}', (v) { setState(() { _houseId = v; _host.clear(); _villageResidents = const []; }); if (v != null) _loadVillageResidents(v); }),
        const SizedBox(height: 12),
        _mapSelect('ผู้อาศัย', int.tryParse(_host.text), residents, (x) => '${x['personName']}', (v) => setState(() => _host.text = v?.toString() ?? '')),
      ]);
    }
    return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_companyContext!.isDormitory) ...[
        TextField(
          decoration: const InputDecoration(
            labelText: 'ค้นหาห้องพัก',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          onChanged: _loadRooms,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _roomOptions.any((option) => option.id == _roomId)
              ? _roomId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'ห้องพัก *'),
          items: _roomOptions
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option.id,
                  child: Text(
                    '${option.code} — ${option.building} / ${option.floor}',
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            setState(() {
              _roomId = value;
              _host.clear();
              _hostOptions = const [];
            });
            _loadHostOptions();
          },
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        enabled: !_companyContext!.isDormitory || _roomId != null,
        decoration: InputDecoration(
          labelText: _hostType == 'RESIDENT'
              ? 'ค้นหาชื่อหรือเบอร์โทรผู้พักอาศัย'
              : 'ค้นหาชื่อหรือเบอร์โทรผู้ใช้บริการ',
          hintText: _companyContext!.isDormitory && _roomId == null
              ? 'เลือกห้องพักก่อนค้นหา'
              : null,
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: _loadHostOptions,
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value:
            _hostOptions.any((option) => option.id == int.tryParse(_host.text))
            ? int.tryParse(_host.text)
            : null,
        decoration: InputDecoration(
          labelText: settings.requireHostEmployee ? 'ผู้รับรอง *' : 'ผู้รับรอง',
        ),
        items: _hostOptions
            .map(
              (option) => DropdownMenuItem<int>(
                value: option.id,
                child: Text(
                  option.phone == null
                      ? option.name
                      : '${option.name} — ${option.phone}',
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (value) =>
            setState(() => _host.text = value?.toString() ?? ''),
      ),
      if (_selectedHost != null) ...[
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _hostType == 'RESIDENT'
                  ? 'ผู้รับรอง: ${_selectedHost!.name}\nอาคาร: ${_selectedHost!.building}  ชั้น: ${_selectedHost!.floor}  ห้อง: ${_selectedHost!.room}'
                  : 'ผู้รับรอง: ${_selectedHost!.name}${_selectedHost!.phone == null ? '' : '\nเบอร์โทร: ${_selectedHost!.phone}'}',
            ),
          ),
        ),
      ],
    ],
    );
  }

  Widget _mapSelect(String label, int? value, List<Map<String, dynamic>> rows,
      String Function(Map<String, dynamic>) text, ValueChanged<int?> changed) =>
      DropdownButtonFormField<int>(
        value: rows.any((x) => (x['id'] as num?)?.toInt() == value || (x['tenantId'] as num?)?.toInt() == value || (x['contactId'] as num?)?.toInt() == value) ? value : null,
        decoration: InputDecoration(labelText: '$label *'), isExpanded: true,
        items: rows.map((x) { final id = ((x['id'] ?? x['contactId'] ?? x['tenantId']) as num).toInt(); return DropdownMenuItem(value: id, child: Text(text(x))); }).toList(), onChanged: changed);

  VisitorHostOption? get _selectedHost {
    final id = int.tryParse(_host.text);
    if (id == null) return null;
    for (final option in _hostOptions) {
      if (option.id == id) return option;
    }
    return null;
  }

  Widget _contactPointField(BuildContext context) {
    final point = _checkInContext;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'ประจำจุด',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
        child: Text(
          point == null
              ? 'ยังไม่ได้กำหนดจุดติดต่อ'
              : '${point.contactPointCode} — ${point.contactPointName}',
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) {
    if (identical(controller, _host)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _card(BuildContext context, String title, Widget child) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  Widget _messageCard(BuildContext context) => Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(4),
    color: _error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.primaryContainer,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(_message ?? '')),
            IconButton(
              onPressed: () => setState(() => _message = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
