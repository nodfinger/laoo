import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_meeting/features/meeting/data/meeting_room_usage_repository.dart';
import 'package:laoo_meeting/features/meeting/meeting_feature_host.dart';
import 'package:laoo_meeting/features/meeting/pages/meeting_feedback_report_page.dart';

void main() {
  testWidgets(
    '24003 narrow report recovers from API error and hides small group',
    (tester) async {
      final repo = _FeedbackRepository();
      configureMeetingFeatureHost(
        ({required pageTitle, required activeMenu, required child}) => child,
      );
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeetingFeedbackReportPage(
              repository: repo,
              captionResolver: () async => 'ผลประเมินห้องประชุม',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('รายละเอียดเพิ่มเติม'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('ลองอีกครั้ง'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('ลองอีกครั้ง'));
      await tester.pumpAndSettle();
      expect(find.text('ลองอีกครั้ง'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ลองอีกครั้ง'));
      await tester.pumpAndSettle();
      expect(repo.feedbackCalls, 2);
      expect(find.text('ลองอีกครั้ง'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('ซ่อนรายละเอียดผล'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('ซ่อนรายละเอียดผล'), findsOneWidget);
      expect(find.textContaining('คะแนนเฉลี่ย - / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FeedbackRepository extends MeetingRoomUsageRepository {
  int feedbackCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> rooms() async => [
    {'roomId': 2, 'code': 'R2', 'name': 'ห้องทดสอบ'},
  ];

  @override
  Future<Map<String, dynamic>> feedback({
    required DateTime from,
    required DateTime to,
    String? search,
    int? roomId,
    int page = 1,
    int pageSize = 20,
  }) async {
    feedbackCalls++;
    if (feedbackCalls == 1) throw StateError('temporary failure');
    return {
      'page': 1,
      'pageSize': 20,
      'total': 1,
      'summary': {
        'rounds': 1,
        'eligible': 3,
        'submitted': 2,
        'averageRating': null,
      },
      'items': [
        {
          'roundNo': 'EV-MEETING-TEST',
          'roundName': 'ประเมินห้องประชุม',
          'status': 'CLOSED',
          'bookingNo': 'BK-TEST',
          'subject': 'ประชุมทดสอบ',
          'roomCode': 'R2',
          'roomName': 'ห้องทดสอบ',
          'meetingDate': '2026-09-29T10:00:00',
          'eligible': 3,
          'submitted': 2,
          'averageRating': null,
        },
      ],
    };
  }
}
