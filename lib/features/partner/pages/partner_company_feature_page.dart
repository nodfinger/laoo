import 'package:flutter/material.dart';

import '../../../app/theme/laoo_typography.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/company_feature_repository.dart';
import '../data/partner_company_repository.dart';
import '../models/company_feature.dart';
import '../models/partner_company.dart';

class PartnerCompanyFeaturePage extends StatefulWidget {
  const PartnerCompanyFeaturePage({super.key});

  @override
  State<PartnerCompanyFeaturePage> createState() =>
      _PartnerCompanyFeaturePageState();
}

class _PartnerCompanyFeaturePageState extends State<PartnerCompanyFeaturePage> {
  final _companyRepository = PartnerCompanyRepository();
  final _featureRepository = CompanyFeatureRepository();
  final _search = TextEditingController();
  final Map<int, CompanyFeatureState> _features = {};
  final Set<int> _saving = {};
  List<PartnerCompany> _companies = const [];
  String _menuName = 'จัดการ Option';
  bool _loading = true;
  String? _error;

  List<PartnerCompany> get _visibleCompanies {
    final search = _search.text.trim().toLowerCase();
    if (search.isEmpty) return _companies;
    return _companies
        .where(
          (company) =>
              company.companyCode.toLowerCase().contains(search) ||
              company.companyNameTh.toLowerCase().contains(search),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadMenuName();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMenuName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        menuCode: '06003',
        routeName: 'partnerCompanyFeatures',
        fallback: _menuName,
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final companies = await _companyRepository.getCompanies();
      final featureRows = await Future.wait(
        companies.map(
          (company) => _featureRepository.getSalesManagement(company.companyId),
        ),
      );
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _features
          ..clear()
          ..addEntries(featureRows.map((row) => MapEntry(row.companyId, row)));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(PartnerCompany company, bool enabled) async {
    final current = _features[company.companyId];
    if (current == null || _saving.contains(company.companyId)) return;
    setState(() => _saving.add(company.companyId));
    try {
      final saved = await _featureRepository.setSalesManagement(
        current,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() => _features[company.companyId] = saved);
      showTimedSnackBar(
        context,
        message: enabled
            ? 'เปิดใช้ระบบบริหารงานขายให้ ${company.companyNameTh} สำเร็จ'
            : 'ปิดใช้ระบบบริหารงานขายของ ${company.companyNameTh} สำเร็จ',
      );
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ไม่สามารถบันทึก Option ได้\nรายละเอียด: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(company.companyId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu: 'partnerCompanyFeatures',
      menuScope: WorkspaceMenuScope.partner,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _menuName,
                    style: LaooTypography.screenCaptionStyle,
                  ),
                ),
                IconButton(
                  tooltip: 'โหลดข้อมูลใหม่',
                  onPressed: _loading ? null : _load,
                  icon: Icon(Icons.refresh_rounded, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'ค้นหาลูกค้า',
                  hintText: 'รหัสหรือชื่อลูกค้า',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _content(accent)),
          ],
        ),
      ),
    );
  }

  Widget _content(Color accent) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    if (_error != null) {
      return Center(
        child: Text(
          'ไม่สามารถโหลดข้อมูลได้\nรายละเอียด: $_error',
          textAlign: TextAlign.center,
        ),
      );
    }
    final companies = _visibleCompanies;
    if (companies.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลลูกค้า'));
    }
    return ListView.separated(
      itemCount: companies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final company = companies[index];
        final feature = _features[company.companyId];
        final enabled = feature?.isEnabled == true;
        final saving = _saving.contains(company.companyId);
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Icon(Icons.business_outlined, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${company.companyCode} - ${company.companyNameTh}',
                        style: const TextStyle(
                          fontSize: LaooTypography.sectionTitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled
                            ? 'เปิดใช้ระบบบริหารงานขาย'
                            : 'ยังไม่ได้เปิดใช้ระบบบริหารงานขาย',
                        style: TextStyle(
                          color: enabled
                              ? accent
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: LaooTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                if (saving)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  Switch(
                    value: enabled,
                    activeTrackColor: accent,
                    onChanged: feature == null
                        ? null
                        : (value) => _toggle(company, value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
