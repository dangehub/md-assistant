part of 'task_editor_cubit.dart';

@immutable
sealed class TaskEditorState {}

@immutable
final class TaskEditorInitial extends TaskEditorState {
  final Task? task;
  TaskEditorInitial(this.task);
}
