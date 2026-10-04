/// Helpers for WhatMeal's Monday–Sunday meal calendar (real calendar dates).
class WeekCalendar {
  WeekCalendar._();

  static const shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const fullDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Calendar date with time stripped (local).
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday (local) of the week containing [date].
  static DateTime mondayOf(DateTime date) {
    final d = dateOnly(date);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  /// Sunday of the week containing [date].
  static DateTime sundayOf(DateTime date) =>
      mondayOf(date).add(const Duration(days: 6));

  /// 0=Mon … 6=Sun for [date].
  static int dayIndexOf(DateTime date) => dateOnly(date).weekday - 1;

  /// Absolute date for [dayIndex] (0=Mon) within the week starting [weekMonday].
  static DateTime dateForDayIndex(DateTime weekMonday, int dayIndex) =>
      dateOnly(weekMonday).add(Duration(days: dayIndex.clamp(0, 6)));

  /// Display range e.g. "Sep 28 – Oct 4".
  static String formatRange(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (s.month == e.month && s.year == e.year) {
      return '${_months[s.month - 1]} ${s.day} – ${e.day}';
    }
    if (s.year == e.year) {
      return '${_months[s.month - 1]} ${s.day} – ${_months[e.month - 1]} ${e.day}';
    }
    return '${_months[s.month - 1]} ${s.day}, ${s.year} – ${_months[e.month - 1]} ${e.day}, ${e.year}';
  }

  static String formatDayMonth(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}';

  static String weekdayName(DateTime d) => fullDays[dayIndexOf(d)];

  static String weekdayShort(DateTime d) => shortDays[dayIndexOf(d)];

  /// Whether [date] falls in the Mon–Sun week starting at [weekMonday].
  static bool isInWeek(DateTime date, DateTime weekMonday) {
    final d = dateOnly(date);
    final start = dateOnly(weekMonday);
    final end = start.add(const Duration(days: 6));
    return !d.isBefore(start) && !d.isAfter(end);
  }
}
