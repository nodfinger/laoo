import 'package:flutter/material.dart';

import '../../../../app/laoo_app.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const Color _primaryGreen = Color(0xFF32C766);
  static const Color _darkGreen = Color(0xFF166534);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopNavigation(
              onLoginPressed: () {
                Navigator.pushNamed(context, LaooApp.loginRoute);
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: const [
                    _HeroSection(),
                    _SolutionsSection(),
                    _Footer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({
    required this.onLoginPressed,
  });

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8EFEA)),
        ),
      ),
      child: Row(
        children: [
          const _BrandLogo(),
          const Spacer(),
          FilledButton.icon(
            onPressed: onLoginPressed,
            icon: const Icon(Icons.login_rounded, size: 20),
            label: const Text('Login'),
            style: FilledButton.styleFrom(
              backgroundColor: LandingPage._primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Laoo Solutions',
      image: true,
      child: Image.asset(
        'assets/images/laoo_logo.png',
        width: 190,
        height: 58,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return const Text(
            'Laoo Solutions',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF16351F),
            ),
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 64,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEFFFF3),
            Color(0xFFF9FCFA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;

              final textContent = Column(
                crossAxisAlignment: isNarrow
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFCFE9D6),
                      ),
                    ),
                    child: const Text(
                      'ระบบที่ออกแบบให้ใช้งานง่ายบนทุกอุปกรณ์',
                      style: TextStyle(
                        color: LandingPage._darkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Laoo Solutions',
                    textAlign: isNarrow ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      fontSize: isNarrow ? 42 : 58,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF16351F),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Simple Today. Ready Tomorrow.',
                    textAlign: isNarrow ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      fontSize: isNarrow ? 21 : 25,
                      fontWeight: FontWeight.w600,
                      color: LandingPage._primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'แพลตฟอร์มสำหรับรวบรวมโซลูชันของ Laoo '
                    'เริ่มต้นจากระบบที่ใช้งานได้จริง และขยายต่อได้ในอนาคต',
                    textAlign: isNarrow ? TextAlign.center : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.7,
                      color: Color(0xFF5D7062),
                    ),
                  ),
                ],
              );

              final visual = Container(
                width: isNarrow ? double.infinity : 440,
                height: isNarrow ? 290 : 310,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/laoo_logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 64,
                        color: Color(0xFF6B7F70),
                      ),
                    );
                  },
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    textContent,
                    const SizedBox(height: 42),
                    visual,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: textContent),
                  const SizedBox(width: 56),
                  visual,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SolutionsSection extends StatelessWidget {
  const _SolutionsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laoo Solutions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: LandingPage._primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ตัวอย่างระบบของเรา',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF16351F),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'เริ่มจาก Project ตัวอย่างก่อน และเพิ่ม Solution อื่นได้ในภายหลัง',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7F70),
                ),
              ),
              const SizedBox(height: 30),
              const _MeetingSolutionCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingSolutionCard extends StatelessWidget {
  const _MeetingSolutionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE1EAE4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          final iconBox = Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F9ED),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.meeting_room_rounded,
              size: 58,
              color: LandingPage._primaryGreen,
            ),
          );

          final details = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Laoo Meeting',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF16351F),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'ระบบตัวอย่างสำหรับแสดงชื่อห้องประชุม '
                'ตารางการใช้งาน และข้อมูลการประชุมหน้าห้อง',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF607064),
                ),
              ),
              SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FeatureChip(
                    icon: Icons.calendar_month_rounded,
                    label: 'ตารางประชุม',
                  ),
                  _FeatureChip(
                    icon: Icons.tv_rounded,
                    label: 'หน้าจอหน้าห้อง',
                  ),
                  _FeatureChip(
                    icon: Icons.devices_rounded,
                    label: 'รองรับหลายอุปกรณ์',
                  ),
                ],
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(height: 24),
                details,
              ],
            );
          }

          return Row(
            children: [
              iconBox,
              const SizedBox(width: 28),
              Expanded(child: details),
              const SizedBox(width: 24),
              OutlinedButton(
                onPressed: null,
                child: Text('ตัวอย่าง Project'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: LandingPage._primaryGreen,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF42604A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      color: const Color(0xFF15351E),
      child: const Text(
        '© Laoo Solutions',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFCFE7D5),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
