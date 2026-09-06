import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_meeting/app/theme/laoo_design_tokens.dart';
import 'package:laoo_meeting/features/meeting/widgets/meeting_pagination_card.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );

  testWidgets('uses the standard card and empty pagination state', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const MeetingPaginationCard(
          total: 0,
          pageIndex: 0,
          pageSize: 20,
          primary: Color(0xFF168364),
          onPrevious: null,
          onNext: null,
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape! as RoundedRectangleBorder;
    expect(card.margin, EdgeInsets.zero);
    expect(card.color, LaooColors.white);
    expect(card.elevation, 0);
    expect(shape.borderRadius, BorderRadius.circular(LaooRadius.xs));
    expect(shape.side, BorderSide.none);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('0-0 จาก 0'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithIcon(OutlinedButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithIcon(OutlinedButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == LaooLayout.paginationCardHeight,
      ),
      findsOneWidget,
    );
  });

  testWidgets('enables next page and keeps the shared spacing token', (
    tester,
  ) async {
    var nextCount = 0;
    await tester.pumpWidget(
      app(
        MeetingPaginationCard(
          total: 42,
          pageIndex: 0,
          pageSize: 20,
          primary: const Color(0xFF168364),
          onPrevious: null,
          onNext: () => nextCount++,
        ),
      ),
    );

    expect(LaooLayout.captionFilterSpacing, 6);
    expect(find.text('1-20 จาก 42'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(nextCount, 1);
  });
}
