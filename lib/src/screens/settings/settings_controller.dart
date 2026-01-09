import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/notification_manager.dart';
import 'package:obsi/src/core/storage/ios_tasks_file_storage.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/subscription/subscription_manager.dart';
import 'dart:io';
import 'settings_service.dart';
import 'package:external_path/external_path.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:obsi/src/core/filter_list.dart';
import 'package:obsi/src/core/task_filter.dart';

class SettingsController with ChangeNotifier {
  static SettingsController? _instance;

  // Unique notification IDs for daily reminders
  // Using ranges to allow for multiple days: 10001-10007, 10010-10016
  static const int _reviewTasksReminderNotificationId = 10001;
  static const int _reviewCompletedReminderNotificationId = 10010;

  static SettingsController getInstance({SettingsService? settingsService}) {
    if (_instance != null) return _instance!;

    _instance = SettingsController._(settingsService!);
    return _instance!;
  }

  static void setInstance(SettingsController instance) {
    _instance = instance;
  }

  static Future<bool> storagePermissionsGranted() async {
    bool status = false;
    if (Platform.isAndroid) {
      if (await SettingsController.isAndroid11OrAbove()) {
        // Request "Manage External Storage" for Android 11+
        status = await Permission.manageExternalStorage.isGranted;
      } else {
        // Request "Storage" for Android 10 and below
        status = await Permission.storage.isGranted;
      }
    } else {
      // Request "Storage" for iOS
      status = await Permission.storage.isGranted;
    }
    return status;
  }

  static Future<PermissionStatus> requestAndroidPermission(
      BuildContext context) async {
    // Capture messenger before any async gaps to avoid using context later
    final messenger = ScaffoldMessenger.maybeOf(context);
    PermissionStatus status = PermissionStatus.denied;
    if (Platform.isAndroid) {
      if (await SettingsController.isAndroid11OrAbove()) {
        // Request "Manage External Storage" for Android 11+
        status = await Permission.manageExternalStorage.request();
      } else {
        // Request "Storage" for Android 10 and below
        status = await Permission.storage.request();
      }

      // Handle denied or permanently denied permission
      if (!status.isGranted) {
        status = PermissionStatus.denied;
        messenger?.showSnackBar(
          const SnackBar(
              content: Text(
                  'Storage permission is required to select a directory.')),
        );
      }
    }
    return status;
  }

  static Future<String?> selectVaultDirectory(BuildContext context) async {
    // Capture messenger before any async gaps to avoid using context later
    final messenger = ScaffoldMessenger.maybeOf(context);
    PermissionStatus status;
    var shortcuts = <FilesystemPickerShortcut>[];
    if (Platform.isAndroid) {
      Logger().i("requesting Android permission");
      status = await requestAndroidPermission(context);
      if (status != PermissionStatus.granted) {
        Logger().i("Storage permission denied");
        return null;
      }

      // Fetch external directories and proceed with directory selection
      var externalDirectories =
          await ExternalPath.getExternalStorageDirectories();
      if (externalDirectories == null || externalDirectories.isEmpty) {
        messenger?.showSnackBar(
          const SnackBar(
              content: Text('No external storage directories found.')),
        );
        return null;
      }

      shortcuts = externalDirectories
          .map((dir) =>
              FilesystemPickerShortcut(name: dir, path: Directory(dir)))
          .toList();
      // Guard against using context after async gaps
      if (!context.mounted) return null;
      // Use a SafeArea-wrapped FilesystemPicker to avoid bottom gesture/nav bar overlap
      return await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (ctx) => SafeArea(
            bottom: true,
            child: FilesystemPicker(
              title: 'Obsidian vault',
              shortcuts: shortcuts,
              fsType: FilesystemType.folder,
              pickText: 'Choose vault folder',
              onSelect: (path) => Navigator.of(ctx).pop(path),
            ),
          ),
        ),
      );
    } else {
      var status = await Permission.storage.request();

      // Handle denied or permanently denied permission
      if (!status.isGranted) {
        messenger?.showSnackBar(
          const SnackBar(
              content: Text(
                  'Storage permission is required to select a directory.')),
        );
      } else {
        return await IosTasksFileStorage.selectFolder();
      }
    }

    return null;
  }

