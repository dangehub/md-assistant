import 'dart:isolate';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
//import 'package:obsiditasks/core/tasks/task_manager.dart';

// Simple persistent isolate worker holder
class TaskWorker {
  final Isolate isolate;
  final SendPort sendPort;

  TaskWorker._(this.isolate, this.sendPort);

  static TaskWorker? _instance;

  static Future<TaskWorker> ensureStarted() async {
    if (_instance != null) return _instance!;

    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn(_taskWorkerEntry, readyPort.sendPort);
    final sendPort = await readyPort.first as SendPort;
    readyPort.close();
    _instance = TaskWorker._(isolate, sendPort);
    return _instance!;
  }

  static Future<void> dispose() async {
    _instance?.isolate.kill(priority: Isolate.immediate);
    _instance = null;
  }
}

// Data classes for isolate communication (result only)

class TaskProcessingResult {
  final List<Task> tasks;
  final List<String> allTags;
  final Object? error;

  TaskProcessingResult({
    required this.tasks,
    required this.allTags,
    this.error,
  });
}

// Persistent worker isolate entry point with chunked messaging
void _taskWorkerEntry(SendPort mainSendPort) async {
  final port = ReceivePort();
  // Send our SendPort back to the main isolate
  mainSendPort.send(port.sendPort);

  await for (final message in port) {
    if (message is Map) {
      final String? type = message['type'] as String?;
      if (type == 'process') {
        final int id = message['id'] as int;
        final List<dynamic> files = message['files'] as List<dynamic>;
        final String taskFilter = message['taskFilter'] as String;
        final bool todoOnly = message['todoOnly'] as bool;
        final DateTime? forDateOnly = message['forDateOnly'] as DateTime?;
        final SendPort replyPort = message['replyPort'] as SendPort;

        try {
          int fileIndex = 0;
          for (final dynamic file in files) {
            try {
              final iterTasks = await Parser.readTasks(file,
                  fileNumber: fileIndex, taskFilter: taskFilter);
              final Set<String> tags = <String>{};
              final filteredTasks =
                  filterAndCollect(iterTasks, todoOnly, forDateOnly, tags);

              // Send a batch per file
              replyPort.send({
                'type': 'batch',
                'id': id,
                'tasks': filteredTasks,
                'tags': tags.toList(),
              });
            } catch (e) {
              Logger().e("Error in file ${file.toString()}", error: e);
            }
            fileIndex++;
          }
          //await Future.delayed(Duration(milliseconds: 5000));
          // Signal completion
          replyPort.send({'type': 'done', 'id': id});
        } catch (e) {
          replyPort.send({'type': 'error', 'id': id, 'error': e});
        }
      }
    }
  }
}

// Helper function to filter tasks in isolate (similar to _addFilteredTasks logic)
List<Task> _filterTasksInIsolate(
    List<Task> inputTasks, bool todoOnly, DateTime? forDate) {
  if (!todoOnly) {
    return inputTasks;
  }

  return inputTasks.where((element) {
    return (element.description != null &&
        element.description != "" &&
        (element.status == TaskStatus.todo ||
            TaskManager.sameDate(element.created, forDate) ||
            TaskManager.sameDate(element.start, forDate) ||
            TaskManager.sameDate(element.done, forDate) ||
            TaskManager.sameDate(element.scheduled, forDate) ||
            TaskManager.sameDate(element.cancelled, forDate)));
  }).toList();
}

// Helper to filter tasks and collect tags into the provided sink
List<Task> filterAndCollect(List<Task> inputTasks, bool todoOnly,
    DateTime? forDate, Set<String> tagSink) {
  final filtered = _filterTasksInIsolate(inputTasks, todoOnly, forDate);
  for (final task in filtered) {
    tagSink.addAll(task.tags);
  }
  return filtered;
}
