import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:obsi/src/screens/calendar/cubit/calendar_cubit.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/widgets/task_card.dart';
import 'package:obsi/src/screens/task_editor/task_editor.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:path/path.dart' as p;
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/core/variable_resolver.dart';

class CalendarWidget extends StatelessWidget {
  final TaskManager taskManager;
  final List<Task> tasks; // Accept filtered tasks
  const CalendarWidget(
      {required this.taskManager, required this.tasks, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CalendarCubit(initialTasks: tasks), // Pass initial tasks
      child: _CalendarView(taskManager: taskManager, tasks: tasks),
    );
  }
}

class _CalendarView extends StatefulWidget {
  final TaskManager taskManager;
  final List<Task> tasks;
  const _CalendarView(
      {required this.taskManager, required this.tasks, Key? key})
      : super(key: key);

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  @override
  void didUpdateWidget(_CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks != oldWidget.tasks) {
      context.read<CalendarCubit>().updateTasks(widget.tasks);
    }
  }

  void _createTask(BuildContext context, DateTime selectedDate) async {
    var settings = SettingsController.getInstance();
    var resolvedTasksFile = VariableResolver.resolve(settings.tasksFile);
    var createTasksPath = p.join(settings.vaultDirectory!, resolvedTasksFile);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
            create: (context) => TaskEditorCubit(widget.taskManager,
                task: Task("",
                    created: DateTime.now(),
                    scheduled: selectedDate, // Pre-fill selected date
                    scheduledTime: false),
                createTasksPath: createTasksPath),
            child: const TaskEditor()),
      ),
    );
    if (result != null) {
      if (context.mounted) {
        // We might need to refresh InboxTasks to get new task, which will flow down to here.
        // Calling refresh on Cubit will re-process current _tasks.
        // But new task is in TaskManager, not in _tasks yet (until InboxRefreshes).
        // InboxTasks listens to lifecycle/updates.
        // If we want immediate update, we might rely on parent rebuild.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocBuilder<CalendarCubit, CalendarState>(
          builder: (context, state) {
            return Column(
              children: [
                TableCalendar<Task>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: state.focusedDate,
                  selectedDayPredicate: (day) =>
                      isSameDay(state.selectedDate, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    context
                        .read<CalendarCubit>()
                        .onDaySelected(selectedDay, focusedDay);
                  },
                  onPageChanged: (focusedDay) {
                    context.read<CalendarCubit>().onPageChanged(focusedDay);
                  },
                  eventLoader: (day) {
                    final normalized = DateTime(day.year, day.month, day.day);
                    return state.events[normalized] ?? [];
                  },
                  // Force format to month to prevent actual view switching
                  calendarFormat: CalendarFormat.month,
                  // Configure available formats to use the button as a toggle
                  // The button shows the text of the *other* format available.
                  // If we want button to say "Due" (when current is Scheduled), we map key 'twoWeeks' to "Due".
                  // When clicked, it tries to switch to 'twoWeeks', triggering onFormatChanged.
                  availableCalendarFormats:
                      state.filterMode == CalendarFilterMode.scheduled
                          ? {
                              CalendarFormat.month: 'Scheduled',
                              CalendarFormat.twoWeeks:
                                  'Due', // Button will show "Due"
                            }
                          : {
                              CalendarFormat.month: 'Due',
                              CalendarFormat.twoWeeks:
                                  'Scheduled', // Button will show "Scheduled"
                            },
                  onFormatChanged: (format) {
                    // Toggle filter mode instead of changing format
                    context.read<CalendarCubit>().toggleFilterMode();
                  },
                  calendarStyle: const CalendarStyle(
                    markersMaxCount: 3,
                    markerDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: true,
                    formatButtonShowsNext:
                        false, // Don't cycle, just show current
                    formatButtonDecoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    formatButtonTextStyle: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.black), // Ensure visibility
                  ),
                ),
                const Divider(),
                Expanded(
                  child: state.tasksForSelectedDate.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks for ${state.selectedDate.month}/${state.selectedDate.day}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 8.0,
                              right: 8.0,
                              bottom: 80.0), // Padding for FAB
                          itemCount: state.tasksForSelectedDate.length,
                          itemBuilder: (context, index) {
                            final task = state.tasksForSelectedDate[index];
                            return TaskCard(
                              task, // Positional
                              editTaskPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BlocProvider(
                                        create: (context) => TaskEditorCubit(
                                            widget.taskManager,
                                            task: task),
                                        child: const TaskEditor()),
                                  ),
                                );
                                // Update handled by parent stream usually
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: BlocBuilder<CalendarCubit, CalendarState>(
            builder: (context, state) {
              return FloatingActionButton(
                heroTag: 'calendarFab',
                onPressed: () => _createTask(context, state.selectedDate),
                child: const Icon(Icons.add),
              );
            },
          ),
        ),
      ],
    );
  }
}
