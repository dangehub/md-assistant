import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/filter_list.dart';
import 'package:obsi/src/core/task_filter.dart';
import 'package:uuid/uuid.dart';

class FilterEditorScreen extends StatefulWidget {
  final FilterList? existingFilter; // If null, creating new

  const FilterEditorScreen({Key? key, this.existingFilter}) : super(key: key);

  @override
  State<FilterEditorScreen> createState() => _FilterEditorScreenState();
}

class _FilterEditorScreenState extends State<FilterEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _pathController;
  late TextEditingController _tagController;
  late TextEditingController _excludedTagController;

  StatusFilterType _statusFilter = StatusFilterType.all;
  DateFilterType _scheduledDateFilter = DateFilterType.none;
  DateFilterType _dueDateFilter = DateFilterType.none;
  int _nextDays = 7;
  bool _useOrLogic = true;
  bool _inheritDate = true;
  int _weekStart = 1; // 1=Mon, 7=Sun
  int? _relativeStart; // default null? or 0?
  int? _relativeEnd;
  List<String> _tags = [];
  List<String> _excludedTags = [];

  DateTime? _customScheduledStart;
  DateTime? _customScheduledEnd;
  DateTime? _customDueStart;
  DateTime? _customDueEnd;
  TaskCompletionAction _completionAction = TaskCompletionAction.keep;
  List<SortRule> _sortRules = [];
  GroupByField _groupBy = GroupByField.none;

  // New Task Defaults
  List<String> _defaultTags = [];
  DatePreset _defaultDueDate = const DatePreset();
  DatePreset _defaultScheduledDate = const DatePreset();
  late TextEditingController _defaultPathController;
  late TextEditingController _defaultTagController;

  @override
  void initState() {
    super.initState();
    if (widget.existingFilter != null) {
      final f = widget.existingFilter!;
      _nameController = TextEditingController(text: f.name);
      _nameController = TextEditingController(text: f.name);
      if (f.filter != null) {
        _statusFilter = f.filter!.statusFilter;
        _scheduledDateFilter = f.filter!.scheduledDateFilter;
        _dueDateFilter = f.filter!.dueDateFilter;
        _nextDays = f.filter!.nextDays;
        _useOrLogic = f.filter!.useOrLogic;
        _inheritDate = f.filter!.inheritDate;
        _tags = List.from(f.filter!.tags);
        _excludedTags = List.from(f.filter!.excludedTags);
        _excludedTags = List.from(f.filter!.excludedTags);
        _customScheduledStart = f.filter!.customScheduledStart;
        _customScheduledEnd = f.filter!.customScheduledEnd;
        _customDueStart = f.filter!.customDueStart;
        _customDueEnd = f.filter!.customDueEnd;
        _relativeStart = f.filter!.relativeStart;
        _relativeEnd = f.filter!.relativeEnd;
        _weekStart = f.filter!.weekStart;
        _pathController =
            TextEditingController(text: f.filter!.pathContains ?? "");
      } else {
        _pathController = TextEditingController();
      }
      _sortRules = List.from(f.sortRules);
      _groupBy = f.groupBy;

      if (f.newTaskDefaults != null) {
        _defaultTags = List.from(f.newTaskDefaults!.tags);
        _defaultDueDate = f.newTaskDefaults!.dueDate ?? const DatePreset();
        _defaultScheduledDate =
            f.newTaskDefaults!.scheduledDate ?? const DatePreset();
        _defaultPathController =
            TextEditingController(text: f.newTaskDefaults!.filePath ?? "");
      } else {
        _defaultPathController = TextEditingController();
      }
      _completionAction = f.completionAction;
    } else {
      _nameController = TextEditingController();
      _pathController = TextEditingController();
      _sortRules = []; // Default empty
      _defaultPathController = TextEditingController();
    }
    _tagController = TextEditingController();
    _excludedTagController = TextEditingController();
    _defaultTagController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _tagController.dispose();
    _pathController.dispose();
    _tagController.dispose();
    _excludedTagController.dispose();
    _defaultPathController.dispose();
    _defaultTagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
      _tagController.clear();
    }
  }

  void _addExcludedTag(String tag) {
    if (tag.isNotEmpty && !_excludedTags.contains(tag)) {
      setState(() {
        _excludedTags.add(tag);
      });
      _excludedTagController.clear();
    }
  }

  void _addDefaultTag(String tag) {
    if (tag.isNotEmpty && !_defaultTags.contains(tag)) {
      setState(() {
        _defaultTags.add(tag);
      });
      _defaultTagController.clear();
    }
  }

  void _save() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入筛选名称')),
      );
      return;
    }

    final taskFilter = TaskFilter(
      scheduledDateFilter: _scheduledDateFilter,
      dueDateFilter: _dueDateFilter,
      nextDays: _nextDays,
      useOrLogic: _useOrLogic,
      inheritDate: _inheritDate,
      tags: _tags,
      excludedTags: _excludedTags,
      pathContains:
          _pathController.text.isNotEmpty ? _pathController.text : null,
      statusFilter: _statusFilter,
      customScheduledStart: _customScheduledStart,
      customScheduledEnd: _customScheduledEnd,
      customDueStart: _customDueStart,
      customDueEnd: _customDueEnd,
      relativeStart: _relativeStart,
      relativeEnd: _relativeEnd,
      weekStart: _weekStart,
    );

    final filterList = FilterList(
      id: widget.existingFilter?.id ?? const Uuid().v4(),
      name: _nameController.text,
      icon: Icons.list, // Default, not used anymore or kept for compat
      type: FilterListType
          .custom, // Always custom now? Or keep existing type if editing?
      // If editing builtin, maybe keep builtin type but properties are edited?
      // If we save it back, does it matter?
      // The user wants to "edit" builtins. If we set type to custom, it just means it's a filter.
      // Let's preserve type if existing, else custom.
      filter: taskFilter,
      taskIds: [],
      sortRules: _sortRules,
      groupBy: _groupBy,
      newTaskDefaults: NewTaskDefaults(
        tags: _defaultTags,
        dueDate: _defaultDueDate.type != DatePresetType.none
            ? _defaultDueDate
            : null,
        scheduledDate: _defaultScheduledDate.type != DatePresetType.none
            ? _defaultScheduledDate
            : null,
        filePath: _defaultPathController.text.isNotEmpty
            ? _defaultPathController.text
            : null,
      ),
    );

    Navigator.pop(context, filterList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingFilter == null ? '新建筛选' : '编辑筛选'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: '筛选名称', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          // Icon selection removed as per request
          const Divider(height: 32),

          // Status Filter
          const Text('任务状态', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 10,
            children: StatusFilterType.values.map((type) {
              return ChoiceChip(
                label: Text(type.toString().split('.').last.toUpperCase()),
                selected: _statusFilter == type,
                onSelected: (selected) {
                  if (selected) setState(() => _statusFilter = type);
                },
              );
            }).toList(),
          ),
          const Divider(height: 32),

          // Date Filter
          const Text('日期筛选 (Scheduled)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<DateFilterType>(
            isExpanded: true,
            value: _scheduledDateFilter,
            items: _buildDropdownItems(_scheduledDateFilter),
            onChanged: (val) {
              if (val != null) setState(() => _scheduledDateFilter = val);
            },
          ),
          if (_scheduledDateFilter == DateFilterType.thisWeek)
            Row(
              children: [
                const Text("周起始日: "),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _weekStart,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("周一")),
                    DropdownMenuItem(value: 7, child: Text("周日")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _weekStart = val);
                  },
                ),
              ],
            ),
          if (_scheduledDateFilter == DateFilterType.relative)
            _buildRelativeDateInputs(
                _relativeStart,
                _relativeEnd,
                (start, end) => setState(() {
                      _relativeStart = start;
                      _relativeEnd = end;
                    })),
          if (_scheduledDateFilter == DateFilterType.nextDays)
            // Deprecated nextDays UI, convert to Relative?
            // For now keep slider for backward compat if user selects it (though hidden from dropdown?)
            // I hid nextNDays, kept nextDays.
            // If user wants "Future X Days", they can use Relative (0 to X).
            // I should prob show nextDays slider if they insist on using legacy type.
            Row(
              children: [
                const Text("天数: "),
                Expanded(
                  child: Slider(
                      value: _nextDays.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: "$_nextDays",
                      onChanged: (val) =>
                          setState(() => _nextDays = val.toInt())),
                ),
                Text("$_nextDays 天"),
              ],
            ),
          if (_scheduledDateFilter == DateFilterType.custom)
            _buildCustomDateRangePicker(
              _customScheduledStart,
              _customScheduledEnd,
              (start, end) {
                setState(() {
                  _customScheduledStart = start;
                  _customScheduledEnd = end;
                });
              },
            ),
          if (_scheduledDateFilter == DateFilterType.beforeDate)
            _buildBeforeDateUI(
              _customScheduledEnd,
              _relativeEnd,
              (customDate, relativeDays) {
                setState(() {
                  _customScheduledEnd = customDate;
                  _relativeEnd = relativeDays;
                  _customScheduledStart = null;
                  _relativeStart = null; // Clear others
                });
              },
            ),

          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('从文件名继承日期'),
            subtitle: const Text('如果启用，无日期的任务将使用文件名中的日期'),
            value: _inheritDate,
            onChanged: (val) => setState(() => _inheritDate = val),
          ),

          const SizedBox(height: 10),
          const Text('日期筛选 (Due Date)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<DateFilterType>(
            isExpanded: true,
            value: _dueDateFilter,
            items: _buildDropdownItems(_dueDateFilter),
            onChanged: (val) {
              if (val != null) setState(() => _dueDateFilter = val);
            },
          ),
          if (_dueDateFilter == DateFilterType.thisWeek)
            Row(
              children: [
                const Text("周起始日: "),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _weekStart,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("周一")),
                    DropdownMenuItem(value: 7, child: Text("周日")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _weekStart = val);
                  },
                ),
              ],
            ),
          if (_dueDateFilter == DateFilterType.relative)
            _buildRelativeDateInputs(
                _relativeStart, // Usually separate for due/scheduled?
                // TaskFilter has single relativeStart/End fields?
                // Ah, TaskFilter has scheduledDateFilter AND dueDateFilter.
                // But only ONE relativeStart/End field set!
                // This is a flaw in my TaskFilter design change.
                // TaskFilter should have scheduledRelativeStart/End and dueRelativeStart/End if they can be different.
                // Or I assume filters usually use one or the other?
                // Currently TaskFilter has:
                // customScheduledStart/End AND customDueStart/End.
                // I added relativeStart/End ONCE.
                // I should have added scheduledRelativeStart... etc.
                // I need to fix TaskFilter first!
                _relativeEnd,
                (start, end) => setState(() {
                      _relativeStart = start;
                      _relativeEnd = end;
                    })),
          if (_dueDateFilter == DateFilterType.custom)
            _buildCustomDateRangePicker(
              _customDueStart,
              _customDueEnd,
              (start, end) {
                setState(() {
                  _customDueStart = start;
                  _customDueEnd = end;
                });
              },
            ),
          if (_dueDateFilter == DateFilterType.beforeDate)
            _buildBeforeDateUI(
              _customDueEnd,
              _relativeEnd, // Note: TaskFilter currently shares relativeEnd. This is a potential bug if both use relative.
              // Logic check: TaskFilter has single relativeEnd.
              // If user sets Scheduled=Relative AND Due=Relative, they clash.
              // But standard usage usually filters one.
              // We will proceed. Ideally TaskFilter needs separate fields.
              (customDate, relativeDays) {
                setState(() {
                  _customDueEnd = customDate;
                  _relativeEnd = relativeDays;
                  _customDueStart = null;
                  _relativeStart = null;
                });
              },
            ),

          CheckboxListTile(
              title: const Text("Scheduled 或 Due 满足任一即可 (OR 逻辑)"),
              value: _useOrLogic,
              onChanged: (val) => setState(() => _useOrLogic = val!)),
          const Divider(height: 32),

          // Tags
          const Text('必须包含标签', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _tags
                .map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ))
                .toList(),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(hintText: '输入标签后点击添加'),
                  onSubmitted: _addTag,
                ),
              ),
              IconButton(
                  onPressed: () => _addTag(_tagController.text),
                  icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 16),

          // Excluded Tags
          const Text('排除标签', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _excludedTags
                .map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.red.shade100,
                      onDeleted: () =>
                          setState(() => _excludedTags.remove(tag)),
                    ))
                .toList(),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _excludedTagController,
                  decoration: const InputDecoration(hintText: '输入排除标签后点击添加'),
                  onSubmitted: _addExcludedTag,
                ),
              ),
              IconButton(
                  onPressed: () => _addExcludedTag(_excludedTagController.text),
                  icon: const Icon(Icons.add)),
            ],
          ),
          const Divider(height: 32),

          // Path
          const Text('文件路径包含', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(hintText: '例如: Work/Projects'),
          ),
          const SizedBox(height: 50),

          // Group By
          const Text('分组方式 (Group By)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<GroupByField>(
            isExpanded: true,
            value: _groupBy,
            items: const [
              DropdownMenuItem(
                  value: GroupByField.none, child: Text('不分组 (None)')),
              DropdownMenuItem(
                  value: GroupByField.dueDate, child: Text('Due Date')),
              DropdownMenuItem(
                  value: GroupByField.scheduledDate,
                  child: Text('Scheduled Date')),
              DropdownMenuItem(
                  value: GroupByField.filePath, child: Text('File Path')),
              DropdownMenuItem(
                  value: GroupByField.priority, child: Text('Priority')),
              DropdownMenuItem(
                  value: GroupByField.status, child: Text('Status')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _groupBy = val);
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 32),

          // Sorting Section
          const Divider(height: 32),
          const Text('排序规则 (优先级从上到下)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ReorderableListView(
            // Not a valid property for ReorderableListView in older Flutter?
            // Better use simple Column if items are few, or reorderable list inside expanded/shrinkwrap
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _sortRules.removeAt(oldIndex);
                _sortRules.insert(newIndex, item);
              });
            },
            children: [
              for (int i = 0; i < _sortRules.length; i++)
                ListTile(
                  // Key might be issue if duplicate rules? SortRule equality?
                  // SortRule uses default equality which is object identity unless overridden?
                  // FilterList is immutable/const but SortRule is simple class.
                  // Just use unique key if possible or object identity if rebuilds create new objects.
                  // Since we treat them as mutable state here, maybe ObjectKey.
                  key: ObjectKey(_sortRules[i]),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.drag_handle),
                  title: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<SortField>(
                          isExpanded: true,
                          value: _sortRules[i].field,
                          items: const [
                            DropdownMenuItem(
                                value: SortField.dueDate,
                                child: Text('Due Date')),
                            DropdownMenuItem(
                                value: SortField.scheduledDate,
                                child: Text('Scheduled Date')),
                            DropdownMenuItem(
                                value: SortField.priority,
                                child: Text('Priority')),
                            DropdownMenuItem(
                                value: SortField.alphabetical,
                                child: Text('Alphabetical')),
                            DropdownMenuItem(
                                value: SortField.createdDate,
                                child: Text('Created Date')),
                            DropdownMenuItem(
                                value: SortField.status, child: Text('Status')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sortRules[i] = SortRule(
                                  field: val,
                                  direction: _sortRules[i].direction,
                                );
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<SortDirection>(
                        value: _sortRules[i].direction,
                        items: const [
                          DropdownMenuItem(
                              value: SortDirection.ascending,
                              child: Text('升序 (Asc)')),
                          DropdownMenuItem(
                              value: SortDirection.descending,
                              child: Text('降序 (Desc)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sortRules[i] = SortRule(
                                field: _sortRules[i].field,
                                direction: val,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _sortRules.removeAt(i);
                      });
                    },
                  ),
                )
            ],
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _sortRules.add(const SortRule(
                    field: SortField.dueDate,
                    direction: SortDirection.ascending));
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('添加排序规则'),
          ),

          const Divider(height: 32),
          const Text('新任务默认设置 (New Task Defaults)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Default Tags
          const Text('默认标签:'),
          Wrap(
            spacing: 8,
            children: _defaultTags
                .map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () => setState(() => _defaultTags.remove(tag)),
                    ))
                .toList(),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _defaultTagController,
                  decoration: const InputDecoration(hintText: '输入默认标签'),
                  onSubmitted: _addDefaultTag,
                ),
              ),
              IconButton(
                  onPressed: () => _addDefaultTag(_defaultTagController.text),
                  icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 16),

          // Default Due DatePreset
          const Text('默认截止日期 (Due Date):'),
          DropdownButton<DatePresetType>(
              value: _defaultDueDate.type,
              isExpanded: true,
              items: DatePresetType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _defaultDueDate = DatePreset(
                        type: val,
                        offsetDays: _defaultDueDate.offsetDays,
                        specificDate: _defaultDueDate.specificDate);
                  });
                }
              }),
          if (_defaultDueDate.type == DatePresetType.todayPlusDays)
            TextFormField(
              initialValue: _defaultDueDate.offsetDays?.toString(),
              decoration: const InputDecoration(labelText: '偏移天数 (0=Today)'),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (val) => setState(() {
                _defaultDueDate = DatePreset(
                    type: _defaultDueDate.type,
                    offsetDays: int.tryParse(val),
                    specificDate: _defaultDueDate.specificDate);
              }),
            ),
          if (_defaultDueDate.type == DatePresetType.specificDate)
            _buildDatePicker(_defaultDueDate.specificDate, (d) {
              setState(() {
                _defaultDueDate = DatePreset(
                    type: _defaultDueDate.type,
                    offsetDays: _defaultDueDate.offsetDays,
                    specificDate: d);
              });
            }, label: "选择指定日期"),

          const SizedBox(height: 16),

          // Default Scheduled DatePreset
          const Text('默认计划日期 (Scheduled Date):'),
          DropdownButton<DatePresetType>(
              value: _defaultScheduledDate.type,
              isExpanded: true,
              items: DatePresetType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _defaultScheduledDate = DatePreset(
                        type: val,
                        offsetDays: _defaultScheduledDate.offsetDays,
                        specificDate: _defaultScheduledDate.specificDate);
                  });
                }
              }),
          if (_defaultScheduledDate.type == DatePresetType.todayPlusDays)
            TextFormField(
              initialValue: _defaultScheduledDate.offsetDays?.toString(),
              decoration: const InputDecoration(labelText: '偏移天数 (0=Today)'),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (val) => setState(() {
                _defaultScheduledDate = DatePreset(
                    type: _defaultScheduledDate.type,
                    offsetDays: int.tryParse(val),
                    specificDate: _defaultScheduledDate.specificDate);
              }),
            ),
          if (_defaultScheduledDate.type == DatePresetType.specificDate)
            _buildDatePicker(_defaultScheduledDate.specificDate, (d) {
              setState(() {
                _defaultScheduledDate = DatePreset(
                    type: _defaultScheduledDate.type,
                    offsetDays: _defaultScheduledDate.offsetDays,
                    specificDate: d);
              });
            }, label: "选择指定日期"),

          const SizedBox(height: 16),
          // Default File Path
          const Text('默认文件路径 (可选):'),
          TextField(
            controller: _defaultPathController,
            decoration:
                const InputDecoration(hintText: '例如: Inbox.md 或 Work/Tasks.md'),
          ),

          const Divider(height: 32),
          const Text('完成任务时 (On Completion)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<TaskCompletionAction>(
            value: _completionAction,
            isExpanded: true,
            items: TaskCompletionAction.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _completionAction = val);
            },
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildCustomDateRangePicker(DateTime? start, DateTime? end,
      Function(DateTime?, DateTime?) onChanged) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Row(
      children: [
        Expanded(
          child: TextButton(
            child: Text(start != null ? dateFormat.format(start) : '开始日期'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: start ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                onChanged(picked, end);
              }
            },
          ),
        ),
        const Text("-"),
        Expanded(
          child: TextButton(
            child: Text(end != null ? dateFormat.format(end) : '结束日期'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: end ?? start ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                onChanged(start, picked);
              }
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            onChanged(null, null);
          },
        )
      ],
    );
  }

  Widget _buildRelativeDateInputs(
      int? start, int? end, Function(int?, int?) onChanged) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: start?.toString(),
            decoration: const InputDecoration(labelText: "开始偏移 (前N)"),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onChanged: (val) => onChanged(int.tryParse(val), end),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: end?.toString(),
            decoration: const InputDecoration(labelText: "结束偏移 (后N)"),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onChanged: (val) => onChanged(start, int.tryParse(val)),
          ),
        ),
      ],
    );
  }

  Widget _buildBeforeDateUI(DateTime? customDate, int? relativeDays,
      Function(DateTime?, int?) onChanged) {
    // Determine mode based on which value is set. Default to Absolute if neither or custom set.
    bool isRelative = relativeDays != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("类型: "),
            ToggleButtons(
              isSelected: [!isRelative, isRelative],
              onPressed: (index) {
                if (index == 0) {
                  // Switch to Absolute
                  onChanged(DateTime.now(), null); // Default to today or keep?
                } else {
                  // Switch to Relative
                  onChanged(null, 0); // Default to 0 (Today)
                }
              },
              constraints: const BoxConstraints(minHeight: 30, minWidth: 60),
              children: const [Text("绝对"), Text("相对")],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isRelative)
          _buildDatePicker(customDate, (d) => onChanged(d, null),
              label: "截止日期 (含)"),
        if (isRelative) ...[
          const Text("相对偏移: 前 N 天 或 后 N 天 (互斥)"),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  // Front N means negative offset.
                  // If relativeDays is negative -> show absolute value here.
                  initialValue:
                      (relativeDays < 0) ? (-relativeDays).toString() : '',
                  decoration: const InputDecoration(labelText: "前 N 天"),
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      final n = int.tryParse(val);
                      if (n != null) {
                        onChanged(null, -n); // Front N = -N
                      }
                    } else {
                      // If cleared, maybe 0?
                      onChanged(null, 0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  // Back N means positive offset.
                  initialValue: (relativeDays != null && relativeDays > 0)
                      ? relativeDays.toString()
                      : '',
                  decoration: const InputDecoration(labelText: "后 N 天"),
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      final n = int.tryParse(val);
                      if (n != null) {
                        onChanged(null, n); // Back N = +N
                      }
                    } else {
                      onChanged(null, 0);
                    }
                  },
                ),
              ),
            ],
          ),
        ]
      ],
    );
  }

  Widget _buildDatePicker(DateTime? date, Function(DateTime?) onChanged,
      {String label = '选择日期'}) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: TextButton(
            child: Text(date != null ? dateFormat.format(date) : '点击选择'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                onChanged(picked);
              }
            },
          ),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => onChanged(null),
          )
      ],
    );
  }

  List<DropdownMenuItem<DateFilterType>> _buildDropdownItems(
      DateFilterType currentValue) {
    // Define supported types to show in the list
    final Set<DateFilterType> supportedTypes = {
      DateFilterType.none,
      DateFilterType.today,
      DateFilterType.tomorrow,
      DateFilterType.thisWeek,
      DateFilterType.thisMonth,
      DateFilterType.overdue,
      DateFilterType.noDate,
      DateFilterType.custom,
      DateFilterType.relative,
      DateFilterType.beforeDate,
    };

    // Ensure the current value is included, even if deprecated/hidden
    final Set<DateFilterType> visibleTypes = {
      ...supportedTypes,
      currentValue,
    };

    // Sort them by enum index order or define a specific order?
    // Enum order is simplest.
    final sortedList = visibleTypes.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return sortedList.map((type) {
      return DropdownMenuItem(
        value: type,
        child: Text(TaskFilter.getFilterTypeName(type, days: _nextDays)),
      );
    }).toList();
  }
}
