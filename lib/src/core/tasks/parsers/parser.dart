import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/tasks/parsers/markdown_parser.dart';
import 'package:obsi/src/core/tasks/parsers/task_note_parser.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';

abstract class Parser {
  static Future<List<Task>> readTasks(TasksFile file,
      {fileNumber = 0, String taskFilter = ""}) async {
    var content = await file.readAsString();

    return _getParser(content).internalParseTasks(file.path, content,
        fileNumber: fileNumber, taskFilter: taskFilter);
  }

  static List<Task> parseTasks(String fileName, String content,
      {int fileNumber = 0, String taskFilter = ""}) {
    return _getParser(content).internalParseTasks(fileName, content,
        fileNumber: fileNumber, taskFilter: taskFilter);
  }

  static Parser _getParser(String content) {
    var yamlResult = TaskNoteParser.extractYamlStart(content);
    if (yamlResult.item1 == 0) {
      return MarkdownParser();
    }

    final tags = TaskNoteParser.parseTags(yamlResult.item2);
    if (tags.contains('task')) {
      return TaskNoteParser();
    }

    return MarkdownParser();
  }

  List<Task> internalParseTasks(String fileName, String content,
      {int fileNumber = 0, String taskFilter = ""});
}
