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

  @override
  void initState() {
    super.initState();
    _filters = List.from(SettingsController.getInstance().filters);
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
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _filters.removeAt(oldIndex);
      _filters.insert(newIndex, item);
    });
    // Update controller immediately (or save on exit? Updating immediately is better UX for sync)
    // But reorder logic in controller handles indices slightly differently potentially or needs to be matched.
    // The controller's reorderFilters handles the index adjustment.
    // However, since we just mutated local state, we should pass original indices.
    // Wait, if I mutated local state, then calling controller might double mutate if I reload?
    // Let's call controller and let it update us via listener.
    // But reorderable list view expects local state update to prevent UI jump.
    // So:
    // 1. Update local state (done above).
    // 2. Call controller.

    // Actually, calling controller which notifies listener might cause a full rebuild that overrides local state anyway.
    // Let's try calling controller directly.
    SettingsController.getInstance().reorderFilters(
        oldIndex, newIndex < oldIndex ? newIndex : newIndex + 1);
    // Note: ReorderableListView passes newIndex such that if dragging downwards, newIndex is index+1 of target.
    // Controller logic: if (oldIndex < newIndex) newIndex -= 1;
    // So if I pass raw indices to controller, it should match.
    // Revert local change and trust controller?
    // ReorderableListView requires immediate visual feedback.
    // Let's trust logic.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理筛选列表'),
      ),
      body: ReorderableListView.builder(
        itemCount: _filters.length,
        onReorder: (oldIndex, newIndex) {
          // ReorderableListView passes newIndex that is 'slot' index.
          // If dragging down, newIndex is > oldIndex.
          // Controller logic:
          // if (oldIndex < newIndex) newIndex -= 1;
          // Let's match controller logic.
          SettingsController.getInstance().reorderFilters(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final filter = _filters[index];
          return ListTile(
            key: ValueKey(filter.id),
            // leading: Text(filter.name.split(' ').firstOrNull ?? '',
            //     style: TextStyle(fontSize: 20)), // Removed to avoid duplication
            // Or just show Icon if it has one (migrated ones might have).
            // But user said "Remove Icon options".
            // Let's show name.
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
