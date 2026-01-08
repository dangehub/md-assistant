import 'package:obsi/src/core/tasks/task.dart';

/// 日期筛选类型
enum DateFilterType {
  none, // 不筛选
  today, // 今天
  tomorrow, // 明天
  thisWeek, // 本周（未来 7 天）
  nextNDays, // Future N Days (Deprecated, use relative)
  overdue, // Overdue
  noDate, // No Date
  custom, // Absolute Range
  recent, // Recent
  nextDays, // Future N Days (Deprecated)
  thisMonth, // This Month
  relative, // Relative Date Range (offsets from Today)
  beforeDate, // Due Before X date (Inclusive)
}

enum StatusFilterType {
  all,
  todo,
  done,
}

/// 任务筛选条件
class TaskFilter {
  /// Scheduled 日期筛选类型
  DateFilterType scheduledDateFilter;

  /// Due 日期筛选类型
  DateFilterType dueDateFilter;

  /// 当选择 nextNDays 时的天数
  int nextDays;

  /// 是否使用 OR 逻辑（默认 AND）
  /// true: scheduled OR due 满足条件即可
  /// false: scheduled AND due 都需要满足条件
  /// 是否使用 OR 逻辑（默认 AND）
  /// true: scheduled OR due 满足条件即可
  /// false: scheduled AND due 都需要满足条件
  bool useOrLogic;

  /// 标签筛选：必须包含的标签 (AND 逻辑)
  List<String> tags;

  /// 排除标签：不能包含的标签
  List<String> excludedTags;

  /// 路径包含：文件路径必须包含此字符串
  String? pathContains;

  /// 状态筛选
  StatusFilterType statusFilter;

  /// 是否继承文件名日期
  /// true: 从文件名提取的日期视为 Scheduled
  /// false: 忽略从文件名提取的日期（视为 null）
  bool inheritDate;

  /// 自定义 Scheduled 日期范围 (当 filter == custom 时使用)
  DateTime? customScheduledStart;
  DateTime? customScheduledEnd;

  /// 自定义 Due 日期范围 (当 filter == custom 时使用)
  DateTime? customDueStart;
  DateTime? customDueEnd;

  /// Relative Start Offset (for DateFilterType.relative)
  /// 0 = Today, 1 = Tomorrow, -1 = Yesterday
  int? relativeStart;

  /// Relative End Offset
  int? relativeEnd;

  /// Week Start Day (1 = Monday, 7 = Sunday)
  int weekStart;

  TaskFilter({
    this.scheduledDateFilter = DateFilterType.none,
    this.dueDateFilter = DateFilterType.none,
    this.nextDays = 7,
    this.useOrLogic = true,
    this.tags = const [],
    this.excludedTags = const [],
    this.pathContains,
    this.statusFilter = StatusFilterType.all,
    this.inheritDate = true,
    this.customScheduledStart,
    this.customScheduledEnd,
    this.customDueStart,
    this.customDueEnd,
    this.relativeStart,
    this.relativeEnd,
    this.weekStart = 1, // Default Monday
  });

