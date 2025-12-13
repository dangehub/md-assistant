import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/notification_manager.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
part 'task_editor_state.dart';

class TaskEditorCubit extends Cubit<TaskEditorState> {
  final TaskManager _taskManager;
  final String? _createTasksPath;
  final Task _currentTask;
  String? _currentDescription;

  TaskEditorCubit(this._taskManager, {Task? task, String? createTasksPath})
      : _createTasksPath = createTasksPath,
        _currentTask = task ?? Task(""),
        _currentDescription = task?.description,
        super(TaskEditorInitial(task));

  Future<void> saveTask(BuildContext context) async {
    try {
      _currentTask.description = _currentDescription;
      await _taskManager.saveTask(_currentTask, filePath: _createTasksPath);

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void setPriority(TaskPriority priority) {
    _currentTask.priority = priority;
    emit(TaskEditorInitial(_currentTask));
  }

  /// Gets all available tags from TaskManager
  List<String> getAllTags() {
    return _taskManager.allTags;
  }

  /// Gets tags for the current task
  List<String> getCurrentTaskTags() {
    return _currentTask.tags;
  }

  /// Toggles a tag for the current task
  void toggleTag(String tag) {
    final currentTags = List<String>.from(_currentTask.tags);

    if (currentTags.contains(tag)) {
      // Remove tag from the list
      currentTags.remove(tag);
    } else {
      // Add tag to the list
      currentTags.add(tag);
    }

    _currentTask.tags = currentTags;
    emit(TaskEditorInitial(_currentTask));
  }

  void setDescription(String cleanDescription) {
    _currentDescription = cleanDescription;
    emit(TaskEditorInitial(_currentTask));
  }

  void setStatus(TaskStatus status) {
    _currentTask.status = status;
    emit(TaskEditorInitial(_currentTask));
  }

  void setScheduledDate(DateTime? date) {
    _currentTask.scheduled = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setScheduledNotificationDateTime(DateTime? date) {
    if (date != null) {
      var notificationManager = NotificationManager.getInstance();

      notificationManager.requestExactAlarmPermission();

      _currentTask.scheduled = date;
      _currentTask.scheduledTime = true;
    } else {
      // null date in this method means - no scheduled time
      _currentTask.scheduledTime = false;
    }
    emit(TaskEditorInitial(_currentTask));
  }

  void setDueDate(DateTime? date) {
    _currentTask.due = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setRecurrenceRule(String? rule) {
    _currentTask.recurrenceRule = rule;
    emit(TaskEditorInitial(_currentTask));
  }

  void setStartDate(DateTime? date) {
    _currentTask.start = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setCancelledDate(DateTime? date) {
    _currentTask.cancelled = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setDoneDate(DateTime? date) {
    _currentTask.done = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setCreatedDate(DateTime? date) {
    _currentTask.created = date;
    emit(TaskEditorInitial(_currentTask));
  }

  String _getSubstringAfter(String source) {
    var settings = SettingsController.getInstance();
    var vaultDirectory = settings.vaultDirectory;
    if (vaultDirectory != null) {
      int index = source.indexOf(vaultDirectory!);
      if (index == -1) {
        // If the search string is not found, return an empty string or handle it as needed
        return '';
      }
      // Add the length of the search string to get the start index of the substring after the found substring
      return source.substring(index + vaultDirectory!.length);
    } else {
      return source;
    }
  }

  Future<void> launchObsidian(BuildContext context) async {
    if (_currentTask.taskSource != null &&
        _currentTask.taskSource!.fileName != null) {
      var noteName = p.basenameWithoutExtension(
        _currentTask.taskSource!.fileName,
      );
      var vaultName = SettingsController.getInstance().vaultName;
      final query = 'obsidian://open?vault=$vaultName&file=$noteName';
      Logger().i('launchObsidian: $query');
      final Uri obsidianUri = Uri.parse(query);

      if (await canLaunchUrl(obsidianUri)) {
        await launchUrl(obsidianUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $obsidianUri')),
        );
      }
    }
  }
}
