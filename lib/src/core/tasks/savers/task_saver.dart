import 'dart:io';

import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/core/tasks/savers/task_note_saver.dart';

class TaskSaver {
  TasksFileStorage storage;
  TaskSaver(this.storage);

  Future<String> saveTaskNote(Task task) async {
    var taskNoteSaver = TaskNoteSaver();
    return taskNoteSaver.toTaskNoteString(task);
  }

  Future<String?> saveTasks(List<Task> tasks,
      {String? filePath,
      String dateTemplate = "yyyy-MM-dd",
      String taskFilter = ""}) async {
    if (tasks[0].taskSource == null && filePath == null) {
      return null;
    }

    var fileName = filePath ?? tasks[0].taskSource!.fileName;
    var file = storage.getFile(fileName);
    var fileExists = await file.exists();
    if (!fileExists) {
      await file.create();
    }

    String savedContent = "";
    if (tasks[0].taskSource != null &&
        tasks[0].taskSource!.type == TaskType.taskNote) {
      savedContent = await saveTaskNote(tasks[0]);
    } else {
      var content = await file.readAsString();
      content =
          _createNewContent(tasks, content, filePath, dateTemplate, taskFilter);
      savedContent = content;
    }
    Logger().i("Content saved: $savedContent");
    await file.writeAsString(savedContent);
    return savedContent;
  }

  String _createNewContent(List<Task> tasks, String content, String? filePath,
      String dateTemplate, String taskFilter) {
    int taskOffset = tasks[0].taskSource == null
        ? content.length
        : tasks[0].taskSource!.offset;
    var taskLength =
        tasks[0].taskSource == null ? 0 : tasks[0].taskSource!.length;

    var beginningOfFileContent = content.substring(0, taskOffset);
    var endOfTask = taskOffset + taskLength;
    var endOfFileContent = content.substring(endOfTask);

    // If this is a new task then add it on a new line
    String serializedTask = filePath != null ? "\n" : "";
    for (var task in tasks) {
      serializedTask += TaskParser().toTaskString(task,
          dateTemplate: dateTemplate, taskFilter: taskFilter);
      if (tasks.length > 1) {
        serializedTask += "\n";
      }
    }

    var result = beginningOfFileContent + serializedTask + endOfFileContent;
    return result;
  }

  Future<void> deleteTask(Task task) async {
    if (task.taskSource == null) return;
    var fileName = task.taskSource!.fileName;
    var file = storage.getFile(fileName);
    if (!await file.exists()) return;

    var content = await file.readAsString();
    int taskOffset = task.taskSource!.offset;
    int taskLength = task.taskSource!.length;

    if (taskOffset < 0 || taskOffset + taskLength > content.length) {
      Logger().e("Invalid task offset/length for deletion");
      return;
    }

    // Try to remove the trailing newline if it exists to avoid empty lines
    var endOffset = taskOffset + taskLength;
    if (endOffset < content.length && content[endOffset] == '\n') {
      endOffset++;
    }

    var beginning = content.substring(0, taskOffset);
    var end = content.substring(endOffset);

    var newContent = beginning + end;
    await file.writeAsString(newContent);
  }
}
