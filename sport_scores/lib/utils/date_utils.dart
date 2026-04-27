import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatMatchTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';

    return DateFormat('EEE, d MMM').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('d MMM').format(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isPast(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  }
}
