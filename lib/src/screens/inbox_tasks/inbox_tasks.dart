import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/inbox_tasks/calendar_view.dart';
import 'package:obsi/src/screens/inbox_tasks/file_view.dart';
import 'package:obsi/src/screens/inbox_tasks/main_messages.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';
import 'package:obsi/main_navigator.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
import 'package:obsi/src/screens/task_editor/task_editor.dart';
import 'package:obsi/src/widgets/task_card.dart';
import 'package:obsi/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart';

import 'package:obsi/src/core/filter_list.dart';
import 'package:obsi/src/screens/inbox_tasks/filter_management_screen.dart';
import 'package:obsi/src/core/variable_resolver.dart';
import 'package:path/path.dart' as p;

class InboxTasks extends StatelessWidget with WidgetsBindingObserver {
  final InboxTasksCubit _inboxTaskCubit;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  InboxTasks(this._inboxTaskCubit, {super.key}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inboxTaskCubit.refreshTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    _inboxTaskCubit.updateSearchQuery(_searchController.text);

    return Scaffold(
        appBar: _showAppBar(context),
        floatingActionButton: _showActionButton(context),
        body: Column(
          children: [
            _buildFilterBar(context),
            Expanded(
              child: BlocBuilder<InboxTasksCubit, InboxTasksState>(
                  bloc: _inboxTaskCubit,
                  builder: (context, state) {
                    if (state is InboxTasksList) {
                      return _showListView(
                          context, state.tasks, _inboxTaskCubit.searchQuery);
                    }

                    if (state is InboxTasksLoading) {
                      return Center(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text('Loading tasks from \n${state.vault}'),
                        ],
                      ));
                    }

                    if (state is InboxTasksMessage) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      });
                      return _showListView(
                          context, state.tasks, _inboxTaskCubit.searchQuery);
                    }

                    return Container();
                  }),
            ),
          ],
        ));
  }

  Widget _buildFilterBar(BuildContext context) {
    return BlocBuilder<InboxTasksCubit, InboxTasksState>(
        bloc: _inboxTaskCubit,
        builder: (context, state) {
          final filters = _inboxTaskCubit.availableFilters;
          final currentFilter = _inboxTaskCubit.currentFilterList;

          return Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...filters.map((filter) {
                        final isSelected = filter.id == currentFilter.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter.name),
                            // avatar: Icon(filter.icon, size: 16), // Icons removed in favor of Emojis
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _inboxTaskCubit.selectFilterList(filter);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune), // Tune/Settings icon
                  onPressed: () => _openFilterManagement(context),
                  tooltip: "管理筛选",
                ),
              ],
            ),
          );
        });
  }

  ListView _showListView(
      BuildContext context, List<Task> tasks, String highlightedText) {
    final items = _createViewItems(context, tasks, highlightedText);
    return ListView(
      controller: _scrollController,
      children: [
        _buildTagFilterLine(context),
        ...items,
        const SizedBox(height: 80),
      ],
    );
  }

  AppBar _showAppBar(BuildContext context) {
    return AppBar(
      title: Align(
          alignment: Alignment.centerLeft,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BlocBuilder<InboxTasksCubit, InboxTasksState>(
                bloc: _inboxTaskCubit,
                builder: (context, _) {
                  return Text(_inboxTaskCubit.caption);
                }),
            BlocBuilder<InboxTasksCubit, InboxTasksState>(
                bloc: _inboxTaskCubit,
                builder: (context, _) {
                  return Text(_inboxTaskCubit.subcaption,
                      style: Theme.of(context).textTheme.bodySmall);
                })
          ])),
      actions: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          BlocBuilder<InboxTasksCubit, InboxTasksState>(
            bloc: _inboxTaskCubit,
            builder: (innerContext, _) {
              return SizedBox(
                width: MediaQuery.of(innerContext).size.width / 3,
                height: kToolbarHeight * 0.5,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Filter tasks...',
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (query) {
                    _inboxTaskCubit.updateSearchQuery(query);
                  },
                ),
              );
            },
          ),
          // Overdue toggle button - Keeping it for legacy support if needed
          // Or we can remove it if "Recent" filter is sufficient.
          // Keeping it as an additional filter.
          BlocBuilder<InboxTasksCubit, InboxTasksState>(
            bloc: _inboxTaskCubit,
            builder: (context, _) {
              return IconButton(
                tooltip: _inboxTaskCubit.showOverdueOnly
                    ? "Show all tasks"
                    : "Show overdue only",
                icon: Icon(
                  Icons.warning_amber_rounded,
                  color: _inboxTaskCubit.showOverdueOnly ? Colors.red : null,
                ),
                onPressed: () {
                  _inboxTaskCubit.updateShowOverdueTasksOnly(
                      !_inboxTaskCubit.showOverdueOnly);
                },
              );
            },
          ),
          // View Mode Switcher
          BlocBuilder<InboxTasksCubit, InboxTasksState>(
              bloc: _inboxTaskCubit,
              builder: (context, _) {
                ViewMode getNextViewMode(ViewMode current) {
                  switch (current) {
                    case ViewMode.list:
                      return ViewMode.grouped;
                    case ViewMode.grouped:
                      return ViewMode.calendar;
                    case ViewMode.calendar:
                      return ViewMode.list;
                  }
                }

                IconData getViewModeIcon(ViewMode mode) {
                  switch (mode) {
                    case ViewMode.list:
                      return Icons.list;
                    case ViewMode.grouped:
                      return Icons.folder;
                    case ViewMode.calendar:
                      return Icons.calendar_month;
                  }
                }

                return IconButton(
                    tooltip: "Switch View Mode",
                    onPressed: () {
                      ViewMode nextMode =
                          getNextViewMode(_inboxTaskCubit.viewMode);
                      _inboxTaskCubit.updateViewMode(nextMode);
                    },
                    icon: Icon(getViewModeIcon(_inboxTaskCubit.viewMode)));
              }),
        ])
      ],
    );
  }

  Widget _buildTagFilterLine(BuildContext context) {
    return BlocBuilder<InboxTasksCubit, InboxTasksState>(
      bloc: _inboxTaskCubit,
      builder: (context, state) {
        final availableTags = _inboxTaskCubit.availableTags;
        final selectedTags = _inboxTaskCubit.selectedTags;
        final excludedTags = _inboxTaskCubit.excludedTags;

        if (availableTags.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableTags.length,
                    itemBuilder: (context, index) {
                      final tag = availableTags[index];
                      final isSelected = selectedTags.contains(tag);
                      final isExcluded = excludedTags.contains(tag);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            _inboxTaskCubit.toggleTag(tag);
                          },
                          onLongPress: () {
                            _inboxTaskCubit.toggleExcludeTag(tag);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isExcluded
                                  ? Colors.red.shade100
                                  : isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: isExcluded
                                    ? Colors.red.shade400
                                    : isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                color: isExcluded
                                    ? Colors.red.shade700
                                    : isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: isSelected || isExcluded
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (selectedTags.isNotEmpty || excludedTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      _inboxTaskCubit.clearTagFilter();
                    },
                    child: Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _showActionButton(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () {
        var settings = SettingsController.getInstance();
        var resolvedTasksFile = VariableResolver.resolve(settings.tasksFile);
        var createTasksPath =
            p.join(settings.vaultDirectory!, resolvedTasksFile);

        // Determine default date based on current filter or today
        // If "Inbox" (No Date) is selected, maybe default to NO date?
        // If "Recent" or "All", default to Today.
        DateTime? defaultScheduled;
        if (_inboxTaskCubit.currentFilterList.id == 'inbox') {
          defaultScheduled = null;
        } else {
          defaultScheduled = DateTime.now();
        }

        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider(
                  create: (context) => TaskEditorCubit(
                      _inboxTaskCubit.taskManager,
                      task: Task("",
                          created: DateTime.now(), scheduled: defaultScheduled),
                      createTasksPath: createTasksPath),
                  child: const TaskEditor()),
            ));
      },
    );
  }

  List<Card> _createViewItems(
      BuildContext context, List<Task> tasks, String highlightedText) {
    switch (_inboxTaskCubit.viewMode) {
      case ViewMode.calendar:
        return _createCalendarViews(tasks, context, highlightedText);
      case ViewMode.grouped:
        return _createFileViews(tasks, context, highlightedText);
      default:
        return tasks.map((task) {
          return _createTaskCard(context, task, highlightedText);
        }).toList();
    }
  }

  List<Card> _createCalendarViews(
      List<Task> tasks, BuildContext context, String highlightedText) {
    List<Card> calendarViews = [];
    List<TaskCard> calendarTasks = [];

    tasks.sort((a, b) {
      if (a.scheduled == null && b.scheduled == null) return 0;
      if (a.scheduled == null) return 1;
      if (b.scheduled == null) return -1;
      return a.scheduled!.compareTo(b.scheduled!);
    });

    int i = 0;
    bool hitPremiumLimit = false;
    for (var task in tasks) {
      if (!SettingsController.getInstance().hasActiveSubscription && i > 10) {
        calendarViews.add(_createPremiumUpgradeCalendarView(
            context, tasks.length - i, highlightedText));
        hitPremiumLimit = true;
        break;
      }

      if ((calendarTasks.isNotEmpty &&
              TaskManager.sameDate(
                  calendarTasks[0].task.scheduled, task.scheduled) &&
              task.scheduled != null) ||
          calendarTasks.isNotEmpty &&
              task.scheduled == null &&
              calendarTasks[0].task.scheduled == null) {
        calendarTasks.add(_createTaskCard(context, task, highlightedText));
      } else {
        if (calendarTasks.isNotEmpty) {
          calendarViews.add(CalendarView(
            List<TaskCard>.from(calendarTasks),
            highlightedText: highlightedText,
          ));
        }
        calendarTasks = [_createTaskCard(context, task, highlightedText)];
      }
      i++;
    }

    if (calendarTasks.isNotEmpty && !hitPremiumLimit) {
      calendarViews.add(CalendarView(
        calendarTasks,
        highlightedText: highlightedText,
      ));
    }

    return calendarViews;
  }

  Card _createPremiumUpgradeCalendarView(
      BuildContext context, int hiddenTasksCount, String highlightedText) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.1),
              Colors.orange.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upgrade to Premium',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You have $hiddenTasksCount more ${hiddenTasksCount == 1 ? 'task' : 'tasks'}. Upgrade to Premium to see all your tasks without limits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionScreen(
                        settingsController: SettingsController.getInstance(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FileView> _createFileViews(
      List<Task> tasks, BuildContext context, String highlightedText) {
    List<FileView> fileViews = [];
    List<TaskCard> fileTasks = [];
    for (var task in tasks) {
      if (fileTasks.isNotEmpty &&
          fileTasks[0].task.taskSource!.fileName == task.taskSource!.fileName) {
        fileTasks.add(_createTaskCard(context, task, highlightedText));
      } else {
        fileTasks = [_createTaskCard(context, task, highlightedText)];
        fileViews.add(FileView(
          fileTasks,
          highlightedText: highlightedText,
          vaultName: SettingsController.getInstance().vaultName!,
        ));
      }
    }

    return fileViews;
  }

  TaskCard _createTaskCard(
      BuildContext context, Task task, String highlightedText) {
    // Determine context-aware action for right button
    bool isScheduledToday =
        TaskManager.sameDate(task.scheduled, DateTime.now());

    return TaskCard(task, hightlightedText: highlightedText,
        taskDonePressed: (bool? res) {
      if (res != null) {
        _inboxTaskCubit.changeTaskStatus(
            task, res == true ? TaskStatus.done : TaskStatus.todo);
      }
    }, editTaskPressed: () {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider(
                create: (context) =>
                    TaskEditorCubit(_inboxTaskCubit.taskManager, task: task),
                child: const TaskEditor()),
          ));
    },
        rightButtonPressed: isScheduledToday
            ? () => _inboxTaskCubit.removeFromTodayPressed(task)
            : () => _inboxTaskCubit.assignForTodayPressed(task),
        rightButtonIcon: isScheduledToday
            ? Icons.remove_circle_outline
            : Icons.add_circle_outline,
        startWorkflowPressed: task.tags.contains("obsi_ai")
            ? () => _startWorkflowPressed(context, task)
            : null);
  }

  Future<void> _startWorkflowPressed(BuildContext context, Task task) async {
    if (context.mounted) {
      final mainNavigatorState =
          context.findAncestorStateOfType<State<MainNavigator>>();

      if (mainNavigatorState != null) {
        (mainNavigatorState as dynamic)
            .switchToAIWithMessage(task.description ?? '');
      }
    }
  }

  void _openFilterManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FilterManagementScreen()),
    );
  }
}
