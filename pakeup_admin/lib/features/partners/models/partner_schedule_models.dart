import 'package:flutter/material.dart';

/// Day-of-week: 1 = Monday … 7 = Sunday.
class DaySchedule {
  const DaySchedule({
    required this.dayOfWeek,
    this.openTime,
    this.closeTime,
    this.isClosed = false,
  });

  final int dayOfWeek;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;
  final bool isClosed;

  static const dayLabels = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  static const dayShortLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  String get dayLabel => dayLabels[dayOfWeek] ?? 'Day $dayOfWeek';
  String get dayShortLabel => dayShortLabels[dayOfWeek] ?? '?';

  String get summary {
    if (isClosed) return 'Closed';
    if (openTime == null || closeTime == null) return 'Not set';
    return '${formatTime(openTime!)} – ${formatTime(closeTime!)}';
  }

  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  DaySchedule copyWith({
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
    bool? isClosed,
  }) {
    return DaySchedule(
      dayOfWeek: dayOfWeek,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'open_time': isClosed ? null : _timeToString(openTime),
        'close_time': isClosed ? null : _timeToString(closeTime),
        'is_closed': isClosed,
      };

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    final closed = json['is_closed'] as bool? ?? false;
    return DaySchedule(
      dayOfWeek: json['day_of_week'] as int? ?? 1,
      openTime: closed ? null : _parseTime(json['open_time']),
      closeTime: closed ? null : _parseTime(json['close_time']),
      isClosed: closed,
    );
  }

  static List<DaySchedule> defaults() {
    const open = TimeOfDay(hour: 9, minute: 0);
    const close = TimeOfDay(hour: 21, minute: 0);
    return [
      for (var d = 1; d <= 7; d++)
        DaySchedule(
          dayOfWeek: d,
          openTime: open,
          closeTime: close,
          isClosed: d == 7,
        ),
    ];
  }

  static List<DaySchedule> parseList(dynamic raw) {
    if (raw is! List || raw.isEmpty) return defaults();
    final parsed = raw
        .map((e) => DaySchedule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return mergeWithDefaults(parsed);
  }

  static List<DaySchedule> mergeWithDefaults(List<DaySchedule> items) {
    final byDay = {for (final s in items) s.dayOfWeek: s};
    return [
      for (var d = 1; d <= 7; d++)
        byDay[d] ?? DaySchedule(dayOfWeek: d, isClosed: true),
    ];
  }

  static String? _timeToString(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay? _parseTime(dynamic raw) {
    if (raw == null) return null;
    final parts = raw.toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

List<Map<String, dynamic>> schedulesToRpc(List<DaySchedule> schedules) =>
    schedules.map((s) => s.toJson()).toList();
