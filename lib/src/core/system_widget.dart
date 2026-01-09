import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/filter_list.dart';
import 'package:obsi/src/core/storage/android_tasks_file_storage.dart';
import 'package:obsi/src/core/storage/changed_files_storage.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';

class HomeWidgetHandler {
  @pragma("vm:entry-point")
  static Future<void> homeWidgetHandler(Uri? uri) async {
    try {
      Logger().i("Widget data update is called with uri: $uri");

      if (uri != null) {
        if (uri.host.contains('request_tasks')) {
          await _requestTasksHandler();
        } else {
          throw Exception("ObsiWidget: unknown request received");
        }
      }
    } catch (e) {
      Logger().e(e);
      _saveAndUpdateWidget("error", e.toString());
    }
  }

  static Future<void> updateWidget(List<Task> tasks) async {
    try {
      Logger().i("Updating widget with tasks: ${tasks.length}");

      // Filter tasks based on widget settings
      var settings = SettingsController
          .getInstance(); // Assumes initialized if called from app
      var targetFilter = _getWidgetFilter(settings);

      var filteredTasks = tasks.where((t) => targetFilter.matches(t)).toList();
      _sortTasks(filteredTasks, targetFilter);
      Logger().i(
          "Filtered widget tasks: ${filteredTasks.length} using filter: ${targetFilter.name}");

      var jsonTasks = jsonEncode(_tasks2Json(filteredTasks));
      await _saveAndUpdateWidget("tasks", jsonTasks);
    } catch (e) {
      Logger().e("Error updating widget: $e");
      await _saveAndUpdateWidget("error", e.toString());
    }
  }

  static Future _requestTasksHandler() async {
    Logger().i("HomeWidget: requesttasks received");
    var tasks = await _getWidgetTasks();
    var jsonTasks = jsonEncode(tasks);
    _saveAndUpdateWidget("tasks", jsonTasks.toString());
  }

  static Future _saveAndUpdateWidget(String key, String value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
    await HomeWidget.updateWidget(
        name: 'ObsiWidgetReceiver', iOSName: 'HomeWidget');
  }

  static Future<List<Map<String, dynamic>>?> _getWidgetTasks() async {
    List<Map<String, dynamic>> resultTask = [];
    var settings =
        SettingsController.getInstance(settingsService: SettingsService());
    await settings.loadSettings();

    TaskManager taskManager = TaskManager(
      ChangedFilesStorage(AndroidTasksFileStorage()),
      todoOnly: false,
    );

    taskManager.dateTemplate = settings.dateTemplate;

    var vaultDirectory = settings.vaultDirectory;
    if (vaultDirectory != null && vaultDirectory.isNotEmpty) {
      Logger().d('Vault directory is set: $vaultDirectory');
      // Load tasks from the specified vault directory
      await taskManager.loadTasks(vaultDirectory,
          taskFilter: settings.globalTaskFilter);

      var targetFilter = _getWidgetFilter(settings);
      var tasks =
          taskManager.tasks.where((t) => targetFilter.matches(t)).toList();
      _sortTasks(tasks, targetFilter);
      resultTask = _tasks2Json(tasks);
    } else {
      Logger().d('Vault directory is not set or empty. Using default tasks.');
      throw Exception(
          "Vault directory is not set. Start application to set it.");
    }

    return resultTask;
  }

  static FilterList _getWidgetFilter(SettingsController settings) {
    var filterId = settings.widgetFilterId;
    if (filterId != null) {
      try {
        return settings.filters.firstWhere((f) => f.id == filterId);
      } catch (e) {
        // Fallback if ID not found
      }
    }
    // Default to 'Today' if possible, or 'Recent', or first available
    try {
      return settings.filters.firstWhere((f) => f.id == 'filter_today');
    } catch (e) {
      return settings.filters.isNotEmpty
          ? settings.filters.first
          : FilterList.upcoming();
    }
  }

  static List<Map<String, dynamic>> _tasks2Json(List<Task> tasks) {
    return tasks.map((task) => task.toJsonMap()).toList();
  }

  static void _sortTasks(List<Task> tasks, FilterList filter) {
    if (filter.sortRules.isNotEmpty) {
      tasks.sort((a, b) {
        for (var rule in filter.sortRules) {
          int cmp = 0;
          switch (rule.field) {
            case SortField.alphabetical:
              cmp = (a.description ?? "").compareTo(b.description ?? "");
              break;
            case SortField.dueDate:
              cmp = _compareDates(a.due, b.due);
              break;
            case SortField.scheduledDate:
              cmp = _compareDates(a.scheduled, b.scheduled);
              break;
            case SortField.createdDate:
              cmp = _compareDates(a.created, b.created);
              break;
            case SortField.priority:
              cmp = a.priority.index.compareTo(b.priority.index);
              break;
            case SortField.status:
              cmp = a.status.index.compareTo(b.status.index);
              break;
          }
          if (cmp != 0) {
            return rule.direction == SortDirection.ascending ? cmp : -cmp;
          }
        }
        return 0; // All rules equal
      });
    }
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // Null is "larger" -> End of list (for ASC)
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
