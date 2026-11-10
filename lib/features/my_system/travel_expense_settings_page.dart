import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class TravelExpenseSettingsPage extends StatefulWidget {
  const TravelExpenseSettingsPage({super.key});
  @override
  State<TravelExpenseSettingsPage> createState() =>
      _TravelExpenseSettingsPageState();
}

class _TravelExpenseSettingsPageState extends State<TravelExpenseSettingsPage> {
  final _api = ApiClient();
  final _rates = <String, TextEditingController>{};
  final _names = <String, String>{};
  final _lodgingRates = <String, TextEditingController>{};
  final _lodgingNames = <String, String>{};
  final _positions = <String, String>{};
  final _positionLevels = <String, String?>{};
  final _levels = <String, String>{};
  bool _positionsLoading = true,
      _positionsSaving = false,
      _canEditPositions = false;
  String? _positionsError;
  String _title = '';
  bool _loading = true, _saving = false, _canEdit = false;
  bool _lodgingLoading = true, _lodgingSaving = false, _canEditLodging = false;
  String? _error;
  String? _lodgingError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLodging();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    try {
      final data = await _api.get(
        '/api/company/travel-settings/position-levels',
      );
      if (data is! Map ||
          data['positions'] is! List ||
          data['levels'] is! List) {
        throw StateError('Invalid response');
      }
      if (!mounted) return;
      setState(() {
        _positions.clear();
        _positionLevels.clear();
        _levels.clear();
        for (final item in (data['positions'] as List).whereType<Map>()) {
          final code = item['code'].toString();
          _positions[code] = item['name'].toString();
          _positionLevels[code] = item['level']?.toString();
        }
        for (final item in (data['levels'] as List).whereType<Map>()) {
          _levels[item['code'].toString()] = item['name'].toString();
        }
        _canEditPositions = data['canEdit'] == true;
        _positionsLoading = false;
        _positionsError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _positionsLoading = false;
          _positionsError =
              'โหลดระดับตำแหน่งงานไม่ได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _savePositions() async {
    setState(() => _positionsSaving = true);
    try {
      await _api.put(
        '/api/company/travel-settings/position-levels',
        body: {
          'items': _positions.keys
              .map((code) => {'code': code, 'level': _positionLevels[code]})
              .toList(),
        },
      );
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกระดับตำแหน่งงานเรียบร้อยแล้ว',
        );
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกระดับตำแหน่งงานไม่สำเร็จ กรุณาตรวจสอบข้อมูลและลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _positionsSaving = false);
    }
  }

