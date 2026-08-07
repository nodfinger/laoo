import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onLogin: () {
                context.goNamed(RouteNames.login);
              },
            ),
            const Expanded(
              child: SingleChildScrollView(
                child: Column(children: [_Hero(), _Benefits(), _Footer()]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: LaooColors.border)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/laoo_logo_new.png',
            width: 150,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'LAOO SOLUTIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: LaooColors.greenDark,
                ),
              );
            },
          ),
          const Spacer(),
          if (wide) ...[
            const _NavText('หน้าหลัก'),
            const _NavText('โซลูชัน'),
            const _NavText('เกี่ยวกับเรา'),
            const _NavText('ติดต่อเรา'),
            const SizedBox(width: 18),
          ],
          FilledButton(onPressed: onLogin, child: const Text('เข้าสู่ระบบ')),
        ],
      ),
    );
  }
}

class _NavText extends StatelessWidget {
  const _NavText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: LaooColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 820;

              final textContent = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'ระบบที่ช่วยให้ธุรกิจของคุณ',
                    textAlign: compact ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      fontSize: compact ? 34 : 46,
                      fontWeight: FontWeight.w900,
                      color: LaooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'เติบโตได้อย่างมั่นคง',
                    textAlign: compact ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      fontSize: compact ? 34 : 46,
                      fontWeight: FontWeight.w900,
                      color: LaooColors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'แพลตฟอร์มรวมโซลูชันสำหรับธุรกิจ '
                    'ออกแบบให้ใช้งานง่าย รองรับทุกอุปกรณ์ '
                    'และพร้อมขยายตามการเติบโตขององค์กร',
                    style: TextStyle(
                      height: 1.7,
                      fontSize: 16,
                      color: LaooColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: const Text('ดูโซลูชันของเรา'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('ติดต่อเรา'),
                      ),
                    ],
                  ),
                ],
              );

              const visual = _ProductPreview();

              if (compact) {
                return Column(
                  children: [textContent, const SizedBox(height: 48), visual],
                );
              }

              return Row(
                children: [
                  Expanded(child: textContent),
                  const SizedBox(width: 48),
                  const Expanded(child: visual),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: LaooColors.surfaceSoft,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: LaooColors.border),
      ),
      child: const Center(
        child: Icon(Icons.devices_rounded, size: 140, color: LaooColors.green),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.edit_note_rounded, 'ใช้งานง่าย', 'ออกแบบมาเพื่อทุกคน'),
      (Icons.verified_user_outlined, 'ปลอดภัย', 'รองรับการกำหนดสิทธิ์'),
      (Icons.sync_rounded, 'ยืดหยุ่น', 'ปรับเข้ากับธุรกิจของคุณ'),
      (Icons.devices_rounded, 'ทุกอุปกรณ์', 'Desktop / Tablet / Mobile'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final item in items)
                SizedBox(
                  width: 270,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(item.$1, color: LaooColors.green),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  item.$3,
                                  style: const TextStyle(
                                    color: LaooColors.textSecondary,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: LaooColors.surfaceSoft,
      padding: const EdgeInsets.all(24),
      child: const Text(
        '© Laoo Solutions • Simple Today. Ready Tomorrow.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: LaooColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
