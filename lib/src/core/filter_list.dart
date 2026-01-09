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

enum SortField {
  alphabetical,
  dueDate,
  scheduledDate,
  createdDate,
  priority,
  status,
}

enum SortDirection {
  ascending,
  descending,
}

enum GroupByField {
  none,
  dueDate,
  scheduledDate,
  filePath,
  priority,
  status,
}

enum TaskCompletionAction {
  keep,
  delete,
  archive,
}

enum DatePresetType {
  none,
  today,
  todayPlusDays,
  specificDate,
}

class DatePreset {
  final DatePresetType type;
  final int? offsetDays;
  final DateTime? specificDate;

  const DatePreset({
    this.type = DatePresetType.none,
    this.offsetDays,
    this.specificDate,
  });

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'offsetDays': offsetDays,
        'specificDate': specificDate?.toIso8601String(),
      };

  factory DatePreset.fromJson(Map<String, dynamic> json) => DatePreset(
        type: DatePresetType.values[json['type']],
        offsetDays: json['offsetDays'],
        specificDate: json['specificDate'] != null
            ? DateTime.parse(json['specificDate'])
            : null,
      );
}

class NewTaskDefaults {
  final List<String> tags;
  final DatePreset? dueDate;
  final DatePreset? scheduledDate;
  final String? filePath;

  const NewTaskDefaults({
    this.tags = const [],
    this.dueDate,
    this.scheduledDate,
    this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'tags': tags,
        'dueDate': dueDate?.toJson(),
        'scheduledDate': scheduledDate?.toJson(),
        'filePath': filePath,
      };

  factory NewTaskDefaults.fromJson(Map<String, dynamic> json) =>
      NewTaskDefaults(
        tags: List<String>.from(json['tags'] ?? []),
        dueDate: json['dueDate'] != null
            ? DatePreset.fromJson(json['dueDate'])
            : null,
        scheduledDate: json['scheduledDate'] != null
            ? DatePreset.fromJson(json['scheduledDate'])
            : null,
        filePath: json['filePath'],
      );
}

class SortRule {
  final SortField field;
  final SortDirection direction;

  const SortRule({
    this.field = SortField.dueDate,
    this.direction = SortDirection.ascending,
  });

  Map<String, dynamic> toJson() => {
        'field': field.index,
        'direction': direction.index,
      };

  factory SortRule.fromJson(Map<String, dynamic> json) => SortRule(
        field: SortField.values[json['field']],
        direction: SortDirection.values[json['direction']],
      );
}

class FilterList {
  final String id;
  final String name;
  final IconData icon;
  final FilterListType type;

  final TaskFilter? filter;
  final List<String> taskIds;
  final List<SortRule> sortRules;
  final GroupByField groupBy;
  final NewTaskDefaults? newTaskDefaults;
  final TaskCompletionAction completionAction;

  const FilterList({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.filter,
    this.taskIds = const [],
    this.sortRules = const [],
    this.groupBy = GroupByField.none,
    this.newTaskDefaults,
    this.completionAction = TaskCompletionAction.keep,
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
        'sortRules': sortRules.map((e) => e.toJson()).toList(),
        'groupBy': groupBy.index,
        'newTaskDefaults': newTaskDefaults?.toJson(),
        'completionAction': completionAction.index,
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
        sortRules: (json['sortRules'] as List<dynamic>?)
                ?.map((e) => SortRule.fromJson(e))
                .toList() ??
            [],
        groupBy: json['groupBy'] != null
            ? GroupByField.values[json['groupBy']]
            : GroupByField.none,
        newTaskDefaults: json['newTaskDefaults'] != null
            ? NewTaskDefaults.fromJson(json['newTaskDefaults'])
            : null,
        completionAction: json['completionAction'] != null
            ? TaskCompletionAction.values[json['completionAction']]
            : TaskCompletionAction.keep,
      );

  static FilterList upcoming() => FilterList(
      id: "upcoming",
      name: "Upcoming",
      icon: Icons.calendar_today,
      type: FilterListType.preset,
      filter: TaskFilter(
          scheduledDateFilter: DateFilterType.beforeDate,
          dueDateFilter: DateFilterType.beforeDate,
          relativeEnd: 14,
          inheritDate: false,
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
