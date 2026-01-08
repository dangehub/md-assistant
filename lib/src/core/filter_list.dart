import 'package:flutter/material.dart';
import 'package:obsi/src/core/task_filter.dart';
import 'package:obsi/src/core/tasks/task.dart';

enum FilterListType {
  preset,
  smart,
  staticList,
  tag,
  custom,
  builtin,
}

class FilterList {
  final String id;
  final String name;
  final IconData icon;
  final FilterListType type;

  final TaskFilter? filter;
  final List<String> taskIds;

  const FilterList({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.filter,
    this.taskIds = const [],
  });

  bool matches(Task task) {
    if (type == FilterListType.staticList) {
      return false; // Not implemented yet without Task IDs
    }
    return filter?.matches(task) ?? true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'type': type.index,
        'filter': filter?.toJson(),
        'taskIds': taskIds,
      };

  factory FilterList.fromJson(Map<String, dynamic> json) => FilterList(
        id: json['id'],
        name: json['name'],
        icon: IconData(json['iconCodePoint'],
            fontFamily: json['iconFontFamily'] ?? 'MaterialIcons'),
        type: FilterListType.values[json['type']],
        filter:
            json['filter'] != null ? TaskFilter.fromJson(json['filter']) : null,
        taskIds: List<String>.from(json['taskIds'] ?? []),
      );

  static FilterList recent() => FilterList(
      id: "recent",
      name: "Recent",
      icon: Icons.calendar_today, // Using calendar_today for Recent/Upcoming
      type: FilterListType.preset,
      filter: TaskFilter(
          scheduledDateFilter: DateFilterType.recent,
          dueDateFilter: DateFilterType.recent,
          nextDays: 14,
          useOrLogic: true));

  static FilterList inbox() => FilterList(
      id: "inbox",
      name: "Inbox",
      icon: Icons.inbox,
      type: FilterListType.preset,
      filter: TaskFilter(
          scheduledDateFilter: DateFilterType.noDate,
          dueDateFilter: DateFilterType.noDate,
          inheritDate: false, // Inbox 默认不继承文件名日期，保持“收件箱”纯净？
          // 用户说“日记日期继承...可以自由决定某个筛选是否启用”。
          // 默认 Global 是开启的。如果我这里设为 false, 那 Inbox 就看不到继承日期的任务了（视为无日期，所以看得到？）
          // 继承日期 ==> 有日期。
          // Inbox logic: noDate.
          // 如果 inheritDate=true (默认): 从文件名继承日期 -> 变为有日期 -> Inbox 排除。
          // 如果 inheritDate=false: 忽略继承日期 -> 无日期 -> Inbox 包含。
          // 逻辑上，Inbox 应该包含那些“还没处理”的任务。如果文件名给了日期，它就“被处理”到那一天了。
          // 但如果用户想在 Inbox 里看到所有“正文没写日期”的任务，即使在日记文件里？
          // 通常 Inbox = No Date.
          // 暂时保持默认 true (继承)，这样“日记里的任务”会自动归档到该日记日期，不在 Inbox 显示。
          useOrLogic: false));

  static FilterList all() => FilterList(
      id: "all",
      name: "All",
      icon: Icons.list,
      type: FilterListType.preset,
      filter: TaskFilter(
          scheduledDateFilter: DateFilterType.none,
          dueDateFilter: DateFilterType.none));
}
