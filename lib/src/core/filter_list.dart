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
      return false;
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

  // ===================== Five Default Filters =====================

  static FilterList upcoming() => FilterList(
        id: "upcoming",
        name: "📅 upcoming",
        icon: Icons.calendar_today,
        type: FilterListType.preset,
        filter: TaskFilter(
          inheritDate: true,
          filterRules: FilterRules(
            groupMode: ConditionCombineMode.all,
            groups: [
              FilterConditionGroup(
                mode: ConditionCombineMode.all,
                conditions: [
                  const FilterCondition(
                    field: FilterField.status,
                    statusValue: StatusFilterType.todo,
                  ),
                ],
              ),
              FilterConditionGroup(
                mode: ConditionCombineMode.any,
                conditions: [
                  const FilterCondition(
                    field: FilterField.scheduledDate,
                    dateOperator: DateOperator.isInNextDays,
                    intValue: 14,
                  ),
                  const FilterCondition(
                    field: FilterField.dueDate,
                    dateOperator: DateOperator.isInNextDays,
                    intValue: 14,
                  ),
                  const FilterCondition(
                    field: FilterField.scheduledDate,
                    dateOperator: DateOperator.isBeforeToday,
                  ),
                  const FilterCondition(
                    field: FilterField.dueDate,
                    dateOperator: DateOperator.isBeforeToday,
                  ),
                ],
              ),
            ],
          ),
        ),
        sortRules: [
          SortRule(
              field: SortField.scheduledDate,
              direction: SortDirection.descending),
        ],
      );

  static FilterList today() => FilterList(
        id: "today",
        name: "📆 today",
        icon: Icons.today,
        type: FilterListType.preset,
        filter: TaskFilter(
          inheritDate: true,
          filterRules: FilterRules(
            groupMode: ConditionCombineMode.all,
            groups: [
              FilterConditionGroup(
                mode: ConditionCombineMode.all,
                conditions: [
                  const FilterCondition(
                    field: FilterField.status,
                    statusValue: StatusFilterType.todo,
                  ),
                ],
              ),
              FilterConditionGroup(
                mode: ConditionCombineMode.any,
                conditions: [
                  const FilterCondition(
                    field: FilterField.scheduledDate,
                    dateOperator: DateOperator.isToday,
                  ),
                  const FilterCondition(
                    field: FilterField.dueDate,
                    dateOperator: DateOperator.isToday,
                  ),
                ],
              ),
            ],
          ),
        ),
        sortRules: [
          SortRule(
              field: SortField.scheduledDate,
              direction: SortDirection.descending),
        ],
      );

  static FilterList inbox() => FilterList(
        id: "inbox",
        name: "📥 inbox",
        icon: Icons.inbox,
        type: FilterListType.preset,
        filter: TaskFilter(
          inheritDate: false,
          filterRules: FilterRules(
            groupMode: ConditionCombineMode.all,
            groups: [
              FilterConditionGroup(
                mode: ConditionCombineMode.all,
                conditions: [
                  const FilterCondition(
                    field: FilterField.status,
                    statusValue: StatusFilterType.todo,
                  ),
                  const FilterCondition(
                    field: FilterField.scheduledDate,
                    dateOperator: DateOperator.isEmpty,
                  ),
                  const FilterCondition(
                    field: FilterField.dueDate,
                    dateOperator: DateOperator.isEmpty,
                  ),
                ],
              ),
            ],
          ),
        ),
        sortRules: [
          SortRule(
              field: SortField.createdDate,
              direction: SortDirection.descending),
        ],
      );

  static FilterList completed() => FilterList(
        id: "completed",
        name: "✅ completed",
        icon: Icons.done_all,
        type: FilterListType.preset,
        filter: TaskFilter(
          filterRules: FilterRules(
            groupMode: ConditionCombineMode.all,
            groups: [
              FilterConditionGroup(
                mode: ConditionCombineMode.all,
                conditions: [
                  const FilterCondition(
                    field: FilterField.status,
                    statusValue: StatusFilterType.done,
                  ),
                ],
              ),
            ],
          ),
        ),
        sortRules: [
          SortRule(
              field: SortField.dueDate, direction: SortDirection.descending),
        ],
      );

  static FilterList all() => FilterList(
        id: "all",
        name: "📋 all",
        icon: Icons.list,
        type: FilterListType.preset,
        filter: TaskFilter(
            // No filterRules means match all tasks
            ),
        sortRules: [
          SortRule(
              field: SortField.scheduledDate,
              direction: SortDirection.descending),
        ],
      );
}
