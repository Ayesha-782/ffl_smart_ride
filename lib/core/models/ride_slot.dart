import 'package:flutter/material.dart';

class RideSlot {
  final String id;
  final String name;
  final String displayName;
  final String shortName;
  final TimeOfDay start;
  final TimeOfDay end;

  const RideSlot({
    required this.id,
    required this.name,
    required this.displayName,
    required this.shortName,
    required this.start,
    required this.end,
  });

  /// The 3 official FFL Smart Ride operating commute slots:
  /// 1. Morning: 07:00 – 09:00 (7:00 AM – 9:00 AM)
  /// 2. Lunch / Afternoon: 12:30 – 14:30 (12:30 PM – 2:30 PM)
  /// 3. Evening: 16:30 – 17:30 (4:30 PM – 5:30 PM)
  static const List<RideSlot> slots = [
    RideSlot(
      id: 'morning',
      name: 'morning',
      displayName: 'Morning Commute (07:00 AM – 09:00 AM)',
      shortName: 'Morning (7:00 – 9:00 AM)',
      start: TimeOfDay(hour: 7, minute: 0),
      end: TimeOfDay(hour: 9, minute: 0),
    ),
    RideSlot(
      id: 'afternoon',
      name: 'afternoon',
      displayName: 'Lunch / Afternoon (12:30 PM – 02:30 PM)',
      shortName: 'Lunch (12:30 – 2:30 PM)',
      start: TimeOfDay(hour: 12, minute: 30),
      end: TimeOfDay(hour: 14, minute: 30),
    ),
    RideSlot(
      id: 'evening',
      name: 'evening',
      displayName: 'Evening Return (04:30 PM – 05:30 PM)',
      shortName: 'Evening (4:30 – 5:30 PM)',
      start: TimeOfDay(hour: 16, minute: 30),
      end: TimeOfDay(hour: 17, minute: 30),
    ),
  ];

  static int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Returns standard 15-minute departure time options inside this slot
  List<TimeOfDay> getIntervals({int stepMinutes = 15}) {
    final List<TimeOfDay> result = [];
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    for (int m = startMin; m <= endMin; m += stepMinutes) {
      result.add(TimeOfDay(hour: m ~/ 60, minute: m % 60));
    }
    return result;
  }

  static String formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool contains(TimeOfDay time) {
    final m = _toMinutes(time);
    final s = _toMinutes(start);
    final e = _toMinutes(end);
    return m >= s && m <= e;
  }

  /// Returns matching slot for given TimeOfDay, or null if outside slots
  static RideSlot? getMatchingSlot(TimeOfDay time) {
    for (final slot in slots) {
      if (slot.contains(time)) return slot;
    }
    return null;
  }

  /// Returns matching slot for given DateTime, or null if outside slots
  static RideSlot? getMatchingSlotForDateTime(DateTime dateTime) {
    final tod = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    return getMatchingSlot(tod);
  }

  /// Check whether given time is inside any of the 3 slots
  static bool isTimeInAnySlot(TimeOfDay time) {
    return getMatchingSlot(time) != null;
  }

  /// Check whether a DateTime is in any slot
  static bool isDateTimeInAnySlot(DateTime dateTime) {
    final tod = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    return isTimeInAnySlot(tod);
  }

  /// Get end DateTime for a ride's slot
  static DateTime getSlotEndTime(DateTime dateTime) {
    final tod = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    final slot = getMatchingSlot(tod);
    if (slot != null) {
      return DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        slot.end.hour,
        slot.end.minute,
      );
    }
    return dateTime;
  }

  /// Whether an unaddressed pending ride request has passed its slot end time
  static bool isSlotExpired(DateTime leavingTime) {
    final slotEnd = getSlotEndTime(leavingTime);
    return DateTime.now().isAfter(slotEnd);
  }

  static String get formattedSlotsSummary =>
      '• Morning: 07:00 AM – 09:00 AM\n• Lunch / Afternoon: 12:30 PM – 02:30 PM\n• Evening: 04:30 PM – 05:30 PM';
}
