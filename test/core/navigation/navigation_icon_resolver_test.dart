import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/navigation/navigation_icon_resolver.dart';

void main() {
  group('NavigationIconResolver', () {
    test('resolves icon names returned by the navigation API', () {
      expect(
        NavigationIconResolver.resolve('admin_panel_settings_outlined'),
        Icons.admin_panel_settings_outlined,
      );
      expect(
        NavigationIconResolver.resolve('request_quote_outlined'),
        Icons.request_quote_outlined,
      );
      expect(
        NavigationIconResolver.resolve('receipt_long_outlined'),
        Icons.receipt_long_outlined,
      );
    });

    test('normalizes icon names without using menu codes or captions', () {
      expect(
        NavigationIconResolver.resolve(' Icons.Settings-Outlined '),
        Icons.settings_outlined,
      );
    });

    test('uses the caller fallback for an unknown or missing icon name', () {
      expect(
        NavigationIconResolver.resolve(
          'not_registered_in_material_icons',
          fallback: Icons.help_outline,
        ),
        Icons.help_outline,
      );
      expect(
        NavigationIconResolver.resolve(null, fallback: Icons.help_outline),
        Icons.help_outline,
      );
    });
  });
}
