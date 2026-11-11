import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../company/ocr/business_card_ocr_ui.dart';

class TravelAccessSettingsCard extends StatefulWidget {
  const TravelAccessSettingsCard({super.key});
  @override
  TravelAccessSettingsCardState createState() =>
      TravelAccessSettingsCardState();
}

class TravelAccessSettingsCardState extends State<TravelAccessSettingsCard> {
  final _api = ApiClient();
  Map<String, dynamic> _values = {};
  bool _loading = true, _saving = false, _canEdit = false, _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _api.get(
        '/api/company/travel-settings/global-access',
      );
      if (result is! Map || result['policy'] is! Map) {
        throw StateError('Invalid policy');
      }
      if (!mounted) return;
      setState(() {
        _values = Map<String, dynamic>.from(result['policy'] as Map);
        _canEdit = result['canEdit'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'โหลดเงื่อนไขการเข้าถึงไม่ได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> saveIfChanged() async {
    if (!_dirty) return;
    if (!_canEdit || _loading || _error != null) {
      throw StateError('ไม่สามารถบันทึกเงื่อนไขการเข้าถึงได้');
    }
    setState(() => _saving = true);
    try {
      await _api.put(
        '/api/company/travel-settings/global-access',
        body: _values,
      );
      _dirty = false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _part(String title, String prefix) {
    final scope = _values['${prefix}Scope'] as String? ?? 'SELF';
    final enabled = _canEdit && !_saving;
    Widget check(String label, String field, bool allowed, {bool all = false}) {
      final value = allowed && (all || _values['$prefix$field'] == true);
      return InkWell(
        onTap: enabled && allowed && !all
            ? () => setState(() {
                _values['$prefix$field'] = !value;
                _dirty = true;
              })
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: enabled && allowed && !all
                  ? (v) => setState(() {
                      _values['$prefix$field'] = v == true;
                      _dirty = true;
                    })
                  : null,
            ),
            Text(label),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('$prefix-$scope'),
          initialValue: scope,
          isExpanded: true,
          decoration: ocrInput(context, 'ขอบเขตข้อมูล'),
          items: const [
            DropdownMenuItem(value: 'SELF', child: Text('เฉพาะของตัวเอง')),
            DropdownMenuItem(value: 'DEPARTMENT', child: Text('ภายในแผนก')),
            DropdownMenuItem(value: 'DIVISION', child: Text('ภายในฝ่าย')),
            DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
          ],
          onChanged: !enabled
              ? null
              : (v) => setState(() {
                  _values['${prefix}Scope'] = v;
                  if (v == 'SELF') {
                    _values['${prefix}Staff'] = false;
                    _values['${prefix}Head'] = false;
                    _values['${prefix}Manager'] = false;
                  } else if (v == 'DEPARTMENT') {
                    _values['${prefix}Manager'] = false;
                  }
                  _dirty = true;
                }),
        ),
        Wrap(
          spacing: 8,
          children: [
            check(
              prefix == 'edit'
                  ? 'เจ้าหน้าที่ภายในสังกัดทุกคนแก้ไขได้'
                  : prefix == 'delete'
                  ? 'เจ้าหน้าที่ภายในสังกัดทุกคนลบได้'
                  : 'เจ้าหน้าที่ภายในสังกัดทุกคนเข้าถึงได้',
              'Staff',
              scope != 'SELF',
              all: scope != 'SELF',
            ),
            check(
              prefix == 'edit'
                  ? 'หัวหน้าแก้ไขได้'
                  : prefix == 'delete'
                  ? 'หัวหน้าลบได้'
                  : 'หัวหน้าเข้าถึงได้',
              'Head',
              scope != 'SELF',
              all: scope == 'ALL',
            ),
            check(
              prefix == 'edit'
                  ? 'ผู้จัดการแก้ไขได้'
                  : prefix == 'delete'
                  ? 'ผู้จัดการลบได้'
                  : 'ผู้จัดการเข้าถึงได้',
              'Manager',
              scope != 'SELF' && scope != 'DEPARTMENT',
              all: scope == 'ALL',
            ),
          ],
        ),
        const Divider(thickness: .6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Text(_error!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'หมายเหตุ\nเฉพาะของตัวเอง : ผู้ใช้อื่นจะเข้าถึงข้อมูลของผู้บันทึกไม่ได้\nภายในแผนก : ผู้ใช้ที่สังกัดแผนกเดียวกับผู้บันทึกสามารถเข้าถึงข้อมูลได้\nภายในฝ่าย : ผู้ใช้ที่สังกัดฝ่ายเดียวกับผู้บันทึกสามารถเข้าถึงข้อมูลได้\nการเข้าถึงขึ้นอยู่กับสิทธิ์เมนูและตัวเลือกด้านล่าง',
        ),
        const SizedBox(height: 16),
        _part('การแสดงข้อมูล', 'view'),
        _part('การแก้ไขข้อมูล', 'edit'),
        _part('การลบข้อมูล', 'delete'),
      ],
    );
  }
}
