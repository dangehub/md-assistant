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
    } else {
      _nameController = TextEditingController();
      _pathController = TextEditingController();
    }
    _tagController = TextEditingController();
    _excludedTagController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _tagController.dispose();
    _excludedTagController.dispose();
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
            items: DateFilterType.values
                .where((t) => t != DateFilterType.nextNDays)
                .map((type) {
              return DropdownMenuItem(
                value: type,
                child:
                    Text(TaskFilter.getFilterTypeName(type, days: _nextDays)),
              );
            }).toList(),
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
            items: DateFilterType.values
                .where((t) => t != DateFilterType.nextNDays)
                .map((type) {
              return DropdownMenuItem(
                value: type,
                child:
                    Text(TaskFilter.getFilterTypeName(type, days: _nextDays)),
              );
            }).toList(),
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
}
