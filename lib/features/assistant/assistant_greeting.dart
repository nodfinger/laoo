/// A company-defined greeting interval. Start is inclusive, end is exclusive.
class AssistantGreetingPeriod {
  const AssistantGreetingPeriod({
    required this.startMinute,
    required this.endMinute,
    required this.text,
  });

  final int startMinute;
  final int endMinute;
  final String text;

  bool contains(int minute) {
    if (startMinute < 0 ||
        startMinute >= 1440 ||
        endMinute < 0 ||
        endMinute >= 1440 ||
        startMinute == endMinute) {
      return false;
    }
    return startMinute < endMinute
        ? minute >= startMinute && minute < endMinute
        : minute >= startMinute || minute < endMinute;
  }

  static int? parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }
}

String assistantGreeting({
  required int mode,
  required DateTime now,
  required String nickname,
  required String pronoun,
  required List<AssistantGreetingPeriod> periods,
}) {
  final name = nickname.trim();
  final who = mode == 2 || name.isEmpty ? 'คุณ' : 'คุณ$name';
  final matching = mode == 1
      ? periods.where((p) => p.contains(now.hour * 60 + now.minute))
      : const Iterable<AssistantGreetingPeriod>.empty();
  final greeting = matching.isEmpty ? '' : matching.first.text.trim();
  final intro = greeting.isEmpty ? who : '$greeting $who';
  final self = pronoun.trim();
  return '$intro มีอะไรให้${self.isEmpty ? 'ผู้ช่วย' : self}ช่วยเหลือ';
}
