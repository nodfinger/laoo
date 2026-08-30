import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStartupProvider = Provider<AppStartupService>(
  (ref) => AppStartupService(),
);

class AppStartupService {
  Future<void> initialize() async {
    // เริ่มต้นงานของแอปพลิเคชัน เช่น โหลดการตั้งค่าเริ่มต้น
    await Future<void>.delayed(Duration.zero);
  }
}
