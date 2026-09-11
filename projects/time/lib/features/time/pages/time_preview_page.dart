import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../time_feature_host.dart';

class TimePreviewPage extends StatelessWidget {
  const TimePreviewPage({
    super.key,
    required this.route,
    required this.title,
    required this.description,
    required this.highlights,
  });

  final FeatureRouteContract route;
  final String title;
  final String description;
  final List<TimePreviewHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return buildTimeWorkspaceShell(
      pageTitle: title,
      activeMenu: route.routeName,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Surface(
                    child: Row(
                      children: [
                        Icon(Icons.schedule_outlined, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          color: colors.primary.withValues(alpha: .10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'โหมด Preview ของระบบบริหารเวลา',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(description),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, box) => Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final item in highlights)
                                SizedBox(
                                  width: box.maxWidth < 700
                                      ? box.maxWidth
                                      : (box.maxWidth - 10) / 2,
                                  child: _HighlightCard(item: item),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TimeEmployeeSettingsPreviewPage extends StatelessWidget {
  const TimeEmployeeSettingsPreviewPage({super.key, required this.route});

  final FeatureRouteContract route;

  @override
  Widget build(BuildContext context) => TimePreviewPage(
    route: route,
    title: 'พนักงาน–ลงเวลาทำงาน',
    description:
        'หน้าจอนี้เชื่อมกับข้อมูลบุคคลและพนักงานจาก Core แล้ว เพื่อเตรียมกำหนดการลงเวลาเป็นลำดับถัดไป',
    highlights: const [
      TimePreviewHighlight(
        icon: Icons.person_outline,
        title: 'ข้อมูลอ้างอิงจาก Core',
        detail: 'ใช้บุคคลและพนักงานชุดเดียวกัน ไม่สร้างข้อมูลซ้ำใน Time',
      ),
      TimePreviewHighlight(
        icon: Icons.fact_check_outlined,
        title: 'พร้อมสำหรับการตั้งค่า',
        detail:
            'กะ ตารางงาน และสิทธิ์การลงเวลาจะเปิดเมื่อ Flow งานเวลาได้รับการพัฒนา',
      ),
    ],
  );
}

class TimeSystemSettingsPreviewPage extends StatelessWidget {
  const TimeSystemSettingsPreviewPage({super.key, required this.route});

  final FeatureRouteContract route;

  @override
  Widget build(BuildContext context) => TimePreviewPage(
    route: route,
    title: 'กำหนดค่าระบบเวลา',
    description:
        'ระบบบริหารเวลาถูกเชื่อมเข้ากับ LAOO แล้วในโหมด Preview เพื่อให้ตรวจโครงเมนูและขอบเขตข้อมูลก่อนเปิดใช้งานจริง',
    highlights: const [
      TimePreviewHighlight(
        icon: Icons.account_tree_outlined,
        title: 'Project และสิทธิ์',
        detail:
            'แยก Project LAOO_TIME และกรอง Company/User Project ตามสิทธิ์เดิมของระบบ',
      ),
      TimePreviewHighlight(
        icon: Icons.storage_outlined,
        title: 'โครงสร้างรองรับแล้ว',
        detail:
            'เตรียม Schema สำหรับกะ การลา OT งวดเวลา และประวัติการอนุมัติไว้แล้ว',
      ),
    ],
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.item});
  final TimePreviewHighlight item;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TimePreviewHighlight {
  const TimePreviewHighlight({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}
