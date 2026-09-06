import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'core/config/app_config.dart';

void main() {
  runApp(const LaooVisitorApp());
}

class LaooVisitorApp extends StatelessWidget {
  const LaooVisitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF168364);

    return MaterialApp(
      title: 'Laoo Visitor',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        useMaterial3: true,
      ),
      home: const VisitorBootstrapPage(),
    );
  }
}

class VisitorBootstrapPage extends StatelessWidget {
  const VisitorBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const supportedScopes = LaooOwnerScope.values;

    return Scaffold(
      appBar: AppBar(title: const Text('ระบบผู้มาติดต่อ')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.badge_outlined, size: 40, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'LAOO Visitor พร้อมสำหรับเริ่มพัฒนา',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Business Route และ API จะเปิดใช้งานทีละเมนูหลังผ่านการทดสอบ',
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Project code: ${AppConfig.projectCode}'),
                    const SizedBox(height: 4),
                    const Text('API: ${AppConfig.apiBaseUrl}'),
                    const SizedBox(height: 4),
                    Text('Owner scopes: ${supportedScopes.length}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
