import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/parsers/task_note_parser.dart';

void main() {
  group('TaskNoteParser', () {
    late TaskNoteParser parser;

    setUp(() {
      parser = TaskNoteParser();
    });

    group('Valid YAML Front Matter', () {
      test('should return Task for complete valid YAML header', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

This is the note content.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.description, contains('This is the note content'));
        expect(result.status.name, equals('todo'));
      });

      test('should return Task with different valid status values', () {
        const content = '''---
status: closed
priority: high
scheduled: 2024-12-25
dateCreated: 2024-01-01T00:00:00.000Z
dateModified: 2024-12-31T23:59:59.999Z
tags:
  - urgent
  - work
---

Note content here.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        // 'closed' maps to default status (todo) per _parseStatus()
        expect(result!.status.name, equals('todo'));
        expect(result.priority.name, equals('high'));
        expect(result.tags, containsAll(['urgent', 'work']));
      });

      test('should return Task with different priority values', () {
        const content = '''---
status: open
priority: low
scheduled: 2025-01-01
dateCreated: 2025-01-01T12:00:00.000+00:00
dateModified: 2025-01-01T12:00:00.000+00:00
tags:
  - personal
---

Content goes here.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.priority.name, equals('low'));
      });

      test('should return Task with extra whitespace in YAML', () {
        const content = '''---
status:   open
priority:    normal  
scheduled:  2025-08-16
dateCreated:  2025-08-16T22:33:28.696+02:00
dateModified:   2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Note with extra spaces.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.description, contains('Note with extra spaces'));
      });

      test('should return Task with multiple tags', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
  - important
  - work
  - project
---

Multi-tag note.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        // Tags are appended then cleaned from description by Task._parseTags()
        expect(result!.description, equals('Multi-tag note.'));
        expect(
            result.tags, containsAll(['task', 'important', 'work', 'project']));
      });
    });

    group('Invalid YAML Front Matter', () {
      test('should return null for empty content', () {
        final result = parser.parseTaskNote('test.md', '');
        expect(result, isNull);
      });

      test('should return null for content without opening delimiter', () {
        const content = '''status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

No opening delimiter.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNull);
      });

      test('should return null for content without closing delimiter', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task

No closing delimiter.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNull);
      });

      test('should return null for content with only opening delimiter', () {
        const content = '---';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle content with multiple YAML blocks', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Some content here.

---
Another block that should be ignored.
---''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
      });

      test('should handle content with --- in the middle of text', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

This content has --- in the middle of a line.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.description,
            contains('This content has --- in the middle of a line'));
      });

      test('should handle very long content', () {
        final longContent = 'A' * 10000;
        final content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

$longContent''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.description, isNotNull);
        expect(result.description!.length, equals(10000));
      });
    });

    group('Content Extraction with parseTaskNoteWithContent', () {
      test('should extract task content after YAML front matter', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

this is content of the task''';

        final result = parser.parseTaskNoteWithContent('test.md', content);
        expect(result, isNotNull);
        expect(result!.taskContent, equals('this is content of the task'));
        expect(result.fileName, equals('test.md'));
        expect(result.fileNumber, equals(0));
      });

      test('should extract multiline task content', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

This is a multiline task content.

It has multiple paragraphs and should be preserved exactly.

- List item 1
- List item 2''';

        final result = parser.parseTaskNoteWithContent('test.md', content);
        expect(result, isNotNull);
        expect(
            result!.taskContent, contains('This is a multiline task content.'));
        expect(result.taskContent, contains('It has multiple paragraphs'));
        expect(result.taskContent, contains('- List item 1'));
        expect(result.taskContent, contains('- List item 2'));
      });

      test('should handle empty content after YAML', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---''';

        final result = parser.parseTaskNoteWithContent('test.md', content);
        expect(result, isNotNull);
        expect(result!.taskContent, equals(''));
      });

      test('should handle content with whitespace after YAML', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---


   Task content with leading whitespace   


''';

        final result = parser.parseTaskNoteWithContent('test.md', content);
        expect(result, isNotNull);
        expect(result!.taskContent,
            equals('Task content with leading whitespace'));
      });

      test('should extract YAML content correctly', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task content here''';

        final result = parser.parseTaskNoteWithContent('test.md', content);
        expect(result, isNotNull);
        expect(result!.yamlContent, contains('status: open'));
        expect(result.yamlContent, contains('priority: normal'));
        expect(result.yamlContent, contains('scheduled: 2025-08-16'));
        expect(result.yamlContent, contains('tags:'));
        expect(result.yamlContent, contains('- task'));
      });

      test('should handle content with markdown formatting', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

# Task Title

This is **bold** text and *italic* text.

## Subtask

- [x] Completed subtask
- [ ] Pending subtask

```code
Some code block
```''';

        final result = parser.parseTaskNoteWithContent('test.md', content);
        expect(result, isNotNull);
        expect(result!.taskContent, contains('# Task Title'));
        expect(result.taskContent, contains('**bold**'));
        expect(result.taskContent, contains('- [x] Completed subtask'));
        expect(result.taskContent, contains('```code'));
      });
    });

    group('Scheduled Date with Time', () {
      test('should parse scheduled date without time', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-11-03
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task with date only.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNotNull);
        expect(result.scheduled!.year, equals(2025));
        expect(result.scheduled!.month, equals(11));
        expect(result.scheduled!.day, equals(3));
        expect(result.scheduledTime, isFalse);
      });

      test('should parse scheduled date with time', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-11-03N19:00:00
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task with date and time.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNotNull);
        expect(result.scheduled!.year, equals(2025));
        expect(result.scheduled!.month, equals(11));
        expect(result.scheduled!.day, equals(3));
        expect(result.scheduled!.hour, equals(19));
        expect(result.scheduled!.minute, equals(0));
        expect(result.scheduled!.second, equals(0));
        expect(result.scheduledTime, isTrue);
      });

      test('should parse scheduled date with different time values', () {
        const content = '''---
status: open
priority: normal
scheduled: 2024-12-25N08:30:45
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task with specific time.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNotNull);
        expect(result.scheduled!.year, equals(2024));
        expect(result.scheduled!.month, equals(12));
        expect(result.scheduled!.day, equals(25));
        expect(result.scheduled!.hour, equals(8));
        expect(result.scheduled!.minute, equals(30));
        expect(result.scheduled!.second, equals(45));
        expect(result.scheduledTime, isTrue);
      });

      test('should parse scheduled date with midnight time', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-01-01N00:00:00
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task at midnight.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNotNull);
        expect(result.scheduled!.hour, equals(0));
        expect(result.scheduled!.minute, equals(0));
        expect(result.scheduled!.second, equals(0));
        expect(result.scheduledTime, isTrue);
      });

      test('should parse scheduled date with end of day time', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-06-15N23:59:59
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task at end of day.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNotNull);
        expect(result.scheduled!.hour, equals(23));
        expect(result.scheduled!.minute, equals(59));
        expect(result.scheduled!.second, equals(59));
        expect(result.scheduledTime, isTrue);
      });

      test('should handle missing scheduled field', () {
        const content = '''---
status: open
priority: normal
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task without scheduled date.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNull);
        expect(result.scheduledTime, isFalse);
      });

      test('should handle empty scheduled field', () {
        const content = '''---
status: open
priority: normal
scheduled: 
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Task with empty scheduled.''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.scheduled, isNull);
        expect(result.scheduledTime, isFalse);
      });
    });

    group('Parameter Handling', () {
      test('should handle different fileName parameter', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Content with different filename.''';

        final result = parser.parseTaskNote('different_file.md', content);
        expect(result, isNotNull);

        final resultWithContent =
            parser.parseTaskNoteWithContent('different_file.md', content);
        expect(resultWithContent, isNotNull);
        expect(resultWithContent!.fileName, equals('different_file.md'));
      });

      test('should handle different fileNumber parameter', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Content with different file number.''';

        final result = parser.parseTaskNote('test.md', content, fileNumber: 5);
        expect(result, isNotNull);

        final resultWithContent =
            parser.parseTaskNoteWithContent('test.md', content, fileNumber: 5);
        expect(resultWithContent, isNotNull);
        expect(resultWithContent!.fileNumber, equals(5));
      });

      test('should handle different taskFilter parameter', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

Content with task filter.''';

        final result =
            parser.parseTaskNote('test.md', content, taskFilter: '#work');
        expect(result, isNotNull);

        final resultWithContent = parser
            .parseTaskNoteWithContent('test.md', content, taskFilter: '#work');
        expect(resultWithContent, isNotNull);
        expect(resultWithContent!.taskContent,
            equals('Content with task filter.'));
      });
    });

    group('Inline Tag Format', () {
      test('should parse inline tag format correctly', () {
        const content = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags: task
---

Task with inline tag format''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.tags, equals(['task']));
        expect(result.description, equals('Task with inline tag format'));
      });

      test('should handle inline tag with extra whitespace', () {
        const content = '''---
status: open
priority: normal
tags:   task   
---

Task content''';

        final result = parser.parseTaskNote('test.md', content);
        expect(result, isNotNull);
        expect(result!.tags, equals(['task']));
      });
    });
  });
}
