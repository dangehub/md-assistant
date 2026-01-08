import 'package:obsi/src/core/tasks/task.dart';

/// 日期筛选类型
enum DateFilterType {
  none, // 不筛选
  today, // 今天
  tomorrow, // 明天
  thisWeek, // 本周（未来 7 天）
  nextNDays, // 未来 N 天
  overdue, // 已逾期
  noDate, // 无日期
  custom, // 自定义日期范围
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
  bool useOrLogic;

  TaskFilter({
    this.scheduledDateFilter = DateFilterType.none,
    this.dueDateFilter = DateFilterType.none,
    this.nextDays = 7,
    this.useOrLogic = true,
  });

  /// 检查日期是否在指定范围内
  bool _matchesDateFilter(DateTime? date, DateFilterType filterType) {
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
        final weekEnd = today.add(const Duration(days: 7));
        return !taskDate.isBefore(today) && taskDate.isBefore(weekEnd);

      case DateFilterType.nextNDays:
        final endDate = today.add(Duration(days: nextDays));
        return !taskDate.isBefore(today) && taskDate.isBefore(endDate);

      case DateFilterType.overdue:
        return taskDate.isBefore(today);

      case DateFilterType.noDate:
      case DateFilterType.none:
      case DateFilterType.custom:
        return true;
    }
  }

  /// 检查任务是否满足筛选条件
  bool matches(Task task) {
    // 如果两个筛选都是 none，则所有任务都匹配
    if (scheduledDateFilter == DateFilterType.none &&
        dueDateFilter == DateFilterType.none) {
      return true;
    }

    final scheduledMatches =
        _matchesDateFilter(task.scheduled, scheduledDateFilter);
    final dueMatches = _matchesDateFilter(task.due, dueDateFilter);

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
        return '未来 ${days ?? 7} 天';
      case DateFilterType.overdue:
        return '已逾期';
      case DateFilterType.noDate:
        return '无日期';
      case DateFilterType.custom:
        return '自定义';
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
