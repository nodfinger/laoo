part of 'patrol_page.dart';

extension _PatrolForms on _PatrolPageState {
  List<Map<String, dynamic>> optionRows(
    Map<String, dynamic> options,
    String key,
  ) => _rows(options[key]);

  Future<void> showCreate(
    Map<String, dynamic> options, {
    Map<String, dynamic>? existing,
  }) async {
    final row = existing ?? <String, dynamic>{};
    final editing = existing != null;
    List<Map<String, dynamic>> priorPoints = [];
    if (row['pointsJson'] is String) {
      try {
        final decoded = jsonDecode(row['pointsJson'] as String);
        if (decoded is List) {
          priorPoints = decoded
              .map((point) => Map<String, dynamic>.from(point as Map))
              .toList();
        }
      } on FormatException {
        priorPoints = [];
      }
    }
    final code = TextEditingController(text: (row['code'] ?? '').toString()),
        name = TextEditingController(text: (row['name'] ?? '').toString()),
        extra = TextEditingController(),
        team = TextEditingController(text: (row['team'] ?? '').toString()),
        latitude = TextEditingController(
          text: (row['latitude'] ?? '').toString(),
        ),
        longitude = TextEditingController(
          text: (row['longitude'] ?? '').toString(),
        ),
        gpsRadius = TextEditingController(
          text: (row['gpsRadius'] ?? 100).toString(),
        );
    final now = DateTime.now();
    final start = TextEditingController(
      text: (DateTime.tryParse((row['startsAt'] ?? '').toString()) ?? now)
          .toIso8601String()
          .substring(0, 16),
    );
    final end = TextEditingController(
      text:
          (DateTime.tryParse((row['endsAt'] ?? '').toString()) ??
                  now.add(const Duration(hours: 8)))
              .toIso8601String()
              .substring(0, 16),
    );
    final windowStart = TextEditingController(
      text: priorPoints.isNotEmpty
          ? (priorPoints.first['windowStart'] ?? '08:00').toString()
          : '08:00',
    );
    final windowEnd = TextEditingController(
      text: priorPoints.isNotEmpty
          ? (priorPoints.first['windowEnd'] ?? '08:15').toString()
          : '08:15',
    );
    final branches = optionRows(options, 'branches'),
        employees = optionRows(options, 'employees'),
        buildings = optionRows(options, 'buildings'),
        floors = optionRows(options, 'floors'),
        rooms = optionRows(options, 'rooms'),
        checkpoints = optionRows(options, 'checkpoints'),
        checklists = optionRows(options, 'checklists'),
        devices = optionRows(options, 'devices'),
        routes = optionRows(options, 'routes');
    int? branch = row['branchId'] is num
        ? (row['branchId'] as num).toInt()
        : (branches.isEmpty ? null : (branches.first['id'] as num).toInt());
    int? building = row['buildingId'] is num
        ? (row['buildingId'] as num).toInt()
        : null;
    int? floor = row['floorId'] is num ? (row['floorId'] as num).toInt() : null;
    int? room = row['roomId'] is num ? (row['roomId'] as num).toInt() : null;
    int? employee = row['employeeId'] is num
        ? (row['employeeId'] as num).toInt()
        : (employees.isEmpty ? null : (employees.first['id'] as num).toInt());
    int? checkpointId = row['checkpointId'] is num
        ? (row['checkpointId'] as num).toInt()
        : null;
    int? deviceId = row['deviceId'] is num
        ? (row['deviceId'] as num).toInt()
        : null;
    int? routeId = row['routeId'] is num
        ? (row['routeId'] as num).toInt()
        : (routes.isEmpty ? null : (routes.first['id'] as num).toInt());
    int? checklistId =
        priorPoints.isNotEmpty &&
            priorPoints.first['checklistTemplateId'] is num
        ? (priorPoints.first['checklistTemplateId'] as num).toInt()
        : (checklists.isEmpty ? null : (checklists.first['id'] as num).toInt());
    String mode =
            (row['timeMode'] ??
                    (priorPoints.isEmpty
                        ? 'ANYTIME_IN_RUN'
                        : priorPoints.first['timeMode']) ??
                    'ANYTIME_IN_RUN')
                .toString(),
        work = (row['workType'] ?? 'SECURITY').toString(),
        adapter = (row['adapter'] ?? 'SIMULATOR').toString(),
        credential = (row['type'] ?? 'CARD').toString(),
        sequence = (row['sequenceMode'] ?? 'FLEXIBLE').toString();
    bool gps = row['requireGps'] == true,
        photo = row['requirePhoto'] == true,
        checklist = row['requireChecklist'] == true,
        active = row['isActive'] != false,
        saving = false;
    if (widget.menuCode == '56005')
      extra.text = (row['items'] ?? '').toString();
    if (widget.menuCode == '56006')
      extra.text = (row['checkpointIds'] ?? '').toString();
    if (widget.menuCode == '56007')
      extra.text = (row['routeId'] ?? '').toString();
    if (widget.menuCode == '56004') extra.text = '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final fields = <Widget>[
            if (widget.menuCode != '56004') ...[
              TextField(controller: code, decoration: input('รหัส *')),
              TextField(controller: name, decoration: input('ชื่อ *')),
            ],
            if ({'56002', '56005', '56006'}.contains(widget.menuCode))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('สถานะ'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
            if ((widget.menuCode == '56002' || widget.menuCode == '56006') &&
                branches.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: branch,
                decoration: input('สาขา *'),
                items: branches
                    .map(
                      (e) => DropdownMenuItem(
                        value: (e['id'] as num).toInt(),
                        child: Text(
                          (e['name'] ?? e['code']).toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() {
                  branch = v;
                  building = null;
                  floor = null;
                  room = null;
                }),
              ),
            if (widget.menuCode == '56002' &&
                buildings.any((e) => e['branchId'] == branch))
              DropdownButtonFormField<int?>(
                initialValue: building,
                decoration: input('อาคาร (ไม่บังคับ)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่ระบุอาคาร'),
                  ),
                  ...buildings
                      .where((e) => e['branchId'] == branch)
                      .map(
                        (e) => DropdownMenuItem<int?>(
                          value: (e['id'] as num).toInt(),
                          child: Text(
                            (e['name'] ?? e['code']).toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: (v) => setLocal(() {
                  building = v;
                  floor = null;
                  room = null;
                }),
              ),
            if (widget.menuCode == '56002' &&
                building != null &&
                floors.any((e) => e['buildingId'] == building))
              DropdownButtonFormField<int?>(
                initialValue: floor,
                decoration: input('ชั้น (ไม่บังคับ)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่ระบุชั้น'),
                  ),
                  ...floors
                      .where((e) => e['buildingId'] == building)
                      .map(
                        (e) => DropdownMenuItem<int?>(
                          value: (e['id'] as num).toInt(),
                          child: Text(
                            (e['name'] ?? e['code']).toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: (v) => setLocal(() {
                  floor = v;
                  room = null;
                }),
              ),
            if (widget.menuCode == '56002' &&
                floor != null &&
                rooms.any((e) => e['floorId'] == floor))
              DropdownButtonFormField<int?>(
                initialValue: room,
                decoration: input('ห้อง (ไม่บังคับ)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่ระบุห้อง'),
                  ),
                  ...rooms
                      .where((e) => e['floorId'] == floor)
                      .map(
                        (e) => DropdownMenuItem<int?>(
                          value: (e['id'] as num).toInt(),
                          child: Text(
                            (e['name'] ?? e['code']).toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: (v) => setLocal(() => room = v),
              ),
            if (widget.menuCode == '56002') ...[
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: input('รูปแบบเวลา *'),
                items: const [
                  DropdownMenuItem(
                    value: 'TIME_WINDOW',
                    child: Text('กำหนดช่วงเวลา'),
                  ),
                  DropdownMenuItem(
                    value: 'ANYTIME_IN_RUN',
                    child: Text('ตรวจได้ตลอดรอบ'),
                  ),
                ],
                onChanged: (v) => setLocal(() => mode = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('บังคับ GPS'),
                value: gps,
                onChanged: (v) => setLocal(() => gps = v),
              ),
              if (gps) ...[
                TextField(
                  controller: latitude,
                  decoration: input('ละติจูด *'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
                TextField(
                  controller: longitude,
                  decoration: input('ลองจิจูด *'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
                TextField(
                  controller: gpsRadius,
                  decoration: input('รัศมีตรวจสอบ GPS (เมตร) *'),
                  keyboardType: TextInputType.number,
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('บังคับแนบรูป'),
                value: photo,
                onChanged: (v) => setLocal(() => photo = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('บังคับ Checklist'),
                value: checklist,
                onChanged: (v) => setLocal(() => checklist = v),
              ),
            ],
            if (widget.menuCode == '56003')
              DropdownButtonFormField<String>(
                initialValue: adapter,
                decoration: input('Adapter *'),
                items: const [
                  DropdownMenuItem(
                    value: 'SIMULATOR',
                    child: Text('Simulator'),
                  ),
                  DropdownMenuItem(value: 'CARD', child: Text('อุปกรณ์จำลอง')),
                  DropdownMenuItem(
                    value: 'BIOMETRIC',
                    child: Text('บัตร/เครื่องอ่าน'),
                  ),
                ],
                onChanged: (v) => setLocal(() => adapter = v!),
              ),
            if (widget.menuCode == '56003')
              DropdownButtonFormField<int?>(
                initialValue: checkpointId,
                decoration: input('จุดตรวจที่ผูก (ไม่บังคับ)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ทุกจุดตรวจ'),
                  ),
                  ...checkpoints.map(
                    (e) => DropdownMenuItem<int?>(
                      value: (e['id'] as num).toInt(),
                      child: Text(
                        (e['name'] ?? e['code']).toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setLocal(() => checkpointId = v),
              ),
            if (widget.menuCode == '56003')
              TextField(
                controller: extra,
                maxLines: 3,
                decoration: input('Public Key สำหรับ Offline (ถ้ามี)'),
              ),
            if (widget.menuCode == '56004') ...[
              DropdownButtonFormField<int>(
                initialValue: employee,
                decoration: input('พนักงาน *'),
                items: employees
                    .map(
                      (e) => DropdownMenuItem(
                        value: (e['id'] as num).toInt(),
                        child: Text(
                          (e['name'] ?? e['code']).toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => employee = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: credential,
                decoration: input('ประเภท *'),
                items: const [
                  DropdownMenuItem(value: 'CARD', child: Text('บัตร')),
                  DropdownMenuItem(value: 'QR', child: Text('QR')),
                  DropdownMenuItem(value: 'NFC', child: Text('NFC')),
                  DropdownMenuItem(
                    value: 'FINGERPRINT',
                    child: Text('ลายนิ้วมือ'),
                  ),
                  DropdownMenuItem(value: 'FACE', child: Text('ใบหน้า')),
                ],
                onChanged: (v) => setLocal(() => credential = v!),
              ),
              TextField(
                controller: extra,
                decoration: input(
                  editing ? 'รหัสอ้างอิงใหม่ *' : 'รหัสอ้างอิงจากอุปกรณ์ *',
                ),
              ),
              if (devices.isNotEmpty)
                DropdownButtonFormField<int?>(
                  initialValue: deviceId,
                  decoration: input('อุปกรณ์ที่ผูก (ถ้ามี)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ไม่ผูกอุปกรณ์'),
                    ),
                    ...devices.map(
                      (d) => DropdownMenuItem<int?>(
                        value: (d['id'] as num).toInt(),
                        child: Text(
                          (d['name'] ?? d['code']).toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => deviceId = v),
                ),
            ],
            if (widget.menuCode == '56005') ...[
              DropdownButtonFormField<String>(
                initialValue: work,
                decoration: input('ประเภทงาน *'),
                items: const [
                  DropdownMenuItem(value: 'SECURITY', child: Text('รปภ.')),
                  DropdownMenuItem(
                    value: 'HOUSEKEEPING',
                    child: Text('แม่บ้าน'),
                  ),
                ],
                onChanged: (v) => setLocal(() => work = v!),
              ),
              TextField(
                controller: extra,
                maxLines: 5,
                decoration: input('รายการตรวจ แยกบรรทัด *'),
              ),
            ],
            if (widget.menuCode == '56006') ...[
              DropdownButtonFormField<String>(
                initialValue: work,
                decoration: input('ประเภทงาน *'),
                items: const [
                  DropdownMenuItem(value: 'SECURITY', child: Text('รปภ.')),
                  DropdownMenuItem(
                    value: 'HOUSEKEEPING',
                    child: Text('แม่บ้าน'),
                  ),
                ],
                onChanged: (v) => setLocal(() => work = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: sequence,
                decoration: input('ลำดับการตรวจ *'),
                items: const [
                  DropdownMenuItem(value: 'FLEXIBLE', child: Text('ไม่บังคับ')),
                  DropdownMenuItem(value: 'STRICT', child: Text('ตามลำดับ')),
                ],
                onChanged: (v) => setLocal(() => sequence = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: input('เวลาแต่ละจุด'),
                items: const [
                  DropdownMenuItem(
                    value: 'ANYTIME_IN_RUN',
                    child: Text('ตรวจได้ตลอดรอบ'),
                  ),
                  DropdownMenuItem(
                    value: 'TIME_WINDOW',
                    child: Text('กำหนดเวลา'),
                  ),
                ],
                onChanged: (v) => setLocal(() => mode = v ?? 'ANYTIME_IN_RUN'),
              ),
              if (checklists.isNotEmpty)
                DropdownButtonFormField<int?>(
                  initialValue: checklistId,
                  decoration: input('Checklist ของแต่ละจุด (ถ้ามี)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ไม่ใช้ Checklist'),
                    ),
                    ...checklists.map(
                      (e) => DropdownMenuItem<int?>(
                        value: (e['id'] as num).toInt(),
                        child: Text(
                          (e['name'] ?? e['code']).toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => checklistId = v),
                ),
              if (mode == 'TIME_WINDOW') ...[
                TextField(
                  controller: windowStart,
                  decoration: input('เวลาเริ่มตรวจ HH:mm *'),
                ),
                TextField(
                  controller: windowEnd,
                  decoration: input('เวลาสิ้นสุดตรวจ HH:mm *'),
                ),
              ],
              TextField(
                controller: extra,
                decoration: input('รหัสจุดตรวจ เรียงตามลำดับ คั่นด้วยจุลภาค *'),
              ),
            ],
            if (widget.menuCode == '56007') ...[
              DropdownButtonFormField<int>(
                initialValue: routeId,
                decoration: input('เส้นทาง *'),
                items: routes
                    .map(
                      (e) => DropdownMenuItem(
                        value: (e['id'] as num).toInt(),
                        child: Text(
                          (e['name'] ?? e['code']).toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => routeId = v),
              ),
              TextField(
                controller: start,
                decoration: input('เวลาเริ่ม YYYY-MM-DDTHH:mm *'),
              ),
              TextField(
                controller: end,
                decoration: input('เวลาสิ้นสุด YYYY-MM-DDTHH:mm *'),
              ),
              TextField(
                controller: team,
                decoration: input('รหัสทีมหรือกลุ่ม (ถ้าไม่เลือกพนักงาน)'),
              ),
              if (employees.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: employee,
                  decoration: input('ผู้รับผิดชอบ *'),
                  items: employees
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text(
                            (e['name'] ?? e['code']).toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => employee = v),
                ),
            ],
          ];
          return LaooActionDialog(
            tokens: patrolTokens,
            icon: Icons.add_task_outlined,
            title: '$title > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  (fields[i]),
                  if (i < fields.length - 1) SizedBox(height: 16),
                ],
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (widget.menuCode != '56004' &&
                            (code.text.trim().isEmpty ||
                                name.text.trim().isEmpty)) {
                          patrolMessage(
                            context,
                            message: 'กรุณากรอกรหัสและชื่อ',
                            error: true,
                          );
                          return;
                        }
                        final lat = double.tryParse(latitude.text.trim());
                        final lon = double.tryParse(longitude.text.trim());
                        final radius = int.tryParse(gpsRadius.text.trim());
                        if (widget.menuCode == '56006' &&
                            extra.text
                                .split(',')
                                .map((v) => int.tryParse(v.trim()))
                                .whereType<int>()
                                .isEmpty) {
                          patrolMessage(
                            context,
                            message: 'กรุณาระบุรหัสจุดตรวจ',
                            error: true,
                          );
                          return;
                        }
                        if (widget.menuCode == '56002' &&
                            gps &&
                            (lat == null ||
                                lat < -90 ||
                                lat > 90 ||
                                lon == null ||
                                lon < -180 ||
                                lon > 180 ||
                                radius == null ||
                                radius <= 0)) {
                          patrolMessage(
                            context,
                            message: 'กรุณาตรวจสอบพิกัดและรัศมี GPS',
                            error: true,
                          );
                          return;
                        }
                        Object body;
                        switch (widget.menuCode) {
                          case '56002':
                            body = {
                              'branchId': branch,
                              'buildingId': building,
                              'floorId': floor,
                              'roomId': room,
                              'code': code.text.trim(),
                              'name': name.text.trim(),
                              'timeMode': mode,
                              'latitude': gps ? lat : null,
                              'longitude': gps ? lon : null,
                              'gpsRadius': gps ? radius : 100,
                              'requireGps': gps,
                              'requirePhoto': photo,
                              'requireChecklist': checklist,
                              'methods': [
                                'CARD',
                                'QR',
                                'NFC',
                                'FINGERPRINT',
                                'FACE',
                                'SIMULATOR',
                              ],
                              'active': active,
                            };
                            break;
                          case '56003':
                            body = {
                              'checkpointId': checkpointId,
                              'code': code.text.trim(),
                              'name': name.text.trim(),
                              'adapter': adapter,
                              'publicKey': extra.text.trim().isEmpty
                                  ? null
                                  : extra.text.trim(),
                            };
                            break;
                          case '56004':
                            body = {
                              'employeeId': employee,
                              'type': credential,
                              'reference': extra.text.trim(),
                              'hint': extra.text.trim().length > 4
                                  ? extra.text.trim().substring(
                                      extra.text.trim().length - 4,
                                    )
                                  : extra.text.trim(),
                              'deviceId': deviceId,
                            };
                            break;
                          case '56005':
                            body = {
                              'code': code.text.trim(),
                              'name': name.text.trim(),
                              'workType': work,
                              'items': extra.text
                                  .split('\n')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList(),
                            };
                            break;
                          case '56006':
                            body = {
                              'branchId': branch,
                              'buildingId': building,
                              'floorId': floor,
                              'roomId': room,
                              'code': code.text.trim(),
                              'name': name.text.trim(),
                              'workType': work,
                              'sequenceMode': sequence,
                              'points': extra.text
                                  .split(',')
                                  .map((v) => int.tryParse(v.trim()))
                                  .whereType<int>()
                                  .map(
                                    (pointId) => {
                                      'checkpointId': pointId,
                                      'timeMode': mode,
                                      'windowStart': mode == 'TIME_WINDOW'
                                          ? windowStart.text.trim()
                                          : null,
                                      'windowEnd': mode == 'TIME_WINDOW'
                                          ? windowEnd.text.trim()
                                          : null,
                                      'graceBefore': 0,
                                      'graceAfter': 15,
                                      'checklistTemplateId': checklistId,
                                    },
                                  )
                                  .toList(),
                              'active': active,
                            };
                            break;
                          default:
                            body = {
                              'routeId': routeId,
                              'code': code.text.trim(),
                              'name': name.text.trim(),
                              'startsAt': DateTime.tryParse(
                                start.text,
                              )?.toUtc().toIso8601String(),
                              'endsAt': DateTime.tryParse(
                                end.text,
                              )?.toUtc().toIso8601String(),
                              'employeeId': employee,
                              'teamCode': team.text.trim().isEmpty
                                  ? null
                                  : team.text.trim(),
                            };
                        }
                        setLocal(() => saving = true);
                        Navigator.pop(dialogContext);
                        await run(
                          () => editing
                              ? api.put(
                                  '/api/company/patrol/${widget.endpoint}/${row['id']}',
                                  body: body,
                                )
                              : api.post(
                                  '/api/company/patrol/${widget.endpoint}',
                                  body: body,
                                ),
                          editing ? 'แก้ไขข้อมูลสำเร็จ' : 'บันทึกข้อมูลสำเร็จ',
                        );
                      },
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    extra.dispose();
    team.dispose();
    start.dispose();
    end.dispose();
    windowStart.dispose();
    windowEnd.dispose();
  }

  Future<void> showRun(int id, Map<String, bool> actions) async {
    try {
      final raw = await api.get('/api/company/patrol/runs/$id'),
          data = _map(raw),
          head = _map(data['run']),
          points = _rows(data['points']);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => LaooActionDialog(
          tokens: patrolTokens,
          width: 720,
          icon: Icons.fact_check_outlined,
          title: '$title > ${head['name'] ?? id}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('สถานะ: ${head['status'] ?? '-'}'),
              SizedBox(height: 16),
              for (final p in points)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: patrolTokens.cardPadding,
                  decoration: BoxDecoration(
                    border: Border.all(color: patrolTokens.borderColor),
                    borderRadius: BorderRadius.circular(patrolTokens.radius),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p['sequence'] ?? ''}. ${p['name'] ?? ''}'),
                            Text(
                              '${p['timeMode'] == 'ANYTIME_IN_RUN' ? 'ตรวจได้ตลอดรอบ' : 'กำหนดช่วงเวลา'} ? ${p['status'] ?? 'PENDING'}',
                            ),
                          ],
                        ),
                      ),
                      if (p['status'] == 'PENDING' &&
                          actions['checkpoint'] == true)
                        IconButton(
                          tooltip: 'จำลองการตรวจ',
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            await scanCard(id, p);
                          },
                          icon: Icon(
                            Icons.touch_app_outlined,
                            color: patrolTokens.primaryColor,
                          ),
                        ),
                      if (p['status'] == 'PENDING' && actions['skip'] == true)
                        IconButton(
                          tooltip: 'ข้ามจุดตรวจ',
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            final reason = await askPatrolReason('ข้ามจุดตรวจ');
                            if (reason != null) {
                              await run(
                                () => api.post(
                                  '/api/company/patrol/runs/$id/checkpoints/${p['id']}/skip',
                                  body: {'reason': reason},
                                ),
                                'ข้ามจุดตรวจสำเร็จ',
                              );
                            }
                          },
                          icon: const Icon(Icons.skip_next_outlined),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ปิด'),
            ),
            if (actions['report_incident'] == true)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  showIncidentForm(id, points);
                },
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('แจ้งเหตุ'),
              ),
            if (actions['cancel'] == true)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final reason = await askPatrolReason('ยกเลิกรอบตรวจ');
                  if (reason != null) {
                    await run(
                      () => api.post(
                        '/api/company/patrol/runs/$id/cancel',
                        body: {'reason': reason},
                      ),
                      'ยกเลิกรอบตรวจสำเร็จ',
                    );
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('ยกเลิกรอบ'),
              ),
            if (actions['start'] == true)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  run(
                    () => api.post('/api/company/patrol/runs/$id/start'),
                    'เริ่มปฏิบัติงานสำเร็จ',
                  );
                },
                child: const Text('เริ่มงาน'),
              ),
            if (actions['complete'] == true)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  run(
                    () => api.post('/api/company/patrol/runs/$id/complete'),
                    'ปิดรอบและสรุปผลสำเร็จ',
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('จบรอบ'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) patrolMessage(context, message: e.toString(), error: true);
    }
  }

  Future<void> showIncidentForm(
    int runId,
    List<Map<String, dynamic>> points,
  ) async {
    final subject = TextEditingController();
    final detail = TextEditingController();
    int? checkpointId;
    String severity = 'MEDIUM';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: patrolTokens,
          icon: Icons.report_problem_outlined,
          title: '$title > แจ้งเหตุ',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: input('ระดับความรุนแรง *'),
                items: const [
                  DropdownMenuItem(value: 'LOW', child: Text('ต่ำ')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('ปานกลาง')),
                  DropdownMenuItem(value: 'HIGH', child: Text('สูง')),
                  DropdownMenuItem(value: 'CRITICAL', child: Text('วิกฤต')),
                ],
                onChanged: (value) =>
                    setLocal(() => severity = value ?? 'MEDIUM'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: checkpointId,
                decoration: input('จุดตรวจ (ถ้ามี)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่ระบุ'),
                  ),
                  ...points.map(
                    (point) => DropdownMenuItem<int?>(
                      value: (point['id'] as num).toInt(),
                      child: Text(
                        '${point['sequence'] ?? ''}. ${point['name'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setLocal(() => checkpointId = value),
              ),
              const SizedBox(height: 16),
              TextField(controller: subject, decoration: input('หัวข้อ *')),
              const SizedBox(height: 16),
              TextField(
                controller: detail,
                maxLines: 4,
                decoration: input('รายละเอียด *'),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (subject.text.trim().isEmpty || detail.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext);
                run(
                  () => api.post(
                    '/api/company/patrol/incidents',
                    body: {
                      'runId': runId,
                      'runCheckpointId': checkpointId,
                      'severity': severity,
                      'subject': subject.text.trim(),
                      'detail': detail.text.trim(),
                    },
                  ),
                  'แจ้งเหตุสำเร็จ',
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึกเหตุ'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    detail.dispose();
  }

  Future<String?> askPatrolReason(String actionName) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: patrolTokens,
        icon: Icons.edit_note_outlined,
        title: '$title > $actionName',
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: input('เหตุผล *'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> scanCard(int runId, Map<String, dynamic> point) async {
    final card = TextEditingController();
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (scanContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            if (saving || card.text.trim().isEmpty) return;
            setLocal(() => saving = true);
            Navigator.pop(scanContext);
            final micros = DateTime.now().microsecondsSinceEpoch
                .toString()
                .padLeft(20, '0');
            await run(
              () => api.post(
                '/api/company/patrol/runs/$runId/checkpoints/${point['id']}/events',
                body: {
                  'eventKey':
                      '${micros.substring(micros.length - 8)}-0000-4000-8000-${micros.substring(micros.length - 12)}',
                  'method': 'CARD',
                  'credentialReference': card.text.trim(),
                  'occurredAt': DateTime.now().toUtc().toIso8601String(),
                  'deviceId': null,
                  'deviceSequence': null,
                  'latitude': 13.7563,
                  'longitude': 100.5018,
                  'gpsAccuracy': 10,
                  'offline': false,
                  'photoPath': point['requirePhoto'] == true
                      ? 'simulator/photo.jpg'
                      : null,
                  'checklistJson': point['requireChecklist'] == true
                      ? '[]'
                      : null,
                  'note': 'Card reader simulator',
                },
              ),
              'บันทึกจุดตรวจสำเร็จ',
            );
          }

          return LaooActionDialog(
            tokens: patrolTokens,
            icon: Icons.badge_outlined,
            title: 'อ่านบัตร > ${point['name']}',
            content: TextField(
              controller: card,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: input('เลขบัตร *'),
            ),
            actions: [
              OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(scanContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_outlined),
                label: const Text('ตรวจสอบ'),
              ),
            ],
          );
        },
      ),
    );
    card.dispose();
  }
}
