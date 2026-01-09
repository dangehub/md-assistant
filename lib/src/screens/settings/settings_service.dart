import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/screens/notes_widget_config/cubit/notes_widget_config_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode {
  file,
  list,
  calendar,
}

enum SortMode {
  none,
  byCreationDate,
}

class SettingsService {
  static const String _vaultDirectoryKey = "vault_directory";
  static const String _vaultNameKey = "vault_name";
  static const String _tasksFileKey = "tasks_file";
  static const String _dateTemplateKey = "date_template";
  //static const String _notificationTimeKey = "notif_time";
  static const String _viewModeKey = "view_mode";
  static const String _sortModeKey = "sort_mode";
  //static const String _notifTimeTemplate = "yyyy-MM-dd";
  static const String _globalTaskFilterKey = "global_task_filter";
  static const String _zeroDateKey = "zero_date";
  static const String _rateDialogCounterKey = "rate_dialog_counter";
  static const String _chatGptKeyKey = "chatgptkey";
  static const String _aiBaseUrlKey = "ai_base_url";
  static const String _aiModelNameKey = "ai_model_name";
  static const String _showOverdueOnlyKey = "show_overdue_only";
  static const String _includeDueTasksInTodayKey = "include_due_tasks_in_today";
  static const String _onboardingCompleteKey = "onboarding_complete";
  static const String _subscriptionStatusKey = "subscription_status";
  static const String _subscriptionExpiryKey = "subscription_expiry";
  static const String _reviewTasksReminderTimeKey =
      "review_tasks_reminder_time";
  static const String _reviewCompletedReminderTimeKey =
      "review_completed_reminder_time";
  static const String _activeFilterIdKey = "active_filter_id";
  static const String _customFiltersKey = "custom_filters";

  Future<ThemeMode> themeMode() async => ThemeMode.system;