  Widget _buildPositionTab(BuildContext context) {
    if (_positionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_positionsError != null) return Center(child: Text(_positionsError!));
    final t = businessCardOcrUi(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_positions.isEmpty)
          const Text('ไม่พบตำแหน่งงาน กรุณาเพิ่มข้อมูลในรหัสพื้นฐาน'),
        if (_levels.isEmpty)
          const Text('ไม่พบระดับตำแหน่งงาน กรุณาเพิ่มข้อมูลในรหัสพื้นฐาน'),
        for (final position in _positions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : constraints.maxWidth * .5,
                    child: Text(position.value, style: t.tableStyle),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _levels.containsKey(_positionLevels[position.key])
                          ? _positionLevels[position.key]
                          : null,
                      decoration: ocrInput(context, 'ระดับตำแหน่งงาน'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('ไม่กำหนด'),
                        ),
                        for (final level in _levels.entries)
                          DropdownMenuItem(
                            value: level.key,
                            child: Text(level.value),
                          ),
                      ],
                      onChanged: !_canEditPositions || _positionsSaving
                          ? null
                          : (value) => setState(
                              () => _positionLevels[position.key] =
                                  value == null || value.isEmpty ? null : value,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_canEditPositions && _positions.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _positionsSaving ? null : _savePositions,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ),
      ],
    );
  }

  Future<void> _loadLodging() async {
    try {
      final data = await _api.get('/api/company/travel-settings/lodging-rates');
      if (!mounted) return;
      if (data is! Map || data['items'] is! List) {
        throw StateError('Invalid response');
      }
      for (final old in _lodgingRates.values) {
        old.dispose();
      }
      _lodgingRates.clear();
      _lodgingNames.clear();
      for (final item in (data['items'] as List).whereType<Map>()) {
        final code = item['code'].toString();
        _lodgingNames[code] = item['name'].toString();
        _lodgingRates[code] = TextEditingController(
          text: item['rate']?.toString() ?? '',
        );
      }
      setState(() {
        _canEditLodging = data['canEdit'] == true;
        _lodgingLoading = false;
        _lodgingError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _lodgingLoading = false;
          _lodgingError =
              'โหลดอัตราค่าห้องพักไม่ได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _saveLodging() async {
    final items = <Map<String, Object?>>[];
    for (final entry in _lodgingRates.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) {
        items.add({'code': entry.key, 'rate': null});
        continue;
      }
      final value = double.tryParse(text);
      if (value == null ||
          value < 0 ||
          value > 9999999999.99 ||
          !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
        showTimedSnackBar(
          context,
          message:
              'อัตราของ ${_lodgingNames[entry.key]} ไม่ถูกต้อง กรุณาระบุตัวเลขไม่ติดลบและทศนิยมไม่เกิน 2 ตำแหน่ง',
          error: true,
        );
        return;
      }
      items.add({'code': entry.key, 'rate': value});
    }
    setState(() => _lodgingSaving = true);
    try {
      await _api.put(
        '/api/company/travel-settings/lodging-rates',
        body: {'items': items},
      );
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกอัตราค่าห้องพักเรียบร้อยแล้ว',
        );
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกอัตราค่าห้องพักไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์แล้วลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _lodgingSaving = false);
    }
  }

  Widget _buildLodgingTab(BuildContext context) {
    if (_lodgingLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lodgingError != null) {
      return Center(child: Text(_lodgingError!));
    }
    final t = businessCardOcrUi(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_lodgingRates.isEmpty)
          const Text('ไม่พบระดับตำแหน่งงาน กรุณาเพิ่มข้อมูลในรหัสพื้นฐาน'),
        for (final entry in _lodgingRates.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : constraints.maxWidth * .5,
                    child: Text(
                      _lodgingNames[entry.key] ?? '',
                      style: t.tableStyle,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : 240,
                    child: TextField(
                      controller: entry.value,
                      enabled: _canEditLodging && !_lodgingSaving,
                      style: t.inputStyle,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: ocrInput(context, 'เบิกได้ (บาท)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_canEditLodging && _lodgingRates.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(0, t.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: _lodgingSaving ? null : _saveLodging,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ),
      ],
    );
  }

  Future<void> _load() async {
    try {
      final menu = await NavigationMenuRepository().findMenu(menuCode: '67001');
      final data = await _api.get('/api/company/travel-settings');
      if (!mounted) return;
      if (data is! Map || data['items'] is! List) {
        throw StateError('Invalid response');
      }
      for (final old in _rates.values) {
        old.dispose();
      }
      _rates.clear();
      _names.clear();
      for (final item in (data['items'] as List).whereType<Map>()) {
        final code = item['code'].toString();
        _names[code] = item['name'].toString();
        _rates[code] = TextEditingController(
          text: item['rate']?.toString() ?? '',
        );
      }
      setState(() {
        _title = menu?.name ?? '';
        _canEdit = data['canEdit'] == true;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'โหลดอัตราค่าเดินทางไม่ได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _save() async {
    final items = <Map<String, Object?>>[];
    for (final entry in _rates.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) {
        items.add({'code': entry.key, 'rate': null});
        continue;
      }
      final value = double.tryParse(text);
      if (value == null ||
          value < 0 ||
          value > 9999999999.99 ||
          !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
        showTimedSnackBar(
          context,
          message:
              'อัตราของ ${_names[entry.key]} ไม่ถูกต้อง กรุณาระบุตัวเลขไม่ติดลบและทศนิยมไม่เกิน 2 ตำแหน่ง',
          error: true,
        );
        return;
      }
      items.add({'code': entry.key, 'rate': value});
    }
    setState(() => _saving = true);
    try {
      await _api.put('/api/company/travel-settings', body: {'items': items});
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกอัตราค่าเดินทางเรียบร้อยแล้ว',
        );
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกอัตราค่าเดินทางไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์แล้วลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _rates.values) {
      c.dispose();
    }
    for (final c in _lodgingRates.values) {
      c.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _title,
    activeMenu: 'travelExpenseSettings',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WorkspacePageTitle(
                title: _title,
                favoriteKey: 'travelExpenseSettings',
              ),
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : DefaultTabController(
                      length: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(text: 'อัตราค่าน้ำมัน/กม./ประเภทรถ'),
                              Tab(text: 'อัตราค่าห้องพัก'),
                              Tab(text: 'ระดับตำแหน่งงาน'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    if (_rates.isEmpty)
                                      const Text(
                                        'ไม่พบประเภทรถ กรุณาเพิ่มข้อมูลประเภทรถในรหัสพื้นฐาน',
                                      ),
                                    for (final entry in _rates.entries)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) => Wrap(
                                            spacing: 16,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth < 500
                                                    ? constraints.maxWidth
                                                    : constraints.maxWidth * .5,
                                                child: Text(
                                                  _names[entry.key] ?? '',
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth < 500
                                                    ? constraints.maxWidth
                                                    : 240,
                                                child: TextField(
                                                  controller: entry.value,
                                                  enabled: _canEdit && !_saving,
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(
                                                      RegExp(r'[0-9.]'),
                                                    ),
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'เบิกได้/กม. (บาท)',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_canEdit && _rates.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.icon(
                                          onPressed: _saving ? null : _save,
                                          icon: const Icon(Icons.save_outlined),
                                          label: const Text('บันทึก'),
                                        ),
                                      ),
                                  ],
                                ),
                                _buildLodgingTab(context),
                                _buildPositionTab(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
