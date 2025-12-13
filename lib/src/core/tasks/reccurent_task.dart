import 'package:obsi/src/core/tasks/task_manager.dart';

class RecurrentTask {
  static List<String> options = [
    'None',
    'every day',
    'every week',
    'every month',
    'every year',
    'every weekday',
    'every Monday',
    'every Tuesday',
    'every Wednesday',
    'every Thursday',
    'every Friday',
    'every Saturday',
    'every Sunday',
  ];
  static DateTime calculateNextOccurrence(
      DateTime lastDate, String recurrenceRule) {
    final ruleParts = recurrenceRule.split(' ');
    if (ruleParts.length < 2 || ruleParts[0].toLowerCase() != 'every') {
      throw ArgumentError('Invalid recurrence rule format.');
    }

    final frequency = ruleParts[1].toLowerCase();
    int interval = 1;
    if (ruleParts.length == 3) {
      interval = int.tryParse(ruleParts[2]) ?? 1;
    }

    switch (frequency) {
      case 'day':
      case 'days':
        return lastDate.add(Duration(days: interval));
      case 'week':
      case 'weeks':
        return lastDate.add(Duration(days: 7 * interval));
      case 'month':
      case 'months':
        return DateTime(lastDate.year, lastDate.month + interval, lastDate.day);
      case 'year':
      case 'years':
        return DateTime(lastDate.year + interval, lastDate.month, lastDate.day);
      case 'weekday':
      case 'weekdays':
        DateTime nextDate = lastDate;
        for (int i = 0; i < interval; i++) {
          nextDate = nextDate.add(Duration(days: 1));
          while (nextDate.weekday == DateTime.saturday ||
              nextDate.weekday == DateTime.sunday) {
            nextDate = nextDate.add(Duration(days: 1));
          }
        }
        return nextDate;
      default:
        // Handle specific days like 'Monday', 'Tuesday', etc.
        final weekdays = {
          'monday': DateTime.monday,
          'tuesday': DateTime.tuesday,
          'wednesday': DateTime.wednesday,
          'thursday': DateTime.thursday,
          'friday': DateTime.friday,
          'saturday': DateTime.saturday,
          'sunday': DateTime.sunday,
        };
        if (weekdays.containsKey(frequency)) {
          DateTime nextDate = lastDate.add(Duration(days: 1));
          while (nextDate.weekday != weekdays[frequency]) {
            nextDate = nextDate.add(Duration(days: 1));
          }
          return nextDate;
        } else {
          throw ArgumentError('Unsupported recurrence frequency.');
        }
    }
  }
}
