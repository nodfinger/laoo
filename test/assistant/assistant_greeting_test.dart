import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/assistant/assistant_greeting.dart';

void main() {
  const morning = AssistantGreetingPeriod(
    startMinute: 360,
    endMinute: 600,
    text: 'สวัสดีตอนเช้า',
  );

  test('mode one uses the configured greeting and nickname', () {
    expect(
      assistantGreeting(
        mode: 1,
        now: DateTime(2026, 1, 1, 6),
        nickname: 'เพรส',
        pronoun: 'ผม',
        periods: [morning],
      ),
      'สวัสดีตอนเช้า คุณเพรส มีอะไรให้ผมช่วยเหลือ',
    );
  });

  test('outside the period and mode two omit the time greeting', () {
    for (final mode in [1, 2]) {
      expect(
        assistantGreeting(
          mode: mode,
          now: DateTime(2026, 1, 1, 10),
          nickname: 'เพรส',
          pronoun: 'หนู',
          periods: [morning],
        ),
        mode == 1
            ? 'คุณเพรส มีอะไรให้หนูช่วยเหลือ'
            : 'คุณ มีอะไรให้หนูช่วยเหลือ',
      );
    }
  });

  test('time parsing and overnight periods respect boundaries', () {
    expect(AssistantGreetingPeriod.parseTime('23:59'), 1439);
    expect(AssistantGreetingPeriod.parseTime('24:00'), isNull);
    expect(AssistantGreetingPeriod.parseTime('06:60'), isNull);
    const night = AssistantGreetingPeriod(
      startMinute: 1320,
      endMinute: 360,
      text: '',
    );
    expect(night.contains(1320), isTrue);
    expect(night.contains(359), isTrue);
    expect(night.contains(360), isFalse);
  });
}
