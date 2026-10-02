import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application notifications cannot use raw SnackBar APIs', () {
    final violations = <String>[];
    for (final root in <String>['lib', 'packages', 'projects']) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized.contains('/test/') || normalized.contains('/build/')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (RegExp(r'\bSnackBar\(').hasMatch(source) ||
            source.contains('.showSnackBar(')) {
          violations.add(normalized);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Use showTimedSnackBar or AutoDismissMessage.',
    );
  });

  test('alert timers use the shared CompanySetup duration', () {
    final violations = <String>[];
    for (final root in <String>['lib', 'packages', 'projects']) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized.contains('/test/') || normalized.contains('/build/')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains(
          'Duration(seconds: companySetupController.current?.timeAlert ?? 30)',
        )) {
          violations.add(normalized);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Use companySetupController.alertDuration.',
    );
  });
}