// Utility function to check Android version
  static Future<bool> isAndroid11OrAbove() async {
    var status = await Permission.manageExternalStorage.status;
    return Platform.isAndroid &&
        (status == PermissionStatus.granted ||
            status == PermissionStatus.denied);
  }

  SettingsController._(SettingsService settingsService)
      : _settingsService = settingsService;

  final SettingsService _settingsService;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  String? _vaultDirectory;
  String? _vaultName;
  String? _tasksFile;
  String? _dateTemplate;
  //DateTime? _notificationTime;
  DateTime? _zeroDate;
  ViewMode _viewMode = ViewMode.list;
  SortMode _sortMode = SortMode.none;
  String? _globalTaskFilter;
  int _rateDialogCounter = 0;
  String? _chatGptKey;
  String? _aiBaseUrl;
  String? _aiModelName;
  String? _activeFilterId;
  String? _widgetFilterId;
  String? get widgetFilterId => _widgetFilterId;
  List<FilterList> _filters = [];

  Future<void> updateWidgetFilterId(String? newId) async {
    if (newId == _widgetFilterId) return;
    _widgetFilterId = newId;
    notifyListeners();
    await _settingsService.updateWidgetFilterId(newId);
  }

  bool _showOverdueOnly = false;
  bool _includeDueTasksInToday = true;
  bool _onboardingComplete = false;
  String? _subscriptionStatus;
  DateTime? _subscriptionExpiry;
  DateTime? _reviewTasksReminderTime;
  DateTime? _reviewCompletedReminderTime;

  SortMode get sortMode => _sortMode;
  ViewMode get viewMode => _viewMode;
  String? get vaultDirectory => _vaultDirectory;
  String get vaultName {
    if (_vaultName == null && vaultDirectory != null) {
      _vaultName = _getVaultName(vaultDirectory!);
      _settingsService.updateVaultName(_vaultName);
    }

    return _vaultName!;
  }

  String get tasksFile => _tasksFile ?? "{{YYYY-MM-DD}}.md";
  String get dateTemplate => _dateTemplate ?? "yyyy-MM-dd";
  //DateTime? get notificationTime => _notificationTime;
  String get globalTaskFilter => _globalTaskFilter ?? "";
  DateTime? get zeroDate => _zeroDate;
  int get rateDialogCounter => _rateDialogCounter;
  String? get chatGptKey => _chatGptKey;
  String? get aiBaseUrl => _aiBaseUrl;
  String? get aiModelName => _aiModelName;
  String? get activeFilterId => _activeFilterId;
  List<FilterList> get filters => List.unmodifiable(_filters);
  bool get showOverdueOnly => _showOverdueOnly;
  bool get includeDueTasksInToday => _includeDueTasksInToday;
  bool get onboardingComplete => _onboardingComplete;
  String? get subscriptionStatus => _subscriptionStatus;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  DateTime? get reviewTasksReminderTime => _reviewTasksReminderTime;
  DateTime? get reviewCompletedReminderTime => _reviewCompletedReminderTime;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _vaultDirectory = await _settingsService.vaultDirectory();
    _vaultName = await _settingsService.vaultName();
    _tasksFile = await _settingsService.tasksFile();
    _dateTemplate = await _settingsService.dateTemplate();
    // _notificationTime = await _settingsService.notificationTime();
    _viewMode = await _settingsService.viewMode();
    _sortMode = await _settingsService.sortMode();
    _globalTaskFilter = await _settingsService.globalTaskFilter();
    _chatGptKey = await _settingsService.chatGptKey();
    _aiBaseUrl = await _settingsService.aiBaseUrl();
    _aiModelName = await _settingsService.aiModelName();
    _showOverdueOnly = await _settingsService.showOverdueOnly();
    _includeDueTasksInToday = await _settingsService.includeDueTasksInToday();
    _onboardingComplete = await _settingsService.onboardingComplete();
    _subscriptionStatus = await _settingsService.subscriptionStatus();
    _subscriptionExpiry = await _settingsService.subscriptionExpiry();
    _reviewTasksReminderTime = await _settingsService.reviewTasksReminderTime();

    _reviewCompletedReminderTime =
        await _settingsService.reviewCompletedReminderTime();
    _activeFilterId = await _settingsService.activeFilterId();
    _widgetFilterId = await _settingsService.widgetFilterId();

    var customFiltersJson = await _settingsService.customFilters();
    if (customFiltersJson.isEmpty) {
      // First run or migration: create defaults
      _filters = _createDefaultFilters();
      await _saveFilters();
    } else {
      // Load existing
      // TODO: Migration from old "custom only" to "unified"
      // Basic check: if we think these are just custom filters (e.g. none have IDs like 'filter_inbox'),
      // we might want to prepend defaults.
      // For now, let's assume we need to prepend defaults if we don't find "Inbox".
      var loadedFilters = customFiltersJson
          .map((e) => FilterList.fromJson(jsonDecode(e)))
          .toList();

      bool hasInbox = loadedFilters.any((f) =>
          f.id == 'filter_inbox' ||
          f.name == 'Inbox' ||
          f.name == '📥 Inbox' ||
          f.name == '收集箱');

      List<FilterList> mergedFilters;
      if (!hasInbox) {
        // Prioritize loaded filters first to keep user edits, then append defaults if missing
        mergedFilters = [...loadedFilters, ..._createDefaultFilters()];
      } else {
        mergedFilters = loadedFilters;
      }

      // Deduplicate by ID, keeping the first occurrence (which comes from loadedFilters)
      final uniqueFilters = <String, FilterList>{};
      for (var f in mergedFilters) {
        if (!uniqueFilters.containsKey(f.id)) {
          uniqueFilters[f.id] = f;
        }
      }
      _filters = uniqueFilters.values.toList();

      // Migration: Refresh all 5 default preset filters to get new names, icons, order
      // This ensures emoji names (📅 upcoming, 📆 today, 📥 inbox, etc.) are applied
      // and filterRules are properly set from the factory methods.
      final defaultFilterIds = [
        // New lowercase IDs
        'upcoming',
        'today',
        'inbox',
        'completed',
        'all',
        // Legacy capitalized IDs (old app versions)
        'Inbox',
        'All',
        'Today',
        'Completed',
        'Upcoming',
        // Other legacy IDs
        'recent',
        'filter_upcoming',
        'filter_inbox',
        'filter_all',
        'filter_today',
        'filter_completed',
      ];

      // Remove old versions of default filters (both lowercase and capitalized)
      _filters.removeWhere((f) => defaultFilterIds.contains(f.id));

      // Add fresh default filters at the beginning in correct order
      final freshDefaults = _createDefaultFilters();
      _filters = [...freshDefaults, ..._filters];

      // Deduplicate by ID (freshDefaults take precedence)
      final uniqueFilters2 = <String, FilterList>{};
      for (var f in _filters) {
        if (!uniqueFilters2.containsKey(f.id)) {
          uniqueFilters2[f.id] = f;
        }
      }
      _filters = uniqueFilters2.values.toList();

      // If we made changes, save them
      if (_filters.length != mergedFilters.length || !hasInbox) {
        await _saveFilters();
      }
    }

    // Future<void> updateNotificationTime(DateTime? newNotifTime) async {
    //   if (newNotifTime == notificationTime) return;

    _zeroDate = await _settingsService.zeroDate();
    _rateDialogCounter = await _settingsService.rateDialogCounter();
    // save date of the first installation
    if (_zeroDate == null) {
      await updateZeroDate(DateTime.now());
    }

    notifyListeners();
  }

  Future<void> updateRateDialogCounter(int newCounter) async {
    if (newCounter == _rateDialogCounter) return;

    _rateDialogCounter = newCounter;
    await _settingsService.updateRateDialogCounter(newCounter);
  }

  //Future<void> updateNotificationTime(DateTime? newNotifTime) async {
  //if (newNotifTime == notificationTime) return;

  //   _notificationTime = newNotifTime;
  //   notifyListeners();
  //   await _settingsService.updateNotificationTime(newNotifTime);
  // }
  Future<void> updateChatGptKey(String? newChatGptKey) async {
    if (newChatGptKey == chatGptKey) return;

    _chatGptKey = newChatGptKey;
    await _settingsService.updateChatGptKey(newChatGptKey);
  }

  Future<void> updateAiBaseUrl(String? newBaseUrl) async {
    if (newBaseUrl == aiBaseUrl) return;

    _aiBaseUrl = newBaseUrl;
    await _settingsService.updateAiBaseUrl(newBaseUrl);
  }

  Future<void> updateAiModelName(String? newModelName) async {
    if (newModelName == aiModelName) return;

    _aiModelName = newModelName;
    await _settingsService.updateAiModelName(newModelName);
  }

  Future<void> updateActiveFilterId(String? newFilterId) async {
    if (newFilterId == activeFilterId) return;

    _activeFilterId = newFilterId;
    await _settingsService.updateActiveFilterId(newFilterId);
  }

  Future<void> updateViewMode(ViewMode newViewMode) async {
    if (newViewMode == viewMode) return;

    _viewMode = newViewMode;
    await _settingsService.updateViewMode(newViewMode);
  }

  Future<void> updateSortMode(SortMode newSortMode) async {
    if (newSortMode == sortMode) return;

    _sortMode = newSortMode;
    await _settingsService.updateSortMode(newSortMode);
  }

  Future<void> updateVaultDirectory(String? newVaultDirectory) async {
    if (newVaultDirectory == vaultDirectory) return;

    _vaultDirectory = newVaultDirectory;
    if (newVaultDirectory != null && newVaultDirectory.isNotEmpty) {
      _vaultName = _getVaultName(newVaultDirectory);
      await _settingsService.updateVaultName(_vaultName);
    } else {
      _vaultName = null;
      await _settingsService.updateVaultName(null);
    }
    notifyListeners();
    await _settingsService.updateVaultDirectory(newVaultDirectory);
  }

  // TODO should not get direct access to file system, this should be done in the storage
  String _getVaultName(String path) {
    var currentPath = path;

    while (currentPath.isNotEmpty) {
      final obsidianFolder = Directory('$currentPath/.obsidian');
      if (obsidianFolder.existsSync()) {
        var currentDirectory = Directory(currentPath);
        if (currentDirectory.uri.pathSegments.length > 1 &&
            currentDirectory.uri.pathSegments.last.isEmpty) {
          return currentDirectory
              .uri.pathSegments[currentDirectory.uri.pathSegments.length - 2];
        }
        return Directory(currentPath).uri.pathSegments.last;
      }

      // Move one level up in the directory hierarchy
      currentPath = Directory(currentPath).parent.path;

      // Stop if we reach the root directory
      if (currentPath == '/' || currentPath.isEmpty || currentPath == '.') {
        break;
      }
    }

    return "";
  }

  Future<void> updateDateTemplate(String newDateTemplate) async {
    if (newDateTemplate == dateTemplate) return;

    _dateTemplate = newDateTemplate;
    notifyListeners();
    await _settingsService.updateDateTemplate(newDateTemplate);
  }

  Future<void> updateTasksFile(String newTasksFile) async {
    if (newTasksFile == tasksFile) return;

    _tasksFile = newTasksFile;
    notifyListeners();
    await _settingsService.updateTasksFile(newTasksFile);
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;

    notifyListeners();
    await _settingsService.updateThemeMode(newThemeMode);
  }

  Future<void> updateGlobalTaskFilter(String? newGlobalTaskFilter) async {
    if (newGlobalTaskFilter == _globalTaskFilter) return;

    _globalTaskFilter = newGlobalTaskFilter;
    TasksFileStorage.getInstance(resetCache: true);
    Logger().d("updateGlobalTaskFilter: $newGlobalTaskFilter");
    notifyListeners();
    await _settingsService.updateGlobalTaskFilter(newGlobalTaskFilter);
  }

  Future<void> updateShowOverdueOnly(bool value) async {
    if (_showOverdueOnly == value) return;
    _showOverdueOnly = value;
    Logger().d("updateShowOverdueOnly: $value");
    await _settingsService.updateShowOverdueOnly(value);
  }

  Future<void> updateIncludeDueTasksInToday(bool value) async {
    if (_includeDueTasksInToday == value) return;
    _includeDueTasksInToday = value;
    Logger().d("updateIncludeDueTasksInToday: $value");
    notifyListeners();
    await _settingsService.updateIncludeDueTasksInToday(value);
  }

  Future<void> updateOnboardingComplete(bool value) async {
    if (_onboardingComplete == value) return;
    _onboardingComplete = value;
    Logger().d("updateOnboardingComplete: $value");
    notifyListeners();
    await _settingsService.updateOnboardingComplete(value);
  }

  Future<void> updateZeroDate(DateTime? newZeroDate) async {
    if (newZeroDate == _zeroDate || _zeroDate != null) return;

    _zeroDate = newZeroDate;
    await _settingsService.updateZeroDate(newZeroDate);
  }

  Future<void> updateReviewTasksReminderTime(DateTime? time) async {
    // if (time == _reviewTasksReminderTime) return;

    _reviewTasksReminderTime = time;
    await _settingsService.updateReviewTasksReminderTime(time);
    if (time == null) {
      await NotificationManager.getInstance()
          .cancelNotification(_reviewTasksReminderNotificationId);
    } else {
      await NotificationManager.getInstance().scheduleDailyNotification(
        _reviewTasksReminderNotificationId,
        TimeOfDay(hour: time!.hour, minute: time.minute),
        'Review your tasks (you can remove this reminder in Settings)',
      );
    }
  }

  Future<void> updateReviewCompletedReminderTime(DateTime? time) async {
    //if (time == _reviewCompletedReminderTime) return;

    _reviewCompletedReminderTime = time;

    await _settingsService.updateReviewCompletedReminderTime(time);
    if (time == null) {
      await NotificationManager.getInstance()
          .cancelNotification(_reviewCompletedReminderNotificationId);
    } else {
      await NotificationManager.getInstance().scheduleDailyNotification(
        _reviewCompletedReminderNotificationId,
        TimeOfDay(hour: time!.hour, minute: time.minute),
        'Review your completed tasks (you can remove this reminder in Settings)',
      );
    }
  }

  Future<String> getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      Logger().e("Error getting app version: $e");
      return 'Unknown';
    }
  }

  Future<void> updateSubscriptionStatus(String? status) async {
    if (_subscriptionStatus == status) return;
    _subscriptionStatus = status;
    notifyListeners();
    await _settingsService.updateSubscriptionStatus(status);
  }

  Future<void> updateSubscriptionExpiry(DateTime? expiry) async {
    if (_subscriptionExpiry == expiry) return;
    _subscriptionExpiry = expiry;
    notifyListeners();
    await _settingsService.updateSubscriptionExpiry(expiry);
  }

  bool get hasActiveSubscription {
    if (_subscriptionStatus == null || _subscriptionStatus != 'active') {
      if (Platform.isIOS ||
          SubscriptionManager.instance.hasActiveSubscription) {
        return true;
      }
      return false;
    }
    if (_subscriptionExpiry == null) {
      return false;
    }
    return DateTime.now().isBefore(_subscriptionExpiry!);
  }

  List<FilterList> _createDefaultFilters() {
    return [
      FilterList.upcoming(),
      FilterList.today(),
      FilterList.inbox(),
      FilterList.completed(),
      FilterList.all(),
    ];
  }

  Future<void> addFilter(FilterList filter) async {
    _filters.add(filter);
    notifyListeners();
    await _saveFilters();
  }

  Future<void> removeFilter(String id) async {
    _filters.removeWhere((element) => element.id == id);
    notifyListeners();
    await _saveFilters();
  }

  Future<void> updateFilter(FilterList filter) async {
    var index = _filters.indexWhere((element) => element.id == filter.id);
    if (index != -1) {
      _filters[index] = filter;
      notifyListeners();
      await _saveFilters();
    }
  }

  Future<void> reorderFilters(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _filters.removeAt(oldIndex);
    _filters.insert(newIndex, item);
    notifyListeners();
    await _saveFilters();
  }

  Future<void> _saveFilters() async {
    var jsonList = _filters.map((e) => jsonEncode(e.toJson())).toList();
    await _settingsService.updateCustomFilters(jsonList);
  }
}
