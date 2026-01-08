import 'package:flutter/material.dart';
import 'package:obsi/src/core/filter_list.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/inbox_tasks/filter_editor_screen.dart';

class FilterManagementScreen extends StatefulWidget {
  const FilterManagementScreen({Key? key}) : super(key: key);

  @override
  State<FilterManagementScreen> createState() => _FilterManagementScreenState();
}

class _FilterManagementScreenState extends State<FilterManagementScreen> {
  late List<FilterList> _filters;
  String? _widgetFilterId;

  @override
  void initState() {
    super.initState();
    _filters = List.from(SettingsController.getInstance().filters);
    _widgetFilterId = SettingsController.getInstance().widgetFilterId;
    SettingsController.getInstance().addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsController.getInstance().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {
      _filters = List.from(SettingsController.getInstance().filters);
      _widgetFilterId = SettingsController.getInstance().widgetFilterId;
    });
  }

  Future<void> _editFilter(FilterList filter) async {
    final result = await Navigator.push<FilterList>(
      context,
      MaterialPageRoute(
          builder: (context) => FilterEditorScreen(existingFilter: filter)),
    );

    if (result != null) {
      await SettingsController.getInstance().updateFilter(result);
    }
  }

  Future<void> _deleteFilter(FilterList filter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除筛选'),
        content: Text('确定要删除 "${filter.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SettingsController.getInstance().removeFilter(filter.id);
    }
  }

  Future<void> _addFilter() async {
    final result = await Navigator.push<FilterList>(
      context,
      MaterialPageRoute(builder: (context) => const FilterEditorScreen()),
    );

    if (result != null) {
      await SettingsController.getInstance().addFilter(result);
    }
  }

  Future<void> _selectWidgetFilter() async {
    var selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择小部件筛选器'),
          children: _filters.map((f) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f.id),
              child: ListTile(
                leading: _widgetFilterId == f.id
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                title: Text(f.name),
              ),
            );
          }).toList(),
        );
      },
    );

    if (selected != null) {
      await SettingsController.getInstance().updateWidgetFilterId(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    String widgetFilterName = "默认 (Default)";
    try {
      if (_widgetFilterId != null) {
        var f = _filters.firstWhere((element) => element.id == _widgetFilterId);
        widgetFilterName = f.name;
      } else {
        var f = _filters.firstWhere((element) => element.id == 'filter_today',
            orElse: () =>
                _filters.isNotEmpty ? _filters.first : FilterList.recent());
        widgetFilterName = "${f.name} (默认)";
      }
    } catch (e) {
      // quiet
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理筛选列表'),
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text("桌面小部件显示"),
            subtitle: Text(widgetFilterName),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _selectWidgetFilter,
          ),
          const Divider(),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _filters.length,
              onReorder: (oldIndex, newIndex) {
                SettingsController.getInstance()
                    .reorderFilters(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final filter = _filters[index];
                return ListTile(
                  key: ValueKey(filter.id),
                  title: Text(filter.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editFilter(filter),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteFilter(filter),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFilter,
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension StringExtension on String {
  String? get firstOrNull => isEmpty ? null : this[0];
}
