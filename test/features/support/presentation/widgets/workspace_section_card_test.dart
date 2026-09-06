import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/laoo_design_tokens.dart';
import 'package:laoo/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: LaooColors.background,
          body: WorkspaceSectionCard(child: Text('อาคารและชั้น')),
        ),
      ),
    );
  }

  for (final size in const [Size(1440, 900), Size(412, 924)]) {
    testWidgets('uses standard background and borderless card at $size', (
      tester,
    ) async {
      await pumpCard(tester, size);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape! as RoundedRectangleBorder;

      expect(scaffold.backgroundColor, LaooColors.background);
      expect(card.color, LaooColors.white);
      expect(card.surfaceTintColor, Colors.transparent);
      expect(card.elevation, 0);
      expect(card.margin, EdgeInsets.zero);
      expect(shape.borderRadius, BorderRadius.circular(LaooRadius.xs));
      expect(shape.side, BorderSide.none);
      expect(tester.takeException(), isNull);
    });
  }
}
