part of 'inbox_tasks_cubit.dart';

sealed class InboxTasksState {}

final class InboxTasksInitial extends InboxTasksState {}

final class InboxTasksList extends InboxTasksState {
  final List<Task> tasks;
  InboxTasksList(this.tasks);
}

final class InboxTasksLoading extends InboxTasksState {
  String vault;
  InboxTasksLoading(this.vault);
}

final class InboxTasksMessage extends InboxTasksState {
  final String message;
  final List<Task> tasks;
  InboxTasksMessage(this.message, this.tasks);
}
