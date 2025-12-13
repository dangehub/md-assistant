import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/parsers/task_note_parser.dart';
import 'package:obsi/src/core/tasks/savers/task_note_saver.dart';
import 'package:obsi/src/core/tasks/task.dart';

void main() {
  group('TaskNote Round-trip Integration Tests', () {
    late TaskNoteParser parser;
    late TaskNoteSaver saver;

    setUp(() {
      parser = TaskNoteParser();
      saver = TaskNoteSaver();
    });

    group('Scheduled Date with Time Round-trip', () {
      test('should preserve scheduled date without time through save and parse',
          () {
        // Create a task with date only
        final originalTask = Task(
          'Task with date only',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 11, 3, 10, 0, 0),
          scheduled: DateTime(2025, 11, 3),
          scheduledTime: false,
        );

        // Save to string
        final savedContent = saver.toTaskNoteString(originalTask);

        // Parse back
        final parsedTask = parser.parseTaskNote('test.md', savedContent);

        // Verify
        expect(parsedTask, isNotNull);
        expect(parsedTask!.scheduled, isNotNull);
        expect(parsedTask.scheduled!.year, equals(2025));
        expect(parsedTask.scheduled!.month, equals(11));
        expect(parsedTask.scheduled!.day, equals(3));
        expect(parsedTask.scheduledTime, isFalse);
        expect(parsedTask.status, equals(TaskStatus.todo));
        expect(parsedTask.priority, equals(TaskPriority.normal));
      });

      test('should preserve scheduled date with time through save and parse',
          () {
        // Create a task with date and time
        final originalTask = Task(
          'Task with date and time',
          status: TaskStatus.inprogress,
          priority: TaskPriority.high,
          created: DateTime(2025, 11, 3, 10, 0, 0),
          scheduled: DateTime(2025, 11, 3, 19, 30, 45),
          scheduledTime: true,
        );

        // Save to string
        final savedContent = saver.toTaskNoteString(originalTask);

        // Parse back
        final parsedTask = parser.parseTaskNote('test.md', savedContent);

        // Verify
        expect(parsedTask, isNotNull);
        expect(parsedTask!.scheduled, isNotNull);
        expect(parsedTask.scheduled!.year, equals(2025));
        expect(parsedTask.scheduled!.month, equals(11));
        expect(parsedTask.scheduled!.day, equals(3));
        expect(parsedTask.scheduled!.hour, equals(19));
        expect(parsedTask.scheduled!.minute, equals(30));
        expect(parsedTask.scheduled!.second, equals(45));
        expect(parsedTask.scheduledTime, isTrue);
        expect(parsedTask.status, equals(TaskStatus.inprogress));
        expect(parsedTask.priority, equals(TaskPriority.high));
      });

      test('should handle multiple round-trips with time', () {
        // Create original task
        final task1 = Task(
          'Multi round-trip task',
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          created: DateTime(2024, 12, 25, 8, 0, 0),
          scheduled: DateTime(2024, 12, 25, 14, 30, 0),
          scheduledTime: true,
        );

        // First round-trip
        final saved1 = saver.toTaskNoteString(task1);
        final parsed1 = parser.parseTaskNote('test.md', saved1);

        // Second round-trip
        final saved2 = saver.toTaskNoteString(parsed1!);
        final parsed2 = parser.parseTaskNote('test.md', saved2);

        // Third round-trip
        final saved3 = saver.toTaskNoteString(parsed2!);
        final parsed3 = parser.parseTaskNote('test.md', saved3);

        // Verify final result matches original
        expect(parsed3, isNotNull);
        expect(parsed3!.scheduled!.year, equals(2024));
        expect(parsed3.scheduled!.month, equals(12));
        expect(parsed3.scheduled!.day, equals(25));
        expect(parsed3.scheduled!.hour, equals(14));
        expect(parsed3.scheduled!.minute, equals(30));
        expect(parsed3.scheduled!.second, equals(0));
        expect(parsed3.scheduledTime, isTrue);
      });

      test('should handle edge case times correctly', () {
        final testCases = [
          // Midnight
          DateTime(2025, 1, 1, 0, 0, 0),
          // End of day
          DateTime(2025, 1, 1, 23, 59, 59),
          // Noon
          DateTime(2025, 6, 15, 12, 0, 0),
          // Random time
          DateTime(2025, 3, 20, 15, 45, 30),
        ];

        for (final scheduledTime in testCases) {
          final task = Task(
            'Edge case time test',
            status: TaskStatus.todo,
            priority: TaskPriority.normal,
            created: DateTime(2025, 1, 1),
            scheduled: scheduledTime,
            scheduledTime: true,
          );

          final saved = saver.toTaskNoteString(task);
          final parsed = parser.parseTaskNote('test.md', saved);

          expect(parsed, isNotNull);
          expect(parsed!.scheduled!.hour, equals(scheduledTime.hour));
          expect(parsed.scheduled!.minute, equals(scheduledTime.minute));
          expect(parsed.scheduled!.second, equals(scheduledTime.second));
          expect(parsed.scheduledTime, isTrue);
        }
      });

      test('should handle null scheduled date correctly', () {
        final task = Task(
          'Task without scheduled date',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: null,
          scheduledTime: false,
        );

        final saved = saver.toTaskNoteString(task);
        final parsed = parser.parseTaskNote('test.md', saved);

        expect(parsed, isNotNull);
        expect(parsed!.scheduled, isNull);
        expect(parsed.scheduledTime, isFalse);
      });

      test('should preserve all task properties with scheduled time', () {
        final task = Task(
          'Complete task with time #work #urgent',
          status: TaskStatus.done,
          priority: TaskPriority.highest,
          created: DateTime(2025, 11, 1, 9, 0, 0),
          scheduled: DateTime(2025, 11, 3, 17, 0, 0),
          scheduledTime: true,
        );

        final saved = saver.toTaskNoteString(task);
        final parsed = parser.parseTaskNote('test.md', saved);

        expect(parsed, isNotNull);
        expect(parsed!.description, contains('Complete task with time'));
        expect(parsed.status, equals(TaskStatus.done));
        expect(parsed.priority, equals(TaskPriority.highest));
        expect(parsed.scheduled!.hour, equals(17));
        expect(parsed.scheduled!.minute, equals(0));
        expect(parsed.scheduledTime, isTrue);
        expect(parsed.tags, containsAll(['work', 'urgent']));
      });

      test('should handle different date formats in same file', () {
        // Task with time
        final taskWithTime = Task(
          'Task with time',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 11, 3, 19, 0, 0),
          scheduledTime: true,
        );

        // Task without time
        final taskWithoutTime = Task(
          'Task without time',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 11, 4),
          scheduledTime: false,
        );

        // Save both
        final saved1 = saver.toTaskNoteString(taskWithTime);
        final saved2 = saver.toTaskNoteString(taskWithoutTime);

        // Parse both
        final parsed1 = parser.parseTaskNote('test1.md', saved1);
        final parsed2 = parser.parseTaskNote('test2.md', saved2);

        // Verify both
        expect(parsed1!.scheduledTime, isTrue);
        expect(parsed1.scheduled!.hour, equals(19));
        expect(parsed2!.scheduledTime, isFalse);
        expect(parsed2.scheduled!.year, equals(2025));
        expect(parsed2.scheduled!.month, equals(11));
        expect(parsed2.scheduled!.day, equals(4));
      });
    });
  });
}
