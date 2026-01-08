import 'package:bloc/bloc.dart';
import 'package:obsi/src/core/tasks/task.dart';

enum CalendarFilterMode { scheduled, due }

class CalendarState {
  final DateTime selectedDate;
  final DateTime focusedDate;
  final List<Task> tasksForSelectedDate;
  final Map<DateTime, List<Task>> events;
  final CalendarFilterMode filterMode;

  CalendarState({
    required this.selectedDate,
    required this.focusedDate,
    required this.tasksForSelectedDate,
    required this.events,
    this.filterMode = CalendarFilterMode.scheduled,
  });

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedDate,
    List<Task>? tasksForSelectedDate,
    Map<DateTime, List<Task>>? events,
    CalendarFilterMode? filterMode,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedDate: focusedDate ?? this.focusedDate,
      tasksForSelectedDate: tasksForSelectedDate ?? this.tasksForSelectedDate,
      events: events ?? this.events,
      filterMode: filterMode ?? this.filterMode,
    );
  }
}

class CalendarCubit extends Cubit<CalendarState> {
  // TaskManager not strictly needed if we push tasks from UI, but might be needed for other ops?
  // Current code uses passed tasks list. _taskManager was unused.
  // Wait, if I remove _taskManager field, I must remove it from constructor or keep it unused?
  // User asked to clean up unused field.
  // But CalendarWidget passes it. I will keep param but not store it if not needed, or better, remove it from constructor too.
  // If I remove it from constructor, I must update CalendarWidget.
  // Let's remove it completely.

  List<Task> _tasks;

  CalendarCubit({
    List<Task> initialTasks = const [],
  })  : _tasks = initialTasks,
        super(CalendarState(
          selectedDate: DateTime.now(),
          focusedDate: DateTime.now(),
          tasksForSelectedDate: [],
          events: {},
          filterMode: CalendarFilterMode.scheduled,
        )) {
    _init();
  }

  void _init() {
    // Initial Load
    _updateEvents();
  }

  void updateTasks(List<Task> tasks) {
    _tasks = tasks;
    _updateEvents();
  }

  void refresh() {
    _updateEvents();
  }

  void toggleFilterMode() {
    final newMode = state.filterMode == CalendarFilterMode.scheduled
        ? CalendarFilterMode.due
        : CalendarFilterMode.scheduled;
    emit(state.copyWith(filterMode: newMode));
    _updateEvents();
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Normalize date (strip time)
    final normalizedSelected =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    final tasks = state.events[normalizedSelected] ?? [];

    emit(state.copyWith(
      selectedDate: normalizedSelected,
      focusedDate: focusedDay,
      tasksForSelectedDate: tasks,
    ));
  }

  void onPageChanged(DateTime focusedDay) {
    emit(state.copyWith(focusedDate: focusedDay));
  }

  void _updateEvents() {
    final tasks = _tasks;
    final events = <DateTime, List<Task>>{};

    for (var task in tasks) {
      DateTime? targetDate;
      if (state.filterMode == CalendarFilterMode.scheduled) {
        targetDate = task.scheduled;
      } else if (state.filterMode == CalendarFilterMode.due) {
        targetDate = task.due;
      }

      if (targetDate != null) {
        final date =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add(task);
      }
    }

    // Update tasks for currently selected date
    final currentSelected = DateTime(state.selectedDate.year,
        state.selectedDate.month, state.selectedDate.day);
    final tasksForSelected = events[currentSelected] ?? [];

    emit(
        state.copyWith(events: events, tasksForSelectedDate: tasksForSelected));
  }
}
