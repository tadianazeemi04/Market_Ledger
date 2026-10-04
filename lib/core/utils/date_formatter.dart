import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _greetingDateFormat = DateFormat('EEEE, dd MMM yyyy');

  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return _dateTimeFormat.format(date);
  }

  static String formatTime(DateTime? date) {
    if (date == null) return 'N/A';
    return _timeFormat.format(date);
  }

  static String formatFullGreetingDate(DateTime date) {
    return _greetingDateFormat.format(date);
  }

  static String formatRelativeOrDate(DateTime? date) {
    if (date == null) return 'Never';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);

    if (aDate == today) {
      return 'Today, ${_timeFormat.format(date)}';
    } else if (aDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return _dateFormat.format(date);
    }
  }

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