  Future<String?> chatGptKey() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_chatGptKeyKey);
  }

  Future<String?> aiBaseUrl() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_aiBaseUrlKey);
  }

  Future<String?> aiModelName() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_aiModelNameKey);
  }

  Future<String?> vaultDirectory() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_vaultDirectoryKey);
  }

  Future<String?> vaultName() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_vaultNameKey);
  }

  Future<String?> tasksFile() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_tasksFileKey);
  }

  Future<String?> dateTemplate() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_dateTemplateKey);
  }

  // Future<DateTime?> notificationTime() async {
  //   var sharedPreferences = await SharedPreferences.getInstance();
  //   var dateTime = sharedPreferences.getString(_notificationTimeKey);
  //   if (dateTime != null) {
  //     return DateTime.parse(_notifTimeTemplate);
  //   }

  //   return null;
  // }

  Future<ViewMode> viewMode() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var viewModeString = sharedPreferences.getString(_viewModeKey);
    if (viewModeString != null) {
      return ViewMode.values.firstWhere(
        (e) => e.toString() == viewModeString,
        orElse: () => ViewMode.list, // Default value
      );
    }

    return ViewMode.list;
  }

  Future<SortMode> sortMode() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var sortModeString = sharedPreferences.getString(_sortModeKey);
    if (sortModeString != null) {
      return SortMode.values.firstWhere(
        (e) => e.toString() == sortModeString,
        orElse: () => SortMode.none, // Default value
      );
    }

    return SortMode.none;
  }

  Future<String?> globalTaskFilter() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_globalTaskFilterKey);
  }

  Future<DateTime?> zeroDate() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var dateTime = sharedPreferences.getString(_zeroDateKey);
    if (dateTime != null) {
      return DateTime.parse(dateTime);
    }
    return null;
  }

  Future<int> rateDialogCounter() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getInt(_rateDialogCounterKey) ?? 0;
  }

  Future<void> updateRateDialogCounter(int counter) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setInt(_rateDialogCounterKey, counter);
  }

  Future<void> updateZeroDate(DateTime? zeroDate) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (zeroDate == null) {
      sharedPreferences.remove(_zeroDateKey);
    } else {
      sharedPreferences.setString(_zeroDateKey, zeroDate.toIso8601String());
    }
  }

  /// Persists the user's preferred ThemeMode to local or remote storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    //TODO not implemented: savidng theme
  }

  Future<void> updateViewMode(ViewMode viewMode) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_viewModeKey, viewMode.toString());
  }

  Future<void> updateSortMode(SortMode sortMode) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_sortModeKey, sortMode.toString());
  }

  Future<void> updateVaultDirectory(String? vaultDirectory) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (vaultDirectory == null) {
      sharedPreferences.remove(_vaultDirectoryKey);
    } else {
      sharedPreferences.setString(_vaultDirectoryKey, vaultDirectory);
    }
  }

  Future<void> updateVaultName(String? vaultName) async {
    var sharedPreferences = await SharedPreferences.getInstance();

    NotesWidgetConfigCubit.updateWidgetWithVaultInfo();

    if (vaultName == null) {
      sharedPreferences.remove(_vaultNameKey);
    } else {
      sharedPreferences.setString(_vaultNameKey, vaultName);
    }
  }

  // Future<void> updateNotificationTime(DateTime? notificationTime) async {
  //   var sharedPreferences = await SharedPreferences.getInstance();
  //   if (notificationTime == null) {
  //     sharedPreferences.remove(_notificationTimeKey);
  //   } else {
  //     sharedPreferences.setString(_notificationTimeKey,
  //         DateFormat(_notifTimeTemplate).format(notificationTime));
  //   }
  // }

  Future<void> updateTasksFile(String tasksFile) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_tasksFileKey, tasksFile);
  }

  Future<void> updateDateTemplate(String dateTemplate) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_dateTemplateKey, dateTemplate);
  }

  Future<void> updateGlobalTaskFilter(String? globalTaskFilter) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (globalTaskFilter == null) {
      sharedPreferences.remove(_globalTaskFilterKey);
    } else {
      sharedPreferences.setString(_globalTaskFilterKey, globalTaskFilter);
    }
  }

  Future<bool> showOverdueOnly() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_showOverdueOnlyKey) ?? false;
  }

  Future<void> updateShowOverdueOnly(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_showOverdueOnlyKey, value);
  }

  Future<bool> includeDueTasksInToday() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_includeDueTasksInTodayKey) ?? true;
  }

  Future<void> updateIncludeDueTasksInToday(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_includeDueTasksInTodayKey, value);
  }

  Future<bool> onboardingComplete() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> updateOnboardingComplete(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_onboardingCompleteKey, value);
  }

  Future<String?> subscriptionStatus() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_subscriptionStatusKey);
  }

  Future<void> updateSubscriptionStatus(String? status) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (status == null) {
      sharedPreferences.remove(_subscriptionStatusKey);
    } else {
      sharedPreferences.setString(_subscriptionStatusKey, status);
    }
  }

  Future<DateTime?> subscriptionExpiry() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var dateTime = sharedPreferences.getString(_subscriptionExpiryKey);
    if (dateTime != null) {
      return DateTime.parse(dateTime);
    }
    return null;
  }

  Future<void> updateSubscriptionExpiry(DateTime? expiry) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (expiry == null) {
      sharedPreferences.remove(_subscriptionExpiryKey);
    } else {
      sharedPreferences.setString(
          _subscriptionExpiryKey, expiry.toIso8601String());
    }
  }

  Future<DateTime?> reviewTasksReminderTime() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var timeString = sharedPreferences.getString(_reviewTasksReminderTimeKey);
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  Future<void> updateReviewTasksReminderTime(DateTime? time) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (time == null) {
      sharedPreferences.remove(_reviewTasksReminderTimeKey);
    } else {
      sharedPreferences.setString(
          _reviewTasksReminderTimeKey, time.toIso8601String());
    }
  }

  Future<DateTime?> reviewCompletedReminderTime() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var timeString =
        sharedPreferences.getString(_reviewCompletedReminderTimeKey);
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  Future<void> updateReviewCompletedReminderTime(DateTime? time) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (time == null) {
      sharedPreferences.remove(_reviewCompletedReminderTimeKey);
    } else {
      sharedPreferences.setString(
          _reviewCompletedReminderTimeKey, time.toIso8601String());
    }
  }

  Future<void> updateChatGptKey(String? chatGptKey) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (chatGptKey == null) {
      sharedPreferences.remove(_chatGptKeyKey);
    } else {
      sharedPreferences.setString(_chatGptKeyKey, chatGptKey);
    }
  }

  Future<void> updateAiBaseUrl(String? baseUrl) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (baseUrl == null) {
      sharedPreferences.remove(_aiBaseUrlKey);
    } else {
      sharedPreferences.setString(_aiBaseUrlKey, baseUrl);
    }
  }

  Future<void> updateAiModelName(String? modelName) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (modelName == null) {
      sharedPreferences.remove(_aiModelNameKey);
    } else {
      sharedPreferences.setString(_aiModelNameKey, modelName);
    }
  }

  Future<String?> activeFilterId() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_activeFilterIdKey);
  }

  Future<void> updateActiveFilterId(String? filterId) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (filterId == null) {
      sharedPreferences.remove(_activeFilterIdKey);
    } else {
      sharedPreferences.setString(_activeFilterIdKey, filterId);
    }
  }

  Future<List<String>> customFilters() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getStringList(_customFiltersKey) ?? [];
  }

  Future<void> updateCustomFilters(List<String> filters) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setStringList(_customFiltersKey, filters);
  }

  static const String _widgetFilterIdKey = "widget_filter_id";

  Future<String?> widgetFilterId() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_widgetFilterIdKey);
  }

  Future<void> updateWidgetFilterId(String? filterId) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (filterId == null) {
      sharedPreferences.remove(_widgetFilterIdKey);
    } else {
      sharedPreferences.setString(_widgetFilterIdKey, filterId);
    }
  }

  // Memos Settings
  static const String _memosPathKey = "memos_path";
  static const String _memosPathIsDynamicKey = "memos_path_is_dynamic";
  static const String _memosWidgetSortAscendingKey =
      "memos_widget_sort_ascending";

  Future<String?> memosPath() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_memosPathKey);
  }

  Future<void> updateMemosPath(String? path) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (path == null) {
      sharedPreferences.remove(_memosPathKey);
    } else {
      sharedPreferences.setString(_memosPathKey, path);
    }
  }

  Future<bool> memosPathIsDynamic() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_memosPathIsDynamicKey) ?? false;
  }

  Future<void> updateMemosPathIsDynamic(bool isDynamic) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_memosPathIsDynamicKey, isDynamic);
  }

  Future<bool> memosWidgetSortAscending() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_memosWidgetSortAscendingKey) ?? false;
  }

  Future<void> updateMemosWidgetSortAscending(bool ascending) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_memosWidgetSortAscendingKey, ascending);
  }
}
