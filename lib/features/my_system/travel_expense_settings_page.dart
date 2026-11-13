import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
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
  final _expiryDays = TextEditingController();
  final _revision = TextEditingController();
  final _remarks = List.generate(5, (_) => TextEditingController());
  bool _generalLoading = true, _generalSaving = false, _canEditGeneral = false;
  String? _generalError;
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
    _loadGeneral();
  }

  Future<void> _loadGeneral() async {
    try {
      final data = await _api.get('/api/company/travel-settings/general');
      if (data is! Map || data['settings'] is! Map) {
        throw StateError('Invalid response');
      }
      final settings = data['settings'] as Map;
      if (!mounted) return;
      _expiryDays.text = settings['documentExpiryDays']?.toString() ?? '';
      _revision.text = settings['documentRevision']?.toString() ?? '';
      for (var i = 0; i < _remarks.length; i++) {
        _remarks[i].text = settings['remark${i + 1}']?.toString() ?? '';
      }
      setState(() {
        _canEditGeneral = data['canEdit'] == true;
        _generalLoading = false;
        _generalError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _generalLoading = false;
          _generalError = error is ApiException
              ? error.message
              : 'โหลดข้อมูลทั่วไปไม่สำเร็จ กรุณาลองใหม่';
        });
      }
    }
  }

  Future<void> _saveGeneral() async {
    final raw = _expiryDays.text.trim();
    final days = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (days == null || days < 0 || days > 2147483647)) {
      showTimedSnackBar(
        context,
        message: 'กรุณาระบุจำนวนวันเป็นจำนวนเต็มที่ไม่ติดลบ',
        error: true,
      );
      return;
    }
    setState(() => _generalSaving = true);
    try {
      await _api.put(
        '/api/company/travel-settings/general',
        body: {
          'documentExpiryDays': days,
          'documentRevision': _revision.text,
          for (var i = 0; i < _remarks.length; i++)
            'remark${i + 1}': _remarks[i].text,
        },
      );
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกข้อมูลทั่วไปเรียบร้อยแล้ว');
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? error.message
              : 'บันทึกข้อมูลทั่วไปไม่สำเร็จ กรุณาลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generalSaving = false);
    }
  }

  Widget _generalCard() {
    final t = businessCardOcrUi(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: t.primaryColor),
                const SizedBox(width: 10),
                Text(
                  'ข้อมูลทั่วไป',
                  style: t.tableStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(thickness: 0.6, color: Theme.of(context).dividerColor),
            const SizedBox(height: 12),
            if (_generalLoading)
              const Center(child: CircularProgressIndicator())
            else if (_generalError != null)
              Row(
                children: [
                  Expanded(child: Text(_generalError!)),
                  TextButton(
                    onPressed: _loadGeneral,
                    child: const Text('ลองใหม่'),
                  ),
                ],
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final width = wide
                      ? (constraints.maxWidth - 14) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _expiryDays,
                          enabled: _canEditGeneral && !_generalSaving,
                          style: t.inputStyle,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: ocrInput(
                            context,
                            'เอกสารหมดอายุ (วันนับจากวันที่บันทึก)',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _revision,
                          enabled: _canEditGeneral && !_generalSaving,
                          style: t.inputStyle,
                          maxLength: 100,
                          decoration: ocrInput(
                            context,
                            'Rev.เอกสาร',
                          ).copyWith(counterText: ''),
                        ),
                      ),
                    ],
                  );
                },
              ),
              for (var i = 0; i < _remarks.length; i++) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _remarks[i],
                  enabled: _canEditGeneral && !_generalSaving,
                  style: t.inputStyle,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 3,
                  decoration: ocrInput(
                    context,
                    'หมายเหตุ ${i + 1}',
                  ).copyWith(counterText: ''),
                ),
              ],
              if (_canEditGeneral) ...[
                const SizedBox(height: 14),
                Divider(thickness: 0.6, color: Theme.of(context).dividerColor),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, t.buttonHeight),
                    ),
                    onPressed: _generalSaving ? null : _saveGeneral,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึกข้อมูลทั่วไป'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
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

  Widget _buildRateTable({
    required Map<String, TextEditingController> rates,
    required Map<String, String> names,
    required String nameHeading,
    required String rateHeading,
    required String emptyMessage,
    required bool canEdit,
    required bool saving,
    required VoidCallback onSave,
  }) {
    final t = businessCardOcrUi(context);
    final headingStyle = t.tableStyle.copyWith(
      color: t.primaryColor,
      fontWeight: FontWeight.w700,
    );
    Widget header(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Text(text, style: headingStyle),
    );
    return ListView(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Table(
            columnWidths: {
              0: FixedColumnWidth(
                constraints.maxWidth < 600
                    ? constraints.maxWidth * 0.45
                    : (constraints.maxWidth * 0.25).clamp(180.0, 320.0),
              ),
              1: const FlexColumnWidth(),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.6,
              ),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: t.primaryColor.withValues(alpha: 0.12),
                ),
                children: [header(nameHeading), header(rateHeading)],
              ),
              for (final entry in rates.entries)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Text(names[entry.key] ?? '', style: t.tableStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: TextField(
                            controller: entry.value,
                            enabled: canEdit && !saving,
                            style: t.inputStyle,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: ocrInput(context, ''),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (rates.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(emptyMessage)),
        if (canEdit && rates.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(thickness: 0.6, color: Theme.of(context).dividerColor),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(0, t.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: saving ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLodgingTab(BuildContext context) {
    if (_lodgingLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lodgingError != null) return Center(child: Text(_lodgingError!));
    return _buildRateTable(
      rates: _lodgingRates,
      names: _lodgingNames,
      nameHeading: 'ระดับตำแหน่งงาน',
      rateHeading: 'เบิกได้ต่อคืน (บาท)',
      emptyMessage: 'ไม่พบระดับตำแหน่งงาน กรุณาเพิ่มข้อมูลในรหัสพื้นฐาน',
      canEdit: _canEditLodging,
      saving: _lodgingSaving,
      onSave: _saveLodging,
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
    _expiryDays.dispose();
    _revision.dispose();
    for (final c in _remarks) {
      c.dispose();
    }
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
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _generalCard(),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    SizedBox(
                      height: constraints.maxHeight < 500
                          ? 500
                          : constraints.maxHeight,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _error != null
                            ? Center(child: Text(_error!))
                            : DefaultTabController(
                                length: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const TabBar(
                                      isScrollable: true,
                                      tabAlignment: TabAlignment.start,
                                      tabs: [
                                        Tab(
                                          text: 'อัตราค่าน้ำมัน/กม./ประเภทรถ',
                                        ),
                                        Tab(text: 'อัตราค่าห้องพัก'),
                                      ],
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          _buildRateTable(
                                            rates: _rates,
                                            names: _names,
                                            nameHeading: 'ประเภทรถ',
                                            rateHeading: 'เบิกได้/กม. (บาท)',
                                            emptyMessage:
                                                'ไม่พบประเภทรถ กรุณาเพิ่มข้อมูลประเภทรถในรหัสพื้นฐาน',
                                            canEdit: _canEdit,
                                            saving: _saving,
                                            onSave: _save,
                                          ),
                                          _buildLodgingTab(context),
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
            ),
          ),
        ],
      ),
    ),
  );
}
