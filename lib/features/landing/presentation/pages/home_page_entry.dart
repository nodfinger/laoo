import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/pages/login_page.dart';
import '../../data/home_page_config.dart';
import 'landing_page.dart';
import 'external_home_frame.dart';

class HomePageEntry extends StatefulWidget {
  const HomePageEntry({super.key, this.service, this.openUrl});
  @visibleForTesting
  static HomePageConfigService Function() serviceFactory =
      HomePageConfigService.new;
  final HomePageConfigService? service;
  final Future<bool> Function(Uri uri)? openUrl;

  @override
  State<HomePageEntry> createState() => _HomePageEntryState();
}

class _HomePageEntryState extends State<HomePageEntry> {
  HomePageConfig? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await (widget.service ?? HomePageEntry.serviceFactory())
        .load();
    if (!mounted) return;
    if (config.mode == 2 &&
        config.externalUrl != null &&
        !config.showLoginButton) {
      try {
        final opened =
            await (widget.openUrl?.call(config.externalUrl!) ??
                launchUrl(config.externalUrl!, webOnlyWindowName: '_self'));
        if (opened) return;
      } catch (_) {
        // Display the existing landing page if opening the configured URL fails.
      }
      if (!mounted) return;
      setState(
        () => _config = const HomePageConfig(
          mode: 3,
          message: 'ไม่สามารถเปิด URL หน้าแรกได้ จึงแสดงหน้าค้นหาช่าง',
        ),
      );
      return;
    }
    setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (config.mode == 1) {
      return LoginPage(homePageConfig: config, openUrl: widget.openUrl);
    }
    if (config.mode == 2 &&
        config.externalUrl != null &&
        config.showLoginButton) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        config.externalUrl!,
                        webOnlyWindowName: '_blank',
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('เปิดเว็บไซต์'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.login),
                      label: const Text('เข้าสู่ระบบ'),
                    ),
                  ],
                ),
              ),
              Expanded(child: ExternalHomeFrame(url: config.externalUrl!)),
            ],
          ),
        ),
      );
    }
    if (config.mode == 4) {
      return const Scaffold(body: Center(child: Text('Intranet')));
    }
    if (config.message == null) return const LandingPage();
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(config.message!, textAlign: TextAlign.center),
            ),
          ),
        ),
        const Expanded(child: LandingPage()),
      ],
    );
  }
}
