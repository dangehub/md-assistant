import 'dart:convert';

import 'package:obsi/src/core/ai_assistant/n8n_web_hook.dart';
import 'package:obsi/src/core/storage/changed_files_storage.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';

class Tools {
  final TaskManager _taskManager;

  Tools(TaskManager taskManager) : _taskManager = taskManager;

  Future<String> getTasksTool() async {
    try {
      var content = "";
      for (var task in _taskManager.tasks) {
        content += TaskParser().toTaskString(task);
        if (_taskManager.tasks.length > 1) {
          content += "\n";
        }
      }
      return content;
    } catch (e) {
      return "Error:$e";
    }
  }

  Future<String> getFileContentTool(String fileName) async {
    try {
      var file = _taskManager.storage.getFile(fileName);
      var content = await file.readAsString();
      return content;
    } catch (e) {
      return "Error:$e";
    }
  }

  Future<String> writeFileContentTool(String fileName, String content) async {
    try {
      String filePath = fileName;
      if (!fileName.contains(_taskManager.vaultPath)) {
        var vaultPath = _taskManager.vaultPath;
        filePath = "$vaultPath/$fileName";
      }

      var file = _taskManager.storage.getFile(filePath);
      if (!await file.exists()) {
        await file.create();
      }

      await file.writeAsString(content);
    } catch (e) {
      return "Error:$e";
    }
    return "File saved successfully";
  }

  Future<String> renameFileTool(String oldFileName, String newFileName) async {
    try {
      //await _taskManager.storage.renameFile(oldFileName, newFileName);
    } catch (e) {
      return "Error:$e";
    }
    return "not implemented yet"; // "File renamed successfully";
  }

  Future<String> changeTaskTool(
      String oldTaskName, String newTaskContent) async {
    try {
      var tasks = _taskManager.tasks;
      var newTask = TaskParser().build(newTaskContent);
      var foundTask =
          tasks.firstWhere((task) => task.description!.startsWith(oldTaskName));
      newTask.taskSource = foundTask.taskSource;
      await _taskManager.saveTask(newTask);
    } catch (e) {
      return "Error:$e";
    }
    return "Task changed successfully";
  }

  Future<String> findTask(String taskName) async {
    try {
      var tasks = _taskManager.tasks;
      var foundTask = tasks.firstWhere((task) =>
          task.description!.toLowerCase().startsWith(taskName.toLowerCase()));
      return TaskParser().toTaskString(foundTask);
    } catch (e) {
      return "Error:Task not found";
    }
  }

  Future<String> httpPost(String uri, String param) async {
    try {
      var response = await n8nWebHook.post(uri, param);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.transform(utf8.decoder).join();
      } else {
        return "Failed request: ${response.statusCode}";
      }
    } catch (e) {
      return "Error:$e";
    }
  }

  Future<String> httpGet(String uri) async {
    try {
      var response = await n8nWebHook.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.transform(utf8.decoder).join();
      } else {
        return "Failed request: ${response.statusCode}";
      }
    } catch (e) {
      return "Error:$e";
    }
  }

  Future<String> getFileList() async {
    try {
      List<TasksFile> files;
      if (_taskManager.storage is ChangedFilesStorage) {
        var changedFilesStorage = _taskManager.storage as ChangedFilesStorage;
        files = await changedFilesStorage.wrapped
            .getAllFiles(_taskManager.vaultPath);
      } else {
        files = await _taskManager.storage.getAllFiles(_taskManager.vaultPath);
      }
      var result = files.join("\n");
      return result;
    } catch (e) {
      return "Error:$e";
    }
  }
}
