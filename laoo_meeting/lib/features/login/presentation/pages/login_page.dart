import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          children: [
                            const Expanded(child: _BrandPanel()),
                            const SizedBox(width: 40),
                            Expanded(child: _buildLoginCard(context)),
                          ],
                        )
                      : Column(
                          children: [
                            const _BrandPanel(compact: true),
                            const SizedBox(height: 24),
                            _buildLoginCard(context),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เข้าสู่ระบบ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรอกข้อมูลเพื่อเข้าใช้งาน Laoo Meeting',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 32),
              const Text(
                'ชื่อผู้ใช้',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(
                  hintText: 'กรอกชื่อผู้ใช้',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'รหัสผ่าน',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'กรอกรหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'แสดงรหัสผ่าน'
                        : 'ซ่อนรหัสผ่าน',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _rememberMe,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('จดจำการเข้าสู่ระบบ'),
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'หน้าจอนี้ยังไม่ได้เชื่อมระบบ Login จริง',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาติดต่อผู้ดูแลระบบ'),
                    ),
                  );
                },
                child: const Text('ลืมรหัสผ่านหรือต้องการความช่วยเหลือ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF0EA5E9),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 20),
          Text(
            'Laoo Meeting',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'ระบบสำหรับแสดงข้อมูลและบริหารจัดการห้องประชุม',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
          ),
          if (!compact) ...[
            const SizedBox(height: 32),
            const _FeatureLine(
              icon: Icons.calendar_month_outlined,
              text: 'ดูตารางการใช้ห้องประชุม',
            ),
            const SizedBox(height: 12),
            const _FeatureLine(
              icon: Icons.schedule_outlined,
              text: 'ตรวจสอบเวลาว่างและการจอง',
            ),
            const SizedBox(height: 12),
            const _FeatureLine(
              icon: Icons.apartment_outlined,
              text: 'รองรับหลายสาขาและหลายห้อง',
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
