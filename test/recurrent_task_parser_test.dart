import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:obsi/src/core/tasks/task.dart';

void main() {
  group('Recurrent Task Parser Tests', () {
    test('Daily recurrence', () {
      final taskString =
          """[x] Daily task ➕ 2025-03-16 🔁 every day"""; //"""- [ ] Daily task 🔁 every day📅 2024-04-07""";
      final task = TaskParser().build(taskString);
      expect(task.description, 'Daily task');
      expect(task.recurrenceRule, 'every day');
    });

    test('Weekly recurrence', () {
      final taskString = '- [ ] Weekly task 🔁 every week';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Weekly task');
      expect(task.recurrenceRule, 'every week');
    });

    test('Monthly recurrence', () {
      final taskString = '- [ ] Monthly task 🔁 every month';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Monthly task');
      expect(task.recurrenceRule, 'every month');
    });

    test('Yearly recurrence', () {
      final taskString = '- [ ] Yearly task 🔁 every year';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Yearly task');
      expect(task.recurrenceRule, 'every year');
    });

    test('Weekday recurrence', () {
      final taskString = '- [ ] Weekday task 🔁 every weekday';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Weekday task');
      expect(task.recurrenceRule, 'every weekday');
    });

    test('Specific day recurrence (Monday)', () {
      final taskString = '- [ ] Monday task 🔁 every Monday';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Monday task');
      expect(task.recurrenceRule, 'every Monday');
    });

    // test('Invalid recurrence rule', () {
    //   final taskString = '- [ ] Invalid task 🔁 every fortnight';
    //   expect(() => TaskParser().build(taskString), throwsArgumentError);
    // });

    test('Daily recurrence with interval', () {
      final taskString = '- [ ] Daily task with interval 🔁 every day 3';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Daily task with interval');
      expect(task.recurrenceRule, 'every day 3');
    });

    test('Weekly recurrence with interval', () {
      final taskString = '- [ ] Weekly task with interval 🔁 every week 2';
      final task = TaskParser().build(taskString);
      expect(task.description, 'Weekly task with interval');
      expect(task.recurrenceRule, 'every week 2');
    });
  });
}