  /// 检查日期是否在指定范围内
  /// 检查日期是否在指定范围内
  bool _matchesDateFilter(DateTime? date, DateFilterType filterType,
      {DateTime? customStart, DateTime? customEnd}) {
    if (filterType == DateFilterType.none) {
      return true; // 不筛选，所有都匹配
    }

    if (filterType == DateFilterType.noDate) {
      return date == null;
    }

    if (date == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    switch (filterType) {
      case DateFilterType.today:
        return taskDate.isAtSameMomentAs(today);

      case DateFilterType.tomorrow:
        final tomorrow = today.add(const Duration(days: 1));
        return taskDate.isAtSameMomentAs(tomorrow);

      case DateFilterType.thisWeek:
        // Calculate start/end of week based on weekStart
        // today.weekday returns 1(Mon)..7(Sun)
        final int currentWeekday = today.weekday;
        int diffToStart = (currentWeekday - weekStart + 7) % 7;
        final startOfWeek = today.subtract(Duration(days: diffToStart));
        final endOfWeek = startOfWeek.add(const Duration(
            days: 7)); // Exclusive end? matches check uses isBefore(end)
        // Check logic: !isBefore(start) && isBefore(end)
        // If today is Monday(1) and weekStart is 1. diff=0. start=Today. end=Today+7. Correct.
        // If today is Sunday(7) and weekStart is 1. diff=6. start=Today-6 (Mon). end=Today+1. Correct.
        return !taskDate.isBefore(startOfWeek) && taskDate.isBefore(endOfWeek);

      case DateFilterType.thisMonth:
        // Start of month: 1st day.
        // End of month: 1st day of next month.
        final startOfMonth = DateTime(today.year, today.month, 1);
        final endOfMonth = DateTime(today.year, today.month + 1, 1);
        return !taskDate.isBefore(startOfMonth) &&
            taskDate.isBefore(endOfMonth);

      case DateFilterType.relative:
        // relativeStart / relativeEnd are offsets from today.
        // If relativeStart is null, unbounded? User said "前NA" (maybe unbounded).
        // Let's assume if null, treated as unbounded.
        DateTime? startRange;
        if (relativeStart != null) {
          startRange = today.add(Duration(days: relativeStart!));
        }
        DateTime? endRange;
        if (relativeEnd != null) {
          // relativeEnd is inclusive? User example "前7后7" = 15 days.
          // If -7 to +7: -7,-6...0...+7. Total 15 days.
          // If we verify date (midnight), we need to check if it's <= endRange (midnight).
          // But our check logic for ranges (`thisWeek`) was `isBefore(endOfWeek)` where endOfWeek was exclusive (next week start).
          // Let's treat relativeEnd as Inclusive day.
          // So cutoff is endRange + 1 day.
          endRange = today
              .add(Duration(days: relativeEnd!))
              .add(const Duration(days: 1));
        }

        if (startRange != null && taskDate.isBefore(startRange)) return false;
        if (endRange != null && !taskDate.isBefore(endRange))
          return false; // isBefore is strict, so !isBefore allows equal?
        // Wait, startRange is Inclusive Midnight. taskDate < startRange => False. Correct.
        // endRange is Exclusive Midnight (Day after end). taskDate < endRange => True. Correct.
        // Wait, !taskDate.isBefore(endRange) -> taskDate >= endRange. Correct.
        return true;

      case DateFilterType.beforeDate:
        DateTime? cutoff;
        if (customEnd != null) {
          cutoff = customEnd;
        } else if (relativeEnd != null) {
          // relativeEnd is relative to today
          cutoff = today.add(Duration(days: relativeEnd!));
        }

        if (cutoff != null) {
          // cutoff is inclusive. taskDate must be <= cutoff.
          // Since dates (taskDate/cutoff) are likely at 00:00:00 (normalized to day),
          // isAfter means strictly >. So !isAfter means <=.
          if (taskDate.isAfter(cutoff)) return false;
        } else {
          // If neither is set, what to do? User might not have configured it yet.
          // Usually assume no restriction? Or fail?
          // Let's assume no restriction (match all) or match today?
          // If user selects "Due Before" but sets nothing, maybe show all.
          return true;
        }
        return true;

      case DateFilterType.nextNDays:
      case DateFilterType.nextDays:
        final endDate = today.add(Duration(days: nextDays));
        return !taskDate.isBefore(today) && taskDate.isBefore(endDate);

      case DateFilterType.overdue:
        return taskDate.isBefore(today);

      case DateFilterType.recent:
        final endDate = today.add(Duration(days: nextDays));
        // Matches anything before endDate (including overdue)
        return taskDate.isBefore(endDate);

      case DateFilterType.noDate:
      case DateFilterType.none:
        return true;

      case DateFilterType.custom:
        if (customStart == null && customEnd == null) {
          return true; // No range specified, match all
        }
        if (customStart != null && taskDate.isBefore(customStart)) {
          return false;
        }
        if (customEnd != null && taskDate.isAfter(customEnd)) {
          return false;
        }
        return true;
    }
  }

  /// 检查任务是否满足筛选条件
  /// 检查任务是否满足筛选条件
  bool matches(Task task) {
    // 1. Status Filter
    if (statusFilter == StatusFilterType.todo && task.status == TaskStatus.done)
      return false;
    if (statusFilter == StatusFilterType.done && task.status != TaskStatus.done)
      return false;

    // 2. Tags Filter (AND logic for included keys)
    if (tags.isNotEmpty) {
      for (var tag in tags) {
        if (!task.tags.contains(tag)) return false;
      }
    }

    // 3. Excluded Tags Filter
    if (excludedTags.isNotEmpty) {
      for (var tag in excludedTags) {
        if (task.tags.contains(tag)) return false;
      }
    }

    // 4. Path Filter
    if (pathContains != null && pathContains!.isNotEmpty) {
      if (task.taskSource?.fileName == null ||
          !task.taskSource!.fileName.contains(pathContains!)) {
        return false;
      }
    }

    // 5. Date Filter (with inheritDate logic)
    // 如果两个筛选都是 none，则日期条件视为匹配
    if (scheduledDateFilter == DateFilterType.none &&
        dueDateFilter == DateFilterType.none) {
      return true;
    }

    // Determine effective scheduled date
    var effectiveScheduled = task.scheduled;
    if (task.isScheduledDateInferred && !inheritDate) {
      effectiveScheduled = null;
    }

    final scheduledMatches = _matchesDateFilter(
        effectiveScheduled, scheduledDateFilter,
        customStart: customScheduledStart, customEnd: customScheduledEnd);
    final dueMatches = _matchesDateFilter(task.due, dueDateFilter,
        customStart: customDueStart, customEnd: customDueEnd);

    if (useOrLogic) {
      // OR 逻辑：任一条件满足即可
      // 如果某个筛选是 none，则该条件视为不参与筛选
      if (scheduledDateFilter == DateFilterType.none) {
        return dueMatches;
      }
      if (dueDateFilter == DateFilterType.none) {
        return scheduledMatches;
      }
      return scheduledMatches || dueMatches;
    } else {
      // AND 逻辑：两个条件都需要满足
      return scheduledMatches && dueMatches;
    }
  }

  Map<String, dynamic> toJson() => {
        'scheduledDateFilter': scheduledDateFilter.index,
        'dueDateFilter': dueDateFilter.index,
        'nextDays': nextDays,
        'useOrLogic': useOrLogic,
        'tags': tags,
        'excludedTags': excludedTags,
        'pathContains': pathContains,
        'statusFilter': statusFilter.index,
        'inheritDate': inheritDate,
        'customScheduledStart': customScheduledStart?.toIso8601String(),
        'customScheduledEnd': customScheduledEnd?.toIso8601String(),
        'customDueStart': customDueStart?.toIso8601String(),
        'customDueEnd': customDueEnd?.toIso8601String(),
        'relativeStart': relativeStart,
        'relativeEnd': relativeEnd,
        'weekStart': weekStart,
      };

  factory TaskFilter.fromJson(Map<String, dynamic> json) => TaskFilter(
        scheduledDateFilter: DateFilterType.values[json['scheduledDateFilter']],
        dueDateFilter: DateFilterType.values[json['dueDateFilter']],
        nextDays: json['nextDays'],
        useOrLogic: json['useOrLogic'],
        tags: List<String>.from(json['tags'] ?? []),
        excludedTags: List<String>.from(json['excludedTags'] ?? []),
        pathContains: json['pathContains'],
        statusFilter: StatusFilterType.values[json['statusFilter'] ?? 0],
        inheritDate: json['inheritDate'] ?? true,
        customScheduledStart: json['customScheduledStart'] != null
            ? DateTime.parse(json['customScheduledStart'])
            : null,
        customScheduledEnd: json['customScheduledEnd'] != null
            ? DateTime.parse(json['customScheduledEnd'])
            : null,
        customDueStart: json['customDueStart'] != null
            ? DateTime.parse(json['customDueStart'])
            : null,
        customDueEnd: json['customDueEnd'] != null
            ? DateTime.parse(json['customDueEnd'])
            : null,
        relativeStart: json['relativeStart'],
        relativeEnd: json['relativeEnd'],
        weekStart: json['weekStart'] ?? 1,
      );

  /// 获取筛选类型的显示名称
  static String getFilterTypeName(DateFilterType type, {int? days}) {
    switch (type) {
      case DateFilterType.none:
        return '全部';
      case DateFilterType.today:
        return '今天';
      case DateFilterType.tomorrow:
        return '明天';
      case DateFilterType.thisWeek:
        return '本周';
      case DateFilterType.nextNDays:
      case DateFilterType.nextDays:
        return '未来 ${days ?? 7} 天';
      case DateFilterType.overdue:
        return '已逾期';
      case DateFilterType.noDate:
        return '无日期';
      case DateFilterType.custom:
        return '自定义范围';
      case DateFilterType.recent:
        return '最近';
      case DateFilterType.thisMonth:
        return '本月';
      case DateFilterType.relative:
        // TODO: improve description?
        return '相对日期';
      case DateFilterType.beforeDate:
        return '截止X日前'; // Dynamic X handled elsewhere? Or just generic name
    }
  }

  /// 创建一个常用筛选：未来 N 天的任务
  static TaskFilter nextDaysFilter(int days) {
    return TaskFilter(
      scheduledDateFilter: DateFilterType.nextNDays,
      dueDateFilter: DateFilterType.nextNDays,
      nextDays: days,
      useOrLogic: true,
    );
  }

  /// 创建一个常用筛选：今天的任务
  static TaskFilter todayFilter() {
    return TaskFilter(
      scheduledDateFilter: DateFilterType.today,
      dueDateFilter: DateFilterType.today,
      useOrLogic: true,
    );
  }

  /// 创建一个常用筛选：逾期任务
  static TaskFilter overdueFilter() {
    return TaskFilter(
      scheduledDateFilter: DateFilterType.overdue,
      dueDateFilter: DateFilterType.overdue,
      useOrLogic: true,
    );
  }
}
